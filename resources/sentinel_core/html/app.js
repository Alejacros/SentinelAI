const mdt = document.getElementById("mdt");
const navigation = document.querySelector(".navigation");
const closeButton = document.getElementById("closeButton");
const pageTitle = document.getElementById("pageTitle");
const sentinelVersion = document.getElementById("sentinelVersion");
const characterCreator = document.getElementById("characterCreator");
const characterForm = document.getElementById("characterForm");
const customPronounsField = document.getElementById("customPronounsField");
const characterError = document.getElementById("characterError");
const characterSubmit = document.getElementById("characterSubmit");
const policeGarage = document.getElementById("policeGarage");
const garageStation = document.getElementById("garageStation");
const garageCurrentUnit = document.getElementById("garageCurrentUnit");
const garageVehicleList = document.getElementById("garageVehicleList");
const garageNextUnlock = document.getElementById("garageNextUnlock");

const terminalState = {
    mode: "PDA",
    activeModule: "HOME",
    modules: [],
    widgetLayout: {},
    widgetKeys: {},
    snapshot: {}
};

const widgetEditorState = {
    active: false,
    mode: "PDA",
    preferences: null,
    defaults: null,
    presets: {},
    editableWidgets: [],
    drag: null
};

const diagnosedDomModes = new Set();
const resolvedWidgetDiagnostics = new Set();

const moduleDescriptions = {
    CAD: "Assignments operativos disponibles y actividad reciente.",
    PEOPLE: "Consulta ciudadana básica preparada para una fase posterior.",
    VEHICLES: "Consulta de matrículas y vehículos próximamente.",
    EVIDENCE: "Cadena de custodia y evidencias del expediente.",
    MAP: "Mapa operativo y herramientas GPS próximamente.",
    SERVICES: "Servicios de apoyo próximamente.",
    RADAR: "Radar vehicular próximamente.",
    ALPR: "Lectura automática de matrículas próximamente.",
    COMMUNICATIONS: "Canal operativo y futuros mensajes de Central/Copilot.",
    EQUIPMENT: "Gestión de equipo próximamente.",
    SUPERVISION: "Herramientas de supervisión para rangos autorizados.",
    SETTINGS: "Preferencias del terminal próximamente."
};

function postNui(endpoint, payload = {}) {
    return fetch(`https://${GetParentResourceName()}/${endpoint}`, {
        method: "POST",
        headers: {"Content-Type": "application/json"},
        body: JSON.stringify(payload)
    });
}

function escapeHtml(value) {
    return String(value ?? "")
        .replaceAll("&", "&amp;")
        .replaceAll("<", "&lt;")
        .replaceAll(">", "&gt;")
        .replaceAll('"', "&quot;")
        .replaceAll("'", "&#039;");
}

function cloneData(value) {
    return JSON.parse(JSON.stringify(value));
}

function logWidgetMutation(source, mode, widgetId, previous, current) {
    if (!previous || !current) return;
    if (previous.anchor === current.anchor
        && previous.x === current.x
        && previous.y === current.y
        && previous.scale === current.scale
        && previous.visible === current.visible) return;
    console.log("[WidgetLayout MUTATION]");
    console.log(`source=${source}`);
    console.log(`mode=${mode}`);
    console.log(`widget=${widgetId}`);
    console.log(`oldAnchor=${previous.anchor}`);
    console.log(`newAnchor=${current.anchor}`);
    console.log(`oldX=${previous.x}`);
    console.log(`newX=${current.x}`);
    console.log(`oldY=${previous.y}`);
    console.log(`newY=${current.y}`);
}

function iconSvg(name, className = "terminal-icon") {
    const icon = String(name || "home").toLowerCase();
    return `<svg class="${className}" aria-hidden="true"><use href="icons.svg#${escapeHtml(icon)}"></use></svg>`;
}

function alertIcon(type) {
    const icons = {
        DISPATCH: "dispatch",
        CENTRAL: "central",
        VEHICLE: "vehicles",
        ALPR: "alpr",
        WARNING: "warning",
        CRITICAL: "warning",
        SUCCESS: "success"
    };
    return iconSvg(icons[type] || "central", "alert-type-icon");
}

function setText(id, value) {
    const element = document.getElementById(id);
    if (element) element.textContent = value;
}

function statusLabel(value) {
    const labels = {
        OFF_DUTY: "Fuera de servicio",
        WAITING: "Disponible",
        PENDING: "Despacho pendiente",
        EN_ROUTE: "En ruta",
        ON_SCENE: "En escena",
        EVIDENCE: "Evidencia",
        TRANSPORT: "Transporte",
        REPORT: "Informe"
    };
    return labels[value] || value || "Sin estado";
}

function priorityLabel(value) {
    return ({LOW: "Baja", NORMAL: "Normal", HIGH: "Alta", EMERGENCY: "Emergencia"})[value] || "Normal";
}

function formatDuration(seconds) {
    const total = Number(seconds) || 0;
    return `${Math.floor(total / 60)}:${String(total % 60).padStart(2, "0")}`;
}

function ensureTerminalShell() {
    document.querySelector(".brand h1").textContent = "SENTINEL POLICE OS";
    document.querySelector(".eyebrow").textContent = "TERMINAL POLICIAL SEGURA";

    let modeBadge = document.getElementById("terminalModeBadge");
    if (!modeBadge) {
        modeBadge = document.createElement("span");
        modeBadge.id = "terminalModeBadge";
        modeBadge.className = "terminal-mode-badge";
        document.querySelector(".topbar > div").appendChild(modeBadge);
    }

    ensureDockSystem();
}

function ensureDockSystem() {
    if (document.getElementById("terminalDockRoot")) return;

    const dockRoot = document.createElement("section");
    dockRoot.id = "terminalDockRoot";
    dockRoot.className = "terminal-dock-root";

    ["TOP", "TOP_RIGHT", "RIGHT", "BOTTOM_RIGHT", "BOTTOM_CENTER", "LEFT"]
        .forEach((dockId) => {
            const dock = document.createElement("div");
            dock.className = `terminal-dock dock-${dockId.toLowerCase().replaceAll("_", "-")}`;
            dock.dataset.dock = dockId;
            dockRoot.appendChild(dock);
        });

    const terminalWidget = document.createElement("section");
    terminalWidget.id = "TerminalWidget";
    terminalWidget.className = "os-widget terminal-widget";
    terminalWidget.appendChild(document.querySelector(".sidebar"));
    terminalWidget.appendChild(document.querySelector(".workspace"));

    ["AlertWidget", "UnitWidget", "DispatchWidget", "SpeedWidget", "HintWidget"]
        .forEach((widgetId) => {
            const widget = document.createElement("section");
            widget.id = widgetId;
            widget.className = `os-widget ${widgetId.replace("Widget", "").toLowerCase()}-widget`;
            dockRoot.appendChild(widget);
        });

    dockRoot.appendChild(terminalWidget);
    mdt.appendChild(dockRoot);
}

function applyWidgetLayout() {
    const config = terminalState.widgetLayout || {};
    const layout = config.layout || {};
    document.documentElement.style.setProperty(
        "--police-ui-scale",
        String(config.uiScale || 1)
    );

    document.querySelectorAll(".os-widget:not(.editor-only)").forEach((widget) => {
        const widgetConfig = layout[widget.id];
        const preference = config.widgets?.[widget.id];
        const requiredDriverSpeed = terminalState.mode === "DRIVER_SAFE"
            && widget.id === "SpeedWidget";
        const visible = widgetConfig?.visible
            && (requiredDriverSpeed
                || (preference ? preference.visible !== false : true));
        widget.classList.toggle("hidden", !visible);

        if (!visible) return;

        if (preference) {
            positionWidget(widget, preference);
            document.getElementById("terminalDockRoot")?.appendChild(widget);
            return;
        }

        const dock = document.querySelector(
            `[data-dock="${widgetConfig.dock}"]`
        );
        widget.dataset.size = widgetConfig.size || "COMPACT";
        widget.style.order = Number(widgetConfig.order) || 0;
        widget.style.marginTop = `${Number(widgetConfig.offsetY) || 0}rem`;
        widget.style.marginRight = `${Number(widgetConfig.offsetX) || 0}rem`;
        dock?.appendChild(widget);
    });
}

