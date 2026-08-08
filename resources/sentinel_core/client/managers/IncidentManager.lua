IncidentManager = IncidentManager or {}

-- T4A mantiene autoridad local. Create/UpdateStatus/Resolve/Cancel y la
-- generación de IDs deberán ejecutarse en servidor al habilitar multiplayer.

local incidents = {}
local sequence = 0
local validStatuses = {
    NEW = true,
    ACTIVE = true,
    RESOLVED = true,
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
    return ("INC-%s-%06d"):format(date, sequence)
end

local function emitUpdated(incident)
    TriggerEvent("sentinel:incident:updated", copy(incident))
end

function IncidentManager.Create(data)
    data = type(data) == "table" and data or {}
    local now = timestamp()
    local incident = {
        id = nextId(),
        type = tostring(data.type or "GENERIC"),
        category = tostring(data.category or data.type or "GENERAL"),
        priority = tostring(data.priority or "NORMAL"),
        status = "NEW",
        location = copy(data.location),
        createdAt = now,
        updatedAt = now,
        source = tostring(data.source or "SYSTEM"),
        metadata = copy(data.metadata or {}),
        assignments = {}
    }

    incidents[incident.id] = incident
    TriggerEvent("sentinel:incident:created", copy(incident))
    return copy(incident)
end

function IncidentManager.GetSnapshot(id)
    return copy(incidents[id])
end

function IncidentManager.GetActiveIncidents()
    local result = {}
    for _, incident in pairs(incidents) do
        if incident.status == "NEW" or incident.status == "ACTIVE" then
            result[#result + 1] = copy(incident)
        end
    end
    table.sort(result, function(left, right)
        return left.createdAt < right.createdAt
            or (left.createdAt == right.createdAt and left.id < right.id)
    end)
    return result
end

function IncidentManager.UpdateStatus(id, status)
    local incident = incidents[id]
    if not incident or not validStatuses[status] then
        return false
    end

    incident.status = status
    incident.updatedAt = timestamp()
    emitUpdated(incident)
    return true
end

function IncidentManager.Resolve(id)
    return IncidentManager.UpdateStatus(id, "RESOLVED")
end

function IncidentManager.Cancel(id)
    return IncidentManager.UpdateStatus(id, "CANCELLED")
end

function IncidentManager.AddAssignmentReference(id, assignmentId)
    local incident = incidents[id]
    if not incident or type(assignmentId) ~= "string" then
        return false
    end

    for _, currentId in ipairs(incident.assignments) do
        if currentId == assignmentId then
            return true
        end
    end

    incident.assignments[#incident.assignments + 1] = assignmentId
    incident.updatedAt = timestamp()
    emitUpdated(incident)
    return true
end
