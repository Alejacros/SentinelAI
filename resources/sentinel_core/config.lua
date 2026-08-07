Config = {}

-- IMPORTANTE:
-- Debe ser false antes de producción/publicación.
Config.DevMode = true

Config.Units = {
    "ADAM-21",
    "ADAM-32",
    "BRAVO-12",
    "BRAVO-18",
    "CHARLIE-08",
    "KING-11",
    "LINCOLN-07",
    "VICTOR-04",
    "DELTA-15"
}

Config.Dispatch = {}

Config.Dispatch.Location = vector3(28.2, -1339.1, 29.5)

Config.PoliceVehicle = "police"

Config.Scene = {}

Config.Scene.NPC = {
    model = "a_m_m_business_01",
    coords = vector4(28.2, -1339.1, 29.5, 180.0)
}
