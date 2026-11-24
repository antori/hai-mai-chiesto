-- Kit «L'hai mai chiesto?» · motore (non serve modificarlo: si lavora in design.lua)
local loader = require("lib.loader")
local Model = require("lib.model")

local W, H = 360, 640            -- spazio logico (verticale, da telefono)
local S, OX, OY = 1, 0, 0
local fonts = {}
local d, warnings, loadError
local m, rng
local screen = "inizio"
local esito = {}
local hits = {}
local disp = {}
local time = 0
local auto                         -- autoplay per i test: lista di indici di azione
local revealed = false             -- alla fine: il messaggio si mostra solo dopo averlo chiesto a chi gioca

local C = {
  bg = { 0.075, 0.082, 0.106 }, panel = { 0.118, 0.129, 0.165 }, line = { 0.22, 0.24, 0.30 },
  text = { 0.93, 0.94, 0.96 }, dim = { 0.58, 0.61, 0.68 },
  social = { 1.00, 0.44, 0.60 }, chatbot = { 0.66, 0.55, 0.98 }, persona = { 0.20, 0.83, 0.60 },
  corpo = { 0.38, 0.70, 0.98 }, altro = { 0.70, 0.72, 0.78 },
  truth = { 0.98, 0.75, 0.15 }, pos = { 0.25, 0.80, 0.70 }, neg = { 0.98, 0.45, 0.40 },
  uni = { 1.00, 0.60, 0.20 }, button = { 0.20, 0.22, 0.29 }, buttonHi = { 0.27, 0.30, 0.40 },
}

local function font(size)
  local key = math.floor(size * S + 0.5)
  if not fonts[key] then fonts[key] = love.graphics.newFont(key) end
  return fonts[key]
end
local function setc(c, a) love.graphics.setColor(c[1], c[2], c[3], a or 1) end

local function text(str, size, x, y, limit, align, color, alpha)
  local f = font(size)
  setc(color or C.text, alpha)
  love.graphics.printf(str, f, x, y, (limit or W) * S, align or "left", 0, 1 / S, 1 / S)
  local _, lines = f:getWrap(str, (limit or W) * S)
  return #lines * f:getHeight() / S
end
local function textHeight(str, size, limit)
  local f = font(size)
  local _, lines = f:getWrap(str, limit * S)
  return #lines * f:getHeight() / S
