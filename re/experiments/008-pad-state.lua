-- ------------------------------------------------------------------
-- Experiment 008 (part 2): Real-time sampling of PadState (0x80069920)
-- and RNG seeds (0x8005f220 / 0x8005f224) during live movement in PCSX-Redux.
--
-- Precondition: PCSX-Redux running Crash Bandicoot 2 (SCUS-94154) inside a
--               playable level (unpaused at start). Load/execute in the PCSX-Redux
--               Lua Console and, during ~1.5 s (45 logical frames), move the
--               D-pad/stick and press a button (e.g. Cross or Square).
-- Output:       PCSX-Redux Lua Console + /tmp/exp008_pad_state.txt (if io.open
--               is available).
-- Writes memory: no (read-only via PCSX.getMemPtr()).
-- ------------------------------------------------------------------

local ffi = require('ffi')
local bit = require('bit')

local MAX_FRAMES = 45
local OUT_PATH   = '/tmp/exp008_pad_state.txt'

local mem = PCSX.getMemPtr()
local u8  = ffi.cast('const uint8_t*', mem)
local u32 = ffi.cast('const uint32_t*', mem)
local i32 = ffi.cast('const int32_t*', mem)

local function phys(va)
    return bit.band(va, 0x1fffff)
end

local function r_u8(va)
    return tonumber(u8[phys(va)])
end

local function r_u32(va)
    return tonumber(u32[bit.rshift(phys(va), 2)])
end

local function r_i32(va)
    return tonumber(i32[bit.rshift(phys(va), 2)])
end

-- Clear any previous sampling hook if the script is reloaded.
if _G.__exp008_pad_bp ~= nil then
    pcall(function() _G.__exp008_pad_bp:remove() end)
    _G.__exp008_pad_bp = nil
end

local out_fh = nil
local ok_io, fh = pcall(io.open, OUT_PATH, 'w')
if ok_io and fh ~= nil then
    out_fh = fh
end

local function emit(line)
    print(line)
    if out_fh ~= nil then
        out_fh:write(line .. '\n')
        out_fh:flush()
    end
end

local frame = 0
local bp = nil

emit('=== Exp 008 Lua: muestreo PadState (0x80069920) por ' .. MAX_FRAMES .. ' cuadros ===')
emit('frame,fc,demo,raw_stat,type,pressed,held,prev1,angle,mag,dir,rng_a,rng_b,player_x,player_y,player_z')

bp = PCSX.addBreakpoint(0x8001645c, 'Exec', 4, 'exp008_pad_sample', function()
    frame = frame + 1

    local pad1      = 0x80069920
    local raw_stat  = r_u8(pad1 + 0x00)
    local pad_type  = r_u8(pad1 + 0x01)
    local pressed   = r_u32(pad1 + 0x24)
    local held      = r_u32(pad1 + 0x28)
    local prev1     = r_u32(pad1 + 0x2c)
    local angle     = r_i32(pad1 + 0x38)
    local mag       = r_i32(pad1 + 0x3c)
    local dir       = r_i32(pad1 + 0x40)

    local demo_mode = r_i32(0x8006cd14)
    local fc        = r_u32(0x8006ccf0)
    local rng_a     = r_u32(0x8005f220)
    local rng_b     = r_u32(0x8005f224)
    local player    = r_u32(0x8005f38c)

    local px, py, pz = 0, 0, 0
    if player >= 0x80060000 and player < 0x80200000 then
        px = r_i32(player + 0x60)
        py = r_i32(player + 0x64)
        pz = r_i32(player + 0x68)
    end

    emit(string.format(
        '%02d,%u,%d,0x%02x,0x%02x,0x%04x,0x%04x,0x%04x,%d,%d,%d,0x%08x,0x%08x,%d,%d,%d',
        frame, fc, demo_mode, raw_stat, pad_type,
        pressed, held, prev1, angle, mag, dir,
        rng_a, rng_b, px, py, pz
    ))

    if frame >= MAX_FRAMES then
        if bp ~= nil then
            bp:disable()
            PCSX.nextTick(function()
                if bp ~= nil then
                    bp:remove()
                    bp = nil
                end
                _G.__exp008_pad_bp = nil
                emit('=== Exp 008 Lua: muestreo finalizado (' .. MAX_FRAMES .. ' cuadros) ===')
                if out_fh ~= nil then
                    out_fh:close()
                    out_fh = nil
                end
            end)
        end
    end

    -- Return true so PCSX-Redux does not pause on any frame.
    return true
end)

_G.__exp008_pad_bp = bp
