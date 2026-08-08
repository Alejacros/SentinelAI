print("[Sentinel AI] Cargando DispatchManager T4B...")

DispatchManager = DispatchManager or {}

-- T4B conserva autoridad local. Queue ownership, creación, transiciones,
-- elegibilidad, expiración, autoasignación e historial migran a servidor en T4C.
local calls = {}
local history = {}
local activeAssignmentId = nil
local nextDispatchAt = nil
local lastDispatchIndex = nil
local lastLocationByType = {}
local scenePreparing = false
local scenePrepared = false
local sceneSpawned = false

local priorityOrder = {EMERGENCY = 4, HIGH = 3, NORMAL = 2, LOW = 1}

local function copy(value)
    if type(value) ~= "table" then return value end
    local result = {}
    for key, item in pairs(value) do
        if key ~= "legacy" and key ~= "alertId"
            and key ~= "autoAssignLogged" then
            result[key] = copy(item)
        end
    end
    return result
end

local function refreshPoliceOS()
    if PoliceTerminalManager and PoliceTerminalManager.IsOpen
        and PoliceTerminalManager.IsOpen()
        and PoliceTerminalManager.RefreshDomain then
        PoliceTerminalManager.RefreshDomain("dispatch")
    end
end

local function recordHistory(eventName, call, metadata)
    history[#history + 1] = {
        event = eventName,
        incidentId = call and call.incidentId or nil,
        assignmentId = call and call.assignmentId or nil,
        status = call and call.status or nil,
        at = GetGameTimer(),
        metadata = copy(metadata or {})
    }
    while #history > DispatchLifecycleConfig.maxHistory do
        table.remove(history, 1)
    end
end

local function pushAlert(call, title, message, persistent)
    if not PoliceAlertManager then
        Sentinel.Notify("CENTRAL", message, {90, 190, 255})
        return nil
    end

    return PoliceAlertManager.Push({
        type = "DISPATCH",
        source = "DISPATCH",
        title = title,
        message = message,
        priority = call.priority,
        persistent = persistent == true,
        actions = call.status == "PENDING" and {
            {id = "dispatch.accept", label = "Aceptar", available = true,
                assignmentId = call.assignmentId},
            {id = "dispatch.decline", label = "Rechazar", available = true,
                assignmentId = call.assignmentId}
        } or {},
        metadata = {
            incidentId = call.incidentId,
            assignmentId = call.assignmentId,
            code = call.code,
            operationalTier = call.operationalTier
        }
    })
end

local function updateCallAlert(call, title, message)
    if call.alertId and PoliceAlertManager then
        PoliceAlertManager.Update(call.alertId, {
            title = title,
            message = message,
            persistent = false,
            acknowledged = true,
            expiresAt = GetGameTimer() + 5000,
            actions = {}
        })
    end
end

local function getDistance(call)
    if not call or not call.location then return nil end
    return #(GetEntityCoords(PlayerPedId()) - call.location)
end

local function getEffectiveRank()
    if type(GetEffectivePlayerRank) == "function" then
        return GetEffectivePlayerRank()
    end
    return PlayerData and PlayerData.Rank or "Cadete"
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
        and (not PlayerData or PlayerData.OnDuty ~= true)) then
        return false, "OFF_DUTY"
    end

    local rank = context.rank or getEffectiveRank()
    if not IsRankAtLeast(rank, assignment.minimumRank or "Cadete") then
        return false, "RANK_REQUIRED"
    end

    if context.forAcceptance ~= false
        and (activeAssignmentId ~= nil
            or (MissionManager and MissionManager.Active == true)) then
        return false, "MISSION_ACTIVE"
    end
    return true
end

local function snapshotCall(call, context)
    local result = copy(call)
    result.distance = getDistance(call)
    result.remainingMs = math.max(0, call.expiresAt - GetGameTimer())
    result.eligible, result.eligibilityReason =
        DispatchManager.IsAssignmentEligible(call, context)
    local rank = context and context.rank or getEffectiveRank()
    result.rankEligible = call.agency == "POLICE"
        and IsRankAtLeast(rank, call.minimumRank or "Cadete")
    result.recommendedEligible = not call.recommendedRank
        or IsRankAtLeast(rank, call.recommendedRank)
    return result
end

