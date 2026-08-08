WidgetLayoutManager = {
    EditorOpen = false,
    Preferences = nil
}

local LAYOUT_SCHEMA_VERSION = 2
local KVP_KEY = "sentinel:police_os_layout:v2"
local LEGACY_KVP_KEY = "sentinel:police_os_layout:v1"
local VALID_ANCHORS = {
    TOP_LEFT = true, TOP = true, TOP_RIGHT = true,
    RIGHT = true, BOTTOM_RIGHT = true, BOTTOM = true,
    BOTTOM_LEFT = true, LEFT = true, FREE = true
}

local function copyTable(value)
    if type(value) ~= "table" then
        return value
    end

    local result = {}

    for key, item in pairs(value) do
        result[key] = copyTable(item)
    end

    return result
end

local function clamp(value, minimum, maximum)
    return math.max(minimum, math.min(maximum, tonumber(value) or minimum))
end

local function sanitizeWidget(value, fallback)
    value = type(value) == "table" and value or {}
    fallback = type(fallback) == "table" and fallback or {}

    local anchor = tostring(value.anchor or fallback.anchor or "FREE")

    if not VALID_ANCHORS[anchor] then
        anchor = fallback.anchor or "FREE"
    end

    return {
        anchor = anchor,
        x = clamp(value.x or fallback.x, 1, 99),
        y = clamp(value.y or fallback.y, 1, 99),
        scale = clamp(value.scale or fallback.scale, 0.6, 1.5),
        visible = value.visible == nil
            and fallback.visible ~= false
            or value.visible == true
    }
end

local function buildDefaults()
    local preferences = {
        schemaVersion = LAYOUT_SCHEMA_VERSION,
        uiScale = WidgetLayout.UIScale,
        preset = WidgetLayout.DefaultPreset,
        modes = {}
    }

    for mode, widgets in pairs(WidgetLayout.EditorDefaults) do
        preferences.modes[mode] = {}

        for widgetId, widget in pairs(widgets) do
            preferences.modes[mode][widgetId] = copyTable(widget)
        end
    end

    return preferences
end

local function sanitizePreferences(raw)
    local defaults = buildDefaults()
    raw = type(raw) == "table" and raw or {}
    local preset = tostring(raw.preset or defaults.preset)

    if not WidgetLayout.Presets[preset] then
        preset = defaults.preset
    end

    local clean = {
        schemaVersion = LAYOUT_SCHEMA_VERSION,
        uiScale = clamp(raw.uiScale or defaults.uiScale, 0.8, 1.25),
        preset = preset,
        modes = {}
    }

    for mode, widgets in pairs(defaults.modes) do
        clean.modes[mode] = {}
        local rawMode = type(raw.modes) == "table"
            and type(raw.modes[mode]) == "table"
            and raw.modes[mode] or {}

        for widgetId, fallback in pairs(widgets) do
            clean.modes[mode][widgetId] = sanitizeWidget(
                rawMode[widgetId],
                fallback
            )
        end
    end

    return clean
end

local function loadPreferences()
    local encoded = GetResourceKvpString(KVP_KEY)

    if not encoded or encoded == "" then
        encoded = GetResourceKvpString(LEGACY_KVP_KEY)
    end

    if not encoded or encoded == "" then
        return buildDefaults()
    end

    local success, decoded = pcall(json.decode, encoded)
    return success and sanitizePreferences(decoded) or buildDefaults()
end

local function savePreferences(preferences)
    local clean = sanitizePreferences(preferences)
    local success, encoded = pcall(json.encode, clean)

    if not success or not encoded then
        return false
    end

    SetResourceKvp(KVP_KEY, encoded)
    DeleteResourceKvp(LEGACY_KVP_KEY)
    WidgetLayoutManager.Preferences = clean
    WidgetLayout.UIScale = clean.uiScale
    return true
end

local function logPreferenceMutations(source, previous, current)
    if not Config or Config.DevMode ~= true then
        return
    end

    for mode, widgets in pairs(current.modes or {}) do
        for widgetId, widget in pairs(widgets) do
            local old = previous
                and previous.modes
                and previous.modes[mode]
                and previous.modes[mode][widgetId]
                or {}

            if old.anchor ~= widget.anchor
                or old.x ~= widget.x
                or old.y ~= widget.y
                or old.scale ~= widget.scale
                or old.visible ~= widget.visible then

                print("[WidgetLayout MUTATION]")
                print(("source=%s"):format(tostring(source)))
                print(("mode=%s"):format(tostring(mode)))
                print(("widget=%s"):format(tostring(widgetId)))
                print(("oldAnchor=%s"):format(tostring(old.anchor)))
                print(("newAnchor=%s"):format(tostring(widget.anchor)))
                print(("oldX=%s"):format(tostring(old.x)))
                print(("newX=%s"):format(tostring(widget.x)))
                print(("oldY=%s"):format(tostring(old.y)))
                print(("newY=%s"):format(tostring(widget.y)))
            end
        end
    end
end

WidgetLayoutManager.Preferences = loadPreferences()
WidgetLayout.UIScale = WidgetLayoutManager.Preferences.uiScale

