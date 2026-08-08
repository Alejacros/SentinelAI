DispatchLifecycleConfig = {
    maxPendingCalls = 3,
    generationInterval = 20000,
    expiryTime = 90000,
    autoAssignEnabled = false,
    autoAssignDelay = 45000,
    maxHistory = 50
}

DispatchOperationalTiers = {
    T1_BASIC = {minimumRank = "Cadete", recommendedCeiling = "Oficial II"},
    T2_INTERMEDIATE = {minimumRank = "Cabo", recommendedCeiling = "Sargento"},
    T3_HIGH_RISK = {minimumRank = "Subteniente", recommendedCeiling = "Capitan"},
    T4_CRITICAL = {minimumRank = "Mayor", recommendedCeiling = "Comandante General"}
}
