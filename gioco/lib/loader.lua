-- Legge design.lua, traduce gli errori in italiano, completa ciò che manca
-- e controlla che ogni nome usato negli effetti e nelle condizioni esista.
local expr = require("lib.expr")

local L = {}

local function num(v, def)
  v = tonumber(v)
  if v == nil then return def end
  return v
end
local function str(v, def)
  if v == nil then return def end
  return tostring(v)
end
local function list(v) return type(v) == "table" and v or {} end

function L.read()
  if love.filesystem.getInfo("design_utente.lua") then
    return love.filesystem.read("design_utente.lua"), "design.lua"
  end
  local okio, f = pcall(function() return io and io.open and io.open("/design_utente.lua", "r") end)
  if okio and f then
    local s = f:read("*a"); f:close()
    if s and #s > 0 then return s, "design.lua" end
  end
  return love.filesystem.read("design.lua"), "design.lua"
end

function L.italian(err)
  err = tostring(err)
  local line, msg = err:match(":(%d+):%s*(.*)$")
  msg = msg or err
  local function near(m) return m:match("near '(.-)'$") or m:match("near (.-)$") or "" end
  local out
  local closeLine = msg:match("to close '{' at line (%d+)")
  if closeLine then
    out = "manca una virgola o una } : la { aperta alla riga " .. closeLine .. " non si chiude bene (vicino a «" .. near(msg) .. "»)"
  elseif msg:find("unfinished string", 1, true) then
    out = "una frase non ha le virgolette di chiusura \""
  elseif msg:find("'}' expected", 1, true) then
    out = "manca una virgola prima di «" .. near(msg) .. "» (o una } di troppo prima)"
  elseif msg:find("'=' expected", 1, true) then
    out = "manca un = vicino a «" .. near(msg) .. "»"
  elseif msg:find("unexpected symbol", 1, true) then
    out = "simbolo inatteso vicino a «" .. near(msg) .. "»: controllate virgole e virgolette alla riga prima"
  elseif msg:find("malformed number", 1, true) then
    out = "un numero è scritto male (vicino a «" .. near(msg) .. "»)"
  elseif msg:find("'<eof>' expected", 1, true) then
    out = "c'è qualcosa dopo la } finale del file"
  else
    out = msg
  end
  if line then return "Riga " .. line .. ": " .. out end
  return out
end

function L.parse(src, name)
  if not src or src == "" then return nil, "Il file design.lua è vuoto." end
  -- Lua 5.1 (LÖVE, love.js) usa loadstring + setfenv; Lua 5.3 (fengari) usa load con ambiente.
  local chunk, err
  if setfenv then
    chunk, err = loadstring(src, "=" .. (name or "design.lua"))
    if chunk then setfenv(chunk, {}) end
  else
    chunk, err = load(src, "=" .. (name or "design.lua"), "t", {})
  end
  if not chunk then return nil, L.italian(err) end
  local ok, res = pcall(chunk)
  if not ok then return nil, L.italian(res) end
  if type(res) ~= "table" then return nil, "Il file deve iniziare con «return {» e finire con «}»." end
  return res
end

local FONTI = { social = true, chatbot = true, persona = true, corpo = true, altro = true }
local VISTE = { sempre = true, ["se scopri"] = true, mai = true }
local STILI = { barra = true, numero = true, pallini = true }

