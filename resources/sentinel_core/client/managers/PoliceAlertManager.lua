PoliceAlertManager = {
    Queue = {},
    History = {},
    Subscribers = {},
    NextId = 1
}

local VALID_TYPES = {
    INFO = true, SUCCESS = true, WARNING = true, CRITICAL = true,
    DISPATCH = true, CENTRAL = true, VEHICLE = true, ALPR = true
}

local PRIORITY_WEIGHT = {
    LOW = 1,
    NORMAL = 2,
    HIGH = 3,
    EMERGENCY = 4
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

local function notifySubscribers(eventName, alert)
    for _, subscriber in pairs(PoliceAlertManager.Subscribers) do
        pcall(subscriber, eventName, copyTable(alert))
    end

    TriggerEvent("sentinel:alertsUpdated", eventName, copyTable(alert))
end

local function findAlert(id)
    for index, alert in ipairs(PoliceAlertManager.Queue) do
        if alert.id == id then
            return alert, index
        end
    end

    return nil, nil
end

function PoliceAlertManager.Push(alert)
    alert = type(alert) == "table" and copyTable(alert) or {}
    alert.id = alert.id or ("ALERT-%06d"):format(
        PoliceAlertManager.NextId
    )
    PoliceAlertManager.NextId = PoliceAlertManager.NextId + 1
    alert.type = VALID_TYPES[alert.type] and alert.type or "INFO"
    alert.source = tostring(alert.source or "SENTINEL")
    alert.title = tostring(alert.title or "Sentinel AI")
    alert.message = tostring(alert.message or "")
    alert.priority = PRIORITY_WEIGHT[alert.priority]
        and alert.priority or "NORMAL"
    alert.createdAt = tonumber(alert.createdAt) or GetGameTimer()
    alert.expiresAt = tonumber(alert.expiresAt)
    alert.persistent = alert.persistent == true
    alert.acknowledged = alert.acknowledged == true
    alert.actions = type(alert.actions) == "table" and alert.actions or {}
    alert.metadata = type(alert.metadata) == "table" and alert.metadata or {}

    PoliceAlertManager.Queue[#PoliceAlertManager.Queue + 1] = alert
    PoliceAlertManager.History[#PoliceAlertManager.History + 1] =
        copyTable(alert)

    while #PoliceAlertManager.History > 100 do
        table.remove(PoliceAlertManager.History, 1)
    end

    notifySubscribers("PUSH", alert)
    return alert.id
end

function PoliceAlertManager.Update(id, patch)
    local alert = findAlert(id)

    if not alert or type(patch) ~= "table" then
        return false
    end

    for key, value in pairs(patch) do
        if key ~= "id" then
            alert[key] = copyTable(value)
        end
    end

    notifySubscribers("UPDATE", alert)
    return true
end

function PoliceAlertManager.Remove(id)
    local alert, index = findAlert(id)

    if not alert then
        return false
    end

    table.remove(PoliceAlertManager.Queue, index)
    notifySubscribers("REMOVE", alert)
    return true
end

function PoliceAlertManager.Acknowledge(id)
    return PoliceAlertManager.Update(id, {acknowledged = true})
end

function PoliceAlertManager.GetQueue()
    return copyTable(PoliceAlertManager.Queue)
end

function PoliceAlertManager.GetHistory()
    return copyTable(PoliceAlertManager.History)
end

function PoliceAlertManager.GetActive()
    local selected = nil

    for _, alert in ipairs(PoliceAlertManager.Queue) do
        if not alert.acknowledged
            and (alert.persistent
                or not alert.expiresAt
                or alert.expiresAt > GetGameTimer())
            and (not selected
                or PRIORITY_WEIGHT[alert.priority]
                    > PRIORITY_WEIGHT[selected.priority]) then

            selected = alert
        end
    end

    return copyTable(selected)
end

function PoliceAlertManager.Subscribe(callback)
    if type(callback) ~= "function" then
        return nil
    end

    local subscriptionId = #PoliceAlertManager.Subscribers + 1
    PoliceAlertManager.Subscribers[subscriptionId] = callback
    return subscriptionId
end

CreateThread(function()
    while true do
        Wait(500)

        local now = GetGameTimer()

        for index = #PoliceAlertManager.Queue, 1, -1 do
            local alert = PoliceAlertManager.Queue[index]

            if not alert.persistent
                and alert.expiresAt
                and alert.expiresAt <= now then

                table.remove(PoliceAlertManager.Queue, index)
                notifySubscribers("EXPIRE", alert)
            end
        end
    end
end)
