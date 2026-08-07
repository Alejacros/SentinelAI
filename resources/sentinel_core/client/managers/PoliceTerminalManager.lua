PoliceTerminalManager = {
    Opened = false,
    Mode = "PDA",
    Context = nil,
    ActiveModule = "HOME",
    DriverStoppedSince = nil
}

local DRIVER_SAFE_SPEED = 10.0
local DRIVER_FULL_SPEED = 5.0
local DRIVER_STOPPED_DELAY = 1000

local function getIdentityName()
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

local function getAssignedVehicleContext(ped)
    local assignedVehicle = PlayerData.Vehicle
    local currentVehicle = GetVehiclePedIsIn(ped, false)
    local inAssignedVehicle = assignedVehicle
        and assignedVehicle ~= 0
        and DoesEntityExist(assignedVehicle)
        and currentVehicle == assignedVehicle
    local driver = inAssignedVehicle
        and GetPedInVehicleSeat(assignedVehicle, -1) == ped
    local passenger = inAssignedVehicle and not driver
    local speedKmh = inAssignedVehicle
        and GetEntitySpeed(assignedVehicle) * 3.6
        or 0.0

    return assignedVehicle, inAssignedVehicle, driver, passenger, speedKmh
end

function PoliceTerminalManager.GetContext()
    local ped = PlayerPedId()
    local assignedVehicle, inAssignedVehicle, driver, passenger, speedKmh =
        getAssignedVehicleContext(ped)
    local contextType = driver and "VEHICLE_DRIVER"
        or (passenger and "VEHICLE_PASSENGER")
        or "ON_FOOT"
    local fullModeAvailable = passenger

    if driver then
        if speedKmh < DRIVER_FULL_SPEED then
            PoliceTerminalManager.DriverStoppedSince =
                PoliceTerminalManager.DriverStoppedSince or GetGameTimer()
            fullModeAvailable = GetGameTimer()
                - PoliceTerminalManager.DriverStoppedSince
                >= DRIVER_STOPPED_DELAY
        else
            PoliceTerminalManager.DriverStoppedSince = nil
        end
    else
        PoliceTerminalManager.DriverStoppedSince = nil
    end

    local context = {
        type = contextType,
        onFoot = not inAssignedVehicle,
        inAssignedVehicle = inAssignedVehicle == true,
        isDriver = driver == true,
        isPassenger = passenger == true,
        speedKmh = speedKmh,
        fullModeAvailable = fullModeAvailable,
        rank = GetEffectivePlayerRank(),
        onDuty = PlayerData.OnDuty == true,
        vehicleState = VehicleManager
            and VehicleManager.VehicleState
            or "NONE",
        certifications = {},
        division = nil,
        assignment = nil,
        assignedVehicle = assignedVehicle
    }

    PoliceTerminalManager.Context = context
    return context
end

local function resolveOpeningMode(context)
    if context.isPassenger then
        return "VEHICLE_FULL"
    elseif context.isDriver then
        return context.speedKmh > DRIVER_SAFE_SPEED
            and "DRIVER_SAFE"
            or "VEHICLE_FULL"
    end

    return "PDA"
end

function PoliceTerminalManager.GetMode()
    return PoliceTerminalManager.Mode
end

function PoliceTerminalManager.IsOpen()
    return PoliceTerminalManager.Opened == true
end

local function getCareerSnapshot()
    local nextRank = type(GetNextRank) == "function" and GetNextRank() or nil

    return {
        name = getIdentityName(),
        rank = PlayerData.Rank or "Cadete",
        effectiveRank = GetEffectivePlayerRank(),
        xp = PlayerData.XP or 0,
        nextRank = nextRank and nextRank.name or nil,
        nextRankXP = nextRank and nextRank.requiredXP or nil,
        completedCases = PlayerData.CompletedCases or 0
    }
end

local function getDutySnapshot()
    return {
        onDuty = PlayerData.OnDuty == true,
        callsign = PlayerData.Unit or "Sin asignar",
        dispatchState = PlayerData.DispatchState or "OFF_DUTY"
    }
end

local function getWidgetLayoutSnapshot(mode)
    return {
        uiScale = WidgetLayout.UIScale,
        layout = WidgetLayout.GetLayout(mode),
        futureWidgets = WidgetLayout.FutureWidgets
    }
end