function anchorTranslate(anchor) {
    const translations = {
        TOP_LEFT: "0% 0%",
        TOP: "-50% 0%",
        TOP_RIGHT: "-100% 0%",
        RIGHT: "-100% -50%",
        BOTTOM_RIGHT: "-100% -100%",
        BOTTOM: "-50% -100%",
        BOTTOM_LEFT: "0% -100%",
        LEFT: "0% -50%",
        FREE: "0% 0%"
    };
    return translations[anchor] || translations.FREE;
}

function positionWidget(widget, config, editor = false) {
    widget.classList.add("free-widget");
    const x = Math.max(2, Math.min(98, Number(config.x) || 50));
    const y = Math.max(2, Math.min(98, Number(config.y) || 50));
    widget.style.left = `${window.innerWidth * x / 100}px`;
    widget.style.top = `${window.innerHeight * y / 100}px`;
    widget.style.translate = anchorTranslate(config.anchor);
    widget.style.setProperty("--widget-scale", String(Number(config.scale) || 1));
    widget.classList.toggle("editor-disabled", editor && config.visible === false);
    requestAnimationFrame(() => {
        constrainWidgetToViewport(widget);
        logResolvedWidget(widget, config);
    });
}

function constrainWidgetToViewport(widget) {
    if (getComputedStyle(widget).display === "none") return;
    const marginX = window.innerWidth * 0.01;
    const marginY = window.innerHeight * 0.01;
    const rect = widget.getBoundingClientRect();
    let offsetX = 0;
    let offsetY = 0;

    if (rect.left < marginX) offsetX = marginX - rect.left;
    else if (rect.right > window.innerWidth - marginX) offsetX = window.innerWidth - marginX - rect.right;
    if (rect.top < marginY) offsetY = marginY - rect.top;
    else if (rect.bottom > window.innerHeight - marginY) offsetY = window.innerHeight - marginY - rect.bottom;

    if (offsetX || offsetY) {
        const style = getComputedStyle(widget);
        widget.style.left = `${parseFloat(style.left) + offsetX}px`;
        widget.style.top = `${parseFloat(style.top) + offsetY}px`;
    }
}

function logResolvedWidget(widget, config) {
    const rect = widget.getBoundingClientRect();
    const key = [
        terminalState.mode,
        widget.id,
        window.innerWidth,
        window.innerHeight,
        config.anchor,
        Number(config.x).toFixed(4),
        Number(config.y).toFixed(4),
        Number(config.scale).toFixed(3)
    ].join("|");

    if (resolvedWidgetDiagnostics.has(key)) return;
    resolvedWidgetDiagnostics.add(key);
    console.log("[WidgetLayout RESOLVED]");
    console.log(`widget=${widget.id}`);
    console.log(`screen=${window.innerWidth}x${window.innerHeight}`);
    console.log(`finalX=${rect.left.toFixed(2)}`);
    console.log(`finalY=${rect.top.toFixed(2)}`);
    console.log(`finalW=${rect.width.toFixed(2)}`);
    console.log(`finalH=${rect.height.toFixed(2)}`);
}

function widgetChanged(widgetId, value) {
    const nextKey = JSON.stringify(value);

    if (terminalState.widgetKeys[widgetId] === nextKey) {
        return false;
    }

    terminalState.widgetKeys[widgetId] = nextKey;
    return true;
}

function renderModules() {
    navigation.innerHTML = terminalState.modules
        .filter((module) => module.visible !== false)
        .map((module) => {
            const state = module.locked
                ? "locked"
                : (!module.implemented
                    ? "upcoming"
                    : (!module.allowed ? "locked" : "available"));
            const suffix = state === "locked"
                ? iconSvg("lock", "module-lock")
                : (state === "upcoming"
                    ? '<span class="module-badge">PRÓX.</span>'
                    : "");
            return `
                <button class="nav-button ${terminalState.activeModule === module.id ? "active" : ""} ${state}"
                    data-module="${escapeHtml(module.id)}" data-enabled="${state === "available"}"
                    title="${escapeHtml(`${module.label} · ${module.reason || "Disponible"}`)}" type="button">
                    ${iconSvg(module.id)}
                    <strong>${escapeHtml(module.label)}</strong>
                    <small>${suffix}</small>
                </button>`;
        }).join("");

    navigation.querySelectorAll(".nav-button").forEach((button) => {
        button.addEventListener("click", async () => {
            if (button.dataset.enabled !== "true") return;
            const moduleId = button.dataset.module;
            const response = await postNui("terminal:openModule", {moduleId});
            const result = await response.json();
            if (result.ok) {
                terminalState.activeModule = moduleId;
                renderModules();
                renderTerminal();
            }
        });
    });
}

function renderHistory(history) {
    const entries = Array.isArray(history) ? history : Object.values(history || {});
    setText("historyCount", `${entries.length} caso${entries.length === 1 ? "" : "s"}`);
    const list = document.getElementById("caseHistoryList");
    if (!list) return;
    if (!entries.length) {
        list.innerHTML = '<div class="empty-history">No hay casos archivados.</div>';
        return;
    }
    list.innerHTML = entries.map((item) => `
        <article class="case-history-item">
            <div class="case-history-header"><div><span>CASO #${String(item.id || 0).padStart(4, "0")}</span>
            <h4>Código ${escapeHtml(item.code)} · ${escapeHtml(item.title)}</h4></div>
            <strong>+${Number(item.xp) || 0} XP</strong></div>
            <div class="case-history-details"><p><b>Evidencia:</b> ${escapeHtml((item.evidence || []).join?.(", ") || "Sin evidencia")}</p>
            <p><b>Duración:</b> ${formatDuration(item.durationSeconds)}</p>
            <p><b>Cerrado:</b> ${escapeHtml(item.completedAt || "Sin fecha")}</p></div>
        </article>`).join("");
}