local function sortedPending(context)
    local result = {}
    for _, call in pairs(calls) do
        if call.status == "PENDING" then
            result[#result + 1] = snapshotCall(call, context)
        end
    end
    table.sort(result, function(left, right)
        local lp, rp = priorityOrder[left.priority] or 0,
            priorityOrder[right.priority] or 0
        if lp ~= rp then return lp > rp end
        if left.eligible ~= right.eligible then return left.eligible end
        local ld, rd = left.distance or math.huge, right.distance or math.huge
        if ld ~= rd then return ld < rd end
        return left.createdAt < right.createdAt
    end)
    return result
end

local function pendingCount()
    local count = 0
    for _, call in pairs(calls) do
        if call.status == "PENDING" then count = count + 1 end
    end
    return count
end

local function getIncidentAssignmentState(incidentId)
    local hasOpen, hasCompleted = false, false
    for _, assignment in ipairs(
        AssignmentManager.GetAssignmentsForIncident(incidentId)) do
        if assignment.status == "PENDING" or assignment.status == "ASSIGNED"
            or assignment.status == "ACTIVE" then
            hasOpen = true
        elseif assignment.status == "COMPLETED" then
            hasCompleted = true
        end
    end
    return hasOpen, hasCompleted
end

local function closeIncidentIfOrphaned(incidentId)
    if not incidentId then return end
    local hasOpen, hasCompleted = getIncidentAssignmentState(incidentId)
    if hasOpen then return end
    local incident = IncidentManager.GetSnapshot(incidentId)
    if incident and (incident.status == "NEW" or incident.status == "ACTIVE") then
        if hasCompleted then IncidentManager.Resolve(incidentId)
        else IncidentManager.Cancel(incidentId) end
    end
end

local function removeDispatchBlip()
    if PlayerData and PlayerData.DispatchBlip
        and DoesBlipExist(PlayerData.DispatchBlip) then
        RemoveBlip(PlayerData.DispatchBlip)
    end
    if PlayerData then PlayerData.DispatchBlip = nil end
    SetWaypointOff()
end

local function resetSceneRuntime()
    scenePreparing, scenePrepared, sceneSpawned = false, false, false
    if SceneBuilder and type(SceneBuilder.Reset) == "function" then
        SceneBuilder.Reset()
    end
end

local function clearActiveBridge(cancelOperational)
    local call = activeAssignmentId and calls[activeAssignmentId] or nil
    if cancelOperational and call and (call.status == "ASSIGNED"
        or call.status == "ACTIVE") then
        call.status = "CANCELLED"
        AssignmentManager.Cancel(call.assignmentId)
        recordHistory("CANCELLED", call)
        updateCallAlert(call, "Asignación cancelada", call.title)
        closeIncidentIfOrphaned(call.incidentId)
    end
    activeAssignmentId = nil
    removeDispatchBlip()
    resetSceneRuntime()
    if PlayerData then PlayerData.CurrentDispatch = nil end
end

function ResetDispatchRuntime()
    clearActiveBridge(true)
    return true
end

local function selectDifferentIndex(count, previous)
    if count <= 1 then return 1 end
    local selected
    repeat selected = math.random(1, count) until selected ~= previous
    return selected
end

local function buildDispatchInstance(definition)
    if type(definition) ~= "table" then return nil end
    local locations = definition.locations
    if type(locations) ~= "table" or #locations == 0 then return nil end
    local dispatchType = definition.type or "GENERIC"
    local operationalTier = definition.operationalTier or "T1_BASIC"
    local tierConfig = DispatchOperationalTiers[operationalTier] or {}
    local locationIndex = selectDifferentIndex(
        #locations, lastLocationByType[dispatchType])
    lastLocationByType[dispatchType] = locationIndex
    return {
        code = definition.code or "000",
        type = dispatchType,
        title = definition.title or "Incidente sin identificar",
        priority = definition.priority or "NORMAL",
        agency = definition.agency or "POLICE",
        operationalTier = operationalTier,
        minimumRank = definition.minimumRank or tierConfig.minimumRank or "Cadete",
        recommendedRank = definition.recommendedRank,
        requiredCertifications = copy(definition.requiredCertifications or {}),
        role = definition.role or "PRIMARY_RESPONSE",
        location = locations[locationIndex],
        locationIndex = locationIndex
    }
end

local function selectRandomDispatch()
    if type(Dispatches) ~= "table" or #Dispatches == 0 then return nil end
    local index = selectDifferentIndex(#Dispatches, lastDispatchIndex)
    lastDispatchIndex = index
    return buildDispatchInstance(Dispatches[index])
end

local function createFoundation(dispatch)
    if dispatch.incidentId and dispatch.assignmentId then
        local incident = IncidentManager.GetSnapshot(dispatch.incidentId)
        local assignment = AssignmentManager.GetSnapshot(dispatch.assignmentId)
        if incident and assignment and assignment.incidentId == incident.id then
            return assignment
        end
        return nil
    end

    local incident = IncidentManager.Create({
        type = dispatch.type,
        category = dispatch.type,
        priority = dispatch.priority,
        location = dispatch.location,
        source = "DISPATCH_T4B",
        metadata = {code = dispatch.code, title = dispatch.title,
            locationIndex = dispatch.locationIndex}
    })
    if not incident then return nil end

    local assignment = AssignmentManager.Create(incident.id, {
        agency = dispatch.agency,
        role = dispatch.role,
        priority = dispatch.priority,
        operationalTier = dispatch.operationalTier,
        minimumRank = dispatch.minimumRank,
        recommendedRank = dispatch.recommendedRank,
        requiredCertifications = dispatch.requiredCertifications,
        metadata = {legacyDispatch = true}
    })
    if not assignment then
        IncidentManager.Cancel(incident.id)
        return nil
    end
    dispatch.incidentId, dispatch.assignmentId = incident.id, assignment.id
    return assignment
end

function DispatchManager.Enqueue(dispatch)
    if type(dispatch) ~= "table" then return nil, "INVALID_DISPATCH" end
    if pendingCount() >= DispatchLifecycleConfig.maxPendingCalls then
        return nil, "QUEUE_FULL"
    end
    local assignment = createFoundation(dispatch)
    if not assignment then return nil, "FOUNDATION_FAILED" end
    local now = GetGameTimer()
    local call = {
        incidentId = dispatch.incidentId,
        assignmentId = dispatch.assignmentId,
        agency = assignment.agency,
        priority = dispatch.priority,
        operationalTier = assignment.operationalTier,
        minimumRank = assignment.minimumRank,
        recommendedRank = assignment.recommendedRank,
        requiredCertifications = copy(assignment.requiredCertifications),
        code = dispatch.code,
        type = dispatch.type,
        title = dispatch.title,
        role = assignment.role,
        location = dispatch.location,
        locationIndex = dispatch.locationIndex,
        createdAt = now,
        expiresAt = now + DispatchLifecycleConfig.expiryTime,
        status = "PENDING",
        legacy = dispatch
    }
    calls[call.assignmentId] = call
    recordHistory("CREATED", call)
    local risk = call.priority == "EMERGENCY" or call.priority == "HIGH"
    call.alertId = pushAlert(call,
        risk and "Incidente de alto riesgo disponible" or "Nueva llamada disponible",
        ("Código %s — %s"):format(call.code, call.title), true)
    refreshPoliceOS()
    return copy(call)
end

function DispatchManager.EnqueueAssignment(incidentId, assignmentData, dispatchData)
    if pendingCount() >= DispatchLifecycleConfig.maxPendingCalls then
        return nil, "QUEUE_FULL"
    end
    local incident = IncidentManager.GetSnapshot(incidentId)
    if not incident then return nil, "INCIDENT_NOT_FOUND" end
    local assignment = AssignmentManager.Create(incidentId, assignmentData)
    if not assignment then return nil, "ASSIGNMENT_FAILED" end
    local dispatch = copy(dispatchData or {})
    dispatch.incidentId = incidentId
    dispatch.assignmentId = assignment.id
    dispatch.type = dispatch.type or incident.type
    dispatch.priority = dispatch.priority or assignment.priority
    dispatch.agency = assignment.agency
    dispatch.operationalTier = assignment.operationalTier
    dispatch.minimumRank = assignment.minimumRank
    dispatch.recommendedRank = assignment.recommendedRank
    dispatch.requiredCertifications = assignment.requiredCertifications
    dispatch.role = assignment.role
    dispatch.location = dispatch.location or incident.location
    return DispatchManager.Enqueue(dispatch)
end

local function generateCall()
    local dispatch = selectRandomDispatch()
    if not dispatch then return false end
    local call, reason = DispatchManager.Enqueue(dispatch)
    if not call then
        print("[Dispatch T4B] Generación omitida: " .. tostring(reason))
        return false
    end
    return true
end

local function createDispatchBlip(dispatch)
    if not dispatch or not dispatch.location then return false end
    removeDispatchBlip()
    local blip = AddBlipForCoord(dispatch.location.x,
        dispatch.location.y, dispatch.location.z)
    SetBlipSprite(blip, 280)
    SetBlipColour(blip, 1)
    SetBlipScale(blip, 0.9)
    SetBlipAsShortRange(blip, false)
    SetBlipRoute(blip, true)
    SetBlipRouteColour(blip, 1)
    BeginTextCommandSetBlipName("STRING")
    AddTextComponentString(("Código %s - %s"):format(
        dispatch.code, dispatch.title))
    EndTextCommandSetBlipName(blip)
    PlayerData.DispatchBlip = blip
    SetNewWaypoint(dispatch.location.x, dispatch.location.y)
    return true
end

local function prepareScene(dispatch)
    if scenePreparing or scenePrepared then return false end
    if not SceneBuilder or type(SceneBuilder.Build) ~= "function" then
        print("[Sentinel AI] ERROR: SceneBuilder.Build no está disponible.")
        return false
    end
    scenePreparing = true
    CreateThread(function()
        local success, layout = pcall(SceneBuilder.Build, dispatch)
        scenePreparing = false
        scenePrepared = success and layout ~= nil
        if not success then
            print("[Dispatch T4B] Escena legacy falló sin bloquear cola: "
                .. tostring(layout))
        elseif scenePrepared then
            Sentinel.Notify("CENTRAL", "Escena validada. Unidad en ruta.",
                {90, 190, 255})
        end
    end)
    return true
end

function DispatchManager.Accept(assignmentId, options)
    options = type(options) == "table" and options or {}
    local call = assignmentId and calls[assignmentId] or nil
    local now = GetGameTimer()
    local source = tostring(options.source or "UNKNOWN")
    local ageMs = call and math.max(0, now - call.createdAt) or -1
    print("[Dispatch ACCEPT TRACE]")
    print(("source=%s"):format(source))
    print(("assignmentId=%s"):format(tostring(assignmentId)))
    print(("incidentId=%s"):format(tostring(call and call.incidentId)))
    print(("ageMs=%s"):format(tostring(ageMs)))
    print(("manual=%s"):format(tostring(source == "MANUAL")))
    print(("autoAssign=%s"):format(tostring(source == "AUTOASSIGN")))
    print(("legacy=%s"):format(tostring(options.legacy == true)))

    if source ~= "MANUAL" and source ~= "AUTOASSIGN" then
        return false, "INVALID_ACCEPT_SOURCE"
    end

    local eligible, reason = DispatchManager.IsAssignmentEligible(call, {
        onDuty = PlayerData and PlayerData.OnDuty == true,
        rank = getEffectiveRank(),
        forAcceptance = true
    })
    if not eligible then
        if reason == "RANK_REQUIRED" and PoliceAlertManager then
            PoliceAlertManager.Push({
                type = "CENTRAL",
                source = "CENTRAL",
                title = "Asignación no autorizada",
                message = "Unidad no autorizada para asignación principal.",
                priority = "NORMAL",
                expiresAt = GetGameTimer() + 5000
            })
        end
        return false, reason
    end

    if type(CreateCurrentCase) ~= "function" or not CreateCurrentCase(call) then
        print("[Dispatch T4B] Assignment legacy no pudo crear Case; cola continúa.")
        return false, "LEGACY_CASE_FAILED"
    end

    local unit = AssignmentManager.BuildPlayerUnit()
    if unit then AssignmentManager.AssignUnit(call.assignmentId, unit) end
    call.status = "ASSIGNED"

    local missionStarted = MissionManager
        and type(MissionManager.StartMission) == "function"
        and MissionManager.StartMission({incidentId = call.incidentId,
            assignmentId = call.assignmentId})
    if missionStarted ~= true then
        if type(CancelCurrentCase) == "function" then CancelCurrentCase() end
        call.status = "CANCELLED"
        AssignmentManager.Cancel(call.assignmentId)
        recordHistory("CANCELLED", call, {reason = "LEGACY_MISSION_FAILED"})
        updateCallAlert(call, "Asignación cancelada", "Mission legacy no disponible.")
        closeIncidentIfOrphaned(call.incidentId)
        refreshPoliceOS()
        print("[Dispatch T4B] Mission legacy no inició; cola continúa operativa.")
        return false, "LEGACY_MISSION_FAILED"
    end

    recordHistory("ACCEPTED", call, {
        source = source,
        autoAssigned = source == "AUTOASSIGN"
    })
    AssignmentManager.Activate(call.assignmentId)
    IncidentManager.UpdateStatus(call.incidentId, "ACTIVE")
    call.status = "ACTIVE"
    activeAssignmentId = call.assignmentId
    PlayerData.CurrentDispatch = call.legacy
    PlayerData.DispatchState = "EN_ROUTE"
    updateCallAlert(call, "Unidad asignada", call.title)
    resetSceneRuntime()
    createDispatchBlip(call.legacy)
    prepareScene(call.legacy)
    refreshPoliceOS()
    return true
end

function DispatchManager.AcceptCurrent(options)
    local pending = sortedPending()
    if not pending[1] then return false, "NO_PENDING_CALL" end
    return DispatchManager.Accept(pending[1].assignmentId, options)
end

function DispatchManager.Decline(assignmentId)
    local call = assignmentId and calls[assignmentId] or nil
    if not call or call.status ~= "PENDING" then return false, "NOT_PENDING" end
    if not PlayerData or PlayerData.OnDuty ~= true then return false, "OFF_DUTY" end
    AssignmentManager.Decline(call.assignmentId)
    call.status = "DECLINED"
    recordHistory("DECLINED", call)
    updateCallAlert(call, "Llamada rechazada", call.title)
    closeIncidentIfOrphaned(call.incidentId)
    refreshPoliceOS()
    return true
end

function DispatchManager.GetQueue()
    return sortedPending({onDuty = PlayerData and PlayerData.OnDuty == true,
        rank = getEffectiveRank(), forAcceptance = true})
end

function DispatchManager.GetHistory()
    return copy(history)
end

function DispatchManager.GetCalls()
    local result = {}
    for _, call in pairs(calls) do
        result[#result + 1] = snapshotCall(call, {
            onDuty = PlayerData and PlayerData.OnDuty == true,
            rank = getEffectiveRank(),
            forAcceptance = true
        })
    end
    table.sort(result, function(left, right)
        return left.createdAt > right.createdAt
    end)
    return result
end

function DispatchManager.GetCall(assignmentId)
    local call = calls[assignmentId]
    return call and snapshotCall(call) or nil
end

function DispatchManager.GetOperationalStatus()
    return getOperationalStatus()
end

function DispatchManager.GetSnapshot()
    local pending = DispatchManager.GetQueue()
    local active = activeAssignmentId and calls[activeAssignmentId] or nil
    local focus = active and snapshotCall(active,
        {onDuty = true, rank = getEffectiveRank(), forAcceptance = false})
        or pending[1]
    return {
        lifecycle = focus and focus.status or "NONE",
        phase = PlayerData and PlayerData.DispatchState or "OFF_DUTY",
        operationalStatus = getOperationalStatus(),
        pending = #pending > 0,
        active = active ~= nil,
        assignmentId = focus and focus.assignmentId or nil,
        incidentId = focus and focus.incidentId or nil,
        code = focus and focus.code or nil,
        title = focus and focus.title or nil,
        type = focus and focus.type or nil,
        priority = focus and focus.priority or nil,
        operationalTier = focus and focus.operationalTier or nil,
        minimumRank = focus and focus.minimumRank or nil,
        distance = focus and focus.distance or nil,
        canAccept = focus and focus.status == "PENDING"
            and focus.eligible == true or false,
        canDecline = focus and focus.status == "PENDING" or false,
        calls = pending,
        recentCalls = DispatchManager.GetCalls(),
        current = active and snapshotCall(active) or nil,
        history = copy(history)
    }
end

function CompleteCurrentDispatch()
    if not PlayerData or PlayerData.DispatchState ~= "REPORT" then return false end
    local call = activeAssignmentId and calls[activeAssignmentId] or nil
    if call then
        AssignmentManager.Complete(call.assignmentId)
        call.status = "COMPLETED"
        recordHistory("COMPLETED", call)
        updateCallAlert(call, "Incidente actualizado", "Assignment completado.")
        closeIncidentIfOrphaned(call.incidentId)
    end
    clearActiveBridge(false)
    PlayerData.DispatchState = PlayerData.OnDuty and "WAITING" or "OFF_DUTY"
    if MissionManager then
        MissionManager.Active = false
        MissionManager.StartedAt = 0
        MissionManager.IncidentId = nil
        MissionManager.AssignmentId = nil
    end
    refreshPoliceOS()
    return true
end

local function expirePendingCalls(now)
    for _, call in pairs(calls) do
        if call.status == "PENDING" and now >= call.expiresAt then
            AssignmentManager.Expire(call.assignmentId)
            call.status = "EXPIRED"
            recordHistory("EXPIRED", call)
            updateCallAlert(call, "Llamada expirada", call.title)
            closeIncidentIfOrphaned(call.incidentId)
            refreshPoliceOS()
        end
    end
end

local function tryAutoAssign(now)
    if DispatchLifecycleConfig.autoAssignEnabled ~= true then return false end
    if getOperationalStatus() ~= "AVAILABLE" then return false end
    for _, call in ipairs(DispatchManager.GetQueue()) do
        local internal = calls[call.assignmentId]
        local ageMs = internal and math.max(0, now - internal.createdAt) or 0
        if internal and ageMs >= DispatchLifecycleConfig.autoAssignDelay then
            if not internal.autoAssignLogged then
                internal.autoAssignLogged = true
                print("[AUTOASSIGN]")
                print(("assignmentId=%s"):format(call.assignmentId))
                print(("ageMs=%s"):format(ageMs))
                print(("delayMs=%s"):format(
                    DispatchLifecycleConfig.autoAssignDelay))
                print(("eligible=%s"):format(tostring(call.eligible == true)))
            end
            if call.eligible then
                return DispatchManager.Accept(call.assignmentId, {
                    source = "AUTOASSIGN"
                })
            end
        end
    end
    return false
end

CreateThread(function()
    while true do
        Wait(500)
        local now = GetGameTimer()
        expirePendingCalls(now)

        if PlayerData and PlayerData.OnDuty then
            if not nextDispatchAt then
                nextDispatchAt = now + DispatchLifecycleConfig.generationInterval
            elseif now >= nextDispatchAt then
                nextDispatchAt = now + DispatchLifecycleConfig.generationInterval
                if pendingCount() < DispatchLifecycleConfig.maxPendingCalls then
                    generateCall()
                end
            end
            tryAutoAssign(now)
        else
            nextDispatchAt = nil
        end
    end
end)

CreateThread(function()
    while true do
        Wait(250)
        if PlayerData and PlayerData.DispatchState == "EN_ROUTE"
            and PlayerData.CurrentDispatch
            and PlayerData.CurrentDispatch.location then
            local dispatch = PlayerData.CurrentDispatch
            local distance = #(GetEntityCoords(PlayerPedId()) - dispatch.location)
            if distance <= 180.0 and not scenePrepared and not scenePreparing then
                prepareScene(dispatch)
            end
            if distance <= 150.0 and scenePrepared and not sceneSpawned
                and type(SpawnCrimeScene) == "function" then
                sceneSpawned = SpawnCrimeScene(dispatch, true) ~= false
            end
            if distance <= 25.0 then
                removeDispatchBlip()
                PlayerData.DispatchState = "ON_SCENE"
                if not sceneSpawned and type(SpawnCrimeScene) == "function" then
                    sceneSpawned = SpawnCrimeScene(dispatch, false) ~= false
                end
                if type(ActivateCrimeScene) == "function" then ActivateCrimeScene() end
                Sentinel.Notify("CENTRAL", "Unidad en escena. Evalúe la situación.",
                    {0, 255, 0})
            end
        end
    end
end)

AddEventHandler("sentinel:assignment:updated", function(assignment)
    local call = assignment and calls[assignment.id] or nil
    if call and assignment.status == "CANCELLED"
        and call.status ~= "CANCELLED" and call.status ~= "COMPLETED" then
        call.status = "CANCELLED"
        recordHistory("CANCELLED", call)
        if activeAssignmentId == call.assignmentId then
            clearActiveBridge(false)
        end
        closeIncidentIfOrphaned(call.incidentId)
        refreshPoliceOS()
    end
end)

AddEventHandler("onResourceStop", function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end
    clearActiveBridge(false)
    calls = {}
    history = {}
    nextDispatchAt = nil
end)

print("[Sentinel AI] DispatchManager T4B listo.")
