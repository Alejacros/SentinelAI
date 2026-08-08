AssignmentManager = AssignmentManager or {}

-- T4B mantiene autoridad local. Create/AssignUnit y todas las transiciones,
-- incluida la generación de IDs, deberán ejecutarse en servidor en T4C.

local assignments = {}
local sequence = 0
local validStatuses = {
    PENDING = true,
    ASSIGNED = true,
    ACTIVE = true,
    DECLINED = true,
    EXPIRED = true,
    COMPLETED = true,
    CANCELLED = true
}

local function copy(value)
    if type(value) ~= "table" then
        return value
    end

    local result = {}
    for key, item in pairs(value) do
        result[key] = copy(item)
    end
    return result
end

local function timestamp()
    return os and os.time and os.time() or GetGameTimer()
end

local function nextId()
    sequence = sequence + 1
    local date = os and os.date and os.date("%Y%m%d") or "RUNTIME"
    return ("ASN-%s-%06d"):format(date, sequence)
end

local function updateStatus(assignment, status)
    if not assignment or not validStatuses[status] then
        return false
    end

    assignment.status = status
    assignment.updatedAt = timestamp()
    TriggerEvent("sentinel:assignment:updated", copy(assignment))
    return true
end

function AssignmentManager.Create(incidentId, data)
    local incident = IncidentManager.GetSnapshot(incidentId)
    data = type(data) == "table" and data or {}
    local agency = tostring(data.agency or "POLICE")

    if not incident or not SentinelAgencies[agency] then
        return nil
    end

    local now = timestamp()
    local assignment = {
        id = nextId(),
        incidentId = incidentId,
        agency = agency,
        role = tostring(data.role or "PRIMARY_RESPONSE"),
        priority = tostring(data.priority or incident.priority or "NORMAL"),
        operationalTier = tostring(data.operationalTier or "T1_BASIC"),
        minimumRank = tostring(data.minimumRank or "Cadete"),
        recommendedRank = data.recommendedRank
            and tostring(data.recommendedRank) or nil,
        requiredCertifications = copy(data.requiredCertifications or {}),
        status = "PENDING",
        assignedUnit = nil,
        createdAt = now,
        updatedAt = now,
        metadata = copy(data.metadata or {})
    }

    assignments[assignment.id] = assignment
    IncidentManager.AddAssignmentReference(incidentId, assignment.id)
    TriggerEvent("sentinel:assignment:created", copy(assignment))
    return copy(assignment)
end

function AssignmentManager.GetSnapshot(id)
    return copy(assignments[id])
end

function AssignmentManager.GetAssignmentsForIncident(incidentId)
    local result = {}
    for _, assignment in pairs(assignments) do
        if assignment.incidentId == incidentId then
            result[#result + 1] = copy(assignment)
        end
    end
    table.sort(result, function(left, right)
        return left.createdAt < right.createdAt
            or (left.createdAt == right.createdAt and left.id < right.id)
    end)
    return result
end

function AssignmentManager.BuildPlayerUnit()
    local callsign = PlayerData and PlayerData.Unit or nil
    if not callsign then
        return nil
    end

    return {
        id = tostring(callsign),
        callsign = tostring(callsign),
        agency = "POLICE",
        operator = GetPlayerServerId(PlayerId()),
        status = PlayerData.DispatchState or "WAITING"
    }
end

function AssignmentManager.AssignUnit(id, unit)
    local assignment = assignments[id]
    if not assignment or type(unit) ~= "table" or not unit.id then
        return false
    end

    assignment.assignedUnit = copy(unit)
    return updateStatus(assignment, "ASSIGNED")
end

function AssignmentManager.Activate(id)
    return updateStatus(assignments[id], "ACTIVE")
end

function AssignmentManager.Complete(id)
    return updateStatus(assignments[id], "COMPLETED")
end

function AssignmentManager.Decline(id)
    return updateStatus(assignments[id], "DECLINED")
end

function AssignmentManager.Expire(id)
    return updateStatus(assignments[id], "EXPIRED")
end

function AssignmentManager.Cancel(id)
    return updateStatus(assignments[id], "CANCELLED")
end