function renderHome(snapshot) {
    const officer = snapshot.officer || {};
    const duty = snapshot.duty || {};
    const dispatch = snapshot.dispatch || {};
    setText("rank", officer.effectiveRank || officer.rank || "Cadete");
    setText("unit", duty.callsign || "Sin asignar");
    setText("xp", `${Number(officer.xp) || 0} XP`);
    setText("cases", Number(officer.completedCases) || 0);
    setText("status", statusLabel(duty.dispatchState));
    setText("statusBadge", statusLabel(duty.dispatchState));
    setText("progress", officer.nextRankXP
        ? `${officer.xp || 0} / ${officer.nextRankXP} XP · ${officer.nextRank}`
        : `${officer.xp || 0} XP · rango máximo`);
    setText("sidebarUnit", duty.callsign || "Sin asignar");
    setText("sidebarStatus", statusLabel(duty.dispatchState));

    const activeCase = document.getElementById("activeCase");
    if (dispatch.lifecycle && dispatch.lifecycle !== "NONE") {
        activeCase.classList.remove("empty");
        setText("caseCode", dispatch.code ? `CÓDIGO ${dispatch.code}` : "DESPACHO");
        setText("caseTitle", dispatch.title || "Incidente activo");
        setText("caseState", dispatch.lifecycle);
    } else {
        activeCase.classList.add("empty");
        setText("caseCode", "SIN DESPACHO");
        setText("caseTitle", "No hay un incidente activo");
        setText("caseState", "Permanece disponible para la central.");
    }

    let homeExtras = document.getElementById("homeExtras");
    if (!homeExtras) {
        homeExtras = document.createElement("div");
        homeExtras.id = "homeExtras";
        homeExtras.className = "home-extras";
        document.querySelector('[data-page-content="dashboard"]').appendChild(homeExtras);
    }
    const vehicle = snapshot.vehicle || {};
    const alert = snapshot.activeAlert || (snapshot.alerts || [])[0];
    const alertActions = (alert?.actions || []).map((action) =>
        `<button data-terminal-action="${escapeHtml(action.id)}" data-assignment-id="${escapeHtml(action.assignmentId || alert?.metadata?.assignmentId || "")}" ${action.available ? "" : "disabled"}>${escapeHtml(action.label)}</button>`
    ).join("");
    const dutyAction = duty.onDuty ? "duty.stop" : "duty.start";
    const dutyLabel = duty.onDuty ? "FINALIZAR TURNO" : "INICIAR TURNO";
    const history = Array.isArray(snapshot.cases?.history)
        ? snapshot.cases.history
        : Object.values(snapshot.cases?.history || {});
    const lastCase = history[history.length - 1];
    homeExtras.innerHTML = `
        <article class="terminal-mini-card duty-card ${duty.onDuty ? "is-on-duty" : "is-off-duty"}">
            <span>${escapeHtml(officer.name || "OFICIAL")} · ${escapeHtml(officer.effectiveRank || officer.rank || "Cadete")}</span><strong>${duty.onDuty ? "EN SERVICIO" : "Fuera de servicio"}</strong>
            <p>${duty.onDuty ? `${escapeHtml(duty.callsign || "Sin callsign")} · ${escapeHtml(officer.effectiveRank || officer.rank || "Cadete")}` : "Inicia un turno para acceder a funciones operativas."}</p>
            <button data-terminal-action="${dutyAction}">${dutyLabel}</button>
        </article>
        <article class="terminal-mini-card"><span>UNIDAD ASIGNADA</span><strong>${escapeHtml(vehicle.label || "Sin unidad asignada")}</strong><p>${escapeHtml(vehicle.state || "NONE")}</p>
            <button data-terminal-action="vehicle.locate" ${vehicle.assigned ? "" : "disabled"}>LOCALIZAR</button>
        </article>
        <article class="terminal-mini-card alert-${escapeHtml((alert?.priority || "NORMAL").toLowerCase())}"><span>${alertIcon(alert?.type)} ALERTA PRIORITARIA</span>
            <strong>${escapeHtml(alert?.title || "Sin alertas")}</strong><p>${escapeHtml(alert?.message || "No hay novedades operativas.")}</p>${alertActions}
        </article>
        <article class="terminal-mini-card quick-actions"><span>ACCESOS RÁPIDOS</span>
            <p>ÚLTIMO CASO · ${escapeHtml(lastCase?.title || "Sin expedientes archivados")}</p>
            <button data-open-module="CAD" ${duty.onDuty ? "" : "disabled"}>CAD</button>
            <button data-open-module="MAP" ${duty.onDuty ? "" : "disabled"}>MAPA</button>
        </article>`;
}

function renderDashboardIfChanged() {
    if (terminalState.mode === "DRIVER_SAFE"
        || terminalState.activeModule !== "HOME") return;

    const snapshot = terminalState.snapshot;
    const rawHistory = snapshot.cases?.history || [];
    const history = Array.isArray(rawHistory)
        ? rawHistory
        : Object.values(rawHistory);
    const lastCase = history[history.length - 1];
    const key = {
        officer: snapshot.officer,
        duty: snapshot.duty,
        vehicle: {
            assigned: snapshot.vehicle?.assigned,
            label: snapshot.vehicle?.label,
            state: snapshot.vehicle?.state
        },
        dispatch: {
            lifecycle: snapshot.dispatch?.lifecycle,
            code: snapshot.dispatch?.code,
            title: snapshot.dispatch?.title
        },
        alertId: snapshot.activeAlert?.id,
        lastCaseId: lastCase?.id
    };

    if (!widgetChanged("DashboardWidget", key)) return;
    renderHome(snapshot);
    bindTerminalActions();
}

function renderAlertWidget() {
    const widget = document.getElementById("AlertWidget");
    const snapshot = terminalState.snapshot;
    const alert = snapshot.activeAlert || (snapshot.alerts || [])[0];

    if (!widgetChanged("AlertWidget", alert || null)) return;

    widget.classList.remove(
        "priority-low",
        "priority-normal",
        "priority-high",
        "priority-emergency"
    );
    widget.classList.add(
        `priority-${String(alert?.priority || "LOW").toLowerCase()}`
    );
    widget.classList.toggle(
        "context-hidden",
        !alert && !widgetEditorState.active
    );
    widget.innerHTML = alert ? `
        <header>${alertIcon(alert.type)}<span>${escapeHtml(alert.source || alert.type)}</span><b>${escapeHtml(priorityLabel(alert.priority))}</b></header>
        <strong>${escapeHtml(alert.title)}</strong>
        <p>${escapeHtml(alert.message)}</p>` : `
        <header>${alertIcon("SUCCESS")}<span>CENTRAL</span><b>NORMAL</b></header>
        <strong>Sin alertas prioritarias</strong>`;
}

function renderUnitWidget() {
    const widget = document.getElementById("UnitWidget");
    const duty = terminalState.snapshot.duty || {};
    const vehicle = terminalState.snapshot.vehicle || {};
    const view = {
        callsign: duty.callsign,
        state: vehicle.state,
        label: vehicle.label
    };

    if (!widgetChanged("UnitWidget", view)) return;
    widget.classList.toggle(
        "is-minimal",
        vehicle.state === "ACTIVE"
    );
    widget.innerHTML = `
        <header>${iconSvg("unit")}<span>UNIDAD</span></header>
        <strong>${escapeHtml(duty.callsign || "SIN ASIGNAR")}</strong>
        <dl><div><dt>ESTADO</dt><dd>${escapeHtml(vehicle.state || "NONE")}</dd></div>
        <div><dt>MODELO</dt><dd>${escapeHtml(vehicle.label || "—")}</dd></div></dl>`;
}

function renderDispatchWidget() {
    const widget = document.getElementById("DispatchWidget");
    const dispatch = terminalState.snapshot.dispatch || {};

    const inactive = !dispatch.lifecycle
        || dispatch.lifecycle === "NONE";

    if (!widgetChanged("DispatchWidget", {
        mode: terminalState.mode,
        lifecycle: dispatch.lifecycle,
        title: dispatch.title,
        code: dispatch.code,
        distance: dispatch.distance
            ? Math.round(dispatch.distance / 10) * 10
            : null,
        canAccept: dispatch.canAccept
    })) return;
    widget.classList.toggle(
        "is-collapsed",
        inactive && !widgetEditorState.active
    );
    widget.classList.toggle(
        "context-hidden",
        inactive
            && terminalState.mode === "DRIVER_SAFE"
            && !widgetEditorState.active
    );
    widget.innerHTML = `
        <header>${iconSvg("cad")}<span>CAD · ${escapeHtml(dispatch.lifecycle || "NONE")}</span></header>
        ${inactive ? "" : `<strong>${escapeHtml(dispatch.title || "Sin llamada activa")}</strong>`}
        ${inactive ? "" : `
        <dl><div><dt>CÓDIGO</dt><dd>${escapeHtml(dispatch.code || "—")}</dd></div>
        <div><dt>DISTANCIA</dt><dd>${dispatch.distance ? `${Math.round(dispatch.distance)} m` : "—"}</dd></div></dl>
        ${inactive ? "" : `<small>${escapeHtml(dispatch.operationalTier || "T1_BASIC")} · ${escapeHtml(dispatch.priority || "NORMAL")}</small>`}
        ${dispatch.canAccept ? '<small>Y · ACEPTAR</small>' : ""}`}`;
}

