import {execFileSync} from "node:child_process";
import {existsSync, mkdirSync, readFileSync, writeFileSync} from "node:fs";
import {tmpdir} from "node:os";
import {join, resolve} from "node:path";
import {pathToFileURL} from "node:url";

const browsers = [
    "C:\\Program Files (x86)\\Microsoft\\Edge\\Application\\msedge.exe",
    "C:\\Program Files\\Microsoft\\Edge\\Application\\msedge.exe",
    "C:\\Program Files\\Google\\Chrome\\Application\\chrome.exe"
];
const browser = browsers.find(existsSync);
if (!browser) throw new Error("Chrome/Edge no disponible.");

const outputRoot = join(tmpdir(), "sentinel-police-os-qa");
const page = pathToFileURL(resolve("resources/sentinel_core/html/index.html")).href;
const resolutions = [[1920, 1080], [1600, 900], [1366, 768]];
const scenarios = [
    {id: "pda", mode: "PDA"},
    {id: "vehicle-full", mode: "VEHICLE_FULL"},
    {id: "driver-empty", mode: "DRIVER_SAFE"},
    {id: "driver-dispatch", mode: "DRIVER_SAFE", dispatch: true},
    {id: "driver-high", mode: "DRIVER_SAFE", dispatch: true, alert: "HIGH"},
    {id: "driver-emergency", mode: "DRIVER_SAFE", dispatch: true, alert: "EMERGENCY"},
    {id: "driver-kvp", mode: "DRIVER_SAFE", dispatch: true, layer: "KVP"},
    {id: "driver-editor", mode: "DRIVER_SAFE", dispatch: true, layer: "EDITOR"},
    {id: "isolated-alert", mode: "DRIVER_SAFE", isolated: "AlertWidget", alert: "HIGH"},
    {id: "isolated-unit", mode: "DRIVER_SAFE", isolated: "UnitWidget"},
    {id: "isolated-dispatch", mode: "DRIVER_SAFE", isolated: "DispatchWidget", dispatch: true},
    {id: "isolated-hint", mode: "DRIVER_SAFE", isolated: "HintWidget"},
    {id: "isolated-speed", mode: "DRIVER_SAFE", isolated: "SpeedWidget"}
];
mkdirSync(outputRoot, {recursive: true});

function makeSnapshot(scenario) {
    const full = scenario.mode !== "DRIVER_SAFE";
    const driverLayout = {
        AlertWidget: {dock: "TOP_RIGHT", order: 1, visible: true},
        UnitWidget: {dock: "RIGHT", order: 1, visible: true},
        DispatchWidget: {dock: "RIGHT", order: 2, visible: true},
        SpeedWidget: {dock: "BOTTOM_CENTER", order: 1, visible: true},
        HintWidget: {dock: "BOTTOM_RIGHT", order: 1, visible: true}
    };
    let layout = full ? {
        TerminalWidget: {dock: "LEFT", order: 1, visible: true},
        AlertWidget: {visible: true}, UnitWidget: {visible: scenario.mode === "VEHICLE_FULL"},
        DispatchWidget: {visible: scenario.mode === "VEHICLE_FULL"}, HintWidget: {visible: true}
    } : driverLayout;
    if (scenario.isolated) {
        layout = Object.fromEntries(Object.entries(driverLayout).map(([id, config]) => [
            id,
            {...config, visible: id === scenario.isolated}
        ]));
    }
    const widgets = {
        AlertWidget: {anchor: "TOP_RIGHT", x: 98, y: 12, scale: 1, visible: true},
        UnitWidget: {anchor: "RIGHT", x: 98, y: 30, scale: 1, visible: true},
        DispatchWidget: {anchor: "RIGHT", x: 98, y: 46, scale: 1, visible: true},
        SpeedWidget: {anchor: "BOTTOM", x: 50, y: 95, scale: 1, visible: true},
        HintWidget: {anchor: "BOTTOM_RIGHT", x: 98, y: 95, scale: 1, visible: true}
    };
    const alert = scenario.alert ? {id: "qa", type: "DISPATCH", source: "CENTRAL", title: "211 — Robo en progreso", message: "Strawberry", priority: scenario.alert} : null;
    return {
        mode: scenario.mode, activeModule: "HOME",
        modules: [{id: "HOME", label: "Inicio", implemented: true, allowed: true, visible: true}],
        widgetLayout: {
            uiScale: 1,
            preset: "TACTICAL",
            layout,
            widgets: full || scenario.layer === "KVP" ? widgets : {},
            nativeHud: {width: 0.165, fullHeight: 0.122, minimalHeight: 0.066}
        },
        context: {type: scenario.mode === "PDA" ? "ON_FOOT" : "VEHICLE_DRIVER", speedKmh: scenario.mode === "DRIVER_SAFE" ? 68 : 0, fullModeAvailable: false},
        officer: {name: "Oficial QA", rank: "Cadete", effectiveRank: "Cadete", xp: 120, nextRankXP: 500, nextRank: "Oficial", completedCases: 2},
        duty: {onDuty: true, callsign: "VICTOR-82", dispatchState: scenario.dispatch ? "PENDING" : "WAITING"},
        vehicle: {assigned: true, label: "Patrulla estándar", state: "ACTIVE", engineHealth: 900, bodyHealth: 950, transportCapacity: 2},
        dispatch: scenario.dispatch ? {lifecycle: "PENDING", code: "211", title: "Robo en progreso", distance: 400, canAccept: true} : {lifecycle: "NONE"},
        cases: {history: []}, alerts: alert ? [alert] : [], activeAlert: alert,
        qaEditor: scenario.layer === "EDITOR" ? {
            preferences: {
                schemaVersion: 2,
                uiScale: 1,
                preset: "TACTICAL",
                modes: {DRIVER_SAFE: widgets}
            },
            editableWidgets: ["HUDWidget", "AlertWidget", "UnitWidget", "DispatchWidget", "SpeedWidget", "HintWidget"],
            presets: {TACTICAL: Object.fromEntries(Object.keys(widgets).map((id) => [id, true]))}
        } : null
    };
}

