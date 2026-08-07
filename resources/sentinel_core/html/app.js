const mdt = document.getElementById("mdt");
const closeButton = document.getElementById("closeButton");

const navigationButtons =
    document.querySelectorAll(".nav-button");

const pages =
    document.querySelectorAll("[data-page-content]");

const pageTitle = document.getElementById("pageTitle");

const rank = document.getElementById("rank");
const unit = document.getElementById("unit");
const xp = document.getElementById("xp");
const cases = document.getElementById("cases");

const status = document.getElementById("status");
const progress = document.getElementById("progress");
const statusBadge = document.getElementById("statusBadge");

const caseCode = document.getElementById("caseCode");
const caseTitle = document.getElementById("caseTitle");
const caseState = document.getElementById("caseState");
const activeCase = document.getElementById("activeCase");

const sidebarUnit = document.getElementById("sidebarUnit");
const sidebarStatus = document.getElementById("sidebarStatus");

const historyCount = document.getElementById("historyCount");
const caseHistoryList = document.getElementById("caseHistoryList");

const characterCreator =
    document.getElementById("characterCreator");
const characterForm =
    document.getElementById("characterForm");
const customPronounsField =
    document.getElementById("customPronounsField");
const characterError =
    document.getElementById("characterError");
const characterSubmit =
    document.getElementById("characterSubmit");

const pageTitles = {
    dashboard: "Dashboard",
    cases: "Historial de casos",
    people: "Personas",
    vehicles: "Vehículos",
    evidence: "Evidencias",
    ai: "Sentinel AI"
};

function postNui(endpoint, payload = {}) {
    return fetch(
        `https://${GetParentResourceName()}/${endpoint}`,
        {
            method: "POST",
            headers: {
                "Content-Type": "application/json"
            },
            body: JSON.stringify(payload)
        }
    );
}

function closeMdt() {
    postNui("closeMdt");
}

function setCharacterError(message = "") {
    characterError.textContent = message;
    characterError.classList.toggle("hidden", !message);
}

function getSelectedValue(name) {
    return characterForm.querySelector(
        `input[name="${name}"]:checked`
    )?.value || "";
}

function selectPage(pageName) {
    navigationButtons.forEach((button) => {
        button.classList.toggle(
            "active",
            button.dataset.page === pageName
        );
    });

    pages.forEach((page) => {
        page.classList.toggle(
            "active",
            page.dataset.pageContent === pageName
        );
    });

    pageTitle.textContent =
        pageTitles[pageName] || "Sentinel MDT";
}

function escapeHtml(value) {
    return String(value ?? "")
        .replaceAll("&", "&amp;")
        .replaceAll("<", "&lt;")
        .replaceAll(">", "&gt;")
        .replaceAll('"', "&quot;")
        .replaceAll("'", "&#039;");
}

function formatDuration(seconds) {
    const total = Number(seconds) || 0;
    const minutes = Math.floor(total / 60);
    const remainder = total % 60;

    return `${minutes}:${String(remainder).padStart(2, "0")}`;
}

function renderCaseHistory(rawHistory) {
    const history = Array.isArray(rawHistory)
        ? rawHistory
        : Object.values(rawHistory || {});

    if (!historyCount || !caseHistoryList) {
        return;
    }

    historyCount.textContent =
        `${history.length} caso${history.length === 1 ? "" : "s"}`;

    if (history.length === 0) {
        caseHistoryList.innerHTML = `
            <div class="empty-history">
                No hay casos archivados en esta sesión.
            </div>
        `;

        return;
    }

    caseHistoryList.innerHTML = history
        .map((caseData) => {
            const evidenceList =
                Array.isArray(caseData.evidence)
                    ? caseData.evidence
                    : Object.values(caseData.evidence || {});

            const evidence =
                evidenceList.length > 0
                    ? evidenceList.map(escapeHtml).join(", ")
                    : "Sin evidencia registrada";

            const id =
                String(caseData.id || 0).padStart(4, "0");

            return `
                <article class="case-history-item">
                    <div class="case-history-header">
                        <div>
                            <span>CASO #${id}</span>

                            <h4>
                                Código ${escapeHtml(caseData.code)}
                                · ${escapeHtml(caseData.title)}
                            </h4>
                        </div>

                        <strong>
                            +${Number(caseData.xp) || 0} XP
                        </strong>
                    </div>

                    <div class="case-history-details">
                        <p>
                            <b>Evidencia:</b> ${evidence}
                        </p>

                        <p>
                            <b>Duración:</b>
                            ${formatDuration(caseData.durationSeconds)}
                        </p>

                        <p>
                            <b>Cerrado:</b>
                            ${escapeHtml(caseData.completedAt || "Sin fecha")}
                        </p>
                    </div>
                </article>
            `;
        })
        .join("");
}

