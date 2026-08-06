local EVIDENCE_GROUP = "active_evidence"

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
    }
}

local function notify(message, color)
    Sentinel.Notify(
        "EVIDENCIA",
        message,
        color or {0, 220, 255}
    )
end

local function isValidPosition(coords)
    return coords
        and coords.x
        and coords.y
        and coords.z
        and coords.z > -50.0
end

local function getGroundPosition(coords)
    if not isValidPosition(coords) then
        return nil
    end

    RequestCollisionAtCoord(
        coords.x,
        coords.y,
        coords.z
    )

    for height = 10.0, 100.0, 10.0 do
        local found, groundZ = GetGroundZFor_3dCoord(
            coords.x,
            coords.y,
            coords.z + height,
            false
        )

        if found then
            return vector3(
                coords.x,
                coords.y,
                groundZ + 0.03
            )
        end
    end

    return nil
end

local function getEvidenceCenter()
    if PlayerData.SceneNPC
        and DoesEntityExist(PlayerData.SceneNPC) then

        return GetEntityCoords(
            PlayerData.SceneNPC
        )
    end

    if PlayerData.CurrentDispatch
        and PlayerData.CurrentDispatch.location then

        return PlayerData.CurrentDispatch.location
    end

    return GetEntityCoords(PlayerPedId())
end

local function findEvidencePosition()
    local center = getEvidenceCenter()

    if SpawnPointManager
        and SpawnPointManager.FindSafeEvidencePosition then

        local safePosition =
            SpawnPointManager.FindSafeEvidencePosition(
                center,
                {}
            )

        local groundedPosition =
            getGroundPosition(safePosition)

        if groundedPosition
            and #(groundedPosition - center) <= 15.0 then

            return groundedPosition
        end
    end

    -- Alternativa segura: delante del jugador.
    local playerPed = PlayerPedId()

    local fallback =
        GetOffsetFromEntityInWorldCoords(
            playerPed,
            0.0,
            2.0,
            0.0
        )

    return getGroundPosition(fallback)
        or vector3(
            fallback.x,
            fallback.y,
            GetEntityCoords(playerPed).z
        )
end

function RemoveActiveEvidence()
    if EntityManager then
        EntityManager.CleanupGroup(
            EVIDENCE_GROUP,
            true
        )
    end

    activeEvidence = nil
    evidenceLocked = false
end

function SpawnEvidence()
    RemoveActiveEvidence()

    local evidencePosition =
        findEvidencePosition()

    if not evidencePosition then
        Sentinel.Notify(
            "ERROR",
            "No fue posible encontrar un punto seguro para la evidencia.",
            {255, 80, 80}
        )

        return false
    end

    local evidenceData =
        evidenceTypes[
            math.random(#evidenceTypes)
        ]

    local object =
        EntityManager.SpawnObject({
            model = evidenceData.model,
            coords = evidencePosition,
            freeze = true,
            placeOnGround = true,
            group = EVIDENCE_GROUP
        })

    if not object
        or not DoesEntityExist(object) then

        Sentinel.Notify(
            "ERROR",
            "No fue posible crear el objeto de evidencia.",
            {255, 80, 80}
        )

        print(
            "[Sentinel AI] Falló SpawnEvidence: "
                .. evidenceData.model
        )

        return false
    end

    local finalCoords =
        GetEntityCoords(object)

    local blip =
        EntityManager.CreateCoordinateBlip(
            finalCoords,
            {
                name = "Evidencia",
                sprite = 1,
                colour = 3,
                scale = 0.75,
                shortRange = false,
                route = false,
                group = EVIDENCE_GROUP
            }
        )

    activeEvidence = {
        object = object,
        blip = blip,
        name = evidenceData.name
    }

    notify(
        "Evidencia localizada. Busque el icono y marcador azul."
    )

    print(
        (
            "[Sentinel AI] Evidencia creada: %s | %.2f %.2f %.2f"
        ):format(
            evidenceData.name,
            finalCoords.x,
            finalCoords.y,
            finalCoords.z
        )
    )

    return true
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
    local started =
        StartCustodyTransport
        and StartCustodyTransport()

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

            if distance <= 100.0 then
                sleep = 0

                DrawMarker(
                    2,
                    objectCoords.x,
                    objectCoords.y,
                    objectCoords.z + 0.75,
                    0.0,
                    0.0,
                    0.0,
                    0.0,
                    180.0,
                    0.0,
                    0.45,
                    0.45,
                    0.45,
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

                if distance <= 2.0 then
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

                        if not AddEvidenceToCurrentCase(
                            evidenceName
                        ) then

                            Sentinel.Notify(
                                "ERROR",
                                "No existe un expediente activo.",
                                {255, 80, 80}
                            )

                            evidenceLocked = false
                            return
                        end

                        notify(
                            evidenceName
                                .. " recogido correctamente."
                        )

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