local function logPreferences(label, preferences)
    if not Config or Config.DevMode ~= true then
        return
    end

    for mode, widgets in pairs(preferences.modes or {}) do
        for widgetId, widget in pairs(widgets) do
            print(("[WidgetLayout %s] widget=%s mode=%s anchor=%s x=%.4f y=%.4f scale=%.3f")
                :format(
                    label,
                    tostring(widgetId),
                    tostring(mode),
                    tostring(widget.anchor),
                    tonumber(widget.x) or 0.0,
                    tonumber(widget.y) or 0.0,
                    tonumber(widget.scale) or 1.0
                ))
        end
    end
end

logPreferences("LOAD", WidgetLayoutManager.Preferences)

function WidgetLayoutManager.IsEditing()
    return WidgetLayoutManager.EditorOpen == true
end

function WidgetLayoutManager.GetWidget(mode, widgetId)
    local preferences = WidgetLayoutManager.Preferences or buildDefaults()
    local widget = preferences.modes[mode]
        and preferences.modes[mode][widgetId]
        or nil

    if not widget then
        return nil
    end

    local result = copyTable(widget)
    result.visible = result.visible == true
    return result
end

function WidgetLayoutManager.GetSnapshot(mode)
    local widgets = {}

    for _, widgetId in ipairs(WidgetLayout.EditableWidgets) do
        widgets[widgetId] = WidgetLayoutManager.GetWidget(mode, widgetId)
    end

    return {
        uiScale = WidgetLayoutManager.Preferences.uiScale,
        preset = WidgetLayoutManager.Preferences.preset,
        layout = WidgetLayout.GetLayout(mode),
        widgets = widgets,
        nativeHud = copyTable(WidgetLayout.NativeHUD.TOP_RIGHT),
        futureWidgets = WidgetLayout.FutureWidgets
    }
end

local function resolveEditorMode()
    if PoliceTerminalManager and PoliceTerminalManager.IsOpen() then
        return PoliceTerminalManager.GetMode()
    end

    local context = PoliceTerminalManager.GetContext()

    if context.isPassenger then
        return "VEHICLE_FULL"
    elseif context.isDriver then
        return context.speedKmh > 10.0
            and "DRIVER_SAFE"
            or "VEHICLE_FULL"
    end

    return "PDA"
end

function WidgetLayoutManager.OpenEditor()
    if WidgetLayoutManager.EditorOpen
        or CharacterManager and CharacterManager.CreatorOpen
        or AppearanceManager and AppearanceManager.EditorOpen
        or VehicleManager and VehicleManager.GarageMenuOpen then

        return false
    end

    local mode = resolveEditorMode()
    local snapshot = PoliceTerminalManager.GetSnapshot()
    snapshot.mode = mode

    if PoliceTerminalManager.IsOpen() then
        PoliceTerminalManager.Close()
    end

    WidgetLayoutManager.EditorOpen = true
    SetNuiFocus(true, true)
    SendNUIMessage({
        action = "widgetEditor:open",
        mode = mode,
        snapshot = snapshot,
        preferences = copyTable(WidgetLayoutManager.Preferences),
        defaults = buildDefaults(),
        editableWidgets = WidgetLayout.EditableWidgets,
        presets = WidgetLayout.Presets
    })

    return true
end

function WidgetLayoutManager.CloseEditor()
    if not WidgetLayoutManager.EditorOpen then
        return false
    end

    WidgetLayoutManager.EditorOpen = false
    SetNuiFocus(false, false)
    SendNUIMessage({action = "widgetEditor:close"})
    return true
end

function WidgetLayoutManager.ToggleEditor()
    return WidgetLayoutManager.EditorOpen
        and WidgetLayoutManager.CloseEditor()
        or WidgetLayoutManager.OpenEditor()
end

function WidgetLayoutManager.ResetPreferences()
    local previous = WidgetLayoutManager.Preferences
    DeleteResourceKvp(KVP_KEY)
    DeleteResourceKvp(LEGACY_KVP_KEY)
    WidgetLayoutManager.Preferences = buildDefaults()
    WidgetLayout.UIScale = WidgetLayoutManager.Preferences.uiScale
    logPreferenceMutations("DEV_UI_RESET", previous, WidgetLayoutManager.Preferences)
    return true
end

RegisterCommand("devuireset", function()
    if not Config or Config.DevMode ~= true then
        return
    end

    WidgetLayoutManager.ResetPreferences()
    print("[PoliceOS DEV] Layout UI restaurado a defaults. Reinicia Police OS con F7.")
end, false)

RegisterNUICallback("widgetEditor:save", function(data, callback)
    local previous = WidgetLayoutManager.Preferences
    local saved = savePreferences(data and data.preferences)

    if saved then
        logPreferenceMutations("EDITOR_SAVE", previous, WidgetLayoutManager.Preferences)
        logPreferences("SAVE", WidgetLayoutManager.Preferences)
        WidgetLayoutManager.CloseEditor()
    end

    callback({ok = saved})
end)

RegisterNUICallback("widgetEditor:toggle", function(_, callback)
    callback({ok = WidgetLayoutManager.ToggleEditor() == true})
end)

RegisterNUICallback("widgetEditor:cancel", function(_, callback)
    WidgetLayoutManager.CloseEditor()
    callback({ok = true})
end)

RegisterNUICallback("widgetEditor:reset", function(_, callback)
    local defaults = buildDefaults()

    callback({
        ok = true,
        preferences = copyTable(defaults)
    })
end)

AddEventHandler("onResourceStop", function(resourceName)
    if resourceName == GetCurrentResourceName()
        and WidgetLayoutManager.EditorOpen then

        SetNuiFocus(false, false)
    end
end)
