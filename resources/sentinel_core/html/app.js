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
    snapshot: {}
};

const moduleDescriptions = {
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

    let safePanel = document.getElementById("driverSafePanel");
    if (!safePanel) {
        safePanel = document.createElement("section");
        safePanel.id = "driverSafePanel";
        safePanel.className = "driver-safe-panel hidden";
        document.querySelector(".workspace").insertBefore(
            safePanel,
            document.querySelector(".workspace-footer")
        );
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

    document.querySelectorAll(".os-widget").forEach((widget) => {
        const widgetConfig = layout[widget.id];
        widget.classList.toggle("hidden", !widgetConfig?.visible);

        if (!widgetConfig?.visible) return;

        const dock = document.querySelector(
            `[data-dock="${widgetConfig.dock}"]`
        );
        widget.dataset.size = widgetConfig.size || "COMPACT";
        widget.style.order = Number(widgetConfig.order) || 0;
        dock?.appendChild(widget);
    });
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
                    title="${escapeHtml(module.reason || "Disponible")}" type="button">
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
        `<button data-terminal-action="${escapeHtml(action.id)}" ${action.available ? "" : "disabled"}>${escapeHtml(action.label)}</button>`
    ).join("");
    const dutyAction = duty.onDuty ? "duty.stop" : "duty.start";
    const dutyLabel = duty.onDuty ? "FINALIZAR TURNO" : "INICIAR TURNO";
    homeExtras.innerHTML = `
        <article class="terminal-mini-card duty-card ${duty.onDuty ? "is-on-duty" : "is-off-duty"}">
            <span>ESTADO PROFESIONAL</span><strong>${duty.onDuty ? "EN SERVICIO" : "Fuera de servicio"}</strong>
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
            <button data-open-module="CAD" ${duty.onDuty ? "" : "disabled"}>CAD</button>
            <button data-open-module="MAP" ${duty.onDuty ? "" : "disabled"}>MAPA</button>
        </article>`;
}

function renderSafeMode(snapshot) {
    const panel = document.getElementById("driverSafePanel");
    const dispatch = snapshot.dispatch || {};
    const vehicle = snapshot.vehicle || {};
    const context = snapshot.context || {};
    const alert = snapshot.activeAlert || (snapshot.alerts || [])[0];
    const duty = snapshot.duty || {};
    const distance = dispatch.distance ? `${Math.round(dispatch.distance)} m` : "—";
    panel.innerHTML = `
        <header><div><span>DRIVER SAFE</span><strong>${escapeHtml(duty.callsign || "SIN CALLSIGN")}</strong></div><b>${Math.round(context.speedKmh || 0)}<small>km/h</small></b></header>
        <div class="safe-status"><span>ESTADO</span><strong>${escapeHtml(statusLabel(duty.dispatchState))}</strong></div>
        <article class="safe-alert priority-${escapeHtml((alert?.priority || "LOW").toLowerCase())}">
            <span>${alertIcon(alert?.type)} ALERTA PRIORITARIA</span><h3>${escapeHtml(alert?.title || "Sin alertas")}</h3>
            <p>${escapeHtml(alert?.message || "Sin novedades críticas.")}</p>
        </article>
        <article class="safe-dispatch"><span>CAD · ${escapeHtml(dispatch.lifecycle || "NONE")}</span>
            <h3>${escapeHtml(dispatch.title || "Sin despacho activo")}</h3>
            <dl><div><dt>CÓDIGO</dt><dd>${escapeHtml(dispatch.code || "—")}</dd></div><div><dt>DISTANCIA</dt><dd>${distance}</dd></div></dl>
        </article>
        <div class="safe-unit"><span>${iconSvg("unit")} ${escapeHtml(vehicle.label || "Sin unidad")}</span><strong>${escapeHtml(vehicle.state || "NONE")}</strong></div>
        <footer>
            ${dispatch.canAccept ? "<strong>Y · ACEPTAR LLAMADA</strong>" : ""}
            ${vehicle.assigned ? "<strong>/locateunit · GPS</strong>" : ""}
            <span>${context.fullModeAvailable ? "Vehículo detenido · F7 para terminal completo" : "F7 · CERRAR VISTA SEGURA"}</span>
        </footer>`;
}

function renderAlertWidget() {
    const widget = document.getElementById("AlertWidget");
    const snapshot = terminalState.snapshot;
    const alert = snapshot.activeAlert || (snapshot.alerts || [])[0];

    widget.className = `os-widget alert-widget priority-${String(alert?.priority || "LOW").toLowerCase()}`;
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
    widget.innerHTML = `
        <header>${iconSvg("unit")}<span>UNIDAD</span></header>
        <strong>${escapeHtml(duty.callsign || "SIN ASIGNAR")}</strong>
        <dl><div><dt>ESTADO</dt><dd>${escapeHtml(vehicle.state || "NONE")}</dd></div>
        <div><dt>MODELO</dt><dd>${escapeHtml(vehicle.label || "—")}</dd></div></dl>`;
}

