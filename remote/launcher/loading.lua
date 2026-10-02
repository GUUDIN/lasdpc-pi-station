-- ============================================================
-- loading.lua — animacao do overlay lasdpc-loading (script do mpv).
-- Desenha, por cima do PNG estatico com o titulo, uma barra de progresso
-- indeterminada, a etapa atual e o tempo decorrido. A etapa vem do arquivo
-- ~/.config/lasdpc/loading_status, escrito por `lasdpc-loading --status`.
-- Texto iniciado por "!" e exibido como erro (vermelho, sem barra).
-- ============================================================
local W, H = 1920, 1080
local CX, CY = W / 2, H / 2
local BAR_W, BAR_H, SEG_W = 560, 10, 170
local SLOW_AFTER = 25 -- s sem terminar -> mostra dica de cancelamento

local status_path = (os.getenv("HOME") or "/home/lasdpc") .. "/.config/lasdpc/loading_status"
local t0 = mp.get_time()
local status_text = ""

local overlay = mp.create_osd_overlay("ass-events")
overlay.res_x, overlay.res_y = W, H

-- cores ASS sao &HBBGGRR&
local ACCENT, TRACK, MUTED, DIM, ERR = "&H42C5F4&", "&H3A3129&", "&HCAC0B7&", "&H8A8178&", "&H6B6BFF&"

local function rect(x, y, w, h, color, clip)
  local c = clip and string.format("\\clip(%d,%d,%d,%d)", clip[1], clip[2], clip[3], clip[4]) or ""
  return string.format("{\\an7\\pos(%d,%d)\\bord0\\shad0\\1c%s%s\\p1}m 0 0 l %d 0 %d %d 0 %d{\\p0}",
    x, y, color, c, w, w, h, h)
end

local function text(x, y, size, color, s)
  -- escapa chaves para o texto nao ser interpretado como tag ASS
  s = s:gsub("\\", "\\\\"):gsub("{", "\\{"):gsub("}", "\\}")
  return string.format("{\\an8\\pos(%d,%d)\\fs%d\\bord0\\shad0\\fnDejaVu Sans\\1c%s}%s", x, y, size, color, s)
end

local function read_status()
  local f = io.open(status_path, "r")
  if not f then status_text = ""; return end
  status_text = (f:read("*l") or ""):gsub("%s+$", "")
  f:close()
end

local function render()
  local t = mp.get_time() - t0
  local secs = math.floor(t)
  local is_err = status_text:sub(1, 1) == "!"
  local lines = {}
  local bx, by = CX - BAR_W / 2, CY + 95

  if is_err then
    table.insert(lines, text(CX, by - 20, 34, ERR, status_text:sub(2)))
    table.insert(lines, text(CX, by + 40, 24, DIM, "Voltando ao menu..."))
  else
    -- barra indeterminada: um segmento que percorre o trilho em loop
    local span = BAR_W + SEG_W
    local sx = bx - SEG_W + (t * 420) % span
    table.insert(lines, rect(bx, by, BAR_W, BAR_H, TRACK))
    table.insert(lines, rect(sx, by, SEG_W, BAR_H, ACCENT, { bx, by, bx + BAR_W, by + BAR_H }))
    local stage = status_text ~= "" and status_text or "Preparando..."
    table.insert(lines, text(CX, by + 34, 30, MUTED, stage))
    table.insert(lines, text(CX, by + 82, 24, DIM, secs .. " s"))
    if t > SLOW_AFTER then
      table.insert(lines, text(CX, by + 130, 24, DIM,
        "Ainda carregando — a primeira vez pode demorar. Super+Esc cancela."))
    end
  end
  overlay.data = table.concat(lines, "\n")
  overlay:update()
end

read_status()
render()
mp.add_periodic_timer(0.4, read_status)
mp.add_periodic_timer(1 / 30, render)
