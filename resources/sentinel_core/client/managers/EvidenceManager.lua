local activeEvidence = nil
local evidenceLocked = false

local evidenceTypes = {
    {
        name = "Billetera",
        model = "prop_ld_wallet_pickup"
    },
    {
        name = "Paquete sospechoso",
        model = "prop_cs_package_01"
    },
    {
        name = "Teléfono celular",
        model = "prop_npc_phone_02"
    }
}

local function loadModel(model)
    RequestModel(model)

    local timeout = GetGameTimer() + 5000

    while not HasModelLoaded(model) do
        Wait(50)

        if GetGameTimer() >= timeout then
            return false
        end
    end

    return true
end

local function notify(message)
    Sentinel.Notify(
        "EVIDENCIA",
        message,
        {0, 220, 255}
    )
end

local function removeEvidence()
    if activeEvidence
        and activeEvidence.object
        and DoesEntityExist(activeEvidence.object) then

        DeleteEntity(activeEvidence.object)
    end

    activeEvidence = nil
end

function SpawnEvidence()
    removeEvidence()
    evidenceLocked = false

    local playerPed = PlayerPedId()

    local spawnPosition =
        GetOffsetFromEntityInWorldCoords(
            playerPed,
            1.5,
            2.0,
            0.0
        )

    local evidenceData =
        evidenceTypes[math.random(#evidenceTypes)]

    local model = GetHashKey(evidenceData.model)

    if not loadModel(model) then
        Sentinel.Notify(
            "ERROR",
            "No fue posible cargar la evidencia.",
            {255, 80, 80}
        )

        return false
    end

    local object = CreateObject(
        model,
        spawnPosition.x,
        spawnPosition.y,
        spawnPosition.z,
        false,
        false,
        false
    )

    if object == 0 or not DoesEntityExist(object) then
        Sentinel.Notify(
            "ERROR",
            "No fue posible crear la evidencia.",
            {255, 80, 80}
        )

        return false
    end

    SetEntityAsMissionEntity(object, true, true)
    PlaceObjectOnGroundProperly(object)
    FreezeEntityPosition(object, true)

    activeEvidence = {
        object = object,
        name = evidenceData.name
    }

    SetModelAsNoLongerNeeded(model)

    notify(
        "Nueva evidencia localizada. Busque el marcador azul."
    )

    return true
end

CreateThread(function()
    while true do
        local sleep = 500

        if activeEvidence
            and activeEvidence.object
            and DoesEntityExist(activeEvidence.object) then

            local objectCoords =
                GetEntityCoords(activeEvidence.object)

            local playerCoords =
                GetEntityCoords(PlayerPedId())

            local distance =
                #(playerCoords - objectCoords)

            if distance <= 40.0 then
                sleep = 0

                DrawMarker(
                    2,
                    objectCoords.x,
                    objectCoords.y,
                    objectCoords.z + 0.8,
                    0.0, 0.0, 0.0,
                    0.0, 180.0, 0.0,
                    0.35, 0.35, 0.35,
                    0, 220, 255, 255,
                    false,
                    true,
                    2,
                    false,
                    nil,
                    nil,
                    false
                )

                if distance <= 1.7 then
                    BeginTextCommandDisplayHelp("STRING")

                    AddTextComponentSubstringPlayerName(
                        "Pulsa ~INPUT_CONTEXT~ para recoger la evidencia."
                    )

                    EndTextCommandDisplayHelp(
                        0,
                        false,
                        true,
                        -1
                    )

                    if IsControlJustPressed(0, 38)
                        and not evidenceLocked then

                        evidenceLocked = true

                        local evidenceName =
                            activeEvidence.name

                        notify(
                            evidenceName
                                .. " recogido correctamente."
                        )

                        local evidenceAdded =
                            AddEvidenceToCurrentCase(
                                evidenceName
                            )

                        if not evidenceAdded then
                            evidenceLocked = false
                            return
                        end

                        PlayerData.DispatchState = "REPORT"

                        removeEvidence()
                        CleanupCrimeScene()

                        local earnedXP = 25

                        local archived =
                            CompleteCase(earnedXP)

                        if not archived then
                            evidenceLocked = false
                            return
                        end

                        AwardXP(earnedXP)
                        CompleteCurrentDispatch()

                        evidenceLocked = false
                    end
                end
            end
        end

        Wait(sleep)
    end
end)