function extractResult(dom) {
    const match = dom.match(/<pre id="police-os-qa-result"[^>]*>([\s\S]*?)<\/pre>/);
    if (!match) throw new Error("El navegador no genero assertions DOM.");
    return JSON.parse(match[1].replaceAll("&quot;", '"').replaceAll("&amp;", "&").replaceAll("&lt;", "<").replaceAll("&gt;", ">"));
}

const reports = [];
const roundTripFailures = [];
const invarianceFailures = [];

function resolveLayout(config, viewport, baseSize, uiScale) {
    const scale = uiScale * config.scale;
    const width = baseSize.width * scale;
    const height = baseSize.height * scale;
    let left = config.x / 100 * viewport.width;
    let top = config.y / 100 * viewport.height;

    if (["TOP", "BOTTOM"].includes(config.anchor)) left -= width / 2;
    else if (["TOP_RIGHT", "RIGHT", "BOTTOM_RIGHT"].includes(config.anchor)) left -= width;
    if (["LEFT", "RIGHT"].includes(config.anchor)) top -= height / 2;
    else if (["BOTTOM_LEFT", "BOTTOM", "BOTTOM_RIGHT"].includes(config.anchor)) top -= height;

    const marginX = viewport.width * 0.01;
    const marginY = viewport.height * 0.01;
    left = Math.max(marginX, Math.min(viewport.width - marginX - width, left));
    top = Math.max(marginY, Math.min(viewport.height - marginY - height, top));
    return {left, top, width, height};
}

function assertNear(label, actual, expected, tolerance = 2) {
    if (Math.abs(actual - expected) > tolerance) {
        roundTripFailures.push(`${label}: ${actual} != ${expected}`);
    }
}

