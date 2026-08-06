const mdt = document.getElementById("mdt");
const closeButton = document.getElementById("closeButton");

const navigationButtons = document.querySelectorAll(".nav-button");
const pages = document.querySelectorAll("[data-page-content]");

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

const pageTitles = {
    dashboard: "Dashboard",
    cases: "Historial de casos",
    people: "Personas",
    vehicles: "Vehículos",
    evidence: "Evidencias",
    ai: "Sentinel AI"
};

function postNui(endpoint, payload = {}) {
    return fetch(`https://${GetParentResourceName()}/${endpoint}`, {
        method: "POST",
        headers: {
            "Content-Type": "application/json"
        },
        body: JSON.stringify(payload)
    });
}

function closeMdt() {
    postNui("closeMdt");
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
        pageTitles[pageName] ?? "Sentinel MDT";
}

function updateDashboard(data) {
    rank.textContent = data.rank;
    unit.textContent = data.unit;
    xp.textContent = `${data.xp} XP`;
    cases.textContent = data.completedCases;

    status.textContent = data.status;
    progress.textContent = `${data.xp} XP acumulados`;
    statusBadge.textContent = data.status;

    sidebarUnit.textContent = data.unit;
    sidebarStatus.textContent = data.status;

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

        caseCode.textContent =
            "SIN DESPACHO";

        caseTitle.textContent =
            "No hay un incidente activo";

        caseState.textContent =
            "Permanezca disponible para la central.";
    }
}

window.addEventListener("message", (event) => {
    const message = event.data;

    if (message.action === "open") {
        updateDashboard(message.data);
        selectPage("dashboard");
        mdt.classList.remove("hidden");
    }

    if (message.action === "update") {
        updateDashboard(message.data);
    }

    if (message.action === "close") {
        mdt.classList.add("hidden");
    }
});

navigationButtons.forEach((button) => {
    button.addEventListener("click", () => {
        selectPage(button.dataset.page);
    });
});

closeButton.addEventListener("click", closeMdt);

window.addEventListener("keydown", (event) => {
    if (event.key === "Escape" || event.key === "F7") {
        event.preventDefault();
        closeMdt();
    }
});