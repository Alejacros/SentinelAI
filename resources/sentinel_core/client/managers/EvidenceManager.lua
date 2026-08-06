print("[Sentinel AI] Cargando EvidenceManager...")

EvidenceManager = {
    Active = nil,
    Locked = false
}

local EVIDENCE_GROUP = "active_evidence"

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

local function notify(message, color)
    Sentinel.Notify(
        "EVIDENCIA",
        message,
        color or {0, 220, 255}
    )
end

local function loadModel(model)
    if not IsModelInCdimage(model)
        or not IsModelValid(model) then

        print(
            "[Sentinel AI] Modelo de evidencia inválido: "
                .. tostring(model)
        )

        return false
    end

    RequestModel(model)

    local timeout = GetGameTimer() + 5000

    while not HasModelLoaded(model) do
        Wait(50)

        if GetGameTimer() >= timeout then
            print(
                "[Sentinel AI] Timeout cargando evidencia."
            )

            return false
        end
    end

    return true
end

local function findSpawnPosition()
    local playerPed = PlayerPedId()

    local position =
        GetOffsetFromEntityInWorldCoords(
            playerPed,
            0.0,
            2.0,
            0.0
        )

    RequestCollisionAtCoord(
        position.x,
        position.y,
        position.z
    )

    for height = 5.0, 50.0, 5.0 do
        local foundGround, groundZ =
            GetGroundZFor_3dCoord(
                position.x,
                position.y,
                position.z + height,
                false
            )

        if foundGround then
            return vector3(
                position.x,
                position.y,
                groundZ + 0.03
            )
        end
    end

    local playerCoords =
        GetEntityCoords(playerPed)

    return vector3(
        position.x,
        position.y,
        playerCoords.z
    )
end

function EvidenceManager.Remove()
    if EvidenceManager.Active then
        if EvidenceManager.Active.blip
            and DoesBlipExist(
                EvidenceManager.Active.blip
            ) then

            RemoveBlip(
                EvidenceManager.Active.blip
            )
        end

        if EvidenceManager.Active.object
            and DoesEntityExist(
                EvidenceManager.Active.object
            ) then

            SetEntityAsMissionEntity(
                EvidenceManager.Active.object,
                true,
                true
            )

            DeleteEntity(
                EvidenceManager.Active.object
            )
        end
    end

    EvidenceManager.Active = nil
    EvidenceManager.Locked = false
end

function EvidenceManager.Spawn()
    EvidenceManager.Remove()

    local evidenceData =
        evidenceTypes[
            math.random(#evidenceTypes)
        ]

    local model =
        GetHashKey(evidenceData.model)

    if not loadModel(model) then
        notify(
            "No fue posible cargar la evidencia.",
            {255, 80, 80}
        )

        return false
    end

    local position =
        findSpawnPosition()

    local object = CreateObject(
        model,
        position.x,
        position.y,
        position.z,
        false,
        false,
        false
    )

    SetModelAsNoLongerNeeded(model)

    if object == 0
        or not DoesEntityExist(object) then

        notify(
            "No fue posible crear la evidencia.",
            {255, 80, 80}
        )

        print(
            "[Sentinel AI] CreateObject falló para "
                .. evidenceData.model
        )

        return false
    end

    SetEntityAsMissionEntity(
        object,
        true,
        true
    )

    PlaceObjectOnGroundProperly(object)
    FreezeEntityPosition(object, true)

    local finalCoords =
        GetEntityCoords(object)

    local blip =
        AddBlipForCoord(
            finalCoords.x,
            finalCoords.y,
            finalCoords.z
        )

    SetBlipSprite(blip, 1)
    SetBlipColour(blip, 3)
    SetBlipScale(blip, 0.8)
    SetBlipAsShortRange(blip, false)

    BeginTextCommandSetBlipName("STRING")
    AddTextComponentString("Evidencia")
    EndTextCommandSetBlipName(blip)

    EvidenceManager.Active = {
        object = object,
        blip = blip,
        name = evidenceData.name
    }

    notify(
        "Evidencia localizada delante de usted."
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

-- Compatibilidad temporal con InteractionManager.
function SpawnEvidence()
    return EvidenceManager.Spawn()
end

function RemoveActiveEvidence()
    EvidenceManager.Remove()
end

local function finishCase()
    local earnedXP = 25

    PlayerData.DispatchState = "REPORT"

    EvidenceManager.Remove()
    CleanupCrimeScene()

    AwardXP(earnedXP)
    CompleteCase(earnedXP)
    CompleteCurrentDispatch()
end

local function continueAfterEvidence()
    if IsSuspectArrested
        and IsSuspectArrested()
        and StartCustodyTransport then

        local custodyStarted =
            StartCustodyTransport()

        if custodyStarted then
            Sentinel.Notify(
                "CENTRAL",
                "Evidencia asegurada. Traslade al detenido.",
                {90, 190, 255}
            )

            return
        end
    end

    finishCase()
end

CreateThread(function()
    while true do
        local sleep = 500
        local evidence =
            EvidenceManager.Active

        if evidence
            and evidence.object
            and DoesEntityExist(
                evidence.object
            ) then

            local objectCoords =
                GetEntityCoords(
                    evidence.object
                )

            local playerCoords =
                GetEntityCoords(
                    PlayerPedId()
                )

            local distance =
                #(playerCoords - objectCoords)

            if distance <= 80.0 then
                sleep = 0

                DrawMarker(
                    2,
                    objectCoords.x,
                    objectCoords.y,
                    objectCoords.z + 0.75,
                    0.0, 0.0, 0.0,
                    0.0, 180.0, 0.0,
                    0.45, 0.45, 0.45,
                    0, 220, 255, 255,
                    false,
                    true,
                    2,
                    false,
                    nil,
                    nil,
                    false
                )

                if distance <= 2.0 then
                    BeginTextCommandDisplayHelp(
                        "STRING"
                    )

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
                        and not EvidenceManager.Locked then

                        EvidenceManager.Locked = true

                        local evidenceName =
                            evidence.name

                        if not AddEvidenceToCurrentCase(
                            evidenceName
                        ) then

                            notify(
                                "No existe un expediente activo.",
                                {255, 80, 80}
                            )

                            EvidenceManager.Locked = false
                            return
                        end

                        notify(
                            evidenceName
                                .. " recogido correctamente."
                        )

                        EvidenceManager.Remove()
                        continueAfterEvidence()
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
        if resourceName
            ~= GetCurrentResourceName() then

            return
        end

        EvidenceManager.Remove()
    end
)

print(
    "[Sentinel AI] EvidenceManager listo. "
        .. "SpawnEvidence = "
        .. type(SpawnEvidence)
)