for (const uiScale of [0.8, 1, 1.25]) {
    for (const config of [
        {anchor: "FREE", x: 34.25, y: 42.5, scale: 1.1},
        {anchor: "TOP_RIGHT", x: 98, y: 3, scale: 0.9},
        {anchor: "BOTTOM_RIGHT", x: 98, y: 97, scale: 1.2}
    ]) {
        const stored = JSON.parse(JSON.stringify(config));
        const first = resolveLayout(stored, {width: 1920, height: 1080}, {width: 240, height: 90}, uiScale);
        const reload = resolveLayout(JSON.parse(JSON.stringify(stored)), {width: 1920, height: 1080}, {width: 240, height: 90}, uiScale);
        assertNear(`${config.anchor}/${uiScale}/reload-x`, reload.left, first.left);
        assertNear(`${config.anchor}/${uiScale}/reload-y`, reload.top, first.top);
        const smaller = resolveLayout(stored, {width: 1600, height: 900}, {width: 200, height: 75}, uiScale);
        assertNear(`${config.anchor}/${uiScale}/relative-x`, smaller.left / 1600, first.left / 1920, 2 / 1600);
        assertNear(`${config.anchor}/${uiScale}/relative-y`, smaller.top / 900, first.top / 1080, 2 / 900);
        const returned = resolveLayout(stored, {width: 1920, height: 1080}, {width: 240, height: 90}, uiScale);
        assertNear(`${config.anchor}/${uiScale}/return-x`, returned.left, first.left);
        assertNear(`${config.anchor}/${uiScale}/return-y`, returned.top, first.top);
    }
}

const layerFixtures = {
    DEFAULTS: makeSnapshot({id: "invariance-defaults", mode: "DRIVER_SAFE"}).widgetLayout,
    KVP: makeSnapshot({id: "invariance-kvp", mode: "DRIVER_SAFE"}).widgetLayout,
    EDITOR: makeSnapshot({id: "invariance-editor", mode: "DRIVER_SAFE"}).widgetLayout
};
for (const [layer, fixture] of Object.entries(layerFixtures)) {
    const initial = JSON.stringify(fixture);
    const visualState = {
        dispatch: {lifecycle: "NONE"}, alert: null, vehicle: {state: "ACTIVE"},
        duty: {onDuty: true}, mode: "PDA"
    };
    visualState.mode = "DRIVER_SAFE";
    visualState.dispatch = {lifecycle: "PENDING", code: "415"};
    visualState.alert = {priority: "HIGH"};
    visualState.mode = "VEHICLE_FULL";
    visualState.vehicle = {state: "DAMAGED"};
    visualState.duty = {onDuty: false};
    visualState.dispatch = {lifecycle: "NONE"};
    if (JSON.stringify(fixture) !== initial) invarianceFailures.push(`${layer}: gameplay mutó layout`);
}

