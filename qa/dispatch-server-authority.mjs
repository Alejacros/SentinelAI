import assert from "node:assert/strict";
import {readFileSync} from "node:fs";

const ranks = ["Cadete", "Oficial", "Oficial II", "Cabo", "Sargento",
    "Subteniente", "Teniente", "Capitan", "Mayor", "General",
    "Brigadier General", "Comandante General"];
const rankAtLeast = (current, required) =>
    ranks.indexOf(current) >= ranks.indexOf(required);

class AuthorityFixture {
    incidents = new Map();
    assignments = new Map();
    active = new Map();
    create(minimumRank = "Cadete", expiresAt = 90000) {
        const incident = {id: "INC-20260808-000001", status: "NEW",
            assignments: ["ASN-20260808-000001"]};
        const assignment = {id: incident.assignments[0], incidentId: incident.id,
            agency: "POLICE", minimumRank, status: "PENDING", owner: null,
            expiresAt};
        this.incidents.set(incident.id, incident);
        this.assignments.set(assignment.id, assignment);
        return assignment;
    }
    accept(player, rank, id) {
        const assignment = this.assignments.get(id);
        if (!assignment) return "ASSIGNMENT_NOT_FOUND";
        if (assignment.status !== "PENDING") return "ALREADY_ASSIGNED";
        if (!rankAtLeast(rank, assignment.minimumRank)) return "RANK_REQUIRED";
        if (this.active.has(player)) return "MISSION_ACTIVE";
        assignment.status = "ASSIGNED";
        assignment.owner = player;
        this.active.set(player, id);
        return "ACCEPTED";
    }
    started(player, id) {
        const assignment = this.assignments.get(id);
        assert.equal(assignment.owner, player);
        assignment.status = "ACTIVE";
        this.incidents.get(assignment.incidentId).status = "ACTIVE";
    }
    complete(player, id) {
        const assignment = this.assignments.get(id);
        if (assignment.owner !== player) return "NOT_OWNER";
        assignment.status = "COMPLETED";
        this.active.delete(player);
        this.incidents.get(assignment.incidentId).status = "RESOLVED";
        return "COMPLETED";
    }
}

const authority = new AuthorityFixture();
const assignment = authority.create("Subteniente"); // A
assert.match(assignment.incidentId, /^INC-/);
assert.match(assignment.id, /^ASN-/);
const snapshot = structuredClone(assignment); // B
assert.notEqual(snapshot, assignment);
assert.equal(authority.accept(1, "Cadete", assignment.id), "RANK_REQUIRED"); // C
assert.equal(authority.accept(2, "Mayor", assignment.id), "ACCEPTED"); // D
assert.equal(authority.accept(3, "Mayor", assignment.id), "ALREADY_ASSIGNED"); // E
authority.started(2, assignment.id);
assert.equal(authority.complete(3, assignment.id), "NOT_OWNER"); // F
assert.equal(assignment.priority, undefined); // G: payload cannot mutate server model

const expiring = new AuthorityFixture();
const expired = expiring.create("Cadete", 100);
if (expired.expiresAt <= 100) expired.status = "EXPIRED";
assert.equal(expired.status, "EXPIRED"); // H
assert.equal(authority.complete(2, assignment.id), "COMPLETED"); // I
assert.equal(authority.incidents.get(assignment.incidentId).status, "RESOLVED");

const disconnected = new AuthorityFixture();
const owned = disconnected.create();
assert.equal(disconnected.accept(4, "Cadete", owned.id), "ACCEPTED");
owned.status = "CANCELLED";
disconnected.active.delete(4);
assert.equal(disconnected.active.has(4), false); // J

const server = readFileSync("resources/sentinel_core/server/dispatch.lua", "utf8");
const client = readFileSync("resources/sentinel_core/client/managers/DispatchManager.lua", "utf8");
const manifest = readFileSync("resources/sentinel_core/fxmanifest.lua", "utf8");
assert.match(server, /local function assignToPlayer/);
assert.match(server, /assignToPlayer\(sourceId, assignment, "MANUAL"\)/);
assert.match(server, /DispatchLifecycleConfig\.autoAssignEnabled == true/);
assert.match(server, /assignment\.owner ~= sourceId/);
assert.match(server, /GetSentinelProfileSnapshot/);
assert.match(server, /SentinelCareer\.IsRankAtLeast/);
assert.match(server, /playerDropped/);
assert.match(client, /sentinel:server:dispatch:missionStarted/);
assert.doesNotMatch(client, /IncidentManager\.Create\(/);
assert.match(manifest, /'server\/dispatch\.lua'/);

console.log("Dispatch T4C server authority QA A-J: PASS");
