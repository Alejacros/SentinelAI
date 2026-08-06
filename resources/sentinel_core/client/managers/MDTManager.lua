local mdtOpen = false

local statusLabels = {
    OFF_DUTY = "Fuera de servicio",
    WAITING = "Esperando despacho",
    PENDING = "Despacho pendiente",
    EN_ROUTE = "En ruta",
    ON_SCENE = "En escena",
    EVIDENCE = "Buscando evidencia",
    REPORT = "Procesando informe"
}

local function buildMdtData()
    local dispatch = nil

    if PlayerData.CurrentDispatch then
        dispatch = {
            code = PlayerData.CurrentDispatch.code,
            title = PlayerData.CurrentDispatch.title
        }
    end

    return {
        rank = PlayerData.Rank or "Cadete",
        unit = PlayerData.Unit or "Sin asignar",
        xp = PlayerData.XP or 0,
        completedCases = PlayerData.CompletedCases or 0,
        status = statusLabels[PlayerData.DispatchState] or "Sin estado",
        dispatch = dispatch
    }
end

local function sendMdtUpdate(action)
    SendNUIMessage({
        action = action,
        data = buildMdtData()
    })
end

local function openMdt()
    if mdtOpen then
        return
    end

    mdtOpen = true
    SetNuiFocus(true, true)
    sendMdtUpdate("open")
end

local function closeMdt()
    if not mdtOpen then
        return
    end

    mdtOpen = false
    SetNuiFocus(false, false)

    SendNUIMessage({
        action = "close"
    })
end

-- Usamos un comando nuevo para evitar la asignación antigua guardada en TAB.
RegisterCommand("sentinel_tablet", function()
    if mdtOpen then
        closeMdt()
    else
        openMdt()
    end
end, false)

RegisterKeyMapping(
    "sentinel_tablet",
    "Abrir tablet policial Sentinel MDT",
    "keyboard",
    "F7"
)

RegisterNUICallback("closeMdt", function(_, callback)
    closeMdt()

    callback({
        ok = true
    })
end)

CreateThread(function()
    while true do
        Wait(500)

        if mdtOpen then
            sendMdtUpdate("update")
        end
    end
end)

AddEventHandler("onResourceStop", function(resourceName)
    if resourceName ~= GetCurrentResourceName() then
        return
    end

    SetNuiFocus(false, false)
end)