print("[Sentinel AI] Cargando IncidentTemplates...")

IncidentTemplates = {
    ROBBERY = {
        {
            id = "STORE_ESCAPE",
            label = "Robo con sospechoso huyendo",
            difficulty = 1,
            weight = 30,

            suspect = {
                count = 1,
                initialState = "FLEEING",
                armed = false
            },

            witnesses = 1,
            victims = 0,

            evidence = {
                "WALLET",
                "PHONE"
            },

            backupChance = 20,
            emsChance = 0
        },

        {
            id = "ARMED_WITH_VICTIM",
            label = "Robo armado con víctima",
            difficulty = 4,
            weight = 25,

            suspect = {
                count = 1,
                initialState = "HOSTILE",
                armed = true
            },

            witnesses = 1,
            victims = 1,

            evidence = {
                "WEAPON",
                "PHONE"
            },

            backupChance = 80,
            emsChance = 25
        },

        {
            id = "GETAWAY_DRIVER",
            label = "Conductor de escape",
            difficulty = 3,
            weight = 20,

            suspect = {
                count = 1,
                initialState = "FLEEING",
                armed = false,
                vehicle = true
            },

            witnesses = 1,
            victims = 0,

            evidence = {
                "WALLET",
                "PACKAGE"
            },

            backupChance = 50,
            emsChance = 0
        },

        {
            id = "SUSPECTS_GONE",
            label = "Responsables fuera del lugar",
            difficulty = 1,
            weight = 15,

            suspect = {
                count = 0,
                initialState = "NONE",
                armed = false
            },

            witnesses = 1,
            victims = 0,

            evidence = {
                "PHONE",
                "PACKAGE"
            },

            backupChance = 0,
            emsChance = 0
        },

        {
            id = "TWO_SUSPECTS",
            label = "Robo cometido por dos sospechosos",
            difficulty = 5,
            weight = 10,

            suspect = {
                count = 2,
                initialState = "FLEEING",
                armed = true
            },

            witnesses = 2,
            victims = 1,

            evidence = {
                "WEAPON",
                "PHONE",
                "WALLET"
            },

            backupChance = 100,
            emsChance = 35
        }
    },

    DISTURBANCE = {
        {
            id = "STREET_FIGHT",
            label = "Pelea en vía pública",
            difficulty = 2,
            weight = 40,

            suspect = {
                count = 2,
                initialState = "FIGHTING",
                armed = false
            },

            witnesses = 1,
            victims = 0,

            evidence = {
                "PHONE"
            },

            backupChance = 30,
            emsChance = 15
        },

        {
            id = "KNIFE_THREAT",
            label = "Amenaza con arma blanca",
            difficulty = 4,
            weight = 30,

            suspect = {
                count = 1,
                initialState = "HOSTILE",
                armed = true,
                weapon = "WEAPON_KNIFE"
            },

            witnesses = 1,
            victims = 1,

            evidence = {
                "WEAPON"
            },

            backupChance = 75,
            emsChance = 25
        },

        {
            id = "CROWD_ARGUMENT",
            label = "Grupo alterado",
            difficulty = 2,
            weight = 30,

            suspect = {
                count = 0,
                initialState = "DISTURBANCE",
                armed = false
            },

            witnesses = 3,
            victims = 0,

            evidence = {
                "PHONE"
            },

            backupChance = 20,
            emsChance = 0
        }
    },

    TRAFFIC_ACCIDENT = {
        {
            id = "MINOR_COLLISION",
            label = "Colisión menor",
            difficulty = 1,
            weight = 35,

            suspect = {
                count = 0,
                initialState = "NONE",
                armed = false
            },

            witnesses = 1,
            victims = 0,
            vehicles = 1,

            evidence = {
                "PHONE"
            },

            backupChance = 0,
            emsChance = 0
        },

        {
            id = "INJURED_DRIVER",
            label = "Accidente con persona herida",
            difficulty = 2,
            weight = 40,

            suspect = {
                count = 0,
                initialState = "NONE",
                armed = false
            },

            witnesses = 1,
            victims = 1,
            vehicles = 1,

            evidence = {
                "PHONE"
            },

            backupChance = 0,
            emsChance = 100
        },

        {
            id = "DRUNK_DRIVER",
            label = "Conductor posiblemente ebrio",
            difficulty = 3,
            weight = 25,

            suspect = {
                count = 1,
                initialState = "FLEEING",
                armed = false
            },

            witnesses = 1,
            victims = 0,
            vehicles = 1,

            evidence = {
                "PHONE",
                "BOTTLE"
            },

            backupChance = 35,
            emsChance = 10
        }
    }
}

local function weightedChoice(templates)
    if type(templates) ~= "table"
        or #templates == 0 then

        return nil
    end

    local totalWeight = 0

    for _, template in ipairs(templates) do
        totalWeight =
            totalWeight
            + math.max(
                0,
                tonumber(template.weight) or 1
            )
    end

    if totalWeight <= 0 then
        return templates[
            math.random(#templates)
        ]
    end

    local roll =
        math.random() * totalWeight

    local accumulated = 0

    for _, template in ipairs(templates) do
        accumulated =
            accumulated
            + math.max(
                0,
                tonumber(template.weight) or 1
            )

        if roll <= accumulated then
            return template
        end
    end

    return templates[#templates]
end

function GetIncidentTemplate(incidentType)
    local templates =
        IncidentTemplates[incidentType]

    return weightedChoice(templates)
end

print("[Sentinel AI] IncidentTemplates listo.")