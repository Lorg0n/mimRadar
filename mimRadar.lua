script_name 'mimRadar'
script_author 'GovnocodeLua'
script_version '0.2.1'

local im = require 'mimgui'
local samp = require 'samp.events'
local new = im.new
local vec2, vec4 = im.ImVec2, im.ImVec4

-- 3D -> World Coordinates
-- Global2D -> Coordinates On 6K MAP
-- 2D -> Coordinates on Radar

local assetsPath = thisScript().directory .. "\\mimRadar\\"
local configPath = assetsPath .. 'mimradar.json'

local cfg, im_cfg = {
    mapFileName = "map2048.png",
    show = false,
    width = 450,
    height = 250,
    scale = 0.1,
    iconSize = 15.0,
}, {
    map_texture = nil,
    marker_texture = nil,
    north_texture = nil,
    gang_zone = {},
    map_icons = {},
    players = {},
}

function main()
    while not isSampAvailable() do wait(0) end
    cfg = readJson(configPath, cfg)

    sampRegisterChatCommand('radar', showRadar)
    sampRegisterChatCommand('setwidth', changeWidth)
    sampRegisterChatCommand('setheight', changeHeight)
    sampRegisterChatCommand('setscale', changeScale)
    sampRegisterChatCommand('seticon', changeIconSize)
    sampRegisterChatCommand('resetcfg', resetCfg)
    wait(-1)
end

function resetCfg()
    writeJson(configPath, 
    {
        mapFileName = "map2048.png",
        show = false,
        width = 450,
        height = 250,
        scale = 0.1,
        iconSize = 15.0,
    })
end

function changeWidth(args)
    args = tonumber(args)
    if args ~= nil and args > 0 then
        cfg.width = args
        writeJson(configPath, cfg)
    end
end

function changeIconSize(args)
    args = tonumber(args)
    if args ~= nil and args > 0 then
        cfg.iconSize = args
        writeJson(configPath, cfg)
    end
end

function changeScale(args)
    args = tonumber(args)
    if args ~= nil and args > 0.0 and args < 1.0 then
        cfg.scale = args
        writeJson(configPath, cfg)
    end
end

function changeHeight(args)
    args = tonumber(args)
    if args ~= nil and args > 0 then
        cfg.height = args
        writeJson(configPath, cfg)
    end
end

im.OnFrame(function() return cfg.show and isCanRadarRender() end,
function()
    local flags = im.WindowFlags.NoDecoration + im.WindowFlags.AlwaysAutoResize + im.WindowFlags.NoBackground + im.WindowFlags.NoSavedSettings
    local sx, sy = getScreenResolution()
    local positionX, positionY, positionZ = getCharCoordinates(PLAYER_PED)

    displayRadar(false)

    im.SetNextWindowPos(vec2(0, sy), im.Cond.Always, vec2(0, 1))
    im.Begin('radar', nil, flags)
    im.BeginChild('radarBorder', vec2(cfg.width * 1.2, cfg.height * 1.2), false)
    im.SetCursorPos(vec2((cfg.width * 1.2 - cfg.width) * 0.5, (cfg.height * 1.2 - cfg.height) * 0.5))
    renderLockedRadar(vec2(positionX, positionY), vec2(cfg.width, cfg.height), cfg.scale, im_cfg.map_texture, 20.0)
    im.EndChild()
    im.End()
end).HideCursor = true

im.OnInitialize(function()
	im_cfg.map_texture = im.CreateTextureFromFile(assetsPath .. 'map2048.png')
    im_cfg.marker_texture = im.CreateTextureFromFile(assetsPath .. 'marker.png')
    im_cfg.north_texture = im.CreateTextureFromFile(assetsPath .. 'north.png')
	im.GetIO().IniFilename = nil
end)

