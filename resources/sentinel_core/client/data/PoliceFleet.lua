PoliceFleet = {
    -- Autorización futura:
    -- rank + certification + assignment = vehicle authorization.
    -- Certificaciones previstas: MOTOR, TACTICAL, INTERCEPTOR, K9, AIR
    -- y ARMORED. En esta fase solo se aplica minRank.
    PATROL = {
        {
            id = "CADET_CRUISER",
            label = "Patrulla de cadete",
            model = "police5",
            minRank = "Cadete",
            canTransportSuspects = true,
            transportCapacity = 2,
            role = "PATROL"
        },
        {
            id = "PATROL_CRUISER",
            label = "Patrulla estándar",
            model = "police2",
            minRank = "Oficial",
            canTransportSuspects = true,
            transportCapacity = 2,
            role = "PATROL"
        },
        {
            id = "PATROL_INTERCEPTOR",
            label = "Interceptor policial",
            model = "police3",
            minRank = "Oficial II",
            canTransportSuspects = true,
            transportCapacity = 2,
            role = "INTERCEPTOR"
        },
        {
            id = "SHERIFF_SUV",
            label = "Sheriff SUV",
            model = "sheriff2",
            minRank = "Cabo",
            canTransportSuspects = true,
            transportCapacity = 2,
            role = "SUPERVISOR"
        },
        {
            id = "MOTOR_UNIT",
            label = "Motocicleta policial",
            model = "policeb",
            minRank = "Cabo",
            canTransportSuspects = false,
            transportCapacity = 0,
            role = "MOTORCYCLE"
        },
        {
            id = "PATROL_CLASSIC",
            label = "Patrulla clásica",
            model = "police",
            minRank = "Sargento",
            canTransportSuspects = true,
            transportCapacity = 2,
            role = "PATROL"
        },
        {
            id = "UNMARKED_CRUISER",
            label = "Unidad sin distintivos",
            model = "police4",
            minRank = "Subteniente",
            canTransportSuspects = true,
            transportCapacity = 2,
            role = "UNMARKED"
        },
        {
            id = "SHERIFF_CRUISER",
            label = "Sheriff Cruiser",
            model = "sheriff",
            minRank = "Subteniente",
            canTransportSuspects = true,
            transportCapacity = 2,
            role = "SUPERVISOR"
        },
        {
            id = "FEDERAL_SEDAN",
            label = "FIB Sedan",
            model = "fbi",
            minRank = "Teniente",
            canTransportSuspects = true,
            transportCapacity = 2,
            role = "FEDERAL"
        },
        {
            id = "FEDERAL_SUV",
            label = "FIB SUV",
            model = "fbi2",
            minRank = "Teniente",
            canTransportSuspects = true,
            transportCapacity = 2,
            role = "FEDERAL"
        },
        {
            id = "TACTICAL_RIOT",
            label = "Unidad táctica",
            model = "riot",
            minRank = "Capitan",
            canTransportSuspects = true,
            transportCapacity = 4,
            role = "TACTICAL"
        },
        {
            id = "ARMORED_RIOT",
            label = "Unidad blindada",
            model = "riot2",
            minRank = "Mayor",
            canTransportSuspects = false,
            transportCapacity = 0,
            role = "ARMORED"
        },
        {
            id = "PRISONER_BUS",
            label = "Transporte penitenciario",
            model = "pbus",
            minRank = "Capitan",
            canTransportSuspects = true,
            transportCapacity = 8,
            role = "TRANSPORT"
        },
        {
            id = "PARK_RANGER",
            label = "Park Ranger",
            model = "pranger",
            minRank = "Sargento",
            canTransportSuspects = true,
            transportCapacity = 2,
            role = "SUPERVISOR"
        }
    }
}