function PoliceTerminalManager.GetSnapshot()
    local context = PoliceTerminalManager.GetContext()
    context.terminalMode = PoliceTerminalManager.Mode

    return {
        mode = PoliceTerminalManager.Mode,
        widgetLayout = getWidgetLayoutSnapshot(
            PoliceTerminalManager.Mode
        ),
        activeModule = PoliceTerminalManager.ActiveModule,
        context = context,
        permissions = PermissionManager.GetCapabilities(context),
        modules = PermissionManager.GetAllowedModules(context),
        officer = getCareerSnapshot(),
        duty = getDutySnapshot(),
        dispatch = DispatchManager and DispatchManager.GetSnapshot
            and DispatchManager.GetSnapshot() or {},
        vehicle = VehicleManager and VehicleManager.GetSnapshot
            and VehicleManager.GetSnapshot() or {},
        cases = CaseManager and CaseManager.GetSnapshot
            and CaseManager.GetSnapshot() or {},
        bodycam = BodyCamManager and BodyCamManager.GetSnapshot
            and BodyCamManager.GetSnapshot() or {},
        alerts = PoliceAlertManager.GetQueue(),
        activeAlert = PoliceAlertManager.GetActive()
    }
end

local function hasIncompatibleView()
    return CharacterManager and CharacterManager.CreatorOpen == true
        or AppearanceManager and AppearanceManager.EditorOpen == true
        or VehicleManager and VehicleManager.GarageMenuOpen == true
end

function PoliceTerminalManager.Open()
    if PoliceTerminalManager.Opened or hasIncompatibleView() then
        return false
    end

    local context = PoliceTerminalManager.GetContext()
    PoliceTerminalManager.Mode = resolveOpeningMode(context)
    PoliceTerminalManager.ActiveModule = "HOME"
    context.terminalMode = PoliceTerminalManager.Mode
    PoliceTerminalManager.Opened = true

    if not MDTManager or not MDTManager.Open then
        PoliceTerminalManager.Opened = false
        return false
    end

    MDTManager.Open(
        PoliceTerminalManager.Mode,
        PoliceTerminalManager.GetSnapshot()
    )

    return true
end

function PoliceTerminalManager.Close()
    if not PoliceTerminalManager.Opened then
        return false
    end

    PoliceTerminalManager.Opened = false
    PoliceTerminalManager.ActiveModule = "HOME"

    if MDTManager and MDTManager.Close then
        MDTManager.Close()
    end

    return true
end

function PoliceTerminalManager.Toggle()
    if not PoliceTerminalManager.Opened then
        return PoliceTerminalManager.Open()
    end

    if PoliceTerminalManager.Mode == "DRIVER_SAFE" then
        local context = PoliceTerminalManager.GetContext()

        if context.isDriver and context.fullModeAvailable then
            return PoliceTerminalManager.ExecuteAction(
                "terminal.full_mode"
            )
        end
    end

    return PoliceTerminalManager.Close()
end

function PoliceTerminalManager.OpenModule(moduleId)
    if not PoliceTerminalManager.Opened then
        return false, "TERMINAL_CLOSED"
    end

    local context = PoliceTerminalManager.GetContext()
    context.terminalMode = PoliceTerminalManager.Mode
    local allowed, reason = PermissionManager.Can(
        "terminal.module." .. tostring(moduleId),
        context
    )

    if not allowed then
        return false, reason
    end

    PoliceTerminalManager.ActiveModule = moduleId
    MDTManager.Update("navigation", {activeModule = moduleId})
    return true
end