function updateMdt(data = {}) {
    rank.textContent = data.rank || "Cadete";
    unit.textContent = data.unit || "Sin asignar";
    xp.textContent = `${Number(data.xp) || 0} XP`;
    cases.textContent = Number(data.completedCases) || 0;

    status.textContent = data.status || "Sin estado";
    progress.textContent =
        `${Number(data.xp) || 0} XP acumulados`;

    statusBadge.textContent =
        data.status || "Sin estado";

    sidebarUnit.textContent =
        data.unit || "Sin asignar";

    sidebarStatus.textContent =
        data.status || "Sin estado";

    if (data.dispatch) {
        activeCase.classList.remove("empty");

        caseCode.textContent =
            `CÓDIGO ${data.dispatch.code}`;

        caseTitle.textContent =
            data.dispatch.title;

        caseState.textContent =
            data.status;
    } else {
        activeCase.classList.add("empty");

        caseCode.textContent = "SIN DESPACHO";
        caseTitle.textContent =
            "No hay un incidente activo";

        caseState.textContent =
            "Permanezca disponible para la central.";
    }

    renderCaseHistory(data.caseHistory);
}

window.addEventListener("message", (event) => {
    const message = event.data || {};

    if (message.action === "open") {
        updateMdt(message.data);
        selectPage("dashboard");
        mdt.classList.remove("hidden");
    }

    if (message.action === "update") {
        updateMdt(message.data);
    }

    if (message.action === "close") {
        mdt.classList.add("hidden");
    }

    if (message.action === "character:open") {
        mdt.classList.add("hidden");
        characterCreator.classList.remove("hidden");
        characterSubmit.disabled = false;
        characterSubmit.textContent = "Comenzar mi carrera";
        setCharacterError();
    }

    if (message.action === "character:close") {
        characterCreator.classList.add("hidden");
        setCharacterError();
    }

    if (message.action === "character:error") {
        characterSubmit.disabled = false;
        characterSubmit.textContent = "Comenzar mi carrera";
        setCharacterError(
            message.message || "No fue posible guardar el personaje."
        );
    }
});

navigationButtons.forEach((button) => {
    button.addEventListener("click", () => {
        selectPage(button.dataset.page);
    });
});

closeButton.addEventListener("click", closeMdt);

characterForm.addEventListener("change", (event) => {
    if (event.target.name === "pronounType") {
        const customSelected =
            event.target.value === "custom";

        customPronounsField.classList.toggle(
            "hidden",
            !customSelected
        );
    }

    if (event.target.name === "bodyModel") {
        postNui("character:previewBody", {
            bodyModel: event.target.value
        });
    }
});

characterForm.addEventListener("submit", async (event) => {
    event.preventDefault();
    setCharacterError();

    const payload = {
        firstName: document
            .getElementById("characterFirstName")
            .value.trim(),
        lastName: document
            .getElementById("characterLastName")
            .value.trim(),
        genderIdentity:
            getSelectedValue("genderIdentity"),
        pronounType:
            getSelectedValue("pronounType"),
        customPronouns: document
            .getElementById("customPronouns")
            .value.trim(),
        bodyModel:
            getSelectedValue("bodyModel")
    };

    if (!payload.firstName || !payload.lastName) {
        setCharacterError("Escribe tu nombre y apellido.");
        return;
    }

    if (!payload.genderIdentity
        || !payload.pronounType
        || !payload.bodyModel) {

        setCharacterError("Completa todas las selecciones.");
        return;
    }

    if (payload.pronounType === "custom"
        && !payload.customPronouns) {

        setCharacterError(
            "Escribe tus pronombres personalizados."
        );
        return;
    }

    characterSubmit.disabled = true;
    characterSubmit.textContent = "Guardando...";

    try {
        const response = await postNui(
            "character:create",
            payload
        );
        const result = await response.json();

        if (!result.ok) {
            throw new Error(
                result.error || "No fue posible crear el personaje."
            );
        }
    } catch (error) {
        characterSubmit.disabled = false;
        characterSubmit.textContent = "Comenzar mi carrera";
        setCharacterError(error.message);
    }
});

window.addEventListener("keydown", (event) => {
    if (!characterCreator.classList.contains("hidden")) {
        if (event.key === "Escape" || event.key === "F7") {
            event.preventDefault();
        }

        return;
    }

    if (event.key === "Escape" || event.key === "F7") {
        event.preventDefault();
        closeMdt();
    }
});