function renderDispatchWidget() {
    const widget = document.getElementById("DispatchWidget");
    const dispatch = terminalState.snapshot.dispatch || {};
    widget.innerHTML = `
        <header>${iconSvg("cad")}<span>CAD · ${escapeHtml(dispatch.lifecycle || "NONE")}</span></header>
        <strong>${escapeHtml(dispatch.title || "Sin llamada activa")}</strong>
        <dl><div><dt>CÓDIGO</dt><dd>${escapeHtml(dispatch.code || "—")}</dd></div>
        <div><dt>DISTANCIA</dt><dd>${dispatch.distance ? `${Math.round(dispatch.distance)} m` : "—"}</dd></div></dl>
        ${dispatch.canAccept ? '<small>Y · ACEPTAR</small>' : ""}`;
}

function renderSpeedWidget() {
    const widget = document.getElementById("SpeedWidget");
    const speed = Math.round(terminalState.snapshot.context?.speedKmh || 0);
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
    widget.innerHTML = `<kbd>F7</kbd><span>${message}</span>`;
}

function renderOperationalWidgets() {
    renderAlertWidget();
    renderUnitWidget();
    renderDispatchWidget();
    renderSpeedWidget();
    renderHintWidget();
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
        placeholder.innerHTML += `<div class="unit-details"><strong>${escapeHtml(dispatch.title || "Sin llamada activa")}</strong>
            <span>Código: ${escapeHtml(dispatch.code || "—")}</span><span>Estado: ${escapeHtml(dispatch.lifecycle || "NONE")}</span>
            <span>Distancia: ${dispatch.distance ? `${Math.round(dispatch.distance)} m` : "—"}</span></div>
            <button data-terminal-action="dispatch.accept" ${dispatch.canAccept ? "" : "disabled"}>Aceptar llamada</button>
            <button disabled title="Disponible en Dispatch 2.0">Rechazar llamada</button>`;
    } else if (moduleId === "MAP") {
        const vehicle = snapshot.vehicle || {};
        placeholder.innerHTML += `<button data-terminal-action="vehicle.locate" ${vehicle.assigned ? "" : "disabled"}>Marcar unidad en GPS</button>`;
    }
}

function renderTerminal() {
    const snapshot = terminalState.snapshot;
    const mode = terminalState.mode;
    mdt.className = `mode-${mode.toLowerCase().replaceAll("_", "-")}`;
    setText("terminalModeBadge", ({PDA: "PDA · CAMPO", DRIVER_SAFE: "CONDUCCIÓN SEGURA", VEHICLE_FULL: "TERMINAL VEHICULAR"})[mode]);
    document.querySelectorAll(".page").forEach((page) => page.classList.remove("active"));
    const safePanel = document.getElementById("driverSafePanel");
    safePanel.classList.toggle("hidden", mode !== "DRIVER_SAFE");
    document.querySelector(".sidebar").classList.toggle("hidden", mode === "DRIVER_SAFE");
    closeButton.classList.toggle("hidden", mode === "DRIVER_SAFE");

    if (mode === "DRIVER_SAFE") {
        pageTitle.textContent = "Operación en movimiento";
        renderSafeMode(snapshot);
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
    bindTerminalActions();
}

function bindTerminalActions() {
    document.querySelectorAll("[data-terminal-action]").forEach((button) => {
        button.onclick = async () => {
            const response = await postNui("terminal:action", {actionId: button.dataset.terminalAction});
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
        terminalState.mode = data.mode || terminalState.mode;
        terminalState.activeModule = data.activeModule || terminalState.activeModule;
        Object.assign(terminalState.snapshot, data);
        if (data.modules) terminalState.modules = data.modules;
    } else if (domain === "alerts") {
        Object.assign(terminalState.snapshot, data);
    } else if (domain === "navigation") {
        terminalState.activeModule = data.activeModule || "HOME";
    } else if (domain === "home") {
        terminalState.snapshot = data;
    } else {
        terminalState.snapshot[domain] = data;
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

ensureTerminalShell();

window.addEventListener("message", (event) => {
    const message = event.data || {};
    if (message.action === "sentinel:version") sentinelVersion.textContent = `Sentinel AI v${message.version}`;
    if (message.action === "terminal:open") {
        terminalState.snapshot = message.data || {};
        terminalState.mode = message.mode || message.data?.mode || "PDA";
        terminalState.activeModule = message.data?.activeModule || "HOME";
        terminalState.modules = message.data?.modules || [];
        renderModules(); renderTerminal(); mdt.classList.remove("hidden");
    }
    if (message.action === "terminal:update") mergeTerminalUpdate(message.domain, message.data || {});
    if (message.action === "terminal:mode") mergeTerminalUpdate("mode", message.data || {});
    if (message.action === "terminal:modules") { terminalState.modules = message.data || []; renderModules(); }
    if (message.action === "terminal:alert") mergeTerminalUpdate("alerts", message.data || {});
    if (message.action === "terminal:close") mdt.classList.add("hidden");
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
    if ((event.key === "Escape" || event.key === "F7") && !mdt.classList.contains("hidden")) { event.preventDefault(); postNui("closeMdt"); }
});