end
local function textWidth(str, size) return font(size):getWidth(str) / S end
local function fitSize(str, sizes, limit, maxH)
  for _, s in ipairs(sizes) do if textHeight(str, s, limit) <= maxH then return s end end
  return sizes[#sizes]
end
local function rect(x, y, w, h, c, a, r)
  setc(c, a)
  love.graphics.rectangle("fill", x, y, w, h, r or 8, r or 8)
end
local function frame(x, y, w, h, c, a, r)
  setc(c, a); love.graphics.setLineWidth(1.5)
  love.graphics.rectangle("line", x, y, w, h, r or 8, r or 8)
end

local function button(label, x, y, w, h, onTap, opts)
  opts = opts or {}
  local enabled = opts.enabled ~= false
  rect(x, y, w, h, opts.color or (enabled and C.button or C.panel), enabled and 1 or 0.55, 10)
  if opts.accent and enabled then frame(x, y, w, h, opts.accent, 1, 10) end
  local size = fitSize(label, { 15, 14, 13, 12, 11 }, w - 14, h - 4)
  local th = textHeight(label, size, w - 14)
  text(label, size, x + 7, y + (h - th) / 2, w - 14, "center", enabled and C.text or C.dim)
  hits[#hits + 1] = { x = x, y = y, w = w, h = h, f = enabled and onTap or nil }
end

-- ---------------------------------------------------------------- avvio

local function resize(w, h)
  S = math.min(w / W, h / H)
  OX, OY = (w - W * S) / 2, (h - H * S) / 2
  fonts = {}
end

local function newGame()
  rng = love.math.newRandomGenerator(auto and 7 or os.time())
  m = Model.new(d, rng)
  revealed = false
  esito = {}
  disp = {}
  for k, v in pairs(m.vars) do disp[k] = v end
end

function love.load(args)
  love.graphics.setDefaultFilter("linear", "linear")
  for i, a in ipairs(args or {}) do
    if a == "--auto" and args[i + 1] then
      auto = { list = {}, i = 0, t = 0, shots = 0 }
      for word in args[i + 1]:gmatch("[^,]+") do auto.list[#auto.list + 1] = tonumber(word) or 1 end
    end
  end
  resize(love.graphics.getDimensions())
  local w
  d, w = loader.load()
  if not d then loadError = w; screen = "errore"; return end
  warnings = w or {}
  local hidesSomething, canDiscover = false, false
  for _, e in ipairs(d.eventi) do if e.nasconde ~= "" then hidesSomething = true end end
  for _, a in ipairs(d.azioni) do if a.scopre then canDiscover = true end end
  if hidesSomething and not canDiscover then
    warnings[#warnings + 1] = "Alcuni eventi nascondono qualcosa, ma nessuna azione ha scopre = true"
  end
  newGame()
end

function love.resize(w, h) resize(w, h) end

local function startTurn()
  m:startTurn()
  esito = {}
  screen = "turno"
end
local function doAction(i)
  esito = m:act(i)
  screen = "esito"
end
local function nextStep()
  if m:isOver() then screen = "fine" else startTurn() end
end

-- ---------------------------------------------------------------- disegno

local SRC = { social = "SOCIAL", chatbot = "CHATBOT", persona = "MESSAGGIO", corpo = "CORPO", altro = "" }

local function visible(g)
  if g.vista == "mai" then return false end
  return true
end
local function shown(g) return g.vista == "sempre" or (g.vista == "se scopri" and m.revealed) end

-- Divide le grandezze tra intestazione (pallini, numeri) e pannello (barre).
local function layoutQuantities()
  local head, rows = {}, {}
  for _, g in ipairs(d.grandezze) do
    if visible(g) then
      if g.stile == "barra" then rows[#rows + 1] = g else head[#head + 1] = g end
    end
  end
  if d.confronta then -- la coppia da confrontare va su righe vicine
    local a, b
    for i, g in ipairs(rows) do
      if g.nome == d.confronta[1] then a = i elseif g.nome == d.confronta[2] then b = i end
    end
    if a and b and math.abs(a - b) > 1 then
      local gb = table.remove(rows, b)
      if b < a then a = a - 1 end
      table.insert(rows, a + 1, gb)
    end
  end
  return head, rows
end

-- Le grandezze in alto (pallini e numeri), da destra a sinistra. Quelle che non stanno
-- accanto a «Turno» scendono su una seconda riga: niente sovrapposizioni, niente tagli.
-- Restituisce dove finisce l'intestazione.
local function drawHeader(head)
  text("Turno " .. m.turno .. " di " .. d.turni, 13, 14, 11, 120, "left", C.dim)
  local row, x, minX = 1, W - 14, 140
  for i = #head, 1, -1 do
    local g = head[i]
    local lw = textWidth(g.etichetta, 12) + 6
    local val, vw, n
    if g.stile == "pallini" then
      n = math.floor(g.max + 0.5); vw = n * 12
    else
      val = shown(g) and Model.fmt(m.vars[g.nome] or 0) or "?"; vw = textWidth(val, 13) + 4
    end
    if x - vw - lw < minX and x < W - 14 then row, x, minX = row + 1, W - 14, 14 end
    local dy = (row - 1) * 22
    if n then
      local v = shown(g) and math.floor((m.vars[g.nome] or 0) + 0.5) or -1
      local x0 = x - vw
      for k = 1, n do
        setc(C.truth, (v >= k) and 1 or 0.22)
        if v < 0 then setc(C.dim, 0.5) end
        love.graphics.circle("fill", x0 + (k - 1) * 12 + 5, 19 + dy, 4.5)
      end
    else
      text(val, 13, x - vw, 11 + dy, vw, "right", C.text)
    end
    text(g.etichetta, 12, x - vw - lw, 12 + dy, lw, "left", C.dim)
    x = x - vw - lw - 12
  end
  return 38 + (row - 1) * 22
end

local function firstDiscover()
  for _, a in ipairs(d.azioni) do if a.scopre then return a end end
end

local function drawCard(y, h)
  local ev = m.current
  local x, w = 12, W - 24
  rect(x, y, w, h, C.panel, 1, 12)
  local col = C[ev.fonte] or C.altro
  rect(x, y, 5, h, col, 1, 3)
  local chip = SRC[ev.fonte] or ""
  local who = m:fill(ev.chi)
  if who ~= "" then chip = (chip ~= "" and (chip .. " · ") or "") .. who end
  if chip ~= "" then text(chip, 11, x + 16, y + 9, w - 30, "left", col) end
  local body = m:fill(ev.mostra)
  local hidden = m:fill(ev.nasconde)
  local avail = h - 32
  if m.revealed and hidden ~= "" then
    local s = 15
    for _, cand in ipairs({ 15, 14, 13, 12, 11 }) do
      s = cand
      if textHeight(body, cand, w - 32) + 10 + textHeight("Davvero: " .. hidden, cand - 1, w - 32) <= avail then break end
    end
    local bh = text(body, s, x + 16, y + 26, w - 32, "left", C.text)
    setc(C.truth, 0.5); love.graphics.setLineWidth(1); love.graphics.line(x + 16, y + 30 + bh, x + w - 16, y + 30 + bh)
    text("Davvero: " .. hidden, s - 1, x + 16, y + 36 + bh, w - 32, "left", C.truth)
  else
    local hint = ""
    if hidden ~= "" then
      local a = firstDiscover()
      hint = a and ("c'è qualcosa dietro: lo scopri con «" .. m:fill(a.nome) .. "»") or "c'è qualcosa dietro"
    end
    local hh = hint ~= "" and textHeight(hint, 11, w - 32) or 0
    local s = fitSize(body, { 17, 16, 15, 14, 13, 12 }, w - 32, avail - hh - 4)
    text(body, s, x + 16, y + 26, w - 32, "left", C.text)
    if hint ~= "" then text(hint, 11, x + 16, y + h - 6 - hh, w - 32, "left", C.dim, 0.85) end
  end
end

local BX, BW = 128, 188          -- barra; il valore sta a destra (fino a 346)
local function bx(g, v) return BX + (v - g.min) / math.max(1e-9, g.max - g.min) * BW end

local function drawBar(g, yc, value, isHidden)
  if isHidden then -- tratteggio: c'è, ma non si vede (il «?» sta nella colonna del valore)
    setc(C.dim, 0.7); love.graphics.setLineWidth(1)
    for k = 0, math.floor(BW / 12) - 1 do love.graphics.line(BX + k * 12, yc, BX + k * 12 + 6, yc) end
    return nil
  end
  rect(BX, yc - 4, BW, 8, C.line, 1, 4)
  local zero = (g.min < 0 and g.max > 0) and bx(g, 0) or BX
  if g.min < 0 and g.max > 0 then
    setc(C.dim, 0.6); love.graphics.rectangle("fill", zero - 0.5, yc - 7, 1, 14)
  end
  local xv = bx(g, value)
  if math.abs(xv - zero) > 0.5 then
    local col = C.uni
    if g.min < 0 then col = value >= 0 and C.pos or C.neg end
    rect(math.min(zero, xv), yc - 4, math.abs(xv - zero), 8, col, 1, 4)
  end
  if g.vista == "se scopri" then frame(BX - 2, yc - 6, BW + 4, 12, C.truth, 0.9, 6) end
  return xv
end

local function drawPanel(y0, y1, rows)
  rect(12, y0, W - 24, y1 - y0, C.panel, 1, 12)
  text(string.upper(m:fill(d.protagonista)), 11, 26, y0 + 7, 200, "left", C.dim)
  local y = y0 + 26
  if #d.opinioni > 0 then
    text("opinione", 14, 16, y + 2, 110, "left", C.text)
    text("cosa crede", 10, 16, y + 19, 110, "left", C.dim)
    local cx, cy, any = BX, y, false
    for _, o in ipairs(m.opinioni) do
      if o.stato ~= "assente" then
        any = true
        local t = m:fill(o.def.testo)
        local tw = math.min(textWidth(t, 11) + 14, BW)
        if cx + tw > BX + BW and cx > BX then cx = BX; cy = cy + 22 end
        local active = o.stato == "attiva"
        rect(cx, cy, tw, 19, active and C.chatbot or C.line, active and 0.85 or 0.6, 9)
        text(t, 11, cx + 7, cy + 3, tw - 10, "left", active and C.text or C.dim)
        if not active then setc(C.dim); love.graphics.setLineWidth(1); love.graphics.line(cx + 6, cy + 10, cx + tw - 6, cy + 10) end
        cx = cx + tw + 6
      end
    end
    if not any then text("nessuna, per ora", 12, BX, y + 3, BW, "left", C.dim) end
    y = math.max(y + 44, cy + 26)
  end
  if #rows == 0 then return end
  local rh = math.max(26, math.min(46, (y1 - 8 - y) / #rows))
  local marks = {}
  for i, g in ipairs(rows) do
    local yc = y + (i - 0.5) * rh
    local isHidden = not shown(g)
    local name = g.etichetta
    local val = isHidden and "?" or Model.fmt(disp[g.nome] or 0)
    local small = rh < 34
    -- etichetta su una riga sola: si rimpicciolisce, poi si accorcia (mai sopra la riga dopo)
    local LW = 104
    local function fitLine(t, size)
      if textWidth(t, size) <= LW then return t end
      local cut = t
      while #cut > 1 and textWidth(cut .. "…", size) > LW do
        cut = cut:sub(1, -2):gsub("[\192-\255][\128-\191]*$", function(c) return c end)
        cut = cut:gsub("[\192-\255]$", "")
      end
      return cut .. "…"
    end
    local ns = small and 13 or 14
    while ns > 11 and textWidth(name, ns) > LW do ns = ns - 0.5 end
    text(fitLine(name, ns), ns, 16, yc - (g.spiega ~= "" and not small and 13 or 8), LW + 30, "left", C.text)
    if g.spiega ~= "" and not small then text(fitLine(g.spiega, 10), 10, 16, yc + 4, LW + 30, "left", C.dim) end
    text(val, 11, BX + BW + 4, yc - 7, W - 14 - (BX + BW + 4), "right", isHidden and C.dim or C.text, 0.85)
    marks[g.nome] = { x = drawBar(g, yc, disp[g.nome] or 0, isHidden), y = yc }
  end
  if d.confronta then
    local A, B = marks[d.confronta[1]], marks[d.confronta[2]]
    if A and B and A.x and B.x and m:test(d.confronta.se) then
      local gap = math.abs((m.vars[d.confronta[1]] or 0) - (m.vars[d.confronta[2]] or 0))
      local up, dn = A, B
      if B.y < A.y then up, dn = B, A end
      if gap >= 8 then
        setc(C.truth, 0.9); love.graphics.setLineWidth(2)
        love.graphics.line(up.x, up.y + 5, dn.x, dn.y - 5)
        -- l'etichetta va nell'intestazione del pannello: lì non tocca mai linee o barre
        local ga, gb = m.defs[d.confronta[1]], m.defs[d.confronta[2]]
        local lbl = "distanza tra " .. ga.etichetta .. " e " .. gb.etichetta .. ": " .. Model.fmt(gap)
        text(lbl, 11, 120, y0 + 7, W - 26 - 120, "right", C.truth)
      end
      setc(C.truth); love.graphics.polygon("fill", A.x, A.y - 8, A.x + 7, A.y, A.x, A.y + 8, A.x - 7, A.y)
      setc(C.text); love.graphics.circle("fill", B.x, B.y, 6)
    end
  end
end

local STYLE = { dim = C.dim, truth = C.truth, bot = C.chatbot, op = C.text, opfall = C.dim, rule = C.uni }

local function drawEsito(y, h)
  local lines = esito
  if screen == "turno" then
    lines = {}
    for _, l in ipairs(m.startLines or {}) do lines[#lines + 1] = l end
    if #lines == 0 then
      text("Cosa fa " .. m:fill(d.protagonista) .. "?", 14, 14, y + 4, W - 28, "left", C.dim)
      return
    end
  end
  local all = {}
  for _, l in ipairs(lines) do all[#all + 1] = l[1] end
  local s = fitSize(table.concat(all, "\n"), { 13, 12, 11, 10.5 }, W - 28, h)
  for _, l in ipairs(lines) do
    y = y + text(l[1], s, 14, y, W - 28, "left", STYLE[l[2]] or C.text) + 1
  end
end

local function buttonsLayout()
  local n = math.min(6, #d.azioni)
  local rows = (n == 1) and 1 or math.ceil(n / 2)
  local bh = rows * 42 + (rows - 1) * 8
  return n, rows, bh, H - 10 - bh
end

local function drawButtons(y0, n)
  if screen == "turno" then
    local gw = (W - 34) / 2
    for i = 1, n do
      local a = d.azioni[i]
      local col, row = (i - 1) % 2, math.floor((i - 1) / 2)
      local x, w = 12 + col * (gw + 10), gw
      if n == 1 or (i == n and n % 2 == 1) then x, w = 12, W - 24 end
      local accent = a.scopre and C.truth or (#a.risposte > 0 and C.chatbot or nil)
      button(m:fill(a.nome), x, y0 + row * 50, w, 42, function() doAction(i) end,
        { enabled = m:available(a), accent = accent })
    end
  elseif screen == "esito" then
    local _, _, bh = buttonsLayout()
    button(m:isOver() and "Vedi il finale ›" or "Avanti ›", 12, y0 + bh - 52, W - 24, 52, nextStep, { color = C.buttonHi })
  end
end

local function drawGame()
  local head, rows = layoutQuantities()
  local top = drawHeader(head)
  local n, _, _, by = buttonsLayout()
  local ey = by - 8 - 56
  local need = 26 + (#d.opinioni > 0 and 44 or 0) + #rows * 30 + 8
  local ch = 140
  if top + ch + 8 + need > ey - 6 then ch = math.max(104, ey - 6 - 8 - need - top) end
  drawCard(top, ch)
  drawPanel(top + ch + 8, ey - 6, rows)
  drawEsito(ey, 56)
  drawButtons(by, n)
end

local function drawStart()
  local y = 64
  text("LAZZARETTO HOSPES", 11, 0, y, W, "center", C.dim)
  text("Lo hai mai fatto? Parliamo d'amore", 11, 0, y + 15, W, "center", C.dim)
  y = y + 42
  y = y + text(m:fill(d.titolo), 28, 20, y, W - 40, "center", C.text) + 6
  if d.autori ~= "" then y = y + text(m:fill(d.autori), 13, 20, y, W - 40, "center", C.dim) + 4 end
  if d.temaNome ~= "" then y = y + text("tema: " .. d.temaNome, 12, 20, y, W - 40, "center", C.truth) + 4 end
  y = y + 14
  local intro = d.presentazione ~= "" and m:fill(d.presentazione)
    or ("Ogni turno succede qualcosa. Scegli cosa fa " .. m:fill(d.protagonista) .. ". Alla fine scoprirai cosa voleva dire chi ha fatto il gioco.")
  text(intro, 15, 28, y + 10, W - 56, "left", C.text)
  button("Inizia", 60, 462, W - 120, 52, startTurn, { color = C.buttonHi })
  if warnings and #warnings > 0 then
    local msg = "Attenzione: " .. table.concat(warnings, " · ")
    local s = fitSize(msg, { 11, 10.5 }, W - 32, 640 - 530)
    text(msg, s, 16, 528, W - 32, "left", C.truth)
  end
end

local function drawEnd()
  local f = m:ending()
  -- Box di aiuto: fisso, non modificabile da design.lua.
  local help = "Se questa storia ti somiglia, parlane con qualcuno di cui ti fidi.\n"
    .. "Telefono Azzurro 19696 · gratis, anche in chat\n"
    .. "Telefono Verde AIDS e IST 800 861061 · anonimo\n"
    .. "Emergenze 112"
  local hh = textHeight(help, 12, W - 48) + 16
  local hy = 640 - 74 - hh
  local titolo, testo, msg = m:fill(f.titolo), m:fill(f.testo), m:fill(d.messaggio)
  local parts = {}
  for _, g in ipairs(d.grandezze) do
    if g.vista ~= "mai" then parts[#parts + 1] = g.etichetta .. " " .. Model.fmt(m.vars[g.nome] or 0) end
  end
  local stats = table.concat(parts, "  ·  ")
  -- Prima si chiede a chi gioca cosa ha capito; solo dopo si mostra il messaggio.
  local ask = "Secondo voi, cosa voleva dire chi ha fatto questo gioco? Ditelo ad alta voce, poi scopritelo."
  local after = "Era quello che avevate capito?"
  local function panelH(s)
    if msg == "" then return 0 end
    if revealed then return 22 + textHeight(msg, s, W - 48) + 6 + textHeight(after, 11, W - 48) + 10 end
    return 22 + textHeight(ask, s - 1, W - 48) + 8 + 38 + 10
  end
  local size = 14
  for _, s in ipairs({ 14, 13, 12, 11 }) do   -- il testo si rimpicciolisce finché tutto sta sopra il box di aiuto
    size = s
    local need = 44 + textHeight(titolo, 24, W - 40) + 10 + textHeight(testo, s, W - 44) + 12
      + (stats ~= "" and (textHeight(stats, s - 2, W - 44) + 12) or 0) + panelH(s) + 8
    if need <= hy then break end
  end
  local y = 26
  text("FINALE", 11, 0, y, W, "center", C.dim)
  y = y + 18
  y = y + text(titolo, 24, 20, y, W - 40, "center", C.text) + 10
  y = y + text(testo, size, 22, y, W - 44, "left", C.text) + 12
  if stats ~= "" then y = y + text(stats, size - 2, 22, y, W - 44, "left", C.dim) + 12 end
  if msg ~= "" then
    local ph = panelH(size)
    rect(12, y, W - 24, ph, C.panel, 1, 12)
    if revealed then
      text("IL MESSAGGIO DI CHI HA FATTO IL GIOCO", 10, 24, y + 8, W - 48, "left", C.social)
      local mh = text(msg, size, 24, y + 22, W - 48, "left", C.text)
      text(after, 11, 24, y + 22 + mh + 6, W - 48, "left", C.dim)
    else
      text("PRIMA DI SCOPRIRE IL MESSAGGIO", 10, 24, y + 8, W - 48, "left", C.truth)
      local ah = text(ask, size - 1, 24, y + 22, W - 48, "left", C.text)
      button("Scopri il messaggio", 24, y + 22 + ah + 8, W - 48, 38, function() revealed = true end, { accent = C.truth })
    end
  end
  rect(12, hy, W - 24, hh, C.persona, 0.14, 12)
  text(help, 12, 24, hy + 8, W - 48, "left", C.text)
  button("Gioca ancora", 60, 640 - 62, W - 120, 46, function() newGame(); screen = "inizio" end, { color = C.buttonHi })
end

local function drawError()
  text("Il vostro design.lua ha un errore", 20, 20, 120, W - 40, "center", C.truth)
  text(loadError or "", 15, 24, 200, W - 48, "left", C.text)
  text("Correggete il file e premete di nuovo «Gioca». Spesso è una virgola o una virgoletta mancante.",
    13, 24, 420, W - 48, "left", C.dim)
end

function love.update(dt)
  time = time + dt
  if m then
    local k = math.min(1, dt * 6)
    for name, v in pairs(m.vars) do
      local cur = disp[name] or v
      disp[name] = cur + (v - cur) * k
    end
  end
  if auto and screen ~= "errore" then
    auto.t = auto.t + dt
    if auto.t > 0.5 then
      auto.t = 0
      if screen == "inizio" then
        if not auto.started then love.graphics.captureScreenshot("auto_inizio.png"); auto.started = true
        else startTurn() end
      elseif screen == "turno" and not auto.turnShot then
        love.graphics.captureScreenshot("auto_turno.png"); auto.turnShot = true
      elseif screen == "turno" then
        auto.i = auto.i + 1
        local i = auto.list[((auto.i - 1) % #auto.list) + 1]
        if not d.azioni[i] or not m:available(d.azioni[i]) then i = #d.azioni end
        doAction(i)
      elseif screen == "esito" then
        if not auto.captured then
          auto.shots = auto.shots + 1
          love.graphics.captureScreenshot(string.format("auto_%02d.png", auto.shots))
          auto.captured = true
        else
          auto.captured = false
          nextStep()
        end
      elseif screen == "fine" then
        if not auto.fine1 then
          love.graphics.captureScreenshot("auto_fine.png"); auto.fine1 = true
        elseif not revealed then
          revealed = true
        else
          love.graphics.captureScreenshot("auto_fine2.png")
          print("FINE " .. m:ending().titolo)
          auto = nil
          love.event.quit()
        end
      end
    end
  end
end

function love.draw()
  love.graphics.clear(C.bg)
  hits = {}
  love.graphics.push()
  love.graphics.translate(OX, OY)
  love.graphics.scale(S)
  if screen == "errore" then drawError()
  elseif screen == "inizio" then drawStart()
  elseif screen == "fine" then drawEnd()
  else drawGame() end
  love.graphics.pop()
end

local function tap(px, py)
  local x, y = (px - OX) / S, (py - OY) / S
  for i = #hits, 1, -1 do
    local h = hits[i]
    if x >= h.x and x <= h.x + h.w and y >= h.y and y <= h.y + h.h then
      if h.f then h.f() end
      return
    end
  end
end

function love.mousereleased(x, y, button, istouch)
  if not istouch and button == 1 then tap(x, y) end
end
function love.touchreleased(id, x, y) tap(x, y) end
function love.keypressed(k) if k == "escape" then love.event.quit() end end
