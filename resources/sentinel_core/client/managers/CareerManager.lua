local ranks = {
    {
        name = "Cadete",
        requiredXP = 0
    },
    {
        name = "Oficial",
        requiredXP = 10000
    },
    {
        name = "Oficial II",
        requiredXP = 25000
    },
    {
        name = "Cabo",
        requiredXP = 50000
    },
    {
        name = "Sargento",
        requiredXP = 90000
    },
    {
        name = "Teniente",
        requiredXP = 150000
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

function AwardXP(amount)
    if type(amount) ~= "number" or amount <= 0 then
        return
    end

    local previousRank = PlayerData.Rank

    PlayerData.XP = PlayerData.XP + amount
    PlayerData.CompletedCases = PlayerData.CompletedCases + 1

    local currentRank = getRankForXP(PlayerData.XP)
    PlayerData.Rank = currentRank.name

    Sentinel.Notify(
        "CARRERA",
        ("Caso completado: +%d XP"):format(amount),
        {100, 200, 255}
    )

    if PlayerData.Rank ~= previousRank then
        Sentinel.Notify(
            "ASCENSO",
            ("Nuevo rango: %s"):format(PlayerData.Rank),
            {255, 220, 0}
        )
    end
end