print("[Sentinel AI] Cargando DispatchManager T4C...")

DispatchManager = DispatchManager or {}

local calls = {}
local history = {}
local activeAssignmentId = nil
local serverClockOffset = 0
local pendingAction = nil
local alertIds = {}
local scenePreparing, scenePrepared, sceneSpawned = false, false, false
local priorityOrder = {EMERGENCY = 4, HIGH = 3, NORMAL = 2, LOW = 1}

local function copy(value)
    if type(value) ~= "table" then return value end
    local result = {}
    for key, item in pairs(value) do result[key] = copy(item) end
    return result
end

local function refreshPoliceOS()
    if PoliceTerminalManager and PoliceTerminalManager.IsOpen
        and PoliceTerminalManager.IsOpen()
        and PoliceTerminalManager.RefreshDomain then
        PoliceTerminalManager.RefreshDomain("dispatch")
    end
end

local function getRank()
    return type(GetEffectivePlayerRank) == "function"
        and GetEffectivePlayerRank() or (PlayerData.Rank or "Cadete")
end

local function getOperationalStatus()
    if not PlayerData or PlayerData.OnDuty ~= true then return "OFF_DUTY" end
    if MissionManager and MissionManager.Active then
        if PlayerData.DispatchState == "EN_ROUTE" then return "EN_ROUTE" end
        if PlayerData.DispatchState == "ON_SCENE" then return "ON_SCENE" end
        return "BUSY"
    end
    return "AVAILABLE"
end

function DispatchManager.IsAssignmentEligible(assignment, context)
    context = type(context) == "table" and context or {}
    if type(assignment) ~= "table" then return false, "INVALID_ASSIGNMENT" end
    if assignment.agency ~= "POLICE" then return false, "AGENCY_UNAVAILABLE" end
    if assignment.status ~= "PENDING" then return false, "NOT_PENDING" end
    if context.onDuty == false or (context.onDuty == nil
        and PlayerData.OnDuty ~= true) then return false, "OFF_DUTY" end
    if not IsRankAtLeast(context.rank or getRank(),
        assignment.minimumRank or "Cadete") then return false, "RANK_REQUIRED" end
    if context.forAcceptance ~= false and (activeAssignmentId
        or (MissionManager and MissionManager.Active)) then
        return false, "MISSION_ACTIVE"
    end
    return true
end

local function snapshotCall(call, context)
    local result = copy(call)
    result.distance = call.location
        and #(GetEntityCoords(PlayerPedId()) - call.location) or nil
    if call.expiresAt then
        result.remainingMs = math.max(0,
            call.expiresAt - (GetGameTimer() + serverClockOffset))
    end
    result.eligible, result.eligibilityReason =
        DispatchManager.IsAssignmentEligible(result, context)
    result.rankEligible = IsRankAtLeast(context and context.rank or getRank(),
        result.minimumRank or "Cadete")
    return result
end

