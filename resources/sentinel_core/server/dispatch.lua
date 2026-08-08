print("[Sentinel AI] Dispatch server authority T4C cargando...")

local incidents = {}
local assignments = {}
local calls = {}
local history = {}
local units = {}
local activeByPlayer = {}
local incidentSequence = 0
local assignmentSequence = 0
local lastTemplateIndex = nil
local lastLocationByType = {}
local nextGenerationAt = nil
local lastRequestAt = {}

local function copy(value)
    if type(value) ~= "table" then return value end
    local result = {}
    for key, item in pairs(value) do result[key] = copy(item) end
    return result
end

local function now()
    return GetGameTimer()
end

local function nextId(prefix, sequence)
    return ("%s-%s-%06d"):format(prefix, os.date("%Y%m%d"), sequence)
end

local function log(action, incidentId, assignmentId, detail)
    print(("[Dispatch Server] %s | incident=%s | assignment=%s%s"):format(
        action, tostring(incidentId or "-"), tostring(assignmentId or "-"),
        detail and (" | " .. tostring(detail)) or ""))
end

local function record(eventName, assignment, metadata)
    history[#history + 1] = {
        event = eventName,
        incidentId = assignment and assignment.incidentId or nil,
        assignmentId = assignment and assignment.id or nil,
        at = now(),
        metadata = copy(metadata or {})
    }
    while #history > DispatchLifecycleConfig.maxHistory do
        table.remove(history, 1)
    end
end

local function callSnapshot(call)
    local result = copy(call)
    result.remainingMs = math.max(0, call.expiresAt - now())
    return result
end

