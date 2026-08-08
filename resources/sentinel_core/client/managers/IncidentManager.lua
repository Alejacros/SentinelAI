IncidentManager = IncidentManager or {}

-- T4C: cache cliente de solo lectura. El servidor es la fuente de verdad.
local incidents = {}

local function copy(value)
    if type(value) ~= "table" then return value end
    local result = {}
    for key, item in pairs(value) do result[key] = copy(item) end
    return result
end

function IncidentManager.ApplyServerSnapshot(snapshot)
    local previous = incidents
    incidents = {}
    for _, incident in ipairs(type(snapshot) == "table" and snapshot or {}) do
        if type(incident) == "table" and type(incident.id) == "string" then
            incidents[incident.id] = copy(incident)
            if not previous[incident.id] then
                TriggerEvent("sentinel:incident:created", copy(incident))
            elseif previous[incident.id].status ~= incident.status
                or previous[incident.id].updatedAt ~= incident.updatedAt then
                TriggerEvent("sentinel:incident:updated", copy(incident))
            end
        end
    end
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
    table.sort(result, function(a, b) return a.createdAt < b.createdAt end)
    return result
end

function IncidentManager.Create()
    return nil, "SERVER_AUTHORITY"
end

function IncidentManager.UpdateStatus()
    return false, "SERVER_AUTHORITY"
end

function IncidentManager.Resolve()
    return false, "SERVER_AUTHORITY"
end

function IncidentManager.Cancel()
    return false, "SERVER_AUTHORITY"
end

function IncidentManager.AddAssignmentReference()
    return false, "SERVER_AUTHORITY"
end