function renderSpeedWidget() {
    const widget = document.getElementById("SpeedWidget");
    const speed = Math.round(terminalState.snapshot.context?.speedKmh || 0);

    if (!widgetChanged("SpeedWidget", speed)) return;
    widget.innerHTML = `<span>SPD</span><strong>${speed}</strong><small>km/h</small>`;
}

function renderHintWidget() {
    const widget = document.getElementById("HintWidget");
    const context = terminalState.snapshot.context || {};
    const message = terminalState.mode === "DRIVER_SAFE"
        ? (context.fullModeAvailable
            ? "Vehículo detenido · terminal completo"
            : "Cerrar vista segura")
        : "Cerrar Police OS";

    if (!widgetChanged("HintWidget", message)) return;
    widget.innerHTML = `<kbd>F7</kbd><span>${message}</span>`;
    widget.classList.remove("hint-transient");
    void widget.offsetWidth;
    widget.classList.add("hint-transient");
}

function renderOperationalWidgets() {
    renderAlertWidget();
    renderUnitWidget();
    renderDispatchWidget();
    renderSpeedWidget();
    renderHintWidget();
    requestAnimationFrame(() => {
        ["AlertWidget", "UnitWidget", "DispatchWidget", "SpeedWidget", "HintWidget"]
            .map((id) => document.getElementById(id))
            .filter(Boolean)
            .forEach(constrainWidgetToViewport);
    });
}

function renderGeneric(moduleId, snapshot) {
    const page = document.querySelector('[data-page-content="people"]');
    const module = terminalState.modules.find((item) => item.id === moduleId) || {};
    const placeholder = page.querySelector(".placeholder-panel");
    placeholder.innerHTML = `<span>${escapeHtml(module.id || moduleId)}</span><h3>${escapeHtml(module.label || moduleId)}</h3>
        <p>${escapeHtml(moduleDescriptions[moduleId] || "Módulo preparado para una fase posterior.")}</p>`;
    if (moduleId === "UNIT") {
        const vehicle = snapshot.vehicle || {};
        placeholder.innerHTML += `<div class="unit-details"><strong>${escapeHtml(vehicle.label || "Sin unidad asignada")}</strong>
            <span>Estado: ${escapeHtml(vehicle.state || "NONE")}</span><span>Motor: ${Math.round(vehicle.engineHealth || 0)}</span>
            <span>Carrocería: ${Math.round(vehicle.bodyHealth || 0)}</span><span>Custodia: ${Number(vehicle.transportCapacity) || 0}</span></div>
            <button data-terminal-action="vehicle.locate" ${vehicle.assigned ? "" : "disabled"}>Localizar unidad</button>`;
    } else if (moduleId === "CAD") {
        const dispatch = snapshot.dispatch || {};
        const calls = Array.isArray(dispatch.calls) ? dispatch.calls : [];
        const recentCalls = Array.isArray(dispatch.recentCalls)
            ? dispatch.recentCalls.filter((call) => call.status !== "PENDING").slice(0, 6)
            : [];
        const cadHistory = Array.isArray(dispatch.history) ? dispatch.history.slice(-8).reverse() : [];
        placeholder.innerHTML += `<div class="cad-assignment-list">${calls.length ? calls.map((call) => {
            const remaining = Math.max(0, Math.ceil((Number(call.remainingMs) || 0) / 1000));
            const authorization = call.rankEligible ? "AUTORIZADO" : "NO AUTORIZADO";
            const reason = call.eligibilityReason === "RANK_REQUIRED"
                ? `Requiere ${escapeHtml(call.minimumRank || "rango superior")}`
                : call.eligibilityReason === "MISSION_ACTIVE"
                ? "Misión principal activa"
                : escapeHtml(call.eligibilityReason || "");
            return `<article class="cad-assignment priority-${escapeHtml(String(call.priority || "NORMAL").toLowerCase())}">
                <header><strong>${escapeHtml(call.code || "—")} · ${escapeHtml(call.title || "Incidente")}</strong><b>${escapeHtml(call.priority || "NORMAL")}</b></header>
                <div><span>${escapeHtml(call.operationalTier || "T1_BASIC")}</span><span>${call.distance ? `${Math.round(call.distance)} m` : "—"}</span><span>${remaining}s</span></div>
                <small>${authorization}${reason ? ` · ${reason}` : ""}</small>
                <footer><button data-terminal-action="dispatch.accept" data-assignment-id="${escapeHtml(call.assignmentId)}" ${call.eligible ? "" : "disabled"}>Aceptar</button>
                <button data-terminal-action="dispatch.decline" data-assignment-id="${escapeHtml(call.assignmentId)}">Rechazar</button></footer>
            </article>`;
        }).join("") : "<p>Sin assignments pendientes.</p>"}</div>
        <div class="cad-runtime-history"><strong>ASSIGNMENTS RECIENTES</strong>${recentCalls.length
            ? recentCalls.map((call) => `<small>${escapeHtml(call.status || "UPDATE")} · ${escapeHtml(call.code || "—")} · ${escapeHtml(call.title || "Incidente")}</small>`).join("")
            : "<small>Sin assignments cerrados o activos.</small>"}</div>
        <div class="cad-runtime-history"><strong>ACTIVIDAD RECIENTE</strong>${cadHistory.length
            ? cadHistory.map((entry) => `<small>${escapeHtml(entry.event || "UPDATE")} · ${escapeHtml(entry.assignmentId || "—")}</small>`).join("")
            : "<small>Sin actividad registrada.</small>"}</div>`;
    } else if (moduleId === "MAP") {
        const vehicle = snapshot.vehicle || {};
        placeholder.innerHTML += `<button data-terminal-action="vehicle.locate" ${vehicle.assigned ? "" : "disabled"}>Marcar unidad en GPS</button>`;
    }
}

function renderTerminal() {
    const snapshot = terminalState.snapshot;
    const mode = terminalState.mode;
    mdt.className = `mode-${mode.toLowerCase().replaceAll("_", "-")}`;
    applyWidgetLayout();
    setText("terminalModeBadge", ({PDA: "PDA · CAMPO", DRIVER_SAFE: "CONDUCCIÓN SEGURA", VEHICLE_FULL: "TERMINAL VEHICULAR"})[mode]);
    document.querySelectorAll(".page").forEach((page) => page.classList.remove("active"));
    if (mode === "DRIVER_SAFE") {
        renderOperationalWidgets();
        diagnoseTerminalDom();
        return;
    }

    const moduleId = terminalState.activeModule;
    const targetPage = moduleId === "HOME" ? "dashboard" : (moduleId === "CASES" ? "cases" : "people");
    document.querySelector(`[data-page-content="${targetPage}"]`).classList.add("active");
    const module = terminalState.modules.find((item) => item.id === moduleId);
    pageTitle.textContent = module?.label || "Inicio";
    renderHome(snapshot);
    renderHistory(snapshot.cases?.history || []);
    if (targetPage === "people") renderGeneric(moduleId, snapshot);
    renderOperationalWidgets();
    diagnoseTerminalDom();
    bindTerminalActions();
}

function diagnoseTerminalDom() {
    const mode = terminalState.mode;

    if (diagnosedDomModes.has(mode)) return;
    diagnosedDomModes.add(mode);

    requestAnimationFrame(() => {
        [
            "TerminalWidget",
            "HUDWidget",
            "AlertWidget",
            "UnitWidget",
            "DispatchWidget",
            "SpeedWidget",
            "HintWidget"
        ].forEach((widgetId) => {
            const widget = document.getElementById(widgetId);

            if (!widget) {
                console.log(`[PoliceOS DOM] ${widgetId} exists=false`);
                return;
            }

            const computed = getComputedStyle(widget);
            const rect = widget.getBoundingClientRect();
            const dock = widget.parentElement?.dataset?.dock
                || (widget.classList.contains("free-widget") ? "FREE" : "ROOT");
            const hasData = widget.textContent.trim().length > 0
                && !widget.classList.contains("context-hidden");

            console.log(
                `[PoliceOS DOM] ${widgetId} exists=true display=${computed.display}`
                + ` visibility=${computed.visibility}`
                + ` ${Math.round(rect.width)}x${Math.round(rect.height)}`
                + ` dock=${dock} hasData=${hasData}`
            );
        });
    });
}

