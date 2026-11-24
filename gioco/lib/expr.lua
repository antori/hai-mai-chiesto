-- Il piccolo linguaggio dei gruppi: effetti e condizioni.
--
--   effetti:     "like + caso(30, 50), coraggio - 1, emozione = vissuto"
--   condizioni:  "chatbot >= 4"   "sentimento < -15 e chiesto >= 2"   "a > b o c == 0"
--
-- Numeri, nomi di grandezze, + - * / e parentesi.
-- Funzioni: caso(a, b)  abs(x)  min(a, b)  max(a, b)  segno(x)  limita(x, da, a)  arrotonda(x)
-- Nelle condizioni: >  <  >=  <=  ==  !=  e si uniscono con «e» / «o».
-- Funziona con Lua 5.1 (LÖVE) e 5.3 (fengari).

local expr = {}

local NAME_START = "[%a_\128-\255]"
local NAME_REST = "[%w_\128-\255]"

expr.FUNZIONI = { caso = 2, abs = 1, min = 2, max = 2, segno = 1, limita = 3, arrotonda = 1 }
expr.RISERVATI = { e = true, o = true, ["and"] = true, ["or"] = true }

local function err(msg) error({ expr = true, msg = msg }, 0) end

local function tokenize(s)
  local toks, i, n = {}, 1, #s
  while i <= n do
    local c = s:sub(i, i)
    if c:match("%s") then
      i = i + 1
    elseif c:match("%d") or (c == "." and s:sub(i + 1, i + 1):match("%d")) then
      local num = s:match("^%d*%.?%d+", i)
      toks[#toks + 1] = { t = "num", v = tonumber(num) }
      i = i + #num
    elseif c:match(NAME_START) then
      local name = s:match("^" .. NAME_START .. NAME_REST .. "*", i)
      toks[#toks + 1] = { t = "name", v = name:lower() }
      i = i + #name
    else
      local two = s:sub(i, i + 1)
      if two == ">=" or two == "<=" or two == "==" or two == "!=" or two == "~=" then
        toks[#toks + 1] = { t = "cmp", v = two }
        i = i + 2
      elseif c == ">" or c == "<" then
        toks[#toks + 1] = { t = "cmp", v = c }
        i = i + 1
      elseif c == "=" then
        toks[#toks + 1] = { t = "=", v = "=" }
        i = i + 1
      elseif ("+-*/(),"):find(c, 1, true) then
        toks[#toks + 1] = { t = c, v = c }
        i = i + 1
      else
        err("non capisco il simbolo «" .. c .. "»")
      end
    end
  end
  toks[#toks + 1] = { t = "end", v = "fine" }
  return toks
end

local Parser = {}
Parser.__index = Parser

local function newParser(s)
  return setmetatable({ toks = tokenize(s), p = 1, names = {} }, Parser)
end
function Parser:peek() return self.toks[self.p] end
function Parser:next() local t = self.toks[self.p]; self.p = self.p + 1; return t end
function Parser:expect(t, what)
  local tok = self:next()
  if tok.t ~= t then err("mi aspettavo " .. what .. " e trovo «" .. tostring(tok.v) .. "»") end
  return tok
end

function Parser:primary()
  local t = self:next()
  if t.t == "num" then return { k = "num", v = t.v } end
  if t.t == "(" then
    local e = self:sum()
    self:expect(")", "una parentesi chiusa )")
    return e
  end
  if t.t == "name" then
    if expr.RISERVATI[t.v] then err("«" .. t.v .. "» qui non va bene: è una parola delle condizioni") end
    if self:peek().t == "(" then
      local arity = expr.FUNZIONI[t.v]
      if not arity then err("la funzione «" .. t.v .. "» non esiste") end
      self:next()
      local args = {}
      if self:peek().t ~= ")" then
        args[1] = self:sum()
        while self:peek().t == "," do self:next(); args[#args + 1] = self:sum() end
      end
      self:expect(")", "una parentesi chiusa )")
      if #args ~= arity then err(t.v .. "(...) vuole " .. arity .. (arity == 1 and " valore" or " valori")) end
      return { k = "call", f = t.v, args = args }
    end
    self.names[t.v] = true
    return { k = "var", name = t.v }
  end
  if t.t == "end" then err("manca un valore alla fine") end
  err("qui ci vuole un numero o un nome, non «" .. tostring(t.v) .. "»")
end

function Parser:unary()
  if self:peek().t == "-" then self:next(); return { k = "neg", a = self:unary() } end
  if self:peek().t == "+" then self:next(); return self:unary() end
  return self:primary()
end

function Parser:product()
  local a = self:unary()
  while self:peek().t == "*" or self:peek().t == "/" do
    local op = self:next().t
    a = { k = "bin", op = op, a = a, b = self:unary() }
  end
  return a
end

function Parser:sum()
  local a = self:product()
  while self:peek().t == "+" or self:peek().t == "-" do
    local op = self:next().t
    a = { k = "bin", op = op, a = a, b = self:product() }
  end
  return a
end

function Parser:comparison()
  local a = self:sum()
  local t = self:next()
  if t.t ~= "cmp" and t.t ~= "=" then
    err("in una condizione serve un confronto (>, <, >=, <=, ==, !=) dopo il primo valore")
  end
  return { k = "cmp", op = (t.v == "=" and "==" or t.v), a = a, b = self:sum() }
end

function Parser:isWord(w1, w2)
  local t = self:peek()
  return t.t == "name" and (t.v == w1 or t.v == w2)
end

function Parser:conj()
  local a = self:comparison()
  while self:isWord("e", "and") do self:next(); a = { k = "and", a = a, b = self:comparison() } end
  return a
end

function Parser:disj()
  local a = self:conj()
  while self:isWord("o", "or") do self:next(); a = { k = "or", a = a, b = self:conj() } end
  return a
end

local function wrap(fn)
  local ok, res = pcall(fn)
  if ok then return res end
  if type(res) == "table" and res.expr then return nil, res.msg end
  return nil, tostring(res)
end

local function namesList(set)
  local out = {}
  for k in pairs(set) do out[#out + 1] = k end
  table.sort(out)
  return out
end

-- Condizione → { ast, names } oppure nil, errore. Vuota = sempre vera.
function expr.condition(text)
  if text == nil or tostring(text):match("^%s*$") then return { always = true, names = {} } end
  return wrap(function()
    local p = newParser(tostring(text))
    local ast = p:disj()
    if p:peek().t ~= "end" then err("non capisco «" .. tostring(p:peek().v) .. "» (per unire due condizioni usate «e» oppure «o»)") end
    return { ast = ast, names = namesList(p.names) }
  end)
end

-- Effetti → { list = { {name, op, ast}, ... }, names, targets } oppure nil, errore.
function expr.effects(text)
  if text == nil or tostring(text):match("^%s*$") then return { list = {}, names = {}, targets = {} } end
  return wrap(function()
    local p = newParser(tostring(text))
    local list, targets = {}, {}
    while true do
      local t = p:next()
      if t.t ~= "name" then err("ogni effetto inizia con il nome di una grandezza (esempio: like + 10)") end
      local op = p:next()
      if not (op.t == "+" or op.t == "-" or op.t == "*" or op.t == "/" or op.t == "=") then
        err("dopo «" .. t.v .. "» ci vuole + - * / oppure =")
      end
      list[#list + 1] = { name = t.v, op = op.t, ast = p:sum() }
      targets[t.v] = true
      local sep = p:next()
      if sep.t == "end" then break end
      if sep.t ~= "," then err("tra due effetti ci vuole una virgola (vicino a «" .. tostring(sep.v) .. "»)") end
    end
    return { list = list, names = namesList(p.names), targets = namesList(targets) }
  end)
end

local function eval(n, env)
  local k = n.k
  if k == "num" then return n.v end
  if k == "var" then return env.vars[n.name] or 0 end
  if k == "neg" then return -eval(n.a, env) end
  if k == "bin" then
    local a, b = eval(n.a, env), eval(n.b, env)
    if n.op == "+" then return a + b elseif n.op == "-" then return a - b
    elseif n.op == "*" then return a * b else return b == 0 and 0 or a / b end
  end
  if k == "call" then
    local v = {}
    for i, a in ipairs(n.args) do v[i] = eval(a, env) end
    local f = n.f
    if f == "caso" then
      local lo, hi = math.floor(math.min(v[1], v[2]) + 0.5), math.floor(math.max(v[1], v[2]) + 0.5)
      return env.rng:random(lo, hi)
    elseif f == "abs" then return math.abs(v[1])
    elseif f == "min" then return math.min(v[1], v[2])
    elseif f == "max" then return math.max(v[1], v[2])
    elseif f == "segno" then return v[1] > 0 and 1 or (v[1] < 0 and -1 or 0)
    elseif f == "limita" then return math.max(v[2], math.min(v[3], v[1]))
    elseif f == "arrotonda" then return math.floor(v[1] + 0.5)
    end
  end
  if k == "cmp" then
    local a, b = eval(n.a, env), eval(n.b, env)
    local op = n.op
    if op == ">" then return a > b elseif op == "<" then return a < b
    elseif op == ">=" then return a >= b elseif op == "<=" then return a <= b
    elseif op == "==" then return math.abs(a - b) < 1e-9 else return math.abs(a - b) >= 1e-9 end
  end
  if k == "and" then return eval(n.a, env) and eval(n.b, env) end
  if k == "or" then return eval(n.a, env) or eval(n.b, env) end
  return 0
end
expr.eval = eval

function expr.test(c, env)
  if not c then return false end
  if c.always then return true end
  if c.never then return false end
  return eval(c.ast, env) and true or false
end

return expr