function renderLockedRadar(center, size, scale, map, rounding)
    local cursorPos = im.GetCursorPos()
    local screenPos = im.GetCursorScreenPos()
    local ratio = size.x / size.y
    local minIconSize = math.min(size.x, size.y) / cfg.iconSize
    local strUniq = string.format('radar<%s; %s, %s>:', screenPos.x, screenPos.y, scale)

    im.BeginChild('##child' .. strUniq, size, nil)
    local dw = im.GetWindowDrawList()
    im.SetCursorPos(vec2(0, 0))
    im.InvisibleButton('##invBtn', size)

    local function transform3DtoGlobal2D(pos)
        return vec2(pos.x + 3000, -pos.y + 3000)
    end
    local function transform3Dto2D(pos)
        local gc = transform3DtoGlobal2D(pos)
        local gcnorm = vec2(gc.x / 6000, gc.y / 6000)
        local cen, square = transform3DtoGlobal2D(center), vec2(0, 0)
        if ratio >= 1 then
            square.x = ((gcnorm.x + scale) - (gcnorm.x - scale)) * 6000
            square.y = ((gcnorm.y + scale / ratio) - (gcnorm.y - scale / ratio)) * 6000
        else
            square.x = ((gcnorm.x + scale * ratio) - (gcnorm.x - scale * ratio)) * 6000
            square.y = ((gcnorm.y + scale) - (gcnorm.y - scale)) * 6000
        end
        return vec2(size.x * (gc.x - (cen.x - square.x / 2)) / square.x, size.y * (gc.y - (cen.y - square.y / 2)) / square.y)
    end
    local function drawRadar()
        local gc = vec2(transform3DtoGlobal2D(center).x / 6000, transform3DtoGlobal2D(center).y / 6000)
        if ratio >= 1 then
            dw:AddImage(map, screenPos, vec2(screenPos.x + size.x, screenPos.y + size.y), vec2(gc.x - scale, gc.y - scale / ratio), vec2(gc.x + scale, gc.y + scale / ratio), 0xFFFFFFFF)
        else
            dw:AddImage(map, screenPos, vec2(screenPos.x + size.x, screenPos.y + size.y), vec2(gc.x - scale * ratio, gc.y - scale), vec2(gc.x + scale * ratio, gc.y + scale), 0xFFFFFFFF)
        end
    end
    local function drawRadarCenter()
        local glcen = transform3Dto2D(center)
        local cen = vec2(screenPos.x + glcen.x, screenPos.y + glcen.y)
        local radius = minIconSize * 0.5
        local colors = {
            a = im.GetColorU32Vec4(im.ImVec4(0.68, 0.83, 1, 1)),
            b = im.GetColorU32Vec4(im.ImVec4(0.1, 0.1, 0.1, 0.2)),
            c = im.GetColorU32Vec4(im.ImVec4(1, 1, 1, 1)),
        }
        local theta = math.rad(45 - getAdaptiveHeading())
        local a = rotatePoint(vec2(cen.x - radius, cen.y - radius), cen, theta)
        local b = rotatePoint(vec2(cen.x, cen.y - radius), cen, theta)
        local c = rotatePoint(vec2(cen.x - radius, cen.y), cen, theta)

        dw:AddCircleFilled(vec2(cen.x, cen.y), minIconSize * 1.5, colors.b, minIconSize * 1.5 * 1.5)
        dw:AddCircleFilled(vec2(cen.x, cen.y), minIconSize * 1, colors.b, minIconSize * 1 * 1.5)
        dw:AddTriangleFilled(a, b, c, colors.a)
        dw:AddCircleFilled(vec2(cen.x, cen.y), radius, colors.a, radius * 1.5)
    end
    local function drawMapIcon()
        for k, v in pairs(im_cfg.map_icons) do
            local gl = transform3Dto2D(vec2(v.position.x, v.position.y))
            local res, px, py = getPointInRect(0, 0, size.x, size.y, gl.x, gl.y)
            local sz = minIconSize * 1

            if not res then
                dw:AddImage(v.texture, vec2(screenPos.x + px - sz, screenPos.y + py - sz), vec2(screenPos.x + px + sz, screenPos.y + py + sz), vec2(0, 0), vec2(1, 1), 0xFFFFFFFF)
            end
        end
    end
    local function drawGangZone()
        for k, v in pairs(im_cfg.gang_zone) do
            local glStart = transform3Dto2D(vec2(v.squareStart.x, v.squareStart.y))
            local glEnd = transform3Dto2D(vec2(v.squareEnd.x, v.squareEnd.y))
            local resStart, xstart, ystart = getPointInRect(0, 0, size.x, size.y, glStart.x, glStart.y)
            local resEnd, xend, yend = getPointInRect(0, 0, size.x, size.y, glEnd.x, glEnd.y)

            if not (resStart and resEnd) then
                dw:AddRectFilled(vec2(screenPos.x + xstart, screenPos.y + ystart), vec2(screenPos.x + xend, screenPos.y + yend), v.color, 0.0)
            end
        end
    end
    local function drawPlayers()
        for k, v in pairs(getAllChars()) do
            local posX, posY, posZ = getCharCoordinates(v)
            local gl = transform3Dto2D(vec2(posX, posY))
            local res, px, py = getPointInRect(0, 0, size.x, size.y, gl.x, gl.y)
            local res_, id = sampGetPlayerIdByCharHandle(v)

            if not res and res_ and v ~= PLAYER_PED then
                local colors = {
                    a = im.GetColorU32Vec4(im.ImVec4(1.0, 0.96, 0.61, 1.0)),
                    b = im.GetColorU32Vec4(im.ImVec4(0.0, 0.0, 0.0, 0.2)),
                }
                dw:AddCircleFilled(vec2(screenPos.x + px, screenPos.y + py), minIconSize * 0.8, colors.b, minIconSize * 0.5 * 1.5)
                dw:AddCircleFilled(vec2(screenPos.x + px, screenPos.y + py), minIconSize * 0.55, colors.b, minIconSize * 0.55 * 1.5)
                dw:AddCircleFilled(vec2(screenPos.x + px, screenPos.y + py), minIconSize * 0.4, colors.a, minIconSize * 0.4 * 1.5)
            end
        end
    end
    local function drawGlobalIcon()
        local sz = minIconSize * 1.0

        local res, px, py = getPointInRect(0, 0, size.x, size.y, size.x / 2, 0)
        dw:AddImage(im_cfg.north_texture, vec2(screenPos.x + px - sz, screenPos.y + py - sz), vec2(screenPos.x + px + sz, screenPos.y + py + sz), vec2(0, 0), vec2(1, 1), 0xFFFFFFFF)
        
        local result, posX, posY, posZ = getTargetBlipCoordinates()
        if result then
            local gl = transform3Dto2D(vec2(posX, posY))
            local res, px, py = getPointInRect(0, 0, size.x, size.y, gl.x, gl.y)
            dw:AddImage(im_cfg.marker_texture, vec2(screenPos.x + px - sz, screenPos.y + py - sz), vec2(screenPos.x + px + sz, screenPos.y + py + sz), vec2(0, 0), vec2(1, 1), 0xFFFFFFFF)
        end
    end

    drawRadar()
    drawGangZone()
    drawMapIcon()
    drawPlayers()
    drawRadarCenter()
    im.EndChild()

    drawGlobalIcon()
