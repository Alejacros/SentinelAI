PoliceFleet = {
    PATROL = {
        {
            id = "CRUISER_1",
            label = "Patrulla estándar",
            model = "police",
            minRank = "Cadete",
            canTransportSuspects = true,
            transportCapacity = 2,
            role = "PATROL"
        },
        {
            id = "CRUISER_2",
            label = "Patrulla rápida",
            model = "police2",
            minRank = "Oficial",
            canTransportSuspects = true,
            transportCapacity = 2,
            role = "PATROL"
        },
        {
            id = "CRUISER_3",
            label = "Interceptor",
            model = "police3",
            minRank = "Cabo",
            canTransportSuspects = false,
            transportCapacity = 0,
            role = "INTERCEPTOR"
        }
    }
}
