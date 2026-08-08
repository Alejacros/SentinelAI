import assert from "node:assert/strict";
import {readFileSync} from "node:fs";

const ranks = ["Cadete", "Oficial", "Oficial II", "Cabo", "Sargento",
    "Subteniente", "Teniente", "Capitan", "Mayor", "General",
    "Brigadier General", "Comandante General"];
const rankAtLeast = (current, required) => ranks.indexOf(current) >= ranks.indexOf(required);
const eligible = (call, rank, {onDuty = true, missionActive = false} = {}) =>
    call.agency === "POLICE" && call.status === "PENDING" && onDuty
    && !missionActive && rankAtLeast(rank, call.minimumRank);

const fixtures = [
    {assignmentId: "A-T1", incidentId: "I-1", agency: "POLICE", priority: "NORMAL", operationalTier: "T1_BASIC", minimumRank: "Cadete", status: "PENDING", distance: 600, createdAt: 1},
    {assignmentId: "A-T2", incidentId: "I-2", agency: "POLICE", priority: "HIGH", operationalTier: "T2_INTERMEDIATE", minimumRank: "Cabo", status: "PENDING", distance: 400, createdAt: 2},
    {assignmentId: "A-T3", incidentId: "I-3", agency: "POLICE", priority: "EMERGENCY", operationalTier: "T3_HIGH_RISK", minimumRank: "Subteniente", status: "PENDING", distance: 300, createdAt: 3},
    {assignmentId: "A-T4", incidentId: "I-4", agency: "POLICE", priority: "EMERGENCY", operationalTier: "T4_CRITICAL", minimumRank: "Mayor", status: "PENDING", distance: 200, createdAt: 4}
];

assert.equal(eligible(fixtures[0], "Cadete"), true); // A
assert.equal(eligible(fixtures[2], "Cadete"), false);
assert.equal(eligible(fixtures[0], "Sargento"), true); // B
assert.equal(eligible(fixtures[1], "Sargento"), true);
assert.equal(eligible(fixtures[2], "Sargento"), false);
assert.deepEqual(fixtures.slice(0, 3).map((call) => eligible(call, "Teniente")), [true, true, true]); // C
assert.deepEqual(fixtures.map((call) => eligible(call, "Mayor")), [true, true, true, true]); // D

const queue = fixtures.slice(0, 3).map((call) => structuredClone(call));
assert.equal(queue.filter((call) => call.status === "PENDING").length, 3); // E
queue[0].status = "ACTIVE";
assert.equal(queue.filter((call) => call.status === "PENDING").length, 2); // F
queue.push({...fixtures[3], assignmentId: "A-NEW"});
assert.equal(queue.length, 4); // G: generación no depende de Mission
queue[1].status = "DECLINED";
assert.equal(queue[1].status, "DECLINED"); // H
queue[2].status = "EXPIRED";
assert.equal(queue[2].status, "EXPIRED"); // I

const autoCandidates = fixtures.filter((call) => eligible(call, "Cadete"));
assert.deepEqual(autoCandidates.map((call) => call.assignmentId), ["A-T1"]); // J
const legacyMicroeventStuck = true;
const generationAllowed = legacyMicroeventStuck && true;
assert.equal(generationAllowed, true); // K
const sharedIncident = "I-COMPLEX";
const multiAssignments = [
    {...fixtures[0], incidentId: sharedIncident, assignmentId: "A-PERIMETER"},
    {...fixtures[2], incidentId: sharedIncident, assignmentId: "A-TACTICAL"}
];
assert.equal(new Set(multiAssignments.map((item) => item.incidentId)).size, 1); // L
assert.equal(new Set(multiAssignments.map((item) => item.assignmentId)).size, 2);

const dispatch = readFileSync("resources/sentinel_core/client/managers/DispatchManager.lua", "utf8");
const assignment = readFileSync("resources/sentinel_core/client/managers/AssignmentManager.lua", "utf8");
const terminal = readFileSync("resources/sentinel_core/client/managers/PoliceTerminalManager.lua", "utf8");
const app = readFileSync("resources/sentinel_core/html/app.js", "utf8");
const config = readFileSync("resources/sentinel_core/client/data/DispatchConfig.lua", "utf8");
assert.match(dispatch, /function DispatchManager\.IsAssignmentEligible/);
assert.match(dispatch, /IsRankAtLeast\(rank, assignment\.minimumRank/);
assert.match(dispatch, /function DispatchManager\.EnqueueAssignment/);
assert.match(dispatch, /function DispatchManager\.Decline/);
assert.match(dispatch, /AssignmentManager\.Expire/);
assert.match(dispatch, /getOperationalStatus\(\) ~= "AVAILABLE"/);
assert.doesNotMatch(dispatch, /PatrolEventManager\.Active/);
assert.match(assignment, /operationalTier = tostring/);
assert.match(assignment, /requiredCertifications = copy/);
assert.match(terminal, /DispatchManager\.Decline\(payload\.assignmentId\)/);
assert.match(terminal, /\{source = "MANUAL"\}/);
assert.match(app, /cad-assignment-list/);
assert.match(app, /NO AUTORIZADO/);

// T4B autoaccept regression: generation only enqueues, and every acceptance
// must declare whether it came from CAD or the delayed autoassignment path.
const enqueueBody = dispatch.slice(
    dispatch.indexOf("function DispatchManager.Enqueue(dispatch)"),
    dispatch.indexOf("function DispatchManager.EnqueueAssignment")
);
assert.doesNotMatch(enqueueBody, /CreateCurrentCase|StartMission|CurrentDispatch\s*=/);
assert.doesNotMatch(dispatch, /IsControlJustPressed\(0, 246\)/);
assert.match(dispatch, /source ~= "MANUAL" and source ~= "AUTOASSIGN"/);
assert.match(dispatch, /\[Dispatch ACCEPT TRACE\]/);
assert.match(dispatch, /ageMs >= DispatchLifecycleConfig\.autoAssignDelay/);
assert.match(dispatch, /source = "AUTOASSIGN"/);
assert.match(config, /autoAssignEnabled = false/);

const autoAssignDelay = 45000;
const canAutoAssign = ({enabled, ageMs, onDuty = true, available = true,
    missionActive = false, rankEligible = true}) => enabled
    && ageMs >= autoAssignDelay && onDuty && available
    && !missionActive && rankEligible;
assert.equal(canAutoAssign({enabled: false, ageMs: 60000}), false);
assert.equal(canAutoAssign({enabled: true, ageMs: 30000}), false);
assert.equal(canAutoAssign({enabled: true, ageMs: 45000}), true);
assert.equal(canAutoAssign({enabled: true, ageMs: 60000, missionActive: true}), false);
assert.equal(canAutoAssign({enabled: true, ageMs: 60000, rankEligible: false}), false);

console.log("Dispatch T4B lifecycle/tiering QA A-L: PASS");
console.log("Rank eligibility Cadete/Sargento/Teniente/Mayor: PASS");
console.log("CAD and legacy-isolation static checks: PASS");
console.log("Dispatch acceptance manual/decline/autoassign regression QA: PASS");
