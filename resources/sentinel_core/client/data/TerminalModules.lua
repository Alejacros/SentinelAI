TerminalModules = {
    {id = "HOME", label = "Inicio", icon = "HOME", allowedModes = {"PDA", "DRIVER_SAFE", "VEHICLE_FULL"}, permission = "terminal.home.view", implemented = true, minRank = "Cadete"},
    {id = "CAD", label = "Despachos", icon = "CAD", allowedModes = {"PDA", "DRIVER_SAFE", "VEHICLE_FULL"}, permission = "terminal.cad.view", implemented = true, minRank = "Cadete"},
    {id = "PEOPLE", label = "Personas", icon = "PEOPLE", allowedModes = {"PDA", "VEHICLE_FULL"}, permission = "terminal.people.view", implemented = false, minRank = "Cadete"},
    {id = "VEHICLES", label = "Vehículos", icon = "VEHICLES", allowedModes = {"PDA", "VEHICLE_FULL"}, permission = "terminal.vehicles.view", implemented = false, minRank = "Cadete"},
    {id = "CASES", label = "Casos", icon = "CASES", allowedModes = {"PDA", "VEHICLE_FULL"}, permission = "terminal.cases.view", implemented = true, minRank = "Cadete"},
    {id = "EVIDENCE", label = "Evidencia", icon = "EVIDENCE", allowedModes = {"PDA", "VEHICLE_FULL"}, permission = "terminal.evidence.view", implemented = true, minRank = "Cadete"},
    {id = "UNIT", label = "Unidad", icon = "UNIT", allowedModes = {"PDA", "DRIVER_SAFE", "VEHICLE_FULL"}, permission = "terminal.unit.view", implemented = true, minRank = "Cadete"},
    {id = "MAP", label = "Mapa / GPS", icon = "MAP", allowedModes = {"PDA", "DRIVER_SAFE", "VEHICLE_FULL"}, permission = "terminal.map.view", implemented = true, minRank = "Cadete"},
    {id = "SERVICES", label = "Servicios", icon = "SERVICES", allowedModes = {"PDA", "VEHICLE_FULL"}, permission = "terminal.services.view", implemented = false, minRank = "Cadete"},
    {id = "RADAR", label = "Radar", icon = "RADAR", allowedModes = {"VEHICLE_FULL"}, permission = "terminal.radar.view", implemented = false, minRank = "Sargento"},
    {id = "ALPR", label = "ALPR", icon = "ALPR", allowedModes = {"DRIVER_SAFE", "VEHICLE_FULL"}, permission = "terminal.alpr.view", implemented = false, minRank = "Sargento"},
    {id = "COMMUNICATIONS", label = "Comunicaciones", icon = "COMMS", allowedModes = {"PDA", "DRIVER_SAFE", "VEHICLE_FULL"}, permission = "terminal.communications.view", implemented = false, minRank = "Cadete"},
    {id = "EQUIPMENT", label = "Equipamiento", icon = "EQUIPMENT", allowedModes = {"PDA", "VEHICLE_FULL"}, permission = "terminal.equipment.view", implemented = false, minRank = "Cadete"},
    {id = "SUPERVISION", label = "Supervisión", icon = "SUPERVISION", allowedModes = {"PDA", "VEHICLE_FULL"}, permission = "terminal.supervision.view", implemented = false, minRank = "Teniente"},
    {id = "SETTINGS", label = "Ajustes", icon = "SETTINGS", allowedModes = {"PDA", "VEHICLE_FULL"}, permission = "terminal.settings.view", implemented = false, minRank = "Cadete"}
}