const hudSource = readFileSync(resolve("resources/sentinel_core/client/managers/HUDManager.lua"), "utf8");
const mainHudSource = hudSource.split("local function drawAlertCard")[0];
if (!/DrawRect\(x \+ width \/ 2, y \+ height \/ 2, width, height,\s*\n\s*10, 15, 22, 210\)/.test(mainHudSource)) {
    invarianceFailures.push("HUD native no usa el fondo compacto esperado");
}
if (/DrawRect\([^\n]*width\s*\/\s*2[\s\S]{0,120}width\s*\*|DrawRect\([^\n]*height\s*\/\s*2[\s\S]{0,120}height\s*\*/.test(mainHudSource)) {
    invarianceFailures.push("HUD native excede sus dimensiones lógicas");
}
const cssSource = readFileSync(resolve("resources/sentinel_core/html/style.css"), "utf8");
if (!/#mdt\.widget-editor-active \.hud-widget\s*\{[\s\S]*?background:\s*rgba\(10, 15, 22, 0\.82\);[\s\S]*?box-shadow:\s*none;/.test(cssSource)) {
    invarianceFailures.push("HUD proxy no usa el fondo compacto esperado");
}
for (const [width, height] of resolutions) {
    for (const scenario of scenarios) {
        const basename = `${width}x${height}-${scenario.id}`;
        const snapshot = encodeURIComponent(JSON.stringify(makeSnapshot(scenario)));
        const screenshot = join(outputRoot, `${basename}.png`);
        const dom = execFileSync(browser, [
            "--headless", "--disable-gpu", "--no-sandbox", "--disable-gpu-sandbox", "--use-angle=swiftshader",
            "--no-first-run", "--log-level=3", "--allow-file-access-from-files",
            `--window-size=${width},${height}`, "--force-device-scale-factor=1",
            "--virtual-time-budget=1200", `--screenshot=${screenshot}`, "--dump-dom",
            `${page}?qaSnapshot=${snapshot}${scenario.layer === "EDITOR" ? "&qaEditor=1" : ""}`
        ], {encoding: "utf8", maxBuffer: 10 * 1024 * 1024});
        const result = extractResult(dom);
        const failures = [];
        if (scenario.mode === "DRIVER_SAFE" && result.widgets.TerminalWidget.display !== "none") failures.push("TerminalWidget visible");
        if (scenario.layer === "EDITOR") {
            const proxyColor = result.widgets.HUDWidget?.computed?.backgroundColor || "";
            const proxyChannels = proxyColor.match(/[\d.]+/g)?.map(Number) || [];
            const expectedProxy = proxyChannels.length === 4
                && proxyChannels[0] === 10
                && proxyChannels[1] === 15
                && proxyChannels[2] === 22
                && Math.abs(proxyChannels[3] - 0.82) < 0.01;
            if (!expectedProxy) failures.push(`HUD proxy con fondo incorrecto (${proxyColor || "missing"})`);
        }
        if (scenario.mode === "DRIVER_SAFE" && !scenario.isolated && !result.widgets.SpeedWidget.shown) failures.push("SpeedWidget oculto");
        // El editor muestra incluso widgets sin datos para que puedan configurarse.
        if (scenario.layer !== "EDITOR" && !scenario.alert && result.widgets.AlertWidget.shown) failures.push("AlertWidget visible sin datos");
        if (scenario.layer !== "EDITOR" && !scenario.dispatch && scenario.mode === "DRIVER_SAFE" && result.widgets.DispatchWidget.shown) failures.push("DispatchWidget visible sin datos");
        if (result.outside.length) failures.push(`fuera viewport: ${result.outside.join(",")}`);
        // Los proxies editables pueden coexistir temporalmente durante drag/resize.
        if (scenario.layer !== "EDITOR" && result.overlaps.length) failures.push(`overlap: ${result.overlaps.join(",")}`);
        if (result.docks.some((dock) => dock.color !== "rgba(0, 0, 0, 0)" || dock.image !== "none")) failures.push("dock no transparente");
        Object.entries(result.widgets).forEach(([id, widget]) => {
            if (id !== "TerminalWidget" && widget.shown && widget.width > 450) failures.push(`${id}: ancho superior a 450px`);
            if (!widget.shown || !widget.parent) return;
            const parentAlpha = widget.parent.backgroundColor.match(/[\d.]+/g)?.[3] || 0;
            if (Number(parentAlpha) > 0) failures.push(`${id}: parent con fondo`);
            const widgetArea = widget.width * widget.height;
            const usefulArea = (widget.contentWidth + 32) * (widget.contentHeight + 32);
            if (widgetArea > usefulArea) failures.push(`${id}: caja mayor que contenido`);
        });
        reports.push({basename, failures, diagnostics: result});
    }
}

for (const scenario of scenarios.filter(({isolated}) => isolated)) {
    const snapshot = encodeURIComponent(JSON.stringify(makeSnapshot(scenario)));
    const screenshot = join(outputRoot, `diagnostic-color-${scenario.id}.png`);
    execFileSync(browser, [
        "--headless", "--disable-gpu", "--no-sandbox", "--disable-gpu-sandbox", "--use-angle=swiftshader",
        "--no-first-run", "--log-level=3", "--allow-file-access-from-files",
        "--window-size=1920,1080", "--force-device-scale-factor=1", "--virtual-time-budget=1200",
        `--screenshot=${screenshot}`, `${page}?qaColor=1&qaSnapshot=${snapshot}`
    ], {stdio: "ignore"});
}

writeFileSync(join(outputRoot, "results.json"), JSON.stringify(reports, null, 2));
const failed = reports.filter(({failures}) => failures.length);
console.log(`Police OS QA: ${reports.length - failed.length}/${reports.length} escenarios PASS`);
console.log(`Widget layout round-trip: ${roundTripFailures.length ? "FAIL" : "PASS"}`);
console.log(`Widget layout invariance DEFAULTS/KVP/EDITOR: ${invarianceFailures.length ? "FAIL" : "PASS"}`);
console.log(`Screenshots: ${outputRoot}`);
failed.forEach(({basename, failures}) => console.error(`FAIL ${basename}: ${failures.join("; ")}`));
roundTripFailures.forEach((failure) => console.error(`FAIL ${failure}`));
invarianceFailures.forEach((failure) => console.error(`FAIL ${failure}`));
if (failed.length || roundTripFailures.length || invarianceFailures.length) process.exitCode = 1;
