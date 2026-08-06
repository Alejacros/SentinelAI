local ranks = {
    {
        name = "Cadete",
        requiredXP = 0
    },
    {
        name = "Oficial",
        requiredXP = 100
    },
    {
        name = "Oficial II",
        requiredXP = 250
    },
    {
        name = "Cabo",
        requiredXP = 500
    },
    {
        name = "Sargento",
        requiredXP = 900
    },
    {
        name = "Teniente",
        requiredXP = 1500
    }
}

local function getRankForXP(xp)
    local selectedRank = ranks[1]

    for _, rank in ipairs(ranks) do
        if xp >= rank.requiredXP then
            selectedRank = rank
        else
            break
        end
    end

    return selectedRank
end

function GetNextRank()
    for _, rank in ipairs(ranks) do
        if rank.requiredXP > PlayerData.XP then
            return rank
        end
    end

    return nil
end

function ApplyCareerProgress(
    xp,
    completedCases
)
    PlayerData.XP = math.max(
        0,
        tonumber(xp) or 0
    )

    PlayerData.CompletedCases = math.max(
        0,
        tonumber(completedCases) or 0
    )

    local currentRank =
        getRankForXP(PlayerData.XP)

    PlayerData.Rank =
        currentRank.name

    TriggerEvent(
        "sentinel:careerLoaded",
        PlayerData
    )
end

function AwardXP(amount)
    amount = tonumber(amount) or 0

    if amount <= 0 then
        return false
    end

    local previousRank =
        PlayerData.Rank

    PlayerData.XP =
        PlayerData.XP + amount

    PlayerData.CompletedCases =
        PlayerData.CompletedCases + 1

    local currentRank =
        getRankForXP(PlayerData.XP)

    PlayerData.Rank =
        currentRank.name

    Sentinel.Notify(
        "CARRERA",
        (
            "Caso completado: +%d XP"
        ):format(amount),
        {100, 200, 255}
    )

    if PlayerData.Rank ~= previousRank then
        Sentinel.Notify(
            "ASCENSO",
            (
                "Nuevo rango: %s"
            ):format(PlayerData.Rank),
            {255, 220, 0}
        )
    end

    TriggerEvent(
        "sentinel:careerUpdated",
        {
            xp = PlayerData.XP,
            completedCases =
                PlayerData.CompletedCases,
            rank = PlayerData.Rank
        }
    )

    return true
end