function bindTerminalActions() {
    document.querySelectorAll("[data-terminal-action]").forEach((button) => {
        button.onclick = async () => {
            const response = await postNui("terminal:action", {
                actionId: button.dataset.terminalAction,
                payload: {assignmentId: button.dataset.assignmentId || null}
            });
            const result = await response.json();
            if (!result.ok) button.dataset.error = result.error || "No disponible";
        };
    });

    document.querySelectorAll("[data-open-module]").forEach((button) => {
        button.onclick = async () => {
            const moduleId = button.dataset.openModule;
            const response = await postNui(
                "terminal:openModule",
                {moduleId}
            );
            const result = await response.json();

            if (result.ok) {
                terminalState.activeModule = moduleId;
                renderModules();
                renderTerminal();
            }
        };
    });
}

function mergeTerminalUpdate(domain, data) {
    if (domain === "context" || domain === "mode") {
        const previousMode = terminalState.mode;
        terminalState.mode = data.mode || terminalState.mode;
        terminalState.activeModule = data.activeModule || terminalState.activeModule;
        Object.assign(terminalState.snapshot, data);
        if (data.modules) terminalState.modules = data.modules;
        if (data.widgetLayout) terminalState.widgetLayout = data.widgetLayout;

        if (previousMode !== terminalState.mode) {
            renderModules();
            renderTerminal();
            return;
        }

        renderSpeedWidget();
        renderUnitWidget();
        renderDispatchWidget();
        renderHintWidget();
        renderDashboardIfChanged();
        return;
    } else if (domain === "alerts") {
        Object.assign(terminalState.snapshot, data);
        renderAlertWidget();
        renderDashboardIfChanged();
        return;
    } else if (domain === "navigation") {
        terminalState.activeModule = data.activeModule || "HOME";
    } else if (domain === "home") {
        terminalState.snapshot = data;
        terminalState.widgetLayout = data.widgetLayout || terminalState.widgetLayout;
    } else {
        terminalState.snapshot[domain] = data;

        if (domain === "vehicle") renderUnitWidget();
        if (domain === "dispatch") {
            renderDispatchWidget();
            if (terminalState.activeModule === "CAD"
                && terminalState.mode !== "DRIVER_SAFE") {
                renderGeneric("CAD", terminalState.snapshot);
                bindTerminalActions();
            }
        }
        if (domain === "cases") renderHistory(data.history || []);
        renderDashboardIfChanged();
        return;
    }
    renderModules();
    renderTerminal();
}

function setCharacterError(message = "") {
    characterError.textContent = message;
    characterError.classList.toggle("hidden", !message);
}

function getSelectedValue(name) {
    return characterForm.querySelector(`input[name="${name}"]:checked`)?.value || "";
}

function updatePoliceGarage(data = {}) {
    const vehicles = Array.isArray(data.vehicles) ? data.vehicles : [];
    const selectedIndex = Math.max(0, Math.min(vehicles.length - 1, (Number(data.selectedIndex) || 1) - 1));
    const firstVisible = Math.max(0, Math.min(selectedIndex - 2, vehicles.length - 6));
    garageStation.textContent = data.station || "Sin estación";
    garageCurrentUnit.textContent = data.currentUnit || "Ninguna";
    garageVehicleList.innerHTML = vehicles.slice(firstVisible, firstVisible + 6).map((vehicle, index) => {
        const selected = firstVisible + index === selectedIndex;
        return `<article class="garage-vehicle${selected ? " selected" : ""}"><div class="garage-selection-marker"></div>
            <div class="garage-vehicle-main"><strong>${escapeHtml(vehicle.label)}</strong><span>Modelo: ${escapeHtml(vehicle.model)}</span></div>
            <div class="garage-vehicle-meta"><span>TIPO</span><strong>${escapeHtml(vehicle.role)}</strong></div>
            <div class="garage-vehicle-meta"><span>CAPACIDAD DE CUSTODIA</span><strong>${Number(vehicle.transportCapacity) || 0}</strong></div></article>`;
    }).join("");
    garageNextUnlock.textContent = data.nextUnlock ? `Próximo desbloqueo: ${data.nextUnlock}` : "";
    garageNextUnlock.classList.toggle("hidden", !data.nextUnlock);
}

function editorModePreferences() {
    return widgetEditorState.preferences?.modes?.[widgetEditorState.mode] || {};
}

function ensureEditorElements() {
    if (!document.getElementById("HUDWidget")) {
        const hud = document.createElement("section");
        hud.id = "HUDWidget";
        hud.className = "os-widget hud-widget editor-only";
        hud.innerHTML = `<header>${iconSvg("unit")}<span>HUD</span></header><strong>OFICIAL · RANGO</strong><p>CALLSIGN · ACTIVE</p>`;
        document.getElementById("terminalDockRoot").appendChild(hud);
    }

    if (!document.getElementById("widgetEditorPanel")) {
        const panel = document.createElement("aside");
        panel.id = "widgetEditorPanel";
        panel.className = "widget-editor-panel";
        mdt.appendChild(panel);
    }

    if (!document.getElementById("widgetAlignmentGuides")) {
        const guides = document.createElement("div");
        guides.id = "widgetAlignmentGuides";
        guides.innerHTML = '<i data-guide="vertical"></i><i data-guide="horizontal"></i>';
        mdt.appendChild(guides);
    }
}

function hideAlignmentGuides() {
    document.querySelectorAll("#widgetAlignmentGuides i").forEach((guide) => {
        guide.classList.remove("visible");
    });
}

function showAlignmentGuide(axis, position) {
    const guide = document.querySelector(`#widgetAlignmentGuides [data-guide="${axis}"]`);
    if (!guide) return;
    guide.style[axis === "vertical" ? "left" : "top"] = `${position}px`;
    guide.classList.add("visible");
}

function getEditorPeers(widget) {
    return [...document.querySelectorAll(".editor-widget")].filter((peer) =>
        peer !== widget
        && !peer.classList.contains("editor-disabled")
        && getComputedStyle(peer).display !== "none"
    );
}

function overlapRatio(left, right) {
    const overlapWidth = Math.max(0, Math.min(left.right, right.right) - Math.max(left.left, right.left));
    const overlapHeight = Math.max(0, Math.min(left.bottom, right.bottom) - Math.max(left.top, right.top));
    const smallestArea = Math.min(left.width * left.height, right.width * right.height);
    return smallestArea > 0 ? overlapWidth * overlapHeight / smallestArea : 0;
}