end

function showRadar()
    cfg.show = not cfg.show 
    writeJson(configPath, cfg)
end

-- @Musaigen
function readJson(path, def)
	if doesFileExist(path) then
		local f = io.open(path, 'r+')
		local data = decodeJson(f:read('*a'))
		f:close()
        print('Configuration loaded')
		return data
	else
        print('Default configuration is loaded')
        writeJson(path, cfg)
		return def
	end
end

function writeJson(path, data) 
	if type(data) ~= 'table' then
		return
	end
	local f = io.open(path, 'w')
	local writing_data = encodeJson(data)
	f:write(writing_data)
	f:close()
    print('Configuration saved')
end

function getPointInRect(x1, y1, x2, y2, px, py) -- upper, bottom, point
    local res, x, y = false, px, py
    local lines = {
        {{x1, y1}, {x2, y1}},
        {{x2, y1}, {x2, y2}},
        {{x2, y2}, {x1, y2}},
        {{x1, y2}, {x1, y1}},
    }
    for _, v in pairs(lines) do
        local result, x3, y3 = get2dLinesIntersectPoint(v[1][1], v[1][2], v[2][1], v[2][2], (x2 - x1) * 0.5, (y2 - y1) * 0.5, px, py)
        if result then
            res, x, y = result, x3, y3
        end
    end
    return res, x, y
end

function rotatePoint(p, c, angle)
    local x = math.cos(angle) * (p.x - c.x) - math.sin(angle) * (p.y - c.y) + c.x
    local y = math.sin(angle) * (p.x-c.x) + math.cos(angle) * (p.y-c.y) + c.y
    return vec2(x, y)
end

function isCanRadarRender()
    local res = isSampAvailable() and not isGamePaused() and isSampLoaded()
    return res
end

function getAdaptiveHeading()
    if isCharInAnyCar(PLAYER_PED) then
        return getHeading()
    end
    return getCameraHeading()
end

function getCameraHeading()
    local x1, y1, z1 = getActiveCameraPointAt()
    local x2, y2, z2 = getActiveCameraCoordinates()
    return getHeadingFromVector2d(x1 - x2, y1 - y2)
end

function getHeading()
    if isCharInAnyCar(PLAYER_PED) then
        return getCarHeading(storeCarCharIsInNoSave(PLAYER_PED))
    end
    return getCharHeading(PLAYER_PED)
end

function samp.onCreateGangZone(zoneId, squareStart, squareEnd, color) -- zoneId = 'int16'}, {squareStart = 'vector2d'}, {squareEnd = 'vector2d'}, {color = 'int32'}
    im_cfg.gang_zone[zoneId] = {}
    im_cfg.gang_zone[zoneId] = {
        squareStart = squareStart,
        squareEnd = squareEnd,
        color = color,
    }
end

function samp.onSetMapIcon(iconId, position, type, color, style) --{iconId = 'int8'}, {position = 'vector3d'}, {type = 'int8'}, {color = 'int32'}, {style = 'int8'}}
    local path = assetsPath .. tostring(type) .. '.png'
    if doesFileExist(path) then
        im_cfg.map_icons[iconId] = {}
        im_cfg.map_icons[iconId] = {
            position = position,
            type = type,
            color = color,
            style = style,
            texture = im.CreateTextureFromFile(path),
        }
    end
end

function samp.onGangZoneDestroy(zoneId)
    if im_cfg.gang_zone[zoneId] ~= nil then
        im_cfg.gang_zone[zoneId] = nil
    end
end

function samp.onRemoveMapIcon(iconId)
    if im_cfg.map_icons[iconId] ~= nil then
        im_cfg.map_icons[iconId] = nil
    end
end