local function sortedPending(context)
    local result = {}
    for _, call in pairs(calls) do
        if call.status == "PENDING" then
            result[#result + 1] = snapshotCall(call, context)
        end
    end
    table.sort(result, function(a, b)
        local ap, bp = priorityOrder[a.priority] or 0, priorityOrder[b.priority] or 0
        if ap ~= bp then return ap > bp end
        if a.eligible ~= b.eligible then return a.eligible end
        if (a.distance or math.huge) ~= (b.distance or math.huge) then
            return (a.distance or math.huge) < (b.distance or math.huge)
        end
        return a.createdAt < b.createdAt
    end)
    return result
end

local function pushPendingAlert(call)
    if alertIds[call.assignmentId] or not PoliceAlertManager then return end
    alertIds[call.assignmentId] = PoliceAlertManager.Push({
        type = "DISPATCH", source = "DISPATCH",
        title = (call.priority == "HIGH" or call.priority == "EMERGENCY")
            and "Incidente de alto riesgo disponible" or "Nueva llamada disponible",
        message = ("Código %s — %s"):format(call.code, call.title),
        priority = call.priority, persistent = true,
        actions = {
            {id = "dispatch.accept", label = "Aceptar", available = true,
                assignmentId = call.assignmentId},
            {id = "dispatch.decline", label = "Rechazar", available = true,
                assignmentId = call.assignmentId}
        },
        metadata = {incidentId = call.incidentId,
            assignmentId = call.assignmentId, code = call.code}
    })
end

local function settleAlert(call)
    local alertId = alertIds[call.assignmentId]
    if not alertId or not PoliceAlertManager then return end
    PoliceAlertManager.Update(alertId, {persistent = false, acknowledged = true,
        expiresAt = GetGameTimer() + 4000, actions = {}})
    alertIds[call.assignmentId] = nil
end

local function removeDispatchBlip()
    if PlayerData.DispatchBlip and DoesBlipExist(PlayerData.DispatchBlip) then
        RemoveBlip(PlayerData.DispatchBlip)
    end
    PlayerData.DispatchBlip = nil
    SetWaypointOff()
end

local function createDispatchBlip(call)
    removeDispatchBlip()
    local blip = AddBlipForCoord(call.location.x, call.location.y, call.location.z)
    SetBlipSprite(blip, 280)
    SetBlipColour(blip, 1)
    SetBlipScale(blip, 0.9)
    SetBlipAsShortRange(blip, false)
    SetBlipRoute(blip, true)
    SetBlipRouteColour(blip, 1)
    BeginTextCommandSetBlipName("STRING")
    AddTextComponentString(("Código %s - %s"):format(call.code, call.title))
    EndTextCommandSetBlipName(blip)
    PlayerData.DispatchBlip = blip
    SetNewWaypoint(call.location.x, call.location.y)
end

local function resetSceneRuntime()
    scenePreparing, scenePrepared, sceneSpawned = false, false, false
    if SceneBuilder and type(SceneBuilder.Reset) == "function" then
        SceneBuilder.Reset()
    end
end

local function prepareScene(call)
    if scenePreparing or scenePrepared or not SceneBuilder
        or type(SceneBuilder.Build) ~= "function" then return false end
    scenePreparing = true
    CreateThread(function()
        local success, layout = pcall(SceneBuilder.Build, call)
        scenePreparing = false
        scenePrepared = success and layout ~= nil
        if not success then
            print("[Dispatch T4C] SceneBuilder falló: " .. tostring(layout))
        end
    end)
    return true
end

local function clearLegacyBridge()
    activeAssignmentId, pendingAction = nil, nil
    removeDispatchBlip()
    resetSceneRuntime()
    PlayerData.CurrentDispatch = nil
end

function ResetDispatchRuntime()
    if activeAssignmentId then
        TriggerServerEvent("sentinel:server:dispatch:cancel", activeAssignmentId,
            "RESET_DISPATCH_RUNTIME")
    end
    clearLegacyBridge()
    return true
end

function DispatchManager.Accept(assignmentId, options)
    options = type(options) == "table" and options or {}
    local source = tostring(options.source or "UNKNOWN")
    local call = calls[assignmentId]
    local ageMs = call and math.max(0,
        GetGameTimer() + serverClockOffset - call.createdAt) or -1
    print(("[Dispatch ACCEPT TRACE] source=%s assignmentId=%s incidentId=%s "
        .. "ageMs=%s manual=%s autoAssign=%s legacy=false"):format(
        source, tostring(assignmentId), tostring(call and call.incidentId), ageMs,
        tostring(source == "MANUAL"), tostring(source == "AUTOASSIGN")))
    if source ~= "MANUAL" and source ~= "AUTOASSIGN" then
        return false, "INVALID_ACCEPT_SOURCE"
    end
    local eligible, reason = DispatchManager.IsAssignmentEligible(call)
    if not eligible then return false, reason end
    if pendingAction then return false, "REQUEST_PENDING" end
    pendingAction = {action = "accept", assignmentId = assignmentId}
    TriggerServerEvent("sentinel:server:dispatch:accept", assignmentId)
    return true, "REQUESTED"
end

function DispatchManager.AcceptCurrent(options)
    local pending = sortedPending()
    if not pending[1] then return false, "NO_PENDING_CALL" end
    return DispatchManager.Accept(pending[1].assignmentId, options)
end

function DispatchManager.Decline(assignmentId)
    local call = calls[assignmentId]
    if not call or call.status ~= "PENDING" then return false, "NOT_PENDING" end
    if pendingAction then return false, "REQUEST_PENDING" end
    pendingAction = {action = "decline", assignmentId = assignmentId}
    TriggerServerEvent("sentinel:server:dispatch:decline", assignmentId)
    return true, "REQUESTED"
end

function DispatchManager.CancelActive(reason)
    if not activeAssignmentId then return false, "NO_ACTIVE_ASSIGNMENT" end
    TriggerServerEvent("sentinel:server:dispatch:cancel", activeAssignmentId,
        tostring(reason or "MISSION_CANCELLED"))
    return true
end

function DispatchManager.GetQueue()
    return sortedPending({onDuty = PlayerData.OnDuty == true, rank = getRank(),
        forAcceptance = true})
end

function DispatchManager.GetHistory() return copy(history) end

function DispatchManager.GetCalls()
    local result = {}
    for _, call in pairs(calls) do result[#result + 1] = snapshotCall(call) end
    table.sort(result, function(a, b) return a.createdAt > b.createdAt end)
    return result
end

function DispatchManager.GetCall(id)
    return calls[id] and snapshotCall(calls[id]) or nil
end

function DispatchManager.GetOperationalStatus() return getOperationalStatus() end

function DispatchManager.GetSnapshot()
    local pending = DispatchManager.GetQueue()
    local active = activeAssignmentId and calls[activeAssignmentId] or nil
    local focus = active and snapshotCall(active, {onDuty = true, rank = getRank(),
        forAcceptance = false}) or pending[1]
    return {
        lifecycle = focus and focus.status or "NONE",
        phase = PlayerData.DispatchState or "OFF_DUTY",
        operationalStatus = getOperationalStatus(),
        pending = #pending > 0, active = active ~= nil,
        assignmentId = focus and focus.assignmentId,
        incidentId = focus and focus.incidentId,
        code = focus and focus.code, title = focus and focus.title,
        type = focus and focus.type, priority = focus and focus.priority,
        operationalTier = focus and focus.operationalTier,
        minimumRank = focus and focus.minimumRank,
        distance = focus and focus.distance,
        canAccept = focus and focus.status == "PENDING" and focus.eligible or false,
        canDecline = focus and focus.status == "PENDING" or false,
        calls = pending, recentCalls = DispatchManager.GetCalls(),
        current = active and snapshotCall(active) or nil,
        history = copy(history)
    }
end

function DispatchManager.Enqueue() return nil, "SERVER_AUTHORITY" end
function DispatchManager.EnqueueAssignment() return nil, "SERVER_AUTHORITY" end

function CompleteCurrentDispatch()
    if PlayerData.DispatchState ~= "REPORT" or not activeAssignmentId then
        return false
    end
    if pendingAction then return false end
    pendingAction = {action = "complete", assignmentId = activeAssignmentId}
    TriggerServerEvent("sentinel:server:dispatch:complete", activeAssignmentId)
    return true
end

RegisterNetEvent("sentinel:client:dispatch:snapshot", function(snapshot)
    snapshot = type(snapshot) == "table" and snapshot or {}
    serverClockOffset = tonumber(snapshot.serverNow) and
        snapshot.serverNow - GetGameTimer() or serverClockOffset
    IncidentManager.ApplyServerSnapshot(snapshot.incidents)
    AssignmentManager.ApplyServerSnapshot(snapshot.assignments)
    history = copy(snapshot.history or {})
    local previous = calls
    calls = {}
    local localServerId = GetPlayerServerId(PlayerId())
    for _, call in ipairs(snapshot.calls or {}) do
        calls[call.assignmentId] = copy(call)
        if call.status == "PENDING" and not previous[call.assignmentId] then
            pushPendingAlert(call)
        elseif call.status ~= "PENDING" then
            settleAlert(call)
        end
    end
    activeAssignmentId = nil
    for _, assignment in ipairs(snapshot.assignments or {}) do
        if assignment.owner == localServerId and (assignment.status == "ASSIGNED"
            or assignment.status == "ACTIVE") then
            activeAssignmentId = assignment.id
            break
        end
    end
    refreshPoliceOS()
end)

RegisterNetEvent("sentinel:client:dispatch:result",
    function(action, assignmentId, success, reason)
        if pendingAction and pendingAction.action == action
            and pendingAction.assignmentId == assignmentId then
            pendingAction = nil
        end
        local call = calls[assignmentId]
        if action == "accept" and success then
            if not call or type(CreateCurrentCase) ~= "function"
                or not CreateCurrentCase(call) then
                TriggerServerEvent("sentinel:server:dispatch:missionStarted",
                    assignmentId, false)
                return
            end
            PlayerData.CurrentDispatch = copy(call)
            local started = MissionManager and MissionManager.StartMission
                and MissionManager.StartMission({incidentId = call.incidentId,
                    assignmentId = assignmentId}) == true
            TriggerServerEvent("sentinel:server:dispatch:missionStarted",
                assignmentId, started)
            if not started then
                if type(CancelCurrentCase) == "function" then CancelCurrentCase() end
                PlayerData.CurrentDispatch = nil
                return
            end
            activeAssignmentId = assignmentId
            PlayerData.DispatchState = "EN_ROUTE"
            resetSceneRuntime()
            createDispatchBlip(call)
            prepareScene(call)
            Sentinel.Notify("CENTRAL", "Despacho aceptado. Unidad en ruta.",
                {90, 190, 255})
        elseif action == "complete" and success then
            clearLegacyBridge()
            PlayerData.DispatchState = PlayerData.OnDuty and "WAITING" or "OFF_DUTY"
            if MissionManager then
                MissionManager.Active = false
                MissionManager.StartedAt = 0
                MissionManager.IncidentId = nil
                MissionManager.AssignmentId = nil
            end
        elseif action == "cancel" and success then
            clearLegacyBridge()
        elseif not success then
            Sentinel.Notify("CENTRAL", "Solicitud rechazada: "
                .. tostring(reason or "UNKNOWN"), {255, 100, 80})
        end
        refreshPoliceOS()
    end)

CreateThread(function()
    while true do
        Wait(250)
        local call = activeAssignmentId and calls[activeAssignmentId] or nil
        if call and PlayerData.DispatchState == "EN_ROUTE" and call.location then
            local distance = #(GetEntityCoords(PlayerPedId()) - call.location)
            if distance <= 180.0 and not scenePrepared and not scenePreparing then
                prepareScene(call)
            end
            if distance <= 150.0 and scenePrepared and not sceneSpawned
                and type(SpawnCrimeScene) == "function" then
                sceneSpawned = SpawnCrimeScene(call, true) ~= false
            end
            if distance <= 25.0 then
                removeDispatchBlip()
                PlayerData.DispatchState = "ON_SCENE"
                if not sceneSpawned and type(SpawnCrimeScene) == "function" then
                    sceneSpawned = SpawnCrimeScene(call, false) ~= false
                end
                if type(ActivateCrimeScene) == "function" then ActivateCrimeScene() end
                Sentinel.Notify("CENTRAL", "Unidad en escena. Evalúe la situación.",
                    {0, 255, 0})
            end
        end
    end
end)

CreateThread(function()
    while not NetworkIsSessionStarted() do Wait(500) end
    TriggerServerEvent("sentinel:server:dispatch:requestSnapshot")
end)

AddEventHandler("onResourceStop", function(resourceName)
    if resourceName == GetCurrentResourceName() then clearLegacyBridge() end
end)

print("[Sentinel AI] DispatchManager T4C listo.")
