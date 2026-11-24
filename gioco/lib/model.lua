-- Il motore del kit: tutto ciò che succede è scritto nel design.lua del gruppo.
--
-- Un turno:
--   1. regole «inizio turno»
--   2. arriva un evento: mostra qualcosa, ne nasconde un'altra; applica i suoi effetti
--   3. il giocatore sceglie UNA azione: effetti, risposte, eventuale «scopre»
--   4. regole «fine turno», opinioni che nascono o cadono, finali anticipati
-- Dopo l'ultimo turno vince il primo finale la cui condizione è vera.

local expr = require("lib.expr")

local Model = {}
Model.__index = Model

local function clamp(v, a, b)
  if a and v < a then return a end
  if b and v > b then return b end
  return v
end

function Model.new(d, rng)
  local m = setmetatable({}, Model)
  m.d, m.rng = d, rng
  m.vars, m.defs = {}, {}
  for _, g in ipairs(d.grandezze) do
    m.vars[g.nome] = g.inizio
    m.defs[g.nome] = g
  end
  m.vars.turni = d.turni
  m.turno, m.vars.turno = 0, 0
  m.env = { vars = m.vars, rng = rng }
  m.next = 1
  m.replies = {}
  m.opinioni = {}
  for i, o in ipairs(d.opinioni) do m.opinioni[i] = { def = o, stato = "assente" } end
  m.early = nil
  return m
end

local function fmt(v)
  if type(v) ~= "number" then return tostring(v) end
  local r = math.floor(v + 0.5)
  return tostring(r)
end
Model.fmt = fmt

function Model:lastOpinion()
  local last
  for _, o in ipairs(self.opinioni) do if o.stato == "attiva" then last = o end end
  return last
end

-- {nome} → protagonista, {opinione} → ultima opinione attiva, {like} → valore della grandezza
function Model:fill(text)
  text = tostring(text or "")
  return (text:gsub("{([^{}]+)}", function(key)
    local k = key:lower():gsub("^%s+", ""):gsub("%s+$", "")
    if k == "nome" then return self.d.protagonista end
    if k == "opinione" then
      local o = self:lastOpinion()
      if not o then return "{opinione}" end
      local t = self:fill(o.def.testo)
      return t:sub(1, 1):lower() .. t:sub(2)
    end
    if self.vars[k] ~= nil then return fmt(self.vars[k]) end
    return "{" .. key .. "}"
  end))
end

function Model:test(c) return expr.test(c, self.env) end

function Model:apply(eff)
  if not eff then return end
  for _, e in ipairs(eff.list) do
    local v = expr.eval(e.ast, self.env)
    local cur = self.vars[e.name] or 0
    if e.op == "=" then cur = v
    elseif e.op == "+" then cur = cur + v
    elseif e.op == "-" then cur = cur - v
    elseif e.op == "*" then cur = cur * v
    elseif e.op == "/" then cur = (v == 0) and cur or cur / v
    end
    local g = self.defs[e.name]
    if g then cur = clamp(cur, g.min, g.max) end
    self.vars[e.name] = cur
  end
end

function Model:runRules(when, out)
  for _, r in ipairs(self.d.regole) do
    if r.quando == when and self:test(r.se) then
      self:apply(r.allora)
      if r.testo ~= "" then out[#out + 1] = { self:fill(r.testo), "rule" } end
    end
  end
end

function Model:checkEarly()
  if self.early then return end
  for _, f in ipairs(self.d.finali) do
    if f.subito and self:test(f.condizione) then self.early = f; return end
  end
end

local QUIET = { fonte = "altro", chi = "", mostra = "Oggi non succede niente di speciale.", nasconde = "", quiet = true }

function Model:pickEvent()
  local list = self.d.eventi
  if #list == 0 then return QUIET end
  if self.d.ordine == "a caso" then
    local ok = {}
    for _, e in ipairs(list) do if self:test(e.se) then ok[#ok + 1] = e end end
    if #ok == 0 then return QUIET end
    return ok[self.rng:random(1, #ok)]
  end
  for step = 0, #list - 1 do
    local i = ((self.next - 1 + step) % #list) + 1
    local e = list[i]
    if self:test(e.se) then
      self.next = i + 1
      return e
    end
  end
  return QUIET
end

function Model:startTurn()
  self.turno = self.turno + 1
  self.vars.turno = self.turno
  self.revealed = false
  local out = {}
  self:runRules("inizio turno", out)
  local ev = self:pickEvent()
  self.current = ev
  self:apply(ev.effetti)
  self:checkEarly()
  self.startLines = out
  return ev
end

function Model:available(a) return self:test(a.se) end

function Model:act(i)
  local a = self.d.azioni[i]
  local out = {}
  if not a or not self:available(a) then return out end
  self:apply(a.effetti)
  if a.scopre and not self.revealed then
    self.revealed = true
    self:apply(self.current.se_scopri)
  end
  if #a.risposte > 0 then
    local n = #a.risposte
    local idx = self.replies[i] or 0
    local text
    for _ = 1, n do
      idx = idx % n + 1
      local r = a.risposte[idx]
      if not r:find("{opinione}", 1, true) or self:lastOpinion() then text = self:fill(r); break end
    end
    self.replies[i] = idx
    if text then
      out[#out + 1] = { (a.chi ~= "" and (self:fill(a.chi) .. ": ") or "") .. "«" .. text .. "»", "bot" }
    end
  end
  if a.dopo ~= "" then out[#out + 1] = { self:fill(a.dopo), "dim" } end
  if a.scopre and self.current.nasconde ~= "" and a.dopo == "" then
    out[#out + 1] = { "Ora sai cosa c'era dietro.", "truth" }
  end
  self:runRules("fine turno", out)
  local now = self.vars
  for _, o in ipairs(self.opinioni) do
    if o.stato == "assente" and self:test(o.def.nasce) then
      o.stato = "attiva"
      out[#out + 1] = { "Nuova opinione: «" .. self:fill(o.def.testo) .. "»", "op" }
    elseif o.stato == "attiva" and o.def.cade and self:test(o.def.cade) then
      o.stato = "caduta"
      out[#out + 1] = { "Messa in discussione: «" .. self:fill(o.def.testo) .. "»", "opfall" }
    end
  end
  self:checkEarly()
  return out
end

function Model:isOver() return self.early ~= nil or self.turno >= self.d.turni end

function Model:ending()
  if self.early then return self.early end
  for _, f in ipairs(self.d.finali) do
    if self:test(f.condizione) then return f end
  end
  return self.d.finali[#self.d.finali]
end

return Model
