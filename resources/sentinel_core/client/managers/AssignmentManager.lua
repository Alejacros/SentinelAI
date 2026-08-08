AssignmentManager = AssignmentManager or {}

-- T4C: cache cliente de solo lectura. El servidor valida ownership y lifecycle.
local assignments = {}

local function copy(value)
    if type(value) ~= "table" then return value end
    local result = {}
    for key, item in pairs(value) do result[key] = copy(item) end
    return result
end

function AssignmentManager.ApplyServerSnapshot(snapshot)
    local previous = assignments
    assignments = {}
    for _, assignment in ipairs(type(snapshot) == "table" and snapshot or {}) do
        if type(assignment) == "table" and type(assignment.id) == "string" then
            assignments[assignment.id] = copy(assignment)
            if not previous[assignment.id] then
                TriggerEvent("sentinel:assignment:created", copy(assignment))
            elseif previous[assignment.id].status ~= assignment.status
                or previous[assignment.id].updatedAt ~= assignment.updatedAt then
                TriggerEvent("sentinel:assignment:updated", copy(assignment))
            end
        end
    end
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
    table.sort(result, function(a, b) return a.createdAt < b.createdAt end)
    return result
end

function AssignmentManager.BuildPlayerUnit()
    return {
        id = tostring(PlayerData and PlayerData.Unit or "UNASSIGNED"),
        callsign = tostring(PlayerData and PlayerData.Unit or "UNASSIGNED"),
        agency = "POLICE",
        operator = GetPlayerServerId(PlayerId()),
        status = PlayerData and PlayerData.DispatchState or "WAITING"
    }
end

function AssignmentManager.Create() return nil, "SERVER_AUTHORITY" end
function AssignmentManager.AssignUnit() return false, "SERVER_AUTHORITY" end
function AssignmentManager.Activate() return false, "SERVER_AUTHORITY" end
function AssignmentManager.Complete() return false, "SERVER_AUTHORITY" end
function AssignmentManager.Decline() return false, "SERVER_AUTHORITY" end
function AssignmentManager.Expire() return false, "SERVER_AUTHORITY" end
function AssignmentManager.Cancel() return false, "SERVER_AUTHORITY" end