function resolveFreeSnap(widget, left, top) {
    const tolerance = 10;
    const rect = widget.getBoundingClientRect();
    const width = rect.width;
    const height = rect.height;
    const marginX = window.innerWidth * 0.01;
    const marginY = window.innerHeight * 0.01;
    const xCandidates = [
        {value: marginX, guide: marginX},
        {value: window.innerWidth - marginX - width, guide: window.innerWidth - marginX}
    ];
    const yCandidates = [
        {value: marginY, guide: marginY},
        {value: window.innerHeight - marginY - height, guide: window.innerHeight - marginY}
    ];

    getEditorPeers(widget).forEach((peer) => {
        const peerRect = peer.getBoundingClientRect();
        xCandidates.push(
            {value: peerRect.left, guide: peerRect.left},
            {value: peerRect.right, guide: peerRect.right},
            {value: peerRect.left + peerRect.width / 2 - width / 2, guide: peerRect.left + peerRect.width / 2},
            {value: peerRect.left - width - 8, guide: peerRect.left - 4},
            {value: peerRect.right + 8, guide: peerRect.right + 4}
        );
        yCandidates.push(
            {value: peerRect.top, guide: peerRect.top},
            {value: peerRect.bottom, guide: peerRect.bottom},
            {value: peerRect.top + peerRect.height / 2 - height / 2, guide: peerRect.top + peerRect.height / 2},
            {value: peerRect.top - height - 8, guide: peerRect.top - 4},
            {value: peerRect.bottom + 8, guide: peerRect.bottom + 4}
        );
    });

    hideAlignmentGuides();
    const snapX = xCandidates.reduce((best, candidate) =>
        Math.abs(candidate.value - left) < Math.abs(best.value - left) ? candidate : best,
        {value: left + tolerance + 1, guide: null}
    );
    const snapY = yCandidates.reduce((best, candidate) =>
        Math.abs(candidate.value - top) < Math.abs(best.value - top) ? candidate : best,
        {value: top + tolerance + 1, guide: null}
    );

    if (Math.abs(snapX.value - left) <= tolerance) {
        left = snapX.value;
        showAlignmentGuide("vertical", snapX.guide);
    }
    if (Math.abs(snapY.value - top) <= tolerance) {
        top = snapY.value;
        showAlignmentGuide("horizontal", snapY.guide);
    }
    return {left, top};
}

function updateLayoutConflict(widget) {
    const rect = widget.getBoundingClientRect();
    const conflict = getEditorPeers(widget).some((peer) =>
        overlapRatio(rect, peer.getBoundingClientRect()) > 0.15
    );
    widget.classList.toggle("layout-conflict", conflict);
    return conflict;
}

function separateFreeOverlap(widget, config) {
    let rect = widget.getBoundingClientRect();
    const peer = getEditorPeers(widget).find((candidate) =>
        overlapRatio(rect, candidate.getBoundingClientRect()) > 0.15
    );
    if (!peer) return;

    const other = peer.getBoundingClientRect();
    const moveLeft = other.left - rect.right - 8;
    const moveRight = other.right - rect.left + 8;
    const moveUp = other.top - rect.bottom - 8;
    const moveDown = other.bottom - rect.top + 8;
    const options = [
        {axis: "x", delta: moveLeft}, {axis: "x", delta: moveRight},
        {axis: "y", delta: moveUp}, {axis: "y", delta: moveDown}
    ].sort((a, b) => Math.abs(a.delta) - Math.abs(b.delta));
    const selected = options[0];
    let left = rect.left + (selected.axis === "x" ? selected.delta : 0);
    let top = rect.top + (selected.axis === "y" ? selected.delta : 0);
    left = Math.max(window.innerWidth * 0.01, Math.min(window.innerWidth * 0.99 - rect.width, left));
    top = Math.max(window.innerHeight * 0.01, Math.min(window.innerHeight * 0.99 - rect.height, top));
    config.x = left / window.innerWidth * 100;
    config.y = top / window.innerHeight * 100;
    positionWidget(widget, config, true);
}

function snapWidget(widgetId, anchor) {
    const config = editorModePreferences()[widgetId];
    const points = {
        TOP_LEFT: [2, 3], TOP: [50, 3], TOP_RIGHT: [98, 3],
        RIGHT: [98, 50], BOTTOM_RIGHT: [98, 97],
        BOTTOM: [50, 97], BOTTOM_LEFT: [2, 97], LEFT: [2, 50]
    };
    config.anchor = anchor;

    if (points[anchor]) {
        [config.x, config.y] = points[anchor];
    }
}

function renderEditorPanel() {
    const panel = document.getElementById("widgetEditorPanel");
    const preferences = widgetEditorState.preferences;
    const modePreferences = editorModePreferences();
    const anchors = ["FREE", "TOP_LEFT", "TOP", "TOP_RIGHT", "RIGHT", "BOTTOM_RIGHT", "BOTTOM", "BOTTOM_LEFT", "LEFT"];

    panel.innerHTML = `
        <header><div><span>POLICE OS CONFIG</span><strong>Widget Layout Editor</strong></div><small>${escapeHtml(widgetEditorState.mode)}</small></header>
        <label class="editor-field"><span>PRESET</span><select id="editorPreset">${Object.keys(widgetEditorState.presets).map((preset) => `<option ${preferences.preset === preset ? "selected" : ""}>${preset}</option>`).join("")}</select></label>
        <label class="editor-field"><span>ESCALA UI</span><select id="editorUiScale">${[0.8, 0.9, 1, 1.1, 1.25].map((scale) => `<option value="${scale}" ${Number(preferences.uiScale) === scale ? "selected" : ""}>${Math.round(scale * 100)}%</option>`).join("")}</select></label>
        <section class="editor-widget-list">${widgetEditorState.editableWidgets.map((widgetId) => {
            const config = modePreferences[widgetId];
            return `<article data-editor-row="${widgetId}"><label title="${widgetId}"><input type="checkbox" data-widget-visible="${widgetId}" ${config.visible ? "checked" : ""}><span>${widgetId.replace("Widget", "")}</span></label>
                <select data-widget-anchor="${widgetId}">${anchors.map((anchor) => `<option ${config.anchor === anchor ? "selected" : ""}>${anchor}</option>`).join("")}</select></article>`;
        }).join("")}</section>
        <p>Arrastra widgets. Usa el tirador inferior para escalar.</p>
        <footer><button id="editorReset" class="secondary">RESTAURAR</button><button id="editorCancel" class="secondary">CANCELAR</button><button id="editorSave">GUARDAR</button></footer>`;

    panel.querySelector("#editorPreset").onchange = (event) => {
        preferences.preset = event.target.value;
        const preset = widgetEditorState.presets[preferences.preset] || {};
        widgetEditorState.editableWidgets.forEach((widgetId) => {
            const previous = cloneData(modePreferences[widgetId]);
            modePreferences[widgetId].visible = preset[widgetId] !== false;
            logWidgetMutation("PRESET", widgetEditorState.mode, widgetId, previous, modePreferences[widgetId]);
        });
        renderEditorPanel();
        applyEditorWidgets();
    };
    panel.querySelector("#editorUiScale").onchange = (event) => {
        preferences.uiScale = Number(event.target.value);
        document.documentElement.style.setProperty("--police-ui-scale", preferences.uiScale);
    };
    panel.querySelectorAll("[data-widget-visible]").forEach((input) => {
        input.onchange = () => {
            const widgetId = input.dataset.widgetVisible;
            const previous = cloneData(modePreferences[widgetId]);
            modePreferences[widgetId].visible = input.checked;
            logWidgetMutation("VISIBILITY", widgetEditorState.mode, widgetId, previous, modePreferences[widgetId]);
            applyEditorWidgets();
        };
    });
    panel.querySelectorAll("[data-widget-anchor]").forEach((select) => {
        select.onchange = () => {
            const widgetId = select.dataset.widgetAnchor;
            const previous = cloneData(modePreferences[widgetId]);
            snapWidget(widgetId, select.value);
            logWidgetMutation("ANCHOR", widgetEditorState.mode, widgetId, previous, modePreferences[widgetId]);
            applyEditorWidgets();
        };
    });
    panel.querySelector("#editorCancel").onclick = () => postNui("widgetEditor:cancel");
    panel.querySelector("#editorSave").onclick = () => {
        captureFreeWidgetPositions();
        postNui("widgetEditor:save", {preferences});
    };
    panel.querySelector("#editorReset").onclick = async () => {
        const result = await (await postNui("widgetEditor:reset")).json();
        if (result.ok) {
            widgetEditorState.preferences = result.preferences;
            renderEditorPanel();
            applyEditorWidgets();
        }
    };
}

function captureFreeWidgetPositions() {
    const modePreferences = editorModePreferences();

    widgetEditorState.editableWidgets.forEach((widgetId) => {
        const widget = document.getElementById(widgetId);
        const config = modePreferences[widgetId];

        if (!widget || !config || config.anchor !== "FREE") return;
        constrainWidgetToViewport(widget);
        const rect = widget.getBoundingClientRect();
        config.x = rect.left / window.innerWidth * 100;
        config.y = rect.top / window.innerHeight * 100;
    });
}

