import assert from "node:assert/strict";
import test from "node:test";
import { dashboardFor, isPublicRegistrationRole } from "../lib/roles.ts";

test("each trusted role maps to its own dashboard", () => {
  assert.equal(dashboardFor("ADMIN"), "/admin");
  assert.equal(dashboardFor("TRAINER"), "/trainer");
  assert.equal(dashboardFor("USER"), "/user");
});

test("public registration permits only User and Trainer", () => {
  assert.equal(isPublicRegistrationRole("USER"), true);
  assert.equal(isPublicRegistrationRole("TRAINER"), true);
  assert.equal(isPublicRegistrationRole("ADMIN"), false);
  assert.equal(isPublicRegistrationRole("admin"), false);
  assert.equal(isPublicRegistrationRole("OWNER"), false);
});
