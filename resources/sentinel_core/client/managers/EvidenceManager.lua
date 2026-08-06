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

    local object = EntityManager.SpawnObject({
        model = evidenceData.model,
        coords = spawnPosition,
        freeze = true,
        placeOnGround = true,
        group = "active_evidence"
    })

    if not object or not DoesEntityExist(object) then
        Sentinel.Notify(
            "ERROR",
            "No fue posible generar la evidencia.",
            {255, 80, 80}
        )

        return false
    end

    activeEvidence = {
        object = object,
        name = evidenceData.name
    }

    notify(
        "Nueva evidencia localizada. Busque el marcador azul."
    )

    return true
end

function RemoveActiveEvidence()
    EntityManager.CleanupGroup(
        "active_evidence",
        true
    )

    activeEvidence = nil
    evidenceLocked = false
end

local function closeCaseWithoutCustody()
    local earnedXP = 25

    PlayerData.DispatchState = "REPORT"

    RemoveActiveEvidence()
    CleanupCrimeScene()

    AwardXP(earnedXP)
    CompleteCase(earnedXP)
    CompleteCurrentDispatch()
end

local function continueWithCustody()
    local started = StartCustodyTransport()

    if not started then
        closeCaseWithoutCustody()
        return
    end

    Sentinel.Notify(
        "CENTRAL",
        "Evidencia asegurada. Traslade al detenido a la comisaría.",
        {90, 190, 255}
    )
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
                    0.0,
                    0.0,
                    0.0,
                    0.0,
                    180.0,
                    0.0,
                    0.35,
                    0.35,
                    0.35,
                    0,
                    220,
                    255,
                    255,
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

                        if not AddEvidenceToCurrentCase(evidenceName) then
                            Sentinel.Notify(
                                "ERROR",
                                "No existe un caso activo para guardar la evidencia.",
                                {255, 80, 80}
                            )

                            evidenceLocked = false
                            return
                        end

                        RemoveActiveEvidence()

                        if IsSuspectArrested
                            and IsSuspectArrested() then

                            continueWithCustody()
                        else
                            closeCaseWithoutCustody()
                        end
                    end
                end
            end
        end

        Wait(sleep)
    end
end)

AddEventHandler(
    "onResourceStop",
    function(resourceName)
        if resourceName ~= GetCurrentResourceName() then
            return
        end

        RemoveActiveEvidence()
    end
)