function PoliceTerminalManager.ExecuteAction(actionId, payload)
    payload = type(payload) == "table" and payload or {}

    if actionId == "vehicle.locate" then
        return VehicleManager.LocatePoliceVehicle()
    elseif actionId == "dispatch.accept" then
        if DispatchManager and DispatchManager.AcceptCurrent then
            return DispatchManager.AcceptCurrent()
        end

        return false, "UNAVAILABLE"
    elseif actionId == "dispatch.decline" then
        return false, "NOT_IMPLEMENTED"
    elseif actionId == "duty.start" then
        if not MenuManager or not MenuManager.StartDuty then
            return false, "UNAVAILABLE"
        end

        local success = MenuManager.StartDuty()

        if success then
            PoliceTerminalManager.RefreshDomain("home")
        end

        return success == true, success and nil or "DUTY_START_FAILED"
    elseif actionId == "duty.stop" then
        if not MenuManager or not MenuManager.StopDuty then
            return false, "UNAVAILABLE"
        end

        local success = MenuManager.StopDuty()

        if success then
            PoliceTerminalManager.RefreshDomain("home")
        end

        return success == true, success and nil or "DUTY_STOP_FAILED"
    elseif actionId == "terminal.full_mode" then
        local context = PoliceTerminalManager.GetContext()

        if not context.fullModeAvailable then
            return false, "VEHICLE_MOVING"
        end

        PoliceTerminalManager.Mode = "VEHICLE_FULL"
        context.terminalMode = PoliceTerminalManager.Mode
        MDTManager.SetFocus(true)
        MDTManager.Update("mode", {
            mode = PoliceTerminalManager.Mode,
            context = context,
            widgetLayout = getWidgetLayoutSnapshot(
                PoliceTerminalManager.Mode
            ),
            modules = PermissionManager.GetAllowedModules(context)
        })
        return true
    end

    return false, "UNKNOWN_ACTION"
end

function PoliceTerminalManager.RefreshDomain(domain)
    if not PoliceTerminalManager.Opened then
        return false
    end

    local data = nil

    if domain == "dispatch" then
        data = DispatchManager.GetSnapshot()
    elseif domain == "vehicle" then
        data = VehicleManager.GetSnapshot()
    elseif domain == "cases" then
        data = CaseManager.GetSnapshot()
    elseif domain == "bodycam" then
        data = BodyCamManager.GetSnapshot()
    elseif domain == "alerts" then
        data = {
            alerts = PoliceAlertManager.GetQueue(),
            activeAlert = PoliceAlertManager.GetActive()
        }
    elseif domain == "home" then
        data = PoliceTerminalManager.GetSnapshot()
    end

    if not data then
        return false
    end

    MDTManager.Update(domain, data)
    return true
end

PoliceAlertManager.Subscribe(function()
    PoliceTerminalManager.RefreshDomain("alerts")
end)

AddEventHandler("sentinel:careerLoaded", function()
    PoliceTerminalManager.RefreshDomain("home")
end)

AddEventHandler("sentinel:careerUpdated", function()
    PoliceTerminalManager.RefreshDomain("home")
end)

AddEventHandler("sentinel:historyUpdated", function()
    PoliceTerminalManager.RefreshDomain("cases")
end)

CreateThread(function()
    while true do
        Wait(500)

        if PoliceTerminalManager.Opened then
            if hasIncompatibleView() then
                PoliceTerminalManager.Close()
            else
                local previousMode = PoliceTerminalManager.Mode
                local context = PoliceTerminalManager.GetContext()

                if previousMode == "DRIVER_SAFE"
                    and not context.isDriver then

                    PoliceTerminalManager.Close()
                else
                    if context.isDriver
                        and context.speedKmh > DRIVER_SAFE_SPEED then

                        PoliceTerminalManager.Mode = "DRIVER_SAFE"
                    elseif context.onFoot then
                        PoliceTerminalManager.Mode = "PDA"
                    elseif context.isPassenger then
                        PoliceTerminalManager.Mode = "VEHICLE_FULL"
                    end

                    context.terminalMode = PoliceTerminalManager.Mode

                    if previousMode ~= PoliceTerminalManager.Mode then
                        if PoliceTerminalManager.Mode == "DRIVER_SAFE" then
                            PoliceTerminalManager.ActiveModule = "HOME"
                        end

                        MDTManager.SetFocus(
                            PoliceTerminalManager.Mode ~= "DRIVER_SAFE"
                        )
                    end

                    MDTManager.Update("context", {
                        mode = PoliceTerminalManager.Mode,
                        widgetLayout = getWidgetLayoutSnapshot(
                            PoliceTerminalManager.Mode
                        ),
                        activeModule = PoliceTerminalManager.ActiveModule,
                        context = context,
                        modules = PermissionManager.GetAllowedModules(context),
                        dispatch = DispatchManager.GetSnapshot(),
                        vehicle = VehicleManager.GetSnapshot()
                    })
                end
            end
        end
    end
end)

AddEventHandler("onResourceStop", function(resourceName)
    if resourceName == GetCurrentResourceName() then
        PoliceTerminalManager.Opened = false
    end
end)
