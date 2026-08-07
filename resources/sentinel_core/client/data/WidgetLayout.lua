WidgetLayout = {
    UIScale = 1.0,
    SupportedScales = {0.8, 0.9, 1.0, 1.1, 1.25},

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
            AlertWidget = {dock = "TOP_RIGHT", order = 2, size = "COMPACT", visible = true},
            TerminalWidget = {dock = "LEFT", order = 1, size = "PDA", visible = true},
            HintWidget = {dock = "BOTTOM_RIGHT", order = 1, size = "COMPACT", visible = true}
        },

        DRIVER_SAFE = {
            HUDWidget = {dock = "TOP_RIGHT", order = 1, size = "MINIMAL", visible = true},
            AlertWidget = {dock = "TOP", order = 1, size = "COMPACT", visible = true},
            UnitWidget = {dock = "RIGHT", order = 1, size = "COMPACT", visible = true},
            DispatchWidget = {dock = "RIGHT", order = 2, size = "COMPACT", visible = true},
            SpeedWidget = {dock = "BOTTOM_CENTER", order = 1, size = "GLANCE", visible = true},
            HintWidget = {dock = "BOTTOM_RIGHT", order = 1, size = "COMPACT", visible = true}
        },

        VEHICLE_FULL = {
            HUDWidget = {dock = "TOP_RIGHT", order = 1, size = "COMPACT", visible = true},
            AlertWidget = {dock = "TOP_RIGHT", order = 2, size = "COMPACT", visible = true},
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
            minimalHeight = 0.066
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
