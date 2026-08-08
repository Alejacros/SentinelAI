local cachedAlert = nil
local cachedDispatch = {}
local cachedVehicle = {}
local devNativeHudDisabled = false

local DISPATCH_LABELS = {
    OFF_DUTY = "OFF DUTY",
    WAITING = "AVAILABLE",
    PENDING = "CALL PENDING",
    BUSY = "BUSY",
    EN_ROUTE = "EN ROUTE",
    ON_SCENE = "ON SCENE",
    EVIDENCE = "EVIDENCE",
    TRANSPORT = "TRANSPORT",
    REPORT = "REPORT"
}

local function drawText(text, x, y, scale, r, g, b, alpha)
    SetTextFont(4)
    SetTextScale(scale, scale)
    SetTextColour(r or 238, g or 247, b or 255, alpha or 255)
    SetTextDropShadow(0, 0, 0, 0, 180)
    SetTextWrap(0.0, 0.98)

    BeginTextCommandDisplayText("STRING")
    AddTextComponentSubstringPlayerName(text)
    EndTextCommandDisplayText(x, y)
end

local function getOfficerName()
    local identity = PlayerData.Character
        and PlayerData.Character.identity
        or nil

    if not identity then
        return nil
    end

    local name = ((identity.firstName or "")
        .. " " .. (identity.lastName or "")):match("^%s*(.-)%s*$")

    return name ~= "" and name or nil
end

local function getProgress()
    local xp = PlayerData.XP or 0
    local nextRank = type(GetNextRank) == "function" and GetNextRank() or nil

    if not nextRank then
        return xp, xp, 1.0, "RANGO MAXIMO"
    end

    local ranks = type(GetCareerRanks) == "function" and GetCareerRanks() or {}
    local currentThreshold = 0

    for _, rank in ipairs(ranks) do
        if rank.requiredXP <= xp then
            currentThreshold = rank.requiredXP
        end
    end

    local range = math.max(1, nextRank.requiredXP - currentThreshold)
    local progress = math.max(0.0, math.min(1.0,
        (xp - currentThreshold) / range
    ))

    return xp, nextRank.requiredXP, progress, nextRank.name
end

local function shouldShow()
    return PlayerData
        and (PlayerData.OnDuty == true
            or (PlayerData.DispatchState
                and PlayerData.DispatchState ~= "OFF_DUTY"))
end

local function resolveWidgetPosition(config, width, height)
    local anchor = config and config.anchor or "TOP_RIGHT"
    local x = (config and config.x or 98) / 100
    local y = (config and config.y or 3) / 100

    if anchor == "TOP" or anchor == "BOTTOM" then
        x = x - width / 2
    elseif anchor == "TOP_RIGHT"
        or anchor == "RIGHT"
        or anchor == "BOTTOM_RIGHT" then

        x = x - width
    end

    if anchor == "LEFT" or anchor == "RIGHT" then
        y = y - height / 2
    elseif anchor == "BOTTOM_LEFT"
        or anchor == "BOTTOM"
        or anchor == "BOTTOM_RIGHT" then

        y = y - height
    end

    return math.max(0.01, math.min(0.99 - width, x)),
        math.max(0.01, math.min(0.99 - height, y))
end

local function drawPoliceHud()
    local safeMode = PoliceTerminalManager
        and PoliceTerminalManager.IsOpen()
        and PoliceTerminalManager.GetMode() == "DRIVER_SAFE"
    local hudLayout = WidgetLayout.NativeHUD.TOP_RIGHT
    local mode = safeMode and "DRIVER_SAFE"
        or (PoliceTerminalManager and PoliceTerminalManager.GetMode())
        or "PDA"
    local widgetConfig = WidgetLayoutManager.GetWidget(mode, "HUDWidget")

    if not widgetConfig or widgetConfig.visible ~= true then
        return
    end

    local uiScale = (WidgetLayout.UIScale or 1.0)
        * (widgetConfig.scale or 1.0)
    local width = hudLayout.width * uiScale
    local height = (safeMode
        and hudLayout.minimalHeight
        or hudLayout.fullHeight) * uiScale
    local x, y = resolveWidgetPosition(widgetConfig, width, height)
    local xp, nextXP, progress, nextRank = getProgress()
    local dispatch = cachedDispatch
    local vehicle = cachedVehicle
    local officer = getOfficerName()
    local rank = PlayerData.Rank or "Cadete"
    local status = DISPATCH_LABELS[PlayerData.DispatchState]
        or PlayerData.DispatchState or "OFF DUTY"

    DrawRect(x + width / 2, y + height / 2, width, height,
        10, 15, 22, 210)
    DrawRect(x + 0.002, y + height / 2, 0.003, height, 67, 181, 241, 235)

    drawText("SENTINEL POLICE", x + 0.009, y + 0.006, 0.22, 91, 194, 255)
    drawText((officer and (officer .. "  |  ") or "") .. rank,
        x + 0.009, y + 0.025, 0.22)
    drawText(status, x + 0.009, y + 0.045, 0.2, 112, 228, 169)

    if safeMode then
        return
    end

    drawText((PlayerData.Unit or "SIN UNIDAD") .. "  |  "
        .. (vehicle.state or "NONE"), x + 0.009, y + 0.064, 0.19,
        196, 220, 235)

    drawText((dispatch.lifecycle ~= "NONE" and
        ((dispatch.code or "CAD") .. " · " .. (dispatch.title or "Incidente"))
        or "SIN INCIDENTE ACTIVO"), x + 0.009, y + 0.082, 0.18,
        196, 220, 235)

    DrawRect(x + 0.082, y + 0.109, 0.142, 0.004, 26, 47, 62, 230)
    DrawRect(x + 0.011 + (0.142 * progress) / 2,
        y + 0.109, 0.142 * progress, 0.004, 72, 188, 244, 245)
    drawText(("%d / %d XP · %s"):format(xp, nextXP, nextRank),
        x + 0.009, y + 0.095, 0.16, 154, 190, 212)
