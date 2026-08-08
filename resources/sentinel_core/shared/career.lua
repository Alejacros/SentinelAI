SentinelCareer = SentinelCareer or {}

SentinelCareer.Ranks = {
    {name = "Cadete", requiredXP = 0},
    {name = "Oficial", requiredXP = 500},
    {name = "Oficial II", requiredXP = 1000},
    {name = "Cabo", requiredXP = 2500},
    {name = "Sargento", requiredXP = 5000},
    {name = "Subteniente", requiredXP = 8000},
    {name = "Teniente", requiredXP = 10000},
    {name = "Capitan", requiredXP = 15000},
    {name = "Mayor", requiredXP = 20000},
    {name = "General", requiredXP = 50000},
    {name = "Brigadier General", requiredXP = 80000},
    {name = "Comandante General", requiredXP = 100000}
}

function SentinelCareer.GetRankIndex(rankName)
    for index, rank in ipairs(SentinelCareer.Ranks) do
        if rank.name == rankName then return index end
    end
    return nil
end

function SentinelCareer.GetRankForXP(xp)
    local selected = SentinelCareer.Ranks[1]
    xp = math.max(0, tonumber(xp) or 0)
    for _, rank in ipairs(SentinelCareer.Ranks) do
        if xp < rank.requiredXP then break end
        selected = rank
    end
    return selected
end

function SentinelCareer.IsRankAtLeast(currentRank, requiredRank)
    local current = SentinelCareer.GetRankIndex(currentRank)
    local required = SentinelCareer.GetRankIndex(requiredRank)
    return current ~= nil and required ~= nil and current >= required
end
