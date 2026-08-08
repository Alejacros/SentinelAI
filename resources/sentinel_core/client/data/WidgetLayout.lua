WidgetLayout = {
    UIScale = 1.0,
    SupportedScales = {0.8, 0.9, 1.0, 1.1, 1.25},
    DefaultPreset = "TACTICAL",
    EditableWidgets = {
        "HUDWidget",
        "AlertWidget",
        "UnitWidget",
        "DispatchWidget",
        "SpeedWidget",
        "HintWidget"
    },

    Presets = {
        COMPACT = {
            HUDWidget = true,
            AlertWidget = true,
            UnitWidget = true,
            DispatchWidget = true,
            SpeedWidget = true,
            HintWidget = false
        },
        TACTICAL = {
            HUDWidget = true,
            AlertWidget = true,
            UnitWidget = true,
            DispatchWidget = true,
            SpeedWidget = true,
            HintWidget = true
        },
        CINEMATIC = {
            HUDWidget = true,
            AlertWidget = true,
            UnitWidget = false,
            DispatchWidget = false,
            SpeedWidget = true,
            HintWidget = false
        }
    },

    EditorDefaults = {
        PDA = {
            HUDWidget = {anchor = "TOP_RIGHT", x = 98, y = 3, scale = 1.0, visible = true},
            AlertWidget = {anchor = "TOP_RIGHT", x = 98, y = 17, scale = 1.0, visible = true},
            UnitWidget = {anchor = "RIGHT", x = 98, y = 34, scale = 1.0, visible = false},
            DispatchWidget = {anchor = "RIGHT", x = 98, y = 50, scale = 1.0, visible = false},
            SpeedWidget = {anchor = "BOTTOM", x = 50, y = 96, scale = 1.0, visible = false},
            HintWidget = {anchor = "BOTTOM_RIGHT", x = 98, y = 96, scale = 1.0, visible = true}
        },
        DRIVER_SAFE = {
            HUDWidget = {anchor = "TOP_RIGHT", x = 98, y = 3, scale = 1.0, visible = true},
            AlertWidget = {anchor = "RIGHT", x = 98, y = 22, scale = 1.0, visible = true},
            DispatchWidget = {anchor = "RIGHT", x = 98, y = 40, scale = 1.0, visible = true},
            UnitWidget = {anchor = "RIGHT", x = 98, y = 58, scale = 1.0, visible = true},
            SpeedWidget = {anchor = "BOTTOM", x = 50, y = 95, scale = 1.0, visible = true},
            HintWidget = {anchor = "BOTTOM_RIGHT", x = 98, y = 95, scale = 1.0, visible = true}
        },
        VEHICLE_FULL = {
            HUDWidget = {anchor = "TOP_RIGHT", x = 98, y = 3, scale = 1.0, visible = true},
            AlertWidget = {anchor = "TOP_RIGHT", x = 98, y = 17, scale = 1.0, visible = true},
            UnitWidget = {anchor = "RIGHT", x = 98, y = 34, scale = 1.0, visible = true},
            DispatchWidget = {anchor = "RIGHT", x = 98, y = 50, scale = 1.0, visible = true},
            SpeedWidget = {anchor = "BOTTOM", x = 50, y = 96, scale = 1.0, visible = false},
            HintWidget = {anchor = "BOTTOM_RIGHT", x = 98, y = 96, scale = 1.0, visible = true}
        }
    },

    Docks = {
        TOP = true,
        TOP_RIGHT = true,
        RIGHT = true,
        BOTTOM_RIGHT = true,
        BOTTOM_CENTER = true,
        LEFT = true
    },

    Layouts = {
        PDA = {
            HUDWidget = {dock = "TOP_RIGHT", order = 1, size = "COMPACT", visible = true},
            AlertWidget = {dock = "TOP_RIGHT", order = 2, size = "COMPACT", visible = true, offsetY = 8.5},
            TerminalWidget = {dock = "LEFT", order = 1, size = "PDA", visible = true},
            HintWidget = {dock = "BOTTOM_RIGHT", order = 1, size = "COMPACT", visible = true}
        },

        DRIVER_SAFE = {
            HUDWidget = {dock = "TOP_RIGHT", order = 1, size = "MINIMAL", visible = true},
            AlertWidget = {dock = "RIGHT", order = 1, size = "COMPACT", visible = true},
            DispatchWidget = {dock = "RIGHT", order = 2, size = "COMPACT", visible = true},
            UnitWidget = {dock = "RIGHT", order = 3, size = "COMPACT", visible = true},
            SpeedWidget = {dock = "BOTTOM_CENTER", order = 1, size = "GLANCE", visible = true},
            HintWidget = {dock = "BOTTOM_RIGHT", order = 1, size = "COMPACT", visible = true}
        },

        VEHICLE_FULL = {
            HUDWidget = {dock = "TOP_RIGHT", order = 1, size = "COMPACT", visible = true},
            AlertWidget = {dock = "TOP_RIGHT", order = 2, size = "COMPACT", visible = true, offsetY = 8.5},
            TerminalWidget = {dock = "LEFT", order = 1, size = "VEHICLE", visible = true},
            UnitWidget = {dock = "RIGHT", order = 1, size = "COMPACT", visible = true},
            DispatchWidget = {dock = "RIGHT", order = 2, size = "COMPACT", visible = true},
            HintWidget = {dock = "BOTTOM_RIGHT", order = 1, size = "COMPACT", visible = true}
        }
    },

    NativeHUD = {
        TOP_RIGHT = {
            anchorX = 0.815,
            anchorY = 0.035,
            width = 0.165,
            fullHeight = 0.122,
            minimalHeight = 0.072
        }
    },

    FutureWidgets = {
        "RadarWidget",
        "ALPRWidget",
        "EmergencyControlsWidget",
        "PAWidget",
        "BodycamWidget",
        "DroneWidget",
        "TacticalMapWidget",
        "SupervisorWidget",
        "CopilotWidget"
    }
}

function WidgetLayout.GetLayout(mode)
    return WidgetLayout.Layouts[mode] or WidgetLayout.Layouts.PDA
end

function WidgetLayout.GetWidget(widgetId, mode)
    local layout = WidgetLayout.GetLayout(mode)
    return layout and layout[widgetId] or nil
end