end

local function drawAlertCard(alert)
    if not alert then
        return
    end

    local age = GetGameTimer() - (tonumber(alert.runtimeCreatedAt) or 0)
    local expanded = age < 7000
    local mode = PoliceTerminalManager and PoliceTerminalManager.GetMode()
        or "PDA"
    local widgetConfig = WidgetLayoutManager.GetWidget(mode, "AlertWidget")

    if not widgetConfig or widgetConfig.visible ~= true then
        return
    end

    local uiScale = (WidgetLayout.UIScale or 1.0)
        * (widgetConfig.scale or 1.0)
    local width = 0.21 * uiScale
    local height = (expanded and 0.088 or 0.035) * uiScale
    local x, y = resolveWidgetPosition(widgetConfig, width, height)
    local colors = {
        EMERGENCY = {231, 71, 71},
        HIGH = {229, 158, 62},
        NORMAL = {72, 188, 232},
        LOW = {143, 164, 176}
    }
    local color = colors[alert.priority] or colors.NORMAL
    local red, green, blue = color[1], color[2], color[3]

    DrawRect(x + width / 2, y + height / 2, width, height, 9, 16, 25, 225)
    DrawRect(x + 0.002, y + height / 2, 0.004, height,
        red, green, blue, 245)
    drawText((alert.type or "ALERTA") .. " · " .. (alert.priority or "NORMAL"),
        x + 0.011, y + 0.006, 0.18, red, green, blue)
    drawText(alert.title or "Nueva alerta", x + 0.011, y + 0.021, 0.23)

    if expanded then
        drawText(alert.message or "", x + 0.011, y + 0.043, 0.18,
            200, 220, 233)

        if alert.type == "DISPATCH" then
            drawText("Y ACEPTAR  ·  RECHAZAR NO DISPONIBLE",
                x + 0.011, y + 0.067, 0.16, 112, 210, 255)
        end
    end
end

CreateThread(function()
    while true do
        if PoliceAlertManager then
            cachedAlert = PoliceAlertManager.GetActive()

            if cachedAlert then
                cachedAlert.runtimeCreatedAt = cachedAlert.createdAt
                    or GetGameTimer()
            end
        end

        cachedDispatch = DispatchManager and DispatchManager.GetSnapshot
            and DispatchManager.GetSnapshot() or {}
        cachedVehicle = VehicleManager and VehicleManager.GetSnapshot
            and VehicleManager.GetSnapshot() or {}

        Wait(250)
    end
end)

CreateThread(function()
    while true do
        local sleep = 500

        if shouldShow()
            and not devNativeHudDisabled
            and not WidgetLayoutManager.IsEditing() then
            sleep = 0
            drawPoliceHud()

            local terminalOpen = PoliceTerminalManager
                and PoliceTerminalManager.IsOpen()

            if not terminalOpen then
                drawAlertCard(cachedAlert)
            end
        end

        Wait(sleep)
    end
end)

RegisterCommand("devnativehud", function()
    if not Config or Config.DevMode ~= true then
        return
    end

    devNativeHudDisabled = not devNativeHudDisabled
    print(("[PoliceOS DEV] HUD nativo DrawRect: %s"):format(
        devNativeHudDisabled and "DESACTIVADO" or "ACTIVADO"
    ))
end, false)
