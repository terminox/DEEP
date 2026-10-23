import { test } from "node:test";
import assert from "node:assert/strict";
import { activityDayKeys, type ActivityAwardRow } from "../src/lib/awardRules.js";

// The days outside DEEP Sessions that keep a streak alive.

function row(
  kind: ActivityAwardRow["kind"],
  dayKey: string,
  createdAt: string,
  timezone = "Asia/Bangkok",
): ActivityAwardRow {
  return { kind, dayKey, timezone, createdAt: new Date(createdAt) };
}

test("a finished track counts on its own (user-local) dayKey", () => {
  // Granted just after midnight for a listen that finished the evening before.
  assert.deepEqual(
    activityDayKeys([row("TRACK_COMPLETED", "2026-08-20", "2026-08-20T17:05:00Z")]),
    ["2026-08-20"],
  );
});

test("an attended pause counts on the local date it was granted", () => {
  // The 20:40 Bangkok pause is 09:40 in New York — the same calendar day
  // there, but its dayKey is Bangkok's pauseDate, which is not what counts.
  assert.deepEqual(
    activityDayKeys([
      row("PAUSE_ATTENDED", "2026-08-20", "2026-08-20T13:42:00Z", "America/New_York"),
    ]),
    ["2026-08-20"],
  );
  // A morning Bangkok pause (08:10, 01:10Z) is still the previous evening in
  // Los Angeles: the member practised on the 19th, their time.
  assert.deepEqual(
    activityDayKeys([
      row("PAUSE_ATTENDED", "2026-08-20", "2026-08-20T01:12:00Z", "America/Los_Angeles"),
    ]),
    ["2026-08-19"],
  );
});

test("days come back sorted and unique", () => {
  assert.deepEqual(
    activityDayKeys([
      row("TRACK_COMPLETED", "2026-08-21", "2026-08-21T03:00:00Z"),
      row("TRACK_COMPLETED", "2026-08-19", "2026-08-19T03:00:00Z"),
      row("TRACK_COMPLETED", "2026-08-21", "2026-08-21T04:00:00Z"),
      row("PAUSE_ATTENDED", "2026-08-21", "2026-08-21T13:42:00Z"),
    ]),
    ["2026-08-19", "2026-08-21"],
  );
});

test("other award kinds are not practice days here", () => {
  assert.deepEqual(
    activityDayKeys([
      row("SESSION_COMPLETED", "2026-08-20", "2026-08-20T03:00:00Z"),
      row("PEACE_MESSAGE", "2026-08-20", "2026-08-20T03:00:00Z"),
      row("DAILY_CHECKIN", "2026-08-20", "2026-08-20T03:00:00Z"),
    ]),
    [],
  );
});

test("an unresolvable row timezone falls back instead of throwing", () => {
  assert.deepEqual(
    activityDayKeys([row("PAUSE_ATTENDED", "2026-08-20", "2026-08-20T13:42:00Z", "Mars/Olympus")]),
    ["2026-08-20"],
  );
});

test("no rows, no days", () => {
  assert.deepEqual(activityDayKeys([]), []);
});