function applyEditorWidgets() {
    const modePreferences = editorModePreferences();
    widgetEditorState.editableWidgets.forEach((widgetId) => {
        const widget = document.getElementById(widgetId);
        const config = modePreferences[widgetId];
        if (!widget || !config) return;
        widget.classList.remove("hidden", "context-hidden", "is-collapsed");
        widget.classList.add("editor-widget");
        positionWidget(widget, config, true);
        document.getElementById("terminalDockRoot").appendChild(widget);

        if (!widget.querySelector(".widget-resize")) {
            const handle = document.createElement("button");
            handle.className = "widget-resize";
            handle.type = "button";
            handle.title = "Arrastrar para escalar";
            widget.appendChild(handle);
        }
    });
}

function openWidgetEditor(message) {
    widgetEditorState.active = true;
    widgetEditorState.mode = message.mode || "PDA";
    widgetEditorState.preferences = cloneData(message.preferences);
    widgetEditorState.defaults = cloneData(message.defaults);
    widgetEditorState.presets = message.presets || {};
    widgetEditorState.editableWidgets = message.editableWidgets || [];
    terminalState.mode = widgetEditorState.mode;
    terminalState.snapshot = message.snapshot || {};
    const nativeHud = terminalState.snapshot.widgetLayout?.nativeHud || {};
    document.documentElement.style.setProperty(
        "--native-hud-width",
        `${Number(nativeHud.width || 0.165) * 100}vw`
    );
    document.documentElement.style.setProperty(
        "--native-hud-full-height",
        `${Number(nativeHud.fullHeight || 0.122) * 100}vh`
    );
    document.documentElement.style.setProperty(
        "--native-hud-minimal-height",
        `${Number(nativeHud.minimalHeight || 0.066) * 100}vh`
    );
    terminalState.widgetKeys = {};
    ensureEditorElements();
    mdt.className = `widget-editor-active mode-${terminalState.mode.toLowerCase().replaceAll("_", "-")}`;
    mdt.classList.remove("hidden");
    renderOperationalWidgets();
    renderEditorPanel();
    applyEditorWidgets();
}

function closeWidgetEditor() {
    widgetEditorState.active = false;
    widgetEditorState.drag = null;
    document.getElementById("widgetEditorPanel")?.remove();
    document.getElementById("HUDWidget")?.remove();
    document.getElementById("widgetAlignmentGuides")?.remove();
    document.querySelectorAll(".editor-widget").forEach((widget) => {
        widget.classList.remove("editor-widget", "editor-disabled");
        widget.querySelector(".widget-resize")?.remove();
    });
    mdt.classList.add("hidden");
}

window.addEventListener("pointerdown", (event) => {
    if (!widgetEditorState.active) return;
    const widget = event.target.closest(".editor-widget");
    if (!widget || event.target.closest("#widgetEditorPanel")) return;
    event.preventDefault();
    const config = editorModePreferences()[widget.id];
    widget.setPointerCapture?.(event.pointerId);
    widgetEditorState.drag = {
        widget,
        config,
        resize: event.target.classList.contains("widget-resize"),
        startX: event.clientX,
        startY: event.clientY,
        startScale: config.scale,
        startConfig: cloneData(config),
        grabX: event.clientX - widget.getBoundingClientRect().left,
        grabY: event.clientY - widget.getBoundingClientRect().top
    };
});

window.addEventListener("pointermove", (event) => {
    const drag = widgetEditorState.drag;
    if (!drag) return;
    if (drag.resize) {
        drag.config.scale = Math.max(0.6, Math.min(1.5, drag.startScale + (event.clientX - drag.startX) / 220));
    } else {
        drag.config.anchor = "FREE";
        const rect = drag.widget.getBoundingClientRect();
        const marginX = window.innerWidth * 0.01;
        const marginY = window.innerHeight * 0.01;
        let left = Math.max(
            marginX,
            Math.min(window.innerWidth - marginX - rect.width, event.clientX - drag.grabX)
        );
        let top = Math.max(
            marginY,
            Math.min(window.innerHeight - marginY - rect.height, event.clientY - drag.grabY)
        );
        const snapped = resolveFreeSnap(drag.widget, left, top);
        left = snapped.left;
        top = snapped.top;
        drag.config.x = left / window.innerWidth * 100;
        drag.config.y = top / window.innerHeight * 100;
    }
    positionWidget(drag.widget, drag.config, true);
    requestAnimationFrame(() => updateLayoutConflict(drag.widget));
});

window.addEventListener("pointerup", () => {
    if (!widgetEditorState.drag) return;
    const drag = widgetEditorState.drag;
    hideAlignmentGuides();
    if (!drag.resize && drag.config.anchor === "FREE") {
        separateFreeOverlap(drag.widget, drag.config);
    }
    logWidgetMutation(
        drag.resize ? "SCALE" : "DRAG",
        widgetEditorState.mode,
        drag.widget.id,
        drag.startConfig,
        drag.config
    );
    drag.widget.classList.remove("layout-conflict");
    captureFreeWidgetPositions();
    widgetEditorState.drag = null;
    renderEditorPanel();
});

ensureTerminalShell();

window.addEventListener("message", (event) => {
    const message = event.data || {};
    if (message.action === "sentinel:version") sentinelVersion.textContent = `Sentinel AI v${message.version}`;
    if (message.action === "terminal:open") {
        diagnosedDomModes.clear();
        terminalState.snapshot = message.data || {};
        terminalState.mode = message.mode || message.data?.mode || "PDA";
        terminalState.activeModule = message.data?.activeModule || "HOME";
        terminalState.modules = message.data?.modules || [];
        terminalState.widgetLayout = message.data?.widgetLayout || {};
        renderModules(); renderTerminal(); mdt.classList.remove("hidden");
    }
    if (message.action === "terminal:update") mergeTerminalUpdate(message.domain, message.data || {});
    if (message.action === "terminal:mode") mergeTerminalUpdate("mode", message.data || {});
    if (message.action === "terminal:modules") { terminalState.modules = message.data || []; renderModules(); }
    if (message.action === "terminal:alert") mergeTerminalUpdate("alerts", message.data || {});
    if (message.action === "terminal:close") mdt.classList.add("hidden");
    if (message.action === "widgetEditor:open") openWidgetEditor(message);
    if (message.action === "widgetEditor:close") closeWidgetEditor();
    if (message.action === "garage:open") { mdt.classList.add("hidden"); updatePoliceGarage(message.data); policeGarage.classList.remove("hidden"); }
    if (message.action === "garage:update") updatePoliceGarage(message.data);
    if (message.action === "garage:close") policeGarage.classList.add("hidden");
    if (message.action === "character:open") { mdt.classList.add("hidden"); characterCreator.classList.remove("hidden"); characterSubmit.disabled = false; characterSubmit.textContent = "Comenzar mi carrera"; setCharacterError(); }
    if (message.action === "character:close") { characterCreator.classList.add("hidden"); setCharacterError(); }
    if (message.action === "character:error") { characterSubmit.disabled = false; characterSubmit.textContent = "Comenzar mi carrera"; setCharacterError(message.message || "No fue posible guardar el personaje."); }
});