local function buildSnapshot()
    local queue, incidentList, assignmentList = {}, {}, {}
    for _, call in pairs(calls) do
        queue[#queue + 1] = callSnapshot(call)
    end
    for _, incident in pairs(incidents) do
        incidentList[#incidentList + 1] = copy(incident)
    end
    for _, assignment in pairs(assignments) do
        assignmentList[#assignmentList + 1] = copy(assignment)
    end
    table.sort(queue, function(a, b) return a.createdAt < b.createdAt end)
    return {
        serverNow = now(),
        calls = queue,
        incidents = incidentList,
        assignments = assignmentList,
        history = copy(history)
    }
end

local function replicate(target)
    TriggerClientEvent("sentinel:client:dispatch:snapshot", target or -1,
        buildSnapshot())
end

local function result(target, action, assignmentId, success, reason)
    TriggerClientEvent("sentinel:client:dispatch:result", target,
        action, assignmentId, success == true, reason)
end

local function rateLimited(sourceId, action)
    local key = ("%s:%s"):format(sourceId, action)
    local current = now()
    if lastRequestAt[key] and current - lastRequestAt[key] < 250 then
        return true
    end
    lastRequestAt[key] = current
    return false
end

local function getRank(sourceId)
    local profile = type(GetSentinelProfileSnapshot) == "function"
        and GetSentinelProfileSnapshot(sourceId) or nil
    if not profile or profile.hasCharacter ~= true then return nil end
    return SentinelCareer.GetRankForXP(profile.xp).name
end

local function isEligible(sourceId, assignment)
    if not assignment then return false, "ASSIGNMENT_NOT_FOUND" end
    if assignment.status ~= "PENDING" then
        return false, assignment.status == "ASSIGNED" and "ALREADY_ASSIGNED"
            or "NOT_PENDING"
    end
    if assignment.agency ~= "POLICE" then return false, "AGENCY_UNAVAILABLE" end
    local unit = units[sourceId]
    if not unit or unit.onDuty ~= true then return false, "OFF_DUTY" end
    if activeByPlayer[sourceId] then return false, "MISSION_ACTIVE" end
    local rank = getRank(sourceId)
    if not rank then return false, "PROFILE_NOT_READY" end
    if not SentinelCareer.IsRankAtLeast(rank, assignment.minimumRank) then
        return false, "RANK_REQUIRED"
    end
    return true
end

local function aggregateIncident(incidentId)
    local incident = incidents[incidentId]
    if not incident then return end
    local open, completed = false, false
    for _, assignmentId in ipairs(incident.assignments) do
        local assignment = assignments[assignmentId]
        if assignment and (assignment.status == "PENDING"
            or assignment.status == "ASSIGNED" or assignment.status == "ACTIVE") then
            open = true
        elseif assignment and assignment.status == "COMPLETED" then
            completed = true
        end
    end
    if not open then
        incident.status = completed and "RESOLVED" or "CANCELLED"
        incident.updatedAt = now()
    end
end

local function selectDifferent(count, previous)
    if count <= 1 then return 1 end
    local selected
    repeat selected = math.random(1, count) until selected ~= previous
    return selected
end

local function createCall()
    if type(Dispatches) ~= "table" or #Dispatches == 0 then return false end
    local templateIndex = selectDifferent(#Dispatches, lastTemplateIndex)
    lastTemplateIndex = templateIndex
    local template = Dispatches[templateIndex]
    if type(template.locations) ~= "table" or #template.locations == 0 then
        return false
    end
    local locationIndex = selectDifferent(#template.locations,
        lastLocationByType[template.type])
    lastLocationByType[template.type] = locationIndex
    local createdAt = now()
    incidentSequence = incidentSequence + 1
    assignmentSequence = assignmentSequence + 1
    local incidentId = nextId("INC", incidentSequence)
    local assignmentId = nextId("ASN", assignmentSequence)
    local incident = {
        id = incidentId,
        type = tostring(template.type or "GENERIC"),
        category = tostring(template.type or "GENERAL"),
        priority = tostring(template.priority or "NORMAL"),
        status = "NEW",
        location = template.locations[locationIndex],
        createdAt = createdAt,
        updatedAt = createdAt,
        source = "DISPATCH_SERVER",
        metadata = {code = template.code, title = template.title,
            locationIndex = locationIndex},
        assignments = {assignmentId}
    }
    local tier = DispatchOperationalTiers[template.operationalTier] or {}
    local assignment = {
        id = assignmentId,
        incidentId = incidentId,
        agency = "POLICE",
        role = tostring(template.role or "PRIMARY_RESPONSE"),
        priority = incident.priority,
        operationalTier = tostring(template.operationalTier or "T1_BASIC"),
        minimumRank = tostring(template.minimumRank or tier.minimumRank or "Cadete"),
        recommendedRank = template.recommendedRank,
        requiredCertifications = copy(template.requiredCertifications or {}),
        status = "PENDING",
        assignedUnit = nil,
        owner = nil,
        createdAt = createdAt,
        updatedAt = createdAt,
        metadata = {templateIndex = templateIndex}
    }
    local call = {
        incidentId = incidentId,
        assignmentId = assignmentId,
        agency = assignment.agency,
        priority = assignment.priority,
        operationalTier = assignment.operationalTier,
        minimumRank = assignment.minimumRank,
        recommendedRank = assignment.recommendedRank,
        requiredCertifications = copy(assignment.requiredCertifications),
        code = tostring(template.code or "000"),
        type = incident.type,
        title = tostring(template.title or "Incidente sin identificar"),
        role = assignment.role,
        location = incident.location,
        locationIndex = locationIndex,
        createdAt = createdAt,
        expiresAt = createdAt + DispatchLifecycleConfig.expiryTime,
        status = "PENDING"
    }
    incidents[incidentId], assignments[assignmentId], calls[assignmentId] =
        incident, assignment, call
    record("CREATED", assignment)
    log("INCIDENT CREATED", incidentId)
    log("ASSIGNMENT CREATED", incidentId, assignmentId)
    replicate()
    return true
end

local function assignToPlayer(sourceId, assignment, origin)
    assignment.status = "ASSIGNED"
    assignment.owner = sourceId
    assignment.assignedUnit = copy(units[sourceId])
    assignment.updatedAt = now()
    calls[assignment.id].status = "ASSIGNED"
    activeByPlayer[sourceId] = assignment.id
    units[sourceId].status = "ASSIGNED"
    record("ACCEPTED", assignment, {player = sourceId, source = origin})
    log("ACCEPTED", assignment.incidentId, assignment.id,
        ("player=%s source=%s"):format(sourceId, origin))
    result(sourceId, "accept", assignment.id, true)
end

RegisterNetEvent("sentinel:server:dispatch:setDuty", function(onDuty, callsign)
    local sourceId = source
    local authorizedRank = getRank(sourceId)
    if onDuty == true and not authorizedRank then
        units[sourceId] = {player = sourceId, agency = "POLICE",
            onDuty = false, status = "OFF_DUTY"}
        return
    end
    units[sourceId] = {
        player = sourceId,
        callsign = onDuty == true and tostring(callsign or "UNASSIGNED") or nil,
        agency = "POLICE",
        onDuty = onDuty == true,
        status = onDuty == true and "AVAILABLE" or "OFF_DUTY"
    }
end)

RegisterNetEvent("sentinel:server:dispatch:requestSnapshot", function()
    replicate(source)
end)

RegisterNetEvent("sentinel:server:dispatch:accept", function(assignmentId)
    local sourceId = source
    if rateLimited(sourceId, "accept") then return end
    assignmentId = type(assignmentId) == "string" and assignmentId or nil
    local assignment = assignmentId and assignments[assignmentId] or nil
    log("ACCEPT REQUEST", assignment and assignment.incidentId, assignmentId,
        "player=" .. sourceId)
    local eligible, reason = isEligible(sourceId, assignment)
    if not eligible then
        result(sourceId, "accept", assignmentId, false, reason)
        return
    end
    -- Event handlers execute serially; this guarded transition is the atomic
    -- PENDING -> ASSIGNED boundary for T4C.
    assignToPlayer(sourceId, assignment, "MANUAL")
    replicate()
end)

RegisterNetEvent("sentinel:server:dispatch:decline", function(assignmentId)
    local sourceId = source
    if rateLimited(sourceId, "decline") then return end
    local assignment = type(assignmentId) == "string" and assignments[assignmentId]
        or nil
    local eligible, reason = isEligible(sourceId, assignment)
    if not eligible then
        result(sourceId, "decline", assignmentId, false, reason)
        return
    end
    assignment.status, assignment.updatedAt = "DECLINED", now()
    calls[assignmentId].status = "DECLINED"
    record("DECLINED", assignment, {player = sourceId})
    aggregateIncident(assignment.incidentId)
    log("DECLINED", assignment.incidentId, assignmentId, "player=" .. sourceId)
    result(sourceId, "decline", assignmentId, true)
    replicate()
end)

RegisterNetEvent("sentinel:server:dispatch:missionStarted",
    function(assignmentId, success)
        local sourceId = source
        local assignment = assignments[assignmentId]
        if not assignment or assignment.owner ~= sourceId
            or assignment.status ~= "ASSIGNED" then return end
        if success ~= true then
            assignment.status = "CANCELLED"
            calls[assignmentId].status = "CANCELLED"
            activeByPlayer[sourceId] = nil
            units[sourceId].status = "AVAILABLE"
            record("CANCELLED", assignment, {reason = "MISSION_START_FAILED"})
            aggregateIncident(assignment.incidentId)
            log("CANCELLED", assignment.incidentId, assignmentId,
                "MISSION_START_FAILED")
            result(sourceId, "missionStarted", assignmentId, false,
                "MISSION_START_FAILED")
        else
            assignment.status, assignment.updatedAt = "ACTIVE", now()
            calls[assignmentId].status = "ACTIVE"
            incidents[assignment.incidentId].status = "ACTIVE"
            incidents[assignment.incidentId].updatedAt = now()
            units[sourceId].status = "ACTIVE"
            record("ACTIVE", assignment, {player = sourceId})
            log("ACTIVE", assignment.incidentId, assignmentId,
                "player=" .. sourceId)
            result(sourceId, "missionStarted", assignmentId, true)
        end
        replicate()
    end)

local function finishOwned(sourceId, assignmentId, action)
    local assignment = assignments[assignmentId]
    if not assignment or assignment.owner ~= sourceId then
        return false, "NOT_OWNER"
    end
    if assignment.status ~= "ACTIVE" and assignment.status ~= "ASSIGNED" then
        return false, "INVALID_STATUS"
    end
    local status = action == "complete" and "COMPLETED" or "CANCELLED"
    assignment.status, assignment.updatedAt = status, now()
    calls[assignmentId].status = status
    activeByPlayer[sourceId] = nil
    if units[sourceId] then units[sourceId].status = "AVAILABLE" end
    record(status, assignment, {player = sourceId})
    aggregateIncident(assignment.incidentId)
    log(status, assignment.incidentId, assignmentId, "player=" .. sourceId)
    return true
end

RegisterNetEvent("sentinel:server:dispatch:complete", function(assignmentId)
    local sourceId = source
    local ok, reason = finishOwned(sourceId, assignmentId, "complete")
    result(sourceId, "complete", assignmentId, ok, reason)
    if ok then replicate() end
end)

RegisterNetEvent("sentinel:server:dispatch:cancel", function(assignmentId, reason)
    local sourceId = source
    local ok, errorReason = finishOwned(sourceId, assignmentId, "cancel")
    result(sourceId, "cancel", assignmentId, ok, errorReason or reason)
    if ok then replicate() end
end)

CreateThread(function()
    while true do
        Wait(500)
        local current = now()
        local changed = false
        for id, assignment in pairs(assignments) do
            local call = calls[id]
            if assignment.status == "PENDING" and current >= call.expiresAt then
                assignment.status, assignment.updatedAt = "EXPIRED", current
                call.status = "EXPIRED"
                record("EXPIRED", assignment)
                aggregateIncident(assignment.incidentId)
                log("EXPIRED", assignment.incidentId, id)
                changed = true
            end
        end
        local onDuty = false
        for _, unit in pairs(units) do
            if unit.onDuty then onDuty = true break end
        end
        if onDuty then
            nextGenerationAt = nextGenerationAt
                or current + DispatchLifecycleConfig.generationInterval
            local pending = 0
            for _, assignment in pairs(assignments) do
                if assignment.status == "PENDING" then pending = pending + 1 end
            end
            if current >= nextGenerationAt then
                nextGenerationAt = current + DispatchLifecycleConfig.generationInterval
                if pending < DispatchLifecycleConfig.maxPendingCalls then
                    createCall()
                end
            end
            if DispatchLifecycleConfig.autoAssignEnabled == true then
                for sourceId, unit in pairs(units) do
                    if unit.onDuty and unit.status == "AVAILABLE"
                        and not activeByPlayer[sourceId] then
                        for _, assignment in pairs(assignments) do
                            local call = calls[assignment.id]
                            local eligible = isEligible(sourceId, assignment)
                            if eligible and current - assignment.createdAt
                                >= DispatchLifecycleConfig.autoAssignDelay then
                                assignToPlayer(sourceId, assignment, "AUTOASSIGN")
                                changed = true
                                break
                            end
                        end
                    end
                end
            end
        else
            nextGenerationAt = nil
        end
        if changed then replicate() end
    end
end)

AddEventHandler("playerDropped", function()
    local sourceId = source
    local assignmentId = activeByPlayer[sourceId]
    if assignmentId then
        finishOwned(sourceId, assignmentId, "cancel")
        replicate()
    end
    units[sourceId] = nil
    activeByPlayer[sourceId] = nil
    for key in pairs(lastRequestAt) do
        if key:match("^" .. sourceId .. ":") then lastRequestAt[key] = nil end
    end
end)

print("[Sentinel AI] Dispatch server authority T4C listo.")
