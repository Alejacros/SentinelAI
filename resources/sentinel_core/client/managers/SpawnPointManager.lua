print("[Sentinel AI] Cargando SpawnPointManager...")

SpawnPointManager = {}

local MAX_VERTICAL_DIFFERENCE = 3.0
local MIN_SEPARATION = 2.5

local function isValidVector(coords)
    return coords
        and coords.x
        and coords.y
        and coords.z
        and coords.z > -100.0
end

local function isSeparated(
    position,
    blockedPositions,
    minimumDistance
)
    for _, blocked in ipairs(blockedPositions or {}) do
        if isValidVector(blocked)
            and #(position - blocked) < minimumDistance then

            return false
        end
    end

    return true
end

local function getGroundPosition(coords)
    if not isValidVector(coords) then
        return nil
    end

    RequestCollisionAtCoord(
        coords.x,
        coords.y,
        coords.z
    )

    for height = 5.0, 100.0, 5.0 do
        local foundGround, groundZ =
            GetGroundZFor_3dCoord(
                coords.x,
                coords.y,
                coords.z + height,
                false
            )

        if foundGround then
            return vector3(
                coords.x,
                coords.y,
                groundZ + 0.05
            )
        end
    end

    return nil
end

local function getRoadAnchor(center)
    local found, roadCoords, heading =
        GetClosestVehicleNodeWithHeading(
            center.x,
            center.y,
            center.z,
            1,
            3.0,
            0
        )

    if found and roadCoords then
        return roadCoords, heading or 0.0
    end

    return center, 0.0
end

local function isHeightSafe(position, anchor)
    return math.abs(position.z - anchor.z)
        <= MAX_VERTICAL_DIFFERENCE
end

local function randomOffset(
    center,
    minimumRadius,
    maximumRadius
)
    local angle =
        math.rad(math.random(0, 359))

    local radius =
        minimumRadius
        + math.random()
        * (maximumRadius - minimumRadius)

    return vector3(
        center.x + math.cos(angle) * radius,
        center.y + math.sin(angle) * radius,
        center.z
    )
end

function SpawnPointManager.PreloadArea(
    center,
    timeoutMs
)
    timeoutMs = timeoutMs or 1500

    RequestCollisionAtCoord(
        center.x,
        center.y,
        center.z
    )

    local timeout =
        GetGameTimer() + timeoutMs

    while GetGameTimer() < timeout do
        RequestCollisionAtCoord(
            center.x,
            center.y,
            center.z
        )

        Wait(50)
    end
end

function SpawnPointManager.FindSafePedPosition(
    center,
    minimumRadius,
    maximumRadius,
    blockedPositions
)
    minimumRadius = minimumRadius or 3.0
    maximumRadius = maximumRadius or 12.0

    local roadAnchor =
        getRoadAnchor(center)

    -- Buscamos alrededor de la calle, no alrededor
    -- de cualquier punto que pueda quedar en un techo.
    for _ = 1, 30 do
        local candidate =
            randomOffset(
                roadAnchor,
                minimumRadius,
                maximumRadius
            )

        local foundSafe, safeCoords =
            GetSafeCoordForPed(
                candidate.x,
                candidate.y,
                roadAnchor.z,
                true,
                16
            )

        if foundSafe and safeCoords then
            local grounded =
                getGroundPosition(safeCoords)

            if grounded
                and isHeightSafe(
                    grounded,
                    roadAnchor
                )
                and isSeparated(
                    grounded,
                    blockedPositions,
                    MIN_SEPARATION
                ) then

                return grounded
            end
        end
    end

    -- Segunda estrategia: punto peatonal muy cerca
    -- del nodo vial.
    for radius = 2, 8 do
        local candidate =
            randomOffset(
                roadAnchor,
                radius,
                radius + 1.0
            )

        local grounded =
            getGroundPosition(candidate)

        if grounded
            and isHeightSafe(
                grounded,
                roadAnchor
            )
            and isSeparated(
                grounded,
                blockedPositions,
                MIN_SEPARATION
            ) then

            return grounded
        end
    end

    local fallback =
        getGroundPosition(roadAnchor)

    return fallback or roadAnchor
end

function SpawnPointManager.FindSafeEvidencePosition(
    center,
    blockedPositions
)
    return SpawnPointManager.FindSafePedPosition(
        center,
        2.0,
        6.0,
        blockedPositions
    )
end

function SpawnPointManager.FindSafeVehiclePosition(
    center
)
    for nodeIndex = 1, 10 do
        local found, nodeCoords, heading =
            GetNthClosestVehicleNodeWithHeading(
                center.x,
                center.y,
                center.z,
                nodeIndex,
                0,
                3.0,
                0
            )

        if found and nodeCoords then
            return nodeCoords, heading or 0.0
        end
    end

    return getRoadAnchor(center)
end

function SpawnPointManager.IsPedAccessible(
    ped,
    referenceCoords
)
    if not ped
        or not DoesEntityExist(ped) then

        return false
    end

    local pedCoords =
        GetEntityCoords(ped)

    local roadAnchor =
        getRoadAnchor(
            referenceCoords or pedCoords
        )

    if math.abs(
        pedCoords.z - roadAnchor.z
    ) > MAX_VERTICAL_DIFFERENCE then

        return false
    end

    return true
end

function SpawnPointManager.RescuePed(
    ped,
    referenceCoords
)
    if not ped
        or not DoesEntityExist(ped) then

        return false
    end

    local center =
        referenceCoords
        or GetEntityCoords(PlayerPedId())

    local safePosition =
        SpawnPointManager.FindSafePedPosition(
            center,
            3.0,
            8.0,
            {}
        )

    if not safePosition then
        return false
    end

    RequestCollisionAtCoord(
        safePosition.x,
        safePosition.y,
        safePosition.z
    )

    FreezeEntityPosition(ped, false)
    ClearPedTasksImmediately(ped)

    SetEntityCoordsNoOffset(
        ped,
        safePosition.x,
        safePosition.y,
        safePosition.z + 0.15,
        false,
        false,
        false
    )

    Wait(100)

    print(
        (
            "[Sentinel AI] NPC rescatado a posición segura: "
            .. "%.2f %.2f %.2f"
        ):format(
            safePosition.x,
            safePosition.y,
            safePosition.z
        )
    )

    return true
end

print("[Sentinel AI] SpawnPointManager listo.")