closeButton.addEventListener("click", () => postNui("closeMdt"));
characterForm.addEventListener("change", (event) => {
    if (event.target.name === "pronounType") customPronounsField.classList.toggle("hidden", event.target.value !== "custom");
    if (event.target.name === "bodyModel") postNui("character:previewBody", {bodyModel: event.target.value});
});
characterForm.addEventListener("submit", async (event) => {
    event.preventDefault(); setCharacterError();
    const payload = {
        firstName: document.getElementById("characterFirstName").value.trim(),
        lastName: document.getElementById("characterLastName").value.trim(),
        genderIdentity: getSelectedValue("genderIdentity"),
        pronounType: getSelectedValue("pronounType"),
        customPronouns: document.getElementById("customPronouns").value.trim(),
        bodyModel: getSelectedValue("bodyModel")
    };
    if (!payload.firstName || !payload.lastName) return setCharacterError("Escribe tu nombre y apellido.");
    if (!payload.genderIdentity || !payload.pronounType || !payload.bodyModel) return setCharacterError("Completa todas las selecciones.");
    if (payload.pronounType === "custom" && !payload.customPronouns) return setCharacterError("Escribe tus pronombres personalizados.");
    characterSubmit.disabled = true; characterSubmit.textContent = "Guardando...";
    try {
        const result = await (await postNui("character:create", payload)).json();
        if (!result.ok) throw new Error(result.error || "No fue posible crear el personaje.");
    } catch (error) {
        characterSubmit.disabled = false; characterSubmit.textContent = "Comenzar mi carrera"; setCharacterError(error.message);
    }
});

window.addEventListener("keydown", (event) => {
    if (!policeGarage.classList.contains("hidden")) { if (event.key === "Escape") event.preventDefault(); return; }
    if (!characterCreator.classList.contains("hidden")) { if (event.key === "Escape" || event.key === "F7") event.preventDefault(); return; }
    if (widgetEditorState.active && (event.key === "Escape" || event.key === "F7")) {
        event.preventDefault();
        postNui("widgetEditor:cancel");
        return;
    }
    if (event.key === "F7" && event.shiftKey && !mdt.classList.contains("hidden")) {
        event.preventDefault();
        postNui("widgetEditor:toggle");
        return;
    }
    if ((event.key === "Escape" || event.key === "F7") && !mdt.classList.contains("hidden")) { event.preventDefault(); postNui("closeMdt"); }
});

function runPoliceOsQaPreview() {
    const qaParameters = new URLSearchParams(location.search);
    const encodedSnapshot = qaParameters.get("qaSnapshot");

    if (!encodedSnapshot) return;

    try {
        if (qaParameters.get("qaColor") === "1") {
            const diagnosticStyle = document.createElement("style");
            diagnosticStyle.textContent = `
                .terminal-dock { background: rgba(255, 0, 255, .24) !important; }
                .terminal-dock-root { background: rgba(0, 255, 0, .12) !important; }
                .os-widget { background: rgba(0, 80, 255, .45) !important; }
                .os-widget::before { height: .35rem !important; background: rgba(255, 0, 0, .9) !important; opacity: 1 !important; }
            `;
            document.head.appendChild(diagnosticStyle);
        }

        const snapshot = JSON.parse(decodeURIComponent(encodedSnapshot));
        if (qaParameters.get("qaEditor") === "1" && snapshot.qaEditor) {
            window.dispatchEvent(new MessageEvent("message", {
                data: {
                    action: "widgetEditor:open",
                    mode: snapshot.mode,
                    snapshot,
                    preferences: snapshot.qaEditor.preferences,
                    defaults: snapshot.qaEditor.preferences,
                    editableWidgets: snapshot.qaEditor.editableWidgets,
                    presets: snapshot.qaEditor.presets
                }
            }));
        } else {
            window.dispatchEvent(new MessageEvent("message", {
                data: {action: "terminal:open", mode: snapshot.mode, data: snapshot}
            }));
        }

        setTimeout(() => {
            const ids = ["TerminalWidget", "HUDWidget", "AlertWidget", "UnitWidget", "DispatchWidget", "SpeedWidget", "HintWidget"];
            const visible = [];
            const widgets = {};

            ids.forEach((id) => {
                const element = document.getElementById(id);
                if (!element) { widgets[id] = {exists: false}; return; }
                const style = getComputedStyle(element);
                const pseudo = getComputedStyle(element, "::before");
                const parent = element.parentElement;
                const parentStyle = parent ? getComputedStyle(parent) : null;
                const parentRect = parent?.getBoundingClientRect();
                const rect = element.getBoundingClientRect();
                const shown = style.display !== "none"
                    && style.visibility !== "hidden"
                    && rect.width > 0
                    && rect.height > 0;
                widgets[id] = {
                    exists: true,
                    display: style.display,
                    left: rect.left,
                    top: rect.top,
                    right: rect.right,
                    bottom: rect.bottom,
                    width: rect.width,
                    height: rect.height,
                    shown,
                    contentWidth: element.scrollWidth,
                    contentHeight: element.scrollHeight,
                    computed: {
                        display: style.display,
                        position: style.position,
                        width: style.width,
                        minWidth: style.minWidth,
                        maxWidth: style.maxWidth,
                        height: style.height,
                        minHeight: style.minHeight,
                        maxHeight: style.maxHeight,
                        inset: style.inset,
                        top: style.top,
                        right: style.right,
                        bottom: style.bottom,
                        left: style.left,
                        flex: style.flex,
                        flexBasis: style.flexBasis,
                        alignSelf: style.alignSelf,
                        justifySelf: style.justifySelf,
                        overflow: style.overflow,
                        background: style.background,
                        backgroundColor: style.backgroundColor,
                        backgroundImage: style.backgroundImage,
                        boxShadow: style.boxShadow,
                        filter: style.filter,
                        backdropFilter: style.backdropFilter,
                        border: style.border,
                        padding: style.padding,
                        margin: style.margin,
                        transform: style.transform,
                        zoom: style.zoom,
                        opacity: style.opacity
                    },
                    pseudo: {
                        background: pseudo.background,
                        width: pseudo.width,
                        height: pseudo.height
                    },
                    parent: parent ? {
                        element: parent.id || parent.className || parent.tagName,
                        left: parentRect.left,
                        top: parentRect.top,
                        right: parentRect.right,
                        bottom: parentRect.bottom,
                        width: parentRect.width,
                        height: parentRect.height,
                        background: parentStyle.background,
                        backgroundColor: parentStyle.backgroundColor,
                        backgroundImage: parentStyle.backgroundImage
                    } : null
                };
                if (shown) visible.push({id, rect});
            });

            const overlaps = [];
            visible.forEach((left, index) => visible.slice(index + 1).forEach((right) => {
                const width = Math.max(0, Math.min(left.rect.right, right.rect.right) - Math.max(left.rect.left, right.rect.left));
                const height = Math.max(0, Math.min(left.rect.bottom, right.rect.bottom) - Math.max(left.rect.top, right.rect.top));
                if (width * height > 16) overlaps.push(`${left.id}/${right.id}`);
            }));
            const outside = visible.filter(({rect}) => rect.left < -1
                || rect.top < -1
                || rect.right > innerWidth + 1
                || rect.bottom > innerHeight + 1).map(({id}) => id);
            const docks = [...document.querySelectorAll(".terminal-dock-root, .terminal-dock")].map((element) => {
                const style = getComputedStyle(element);
                return {name: element.className, color: style.backgroundColor, image: style.backgroundImage};
            });
            const cadCards = [...document.querySelectorAll(".cad-assignment")];
            const result = {
                mode: terminalState.mode,
                widgets,
                overlaps,
                outside,
                docks,
                cad: {
                    count: cadCards.length,
                    unauthorized: cadCards.filter((card) => card.textContent.includes("NO AUTORIZADO")).length,
                    enabledAccept: cadCards.filter((card) => !card.querySelector('[data-terminal-action="dispatch.accept"]')?.disabled).length
                }
            };
            const output = document.createElement("pre");
            output.id = "police-os-qa-result";
            output.hidden = true;
            output.textContent = JSON.stringify(result);
            document.body.appendChild(output);
        }, 250);
    } catch (error) {
        console.error("[PoliceOS QA] Snapshot invalido", error);
    }
}

runPoliceOsQaPreview();