function L.normalize(raw)
  local w, d = {}, {}
  local known = { turno = true, turni = true }
  local function warn(t) if #w < 12 then w[#w + 1] = t end end

  d.titolo = str(raw.titolo, "Senza titolo")
  d.autori = str(raw.autori, "")
  d.messaggio = str(raw.messaggio, "")
  local TEMI = { social = "Social", chatbot = "Chatbot e IA", male = "Stare male", corpo = "Corpo e salute", relazioni = "Relazioni" }
  d.tema = str(raw.tema, "")
  d.temaNome = TEMI[d.tema] or ""
  d.presentazione = str(raw.presentazione, "")
  d.protagonista = str(raw.protagonista, "Ale")
  d.turni = math.floor(math.max(1, math.min(40, num(raw.turni, 10))))
  d.ordine = (str(raw.ordine, "in fila") == "a caso") and "a caso" or "in fila"

  -- grandezze
  d.grandezze = {}
  for i, g in ipairs(list(raw.grandezze)) do
    if type(g) == "table" then
      local nome = str(g.nome, ""):lower():gsub("%s+", "_")
      if not nome:match("^[%a_\128-\255][%w_\128-\255]*$") or expr.RISERVATI[nome] or nome == "nome" or nome == "opinione" or nome == "turno" or nome == "turni" then
        warn("Grandezza " .. i .. ": il nome «" .. str(g.nome, "") .. "» non va bene (lettere, numeri e _; non «e», «o», «turno»)")
      elseif known[nome] then
        warn("Grandezza «" .. nome .. "» definita due volte")
      else
        known[nome] = true
        local inizio = num(g.inizio, 0)
        local mn = num(g.min, inizio < 0 and -100 or 0)
        local mx = num(g.max, 100)
        if mx < mn then mn, mx = mx, mn end
        local vista = str(g.vista, "sempre")
        if not VISTE[vista] then warn("Grandezza «" .. nome .. "»: vista deve essere \"sempre\", \"se scopri\" o \"mai\""); vista = "sempre" end
        local stile = g.stile and str(g.stile, "") or nil
        if stile and not STILI[stile] then warn("Grandezza «" .. nome .. "»: stile deve essere \"barra\", \"numero\" o \"pallini\""); stile = nil end
        if not stile then stile = (mn >= -100 and mx <= 100) and "barra" or "numero" end
        if stile == "pallini" and (mx > 9 or mn < 0) then stile = "barra" end
        d.grandezze[#d.grandezze + 1] = {
          nome = nome, etichetta = str(g.etichetta, (nome:gsub("_", " "))), spiega = str(g.spiega, ""),
          inizio = math.max(mn, math.min(mx, inizio)), min = mn, max = mx, vista = vista, stile = stile,
        }
      end
    end
  end

  local used = {}
  local function cond(text, where)
    local c, e = expr.condition(text)
    if not c then warn(where .. ": " .. e); return { never = true, names = {} } end
    for _, n in ipairs(c.names) do used[n] = used[n] or where end
    return c
  end
  local function eff(text, where)
    local c, e = expr.effects(text)
    if not c then warn(where .. ": " .. e); return { list = {}, names = {}, targets = {} } end
    for _, n in ipairs(c.names) do used[n] = used[n] or where end
    for _, n in ipairs(c.targets) do used[n] = used[n] or where end
    return c
  end

  -- azioni
  d.azioni = {}
  for i, a in ipairs(list(raw.azioni)) do
    if type(a) == "table" then
      local where = "Azione «" .. str(a.nome, tostring(i)) .. "»"
      local risposte = {}
      for _, r in ipairs(list(a.risposte)) do risposte[#risposte + 1] = tostring(r) end
      d.azioni[#d.azioni + 1] = {
        nome = str(a.nome, "Azione " .. i), chi = str(a.chi, ""), dopo = str(a.dopo, ""),
        effetti = eff(a.effetti, where), se = cond(a.se, where .. " (se)"),
        scopre = a.scopre == true or a.scopre == "sì" or a.scopre == "si", risposte = risposte,
      }
    end
  end
  if #d.azioni == 0 then return nil, "Non c'è nessuna azione: aggiungete almeno un'azione nella sezione «azioni»." end
  if #d.azioni > 6 then warn("Ci sono " .. #d.azioni .. " azioni: il gioco ne mostra solo 6") end

  -- regole
  d.regole = {}
  for i, r in ipairs(list(raw.regole)) do
    if type(r) == "table" then
      local where = "Regola «" .. str(r.nome, tostring(i)) .. "»"
      local q = str(r.quando, "fine turno")
      if q ~= "inizio turno" and q ~= "fine turno" then warn(where .. ": quando deve essere \"inizio turno\" o \"fine turno\""); q = "fine turno" end
      d.regole[#d.regole + 1] = {
        nome = str(r.nome, "Regola " .. i), quando = q, testo = str(r.testo, ""),
        se = cond(r.se, where .. " (se)"), allora = eff(r.allora, where),
      }
    end
  end

  -- eventi
  d.eventi = {}
  for i, e in ipairs(list(raw.eventi)) do
    if type(e) == "table" then
      local f = str(e.fonte, "persona")
      if f == "feed" then f = "social" end
      if not FONTI[f] then warn("Evento " .. i .. ": la fonte «" .. f .. "» non esiste, uso «altro»"); f = "altro" end
      local where = "Evento " .. i
      d.eventi[#d.eventi + 1] = {
        fonte = f, chi = str(e.chi, ""), mostra = str(e.mostra, "..."), nasconde = str(e.nasconde, ""),
        effetti = eff(e.effetti, where), se_scopri = eff(e.se_scopri, where .. " (se scopri)"), se = cond(e.se, where .. " (se)"),
      }
    end
  end
  if #d.eventi == 0 then return nil, "Non c'è nessun evento: aggiungete almeno un evento nella sezione «eventi»." end

  -- opinioni
  d.opinioni = {}
  for i, o in ipairs(list(raw.opinioni)) do
    if type(o) == "table" then
      local where = "Opinione " .. i
      d.opinioni[#d.opinioni + 1] = {
        testo = str(o.testo, "..."), nasce = cond(o.nasce_se or "turno < 0", where .. " (nasce se)"),
        cade = (o.cade_se and o.cade_se ~= "") and cond(o.cade_se, where .. " (cade se)") or nil,
      }
    end
  end

  -- finali
  d.finali = {}
  for i, f in ipairs(list(raw.finali)) do
    if type(f) == "table" then
      d.finali[#d.finali + 1] = {
        titolo = str(f.titolo, "Fine"), testo = str(f.testo, ""),
        condizione = cond(f.se, "Finale " .. i), subito = f.subito == true and f.se ~= nil and f.se ~= "",
      }
    end
  end
  if #d.finali == 0 then d.finali = { { titolo = "Fine", testo = "", condizione = { always = true } } } end

  -- confronta = { "emozione", "vissuto" }: una linea mostra la distanza tra due grandezze
  if type(raw.confronta) == "table" and raw.confronta[1] and raw.confronta[2] then
    local a, b = str(raw.confronta[1], ""):lower(), str(raw.confronta[2], ""):lower()
    if known[a] and known[b] then d.confronta = { a, b, se = cond(raw.confronta.se, "confronta (se)") }
    else warn("confronta: «" .. a .. "» o «" .. b .. "» non è una grandezza") end
  end

  -- nomi usati ma mai definiti: il gioco li crea a 0 e avvisa
  local missing = {}
  for n, where in pairs(used) do
    if not known[n] then missing[#missing + 1] = n end
  end
  table.sort(missing)
  for _, n in ipairs(missing) do
    warn(used[n] .. ": la grandezza «" .. n .. "» non esiste (la creo a 0, nascosta)")
    d.grandezze[#d.grandezze + 1] = { nome = n, etichetta = n, spiega = "", inizio = 0, vista = "mai", stile = "numero" }
  end
  return d, w
end

function L.load()
  local src, name = L.read()
  local raw, err = L.parse(src, name)
  if not raw then return nil, err end
  local d, w = L.normalize(raw)
  if not d then return nil, w end
  return d, w
end

return L
