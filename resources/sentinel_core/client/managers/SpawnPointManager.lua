SpawnPointManager = {}

local function distanceBetween(first, second)
    return #(first - second)
end

local function isReasonableHeight(position, center)
    return math.abs(position.z - center.z) <= 5.0
end

local function isPositionInWater(position)
    return TestVerticalProbeAgainstAllWater(
        position.x,
        position.y,
        position.z + 2.0,
        position.z - 2.0,
        0
    )
end

local function getGroundPosition(position)
    for height = 50, 800, 50 do
        local foundGround, groundZ = GetGroundZFor_3dCoord(
            position.x,
            position.y,
            position.z + height,
            false
        )

        if foundGround then
            return true, vector3(
                position.x,
                position.y,
                groundZ
            )
        end
    end

    return false, position
end

local function getRandomOffset(center, minimumRadius, maximumRadius)
    local angle = math.rad(math.random(0, 359))
    local radius = minimumRadius
        + math.random() * (maximumRadius - minimumRadius)

    return vector3(
        center.x + math.cos(angle) * radius,
        center.y + math.sin(angle) * radius,
        center.z
    )
end

local function isSeparated(position, blockedPositions, minimumDistance)
    for _, blockedPosition in ipairs(blockedPositions or {}) do
        if distanceBetween(position, blockedPosition) < minimumDistance then
            return false
        end
    end

    return true
end

function SpawnPointManager.PreloadArea(center, timeoutMs)
    timeoutMs = timeoutMs or 2500

    SetFocusPosAndVel(
        center.x,
        center.y,
        center.z,
        0.0,
        0.0,
        0.0
    )

    RequestCollisionAtCoord(
        center.x,
        center.y,
        center.z
    )

    local timeoutAt = GetGameTimer() + timeoutMs

    while GetGameTimer() < timeoutAt do
        RequestCollisionAtCoord(
            center.x,
            center.y,
            center.z
        )

        Wait(50)
    end

    ClearFocus()
end

function SpawnPointManager.FindSafePedPosition(
    center,
    minimumRadius,
    maximumRadius,
    blockedPositions
)
    minimumRadius = minimumRadius or 3.0
    maximumRadius = maximumRadius or 12.0

    for _ = 1, 24 do
        local candidate = getRandomOffset(
            center,
            minimumRadius,
            maximumRadius
        )

        local foundSafe, safePosition = GetSafeCoordForPed(
            candidate.x,
            candidate.y,
            candidate.z,
            true,
            16
        )

        if foundSafe and safePosition then
            local foundGround, groundPosition =
                getGroundPosition(safePosition)

            if foundGround
                and isReasonableHeight(groundPosition, center)
                and not isPositionInWater(groundPosition)
                and isSeparated(
                    groundPosition,
                    blockedPositions,
                    2.5
                ) then

                return groundPosition
            end
        end
    end

    local foundGround, fallback =
        getGroundPosition(center)

    if foundGround then
        return fallback
    end

    return center
end

function SpawnPointManager.FindSafeEvidencePosition(
    center,
    blockedPositions
)
    return SpawnPointManager.FindSafePedPosition(
        center,
        2.0,
        7.0,
        blockedPositions
    )
end

function SpawnPointManager.FindSafeVehiclePosition(center)
    for nodeIndex = 1, 8 do
        local foundNode, nodePosition, heading =
            GetNthClosestVehicleNodeWithHeading(
                center.x,
                center.y,
                center.z,
                nodeIndex,
                0,
                3.0,
                0
            )

        if foundNode
            and nodePosition
            and isReasonableHeight(nodePosition, center) then

            return nodePosition, heading
        end
    end

    local foundNode, nodePosition, heading =
        GetClosestVehicleNodeWithHeading(
            center.x,
            center.y,
            center.z,
            1,
            3.0,
            0
        )

    if foundNode then
        return nodePosition, heading
    end

    return center, 0.0
end