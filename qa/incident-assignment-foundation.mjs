import assert from "node:assert/strict";
import {readFileSync} from "node:fs";

let incidentSequence = 0;
let assignmentSequence = 0;
const incidents = new Map();
const assignments = new Map();
const agencies = new Set(["POLICE", "EMS", "FIRE"]);

const clone = (value) => structuredClone(value);
const nextId = (prefix, sequence) => `${prefix}-20260808-${String(sequence).padStart(6, "0")}`;

function createIncident(data = {}) {
    const incident = {
        id: nextId("INC", ++incidentSequence),
        type: data.type || "GENERIC",
        category: data.category || data.type || "GENERAL",
        priority: data.priority || "NORMAL",
        status: "NEW",
        location: clone(data.location),
        source: data.source || "SYSTEM",
        metadata: clone(data.metadata || {}),
        assignments: []
    };
    incidents.set(incident.id, incident);
    return clone(incident);
}

function createAssignment(incidentId, data = {}) {
    assert(incidents.has(incidentId));
    assert(agencies.has(data.agency));
    const assignment = {
        id: nextId("ASN", ++assignmentSequence),
        incidentId,
        agency: data.agency,
        role: data.role || "PRIMARY_RESPONSE",
        priority: data.priority || "NORMAL",
        status: "PENDING",
        assignedUnit: null,
        metadata: clone(data.metadata || {})
    };
    assignments.set(assignment.id, assignment);
    incidents.get(incidentId).assignments.push(assignment.id);
    return clone(assignment);
}

const incident = createIncident({type: "ACCIDENT_MAJOR", location: {x: 1, y: 2, z: 3}});
assert.match(incident.id, /^INC-\d{8}-\d{6}$/); // A
assert.equal(incident.status, "NEW");

const police = createAssignment(incident.id, {agency: "POLICE", role: "SECURE_SCENE"});
assert.match(police.id, /^ASN-\d{8}-\d{6}$/); // B
assert.equal(police.incidentId, incident.id);

const storedPolice = assignments.get(police.id);
storedPolice.assignedUnit = {id: "VICTOR-82", callsign: "VICTOR-82", agency: "POLICE", operator: 1, status: "WAITING"};
storedPolice.status = "ASSIGNED";
assert.equal(storedPolice.status, "ASSIGNED"); // C
storedPolice.status = "ACTIVE";
assert.equal(storedPolice.status, "ACTIVE"); // D
storedPolice.status = "COMPLETED";
assert.equal(storedPolice.status, "COMPLETED"); // E
incidents.get(incident.id).status = "RESOLVED";
assert.equal(incidents.get(incident.id).status, "RESOLVED"); // F

assert.equal(incidents.get(incident.id).caseId, undefined); // G: Case opcional
const policeCase = {id: 7, incidentId: incident.id, assignmentId: police.id};
assert.equal(policeCase.incidentId, incident.id); // H

const multi = createIncident({type: "ACCIDENT_MAJOR"});
const multiAssignments = [
    createAssignment(multi.id, {agency: "POLICE", role: "SECURE_SCENE"}),
    createAssignment(multi.id, {agency: "EMS", role: "TREAT_VICTIMS"}),
    createAssignment(multi.id, {agency: "FIRE", role: "EXTRACTION"})
];
assert.deepEqual(multiAssignments.map((item) => item.agency), ["POLICE", "EMS", "FIRE"]); // I
assert.equal(multiAssignments.filter((item) => item.agency === "POLICE").length, 1);

const dispatchSource = readFileSync("resources/sentinel_core/client/managers/DispatchManager.lua", "utf8");
const dispatchServer = readFileSync("resources/sentinel_core/server/dispatch.lua", "utf8");
const missionSource = readFileSync("resources/sentinel_core/client/managers/MissionManager.lua", "utf8");
const caseSource = readFileSync("resources/sentinel_core/client/managers/CaseManager.lua", "utf8");
assert.match(dispatchServer, /local incidentId = nextId\("INC", incidentSequence\)/);
assert.match(dispatchServer, /local assignmentId = nextId\("ASN", assignmentSequence\)/);
assert.match(dispatchSource, /MissionManager\.StartMission/);
assert.match(missionSource, /MissionManager\.IncidentId = context\.incidentId/);
assert.match(missionSource, /MissionManager\.AssignmentId = context\.assignmentId/);
assert.match(caseSource, /incidentId = dispatch\.incidentId/);
assert.match(caseSource, /assignmentId = dispatch\.assignmentId/);

console.log("Incident/Assignment foundation fixtures A-I: PASS");
console.log("Legacy Dispatch/Mission/Case bridges: PASS");
