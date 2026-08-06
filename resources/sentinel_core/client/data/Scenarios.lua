ScenarioDefinitions = {
    ROBBERY = {
        {
            id = "armed_suspect",
            objective = "Neutralice o controle al sospechoso armado.",
            safeWhen = "SUSPECT_NEUTRALIZED"
        },
        {
            id = "fleeing_suspect",
            objective = "Localice al sospechoso que huye.",
            safeWhen = "SUSPECT_ESCAPED_OR_NEUTRALIZED"
        },
        {
            id = "suspects_gone",
            objective = "La amenaza terminó. Entreviste al testigo.",
            safeWhen = "IMMEDIATE"
        }
    },

    DISTURBANCE = {
        {
            id = "active_fight",
            objective = "Controle la pelea antes de entrevistar testigos.",
            safeWhen = "FIGHT_STOPPED"
        },
        {
            id = "verbal_argument",
            objective = "Separe a los involucrados.",
            safeWhen = "TIMED"
        }
    },

    TRAFFIC_ACCIDENT = {
        {
            id = "injured_driver",
            objective = "Asegure la escena y localice al testigo.",
            safeWhen = "IMMEDIATE"
        },
        {
            id = "medical_response",
            objective = "Servicios médicos trabajan en la escena.",
            safeWhen = "IMMEDIATE"
        }
    }
}