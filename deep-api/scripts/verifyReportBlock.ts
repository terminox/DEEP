// End-to-end proof of Report and Block on peace messages (Apple Guideline 1.2):
// the post filter, reports that hide a message, blocks that hide an author for
// the blocker only, isMine, keyset pagination under exclusions, the admin
// queue, and account deletion cascading through both new tables.
//
// Drives the real HTTP routes with fastify inject() against a THROWAWAY
// database, and refuses to run against anything not named *_verify / *_test.
//
//   createdb deep_verify
//   DATABASE_URL="postgresql://.../deep_verify" npx prisma migrate deploy
//   DATABASE_URL="postgresql://.../deep_verify" npm run verify:report-block
import assert from "node:assert/strict";
import crypto from "node:crypto";

const dbName = (process.env.DATABASE_URL ?? "").split("?")[0]?.split("/").pop() ?? "";
if (!/_(verify|test)$/.test(dbName)) {
  console.error(
    `Refusing to run against database "${dbName}": name must end in _verify or _test.`,
  );
  process.exit(1);
}

// env.ts parses process.env once at import, so pin the threshold first.
process.env.REPORT_HIDE_THRESHOLD = "3";

const { buildApp } = await import("../src/app.js");
const { prisma } = await import("../src/prisma.js");
const { hashPassword } = await import("../src/auth/password.js");

const pass = (msg: string) => console.log(`  ok  ${msg}`);
const json = (res: { body: string }) => JSON.parse(res.body);

type FeedMessage = { id: string; displayName: string; text: string; isMine: boolean };
type Headers = Record<string, string>;

async function main() {
  const app = buildApp();
  await app.ready();
  const tag = crypto.randomBytes(4).toString("hex");

  const signup = async (name: string) => {
    const res = await app.inject({
      method: "POST",
      url: "/auth/signup",
      payload: {
        email: `${name}-${tag}@deep.test`,
        password: "password123",
        displayName: `${name}-${tag}`,
      },
    });
    assert.equal(res.statusCode, 200, `signup ${name}`);
    const body = json(res);
    return { id: body.user.id as string, as: { authorization: `Bearer ${body.accessToken}` } };
  };
  const [alice, bob, carol, dave, erin] = await Promise.all(
    ["alice", "bob", "carol", "dave", "erin"].map(signup),
  );
  const anon: Headers = {};

  const get = (url: string, headers: Headers) => app.inject({ method: "GET", url, headers });
  const post = (url: string, headers: Headers, payload?: object) =>
    app.inject({ method: "POST", url, headers, ...(payload ? { payload } : {}) });
  const del = (url: string, headers: Headers) => app.inject({ method: "DELETE", url, headers });
  const postMessage = (who: Headers, text: string) => post("/pause/messages", who, { text });

  /** Every message the caller can see on /pause/messages, walking every page. */
  const wholeFeed = async (who: Headers, limit = 50) => {
    const pages: FeedMessage[][] = [];
    let cursor: string | null = null;
    do {
      const qs: string = `limit=${limit}${cursor ? `&cursor=${cursor}` : ""}`;
      const res = await get(`/pause/messages?${qs}`, who);
      assert.equal(res.statusCode, 200);
      const body = json(res);
      pages.push(body.messages);
      cursor = body.nextCursor;
    } while (cursor);
    return pages;
  };
  const feedIds = async (who: Headers) => new Set((await wholeFeed(who)).flat().map((m) => m.id));
  const liveIds = async (who: Headers) => {
    const res = await get("/pause/live", who);
    assert.equal(res.statusCode, 200);
    return new Set((json(res).messages as FeedMessage[]).map((m) => m.id));
  };
  /** Asserts visibility of `ids` on both feeds for one caller. */
  const sees = async (who: Headers, ids: string[], visible: boolean, label: string) => {
    const [feed, live] = await Promise.all([feedIds(who), liveIds(who)]);
    for (const id of ids) {
      assert.equal(feed.has(id), visible, `${label}: /pause/messages`);
      assert.equal(live.has(id), visible, `${label}: /pause/live`);
    }
  };

  // ---- 1. The filter refuses, and lets kind words through ----
  for (const text of ["fuck this", "what sh1t", "ไอ้สัตว์", "พวกมึงมันเหี้ย"]) {
    const res = await postMessage(alice.as, text);
    assert.equal(res.statusCode, 422, text);
    assert.equal(json(res).error.code, "message_rejected", text);
  }
  assert.equal(
    await prisma.peaceMessage.count({ where: { userId: alice.id } }),
    0,
    "a refused message is never stored, nor counted against the daily limit",
  );
  const kind = ["Greetings from Scunthorpe, peace to all", "แกงกะหรี่อร่อย ขอให้โลกสงบสุข", "Breathe"];
  const aliceIds: string[] = [];
  for (const text of kind) {
    const res = await postMessage(alice.as, text);
    assert.equal(res.statusCode, 200, text);
    const { message } = json(res);
    assert.equal(message.isMine, true, "the author's own post comes back isMine");
    assert.equal(message.text, text);
    aliceIds.push(message.id);
  }
  const [a1, a2, a3] = aliceIds as [string, string, string];
  const b1 = json(await postMessage(bob.as, "Calm night to everyone")).message.id as string;
  const c1 = json(await postMessage(carol.as, "Sending love")).message.id as string;
  pass("1. 422 message_rejected for EN/TH abuse; innocent EN/TH posts unchanged");

  // ---- 2. isMine, and per-caller caching headers ----
  const asAlice = (await wholeFeed(alice.as)).flat();
  assert.equal(asAlice.find((m) => m.id === a1)?.isMine, true);
  assert.equal(asAlice.find((m) => m.id === b1)?.isMine, false);
  assert.ok((await wholeFeed(anon)).flat().every((m) => m.isMine === false), "anonymous: never");
  const liveAsBob = json(await get("/pause/live", bob.as)).messages as FeedMessage[];
  assert.equal(liveAsBob.find((m) => m.id === b1)?.isMine, true);
  assert.equal(liveAsBob.find((m) => m.id === a1)?.isMine, false);
  for (const url of ["/pause/messages", "/pause/live"]) {
    const res = await get(url, anon);
    assert.equal(res.headers["cache-control"], "no-store", url);
    assert.match(String(res.headers.vary), /Authorization/, url);
  }
  pass("2. isMine is true only for the signed-in author; both feeds are no-store, Vary: Authorization");

  // ---- 3. Report: validation, ownership, idempotency, reporter-only hiding ----
  assert.equal((await post(`/pause/messages/${a1}/report`, anon, { reason: "spam" })).statusCode, 401);
  assert.equal((await post(`/pause/messages/${a1}/report`, bob.as, { reason: "rude" })).statusCode, 400);
  const own = await post(`/pause/messages/${b1}/report`, bob.as, { reason: "spam" });
  assert.equal(own.statusCode, 400);
  assert.equal(json(own).error.code, "own_message");
  const unknown = await post(`/pause/messages/${crypto.randomUUID()}/report`, bob.as, {
    reason: "spam",
  });
  assert.equal(unknown.statusCode, 404);

  for (const reason of ["offensive", "harassment"]) {
    const res = await post(`/pause/messages/${a1}/report`, bob.as, { reason });
    assert.equal(res.statusCode, 200);
    assert.deepEqual(json(res), { ok: true });
  }
  const bobsReports = await prisma.peaceMessageReport.findMany({ where: { messageId: a1 } });
  assert.equal(bobsReports.length, 1, "a repeat report changes nothing");
  assert.equal(bobsReports[0]!.reason, "OFFENSIVE", "the first reason stands");
  await sees(bob.as, [a1], false, "bob reported a1");
  await sees(erin.as, [a1], true, "erin did not");
  await sees(anon, [a1], true, "anonymous did not");
  pass("3. report: 401/400/own_message/404; idempotent; hidden at once for the reporter only");

  // ---- 4. Threshold: distinct reporters hide the message for everyone ----
  assert.equal((await post(`/pause/messages/${a1}/report`, carol.as, { reason: "spam" })).statusCode, 200);
  assert.equal((await prisma.peaceMessage.findUnique({ where: { id: a1 } }))!.status, "PUBLISHED");
  await sees(erin.as, [a1], true, "two reports: still up");
  assert.equal((await post(`/pause/messages/${a1}/report`, dave.as, { reason: "other" })).statusCode, 200);
  assert.equal((await prisma.peaceMessage.findUnique({ where: { id: a1 } }))!.status, "HIDDEN");
  await sees(erin.as, [a1], false, "three reports: hidden");
  await sees(anon, [a1], false, "three reports: hidden for anonymous");
  await sees(alice.as, [a1], false, "hidden for its author too");
  pass("4. the 3rd distinct reporter flips the message to HIDDEN for everyone");

  // ---- 5. Admin: reportCount and the Reported queue ----
  await prisma.user.create({
    data: {
      email: `admin-${tag}@deep.test`,
      passwordHash: await hashPassword("password123"),
      displayName: "Admin",
      role: "ADMIN",
    },
  });
  const adminToken = json(
    await post("/admin/auth/login", anon, { email: `admin-${tag}@deep.test`, password: "password123" }),
  ).accessToken;
  const asAdmin = { authorization: `Bearer ${adminToken}` };
  await post(`/pause/messages/${a2}/report`, dave.as, { reason: "spam" });
  const queue = json(await get("/admin/pause/messages?reported=true", asAdmin)).messages as {
    id: string;
    reportCount: number;
  }[];
  assert.ok(queue.every((m) => m.reportCount > 0), "the queue holds reported messages only");
  const counts = queue.map((m) => m.reportCount);
  assert.deepEqual(counts, [...counts].sort((x, y) => y - x), "most-reported first");
  assert.equal(queue.find((m) => m.id === a1)?.reportCount, 3);
  assert.equal(queue.find((m) => m.id === a2)?.reportCount, 1);
  assert.ok(!queue.some((m) => m.id === c1), "unreported messages stay out of the queue");
  const all = json(await get("/admin/pause/messages", asAdmin)).messages as {
    id: string;
    reportCount: number;
  }[];
  assert.equal(all.find((m) => m.id === c1)?.reportCount, 0);
  assert.equal((await get("/admin/pause/messages?reported=true", bob.as)).statusCode, 403);
  // Restoring is the existing PATCH; it brings the message back for everyone
  // who did not report it.
  await app.inject({
    method: "PATCH",
    url: `/admin/pause/messages/${a1}`,
    headers: asAdmin,
    payload: { status: "PUBLISHED" },
  });
  await sees(erin.as, [a1], true, "restored by an admin");
  await sees(bob.as, [a1], false, "but never back for someone who reported it");
  pass("5. admin list carries reportCount; reported=true is most-reported first; PATCH restores");

  // ---- 6. Block: hides every message by the author, for the blocker only ----
  const ownBlock = await post(`/pause/messages/${b1}/block-author`, bob.as);
  assert.equal(ownBlock.statusCode, 400);
  assert.equal(json(ownBlock).error.code, "own_message");
  assert.equal(
    (await post(`/pause/messages/${crypto.randomUUID()}/block-author`, bob.as)).statusCode,
    404,
  );
  assert.equal((await post(`/pause/messages/${a2}/block-author`, anon)).statusCode, 401);

  const blocked = await post(`/pause/messages/${a2}/block-author`, bob.as);
  assert.equal(blocked.statusCode, 200);
  const { block } = json(blocked);
  assert.deepEqual(Object.keys(block).sort(), ["createdAt", "displayName", "id"]);
  assert.equal(block.displayName, `alice-${tag}`);
  assert.ok(!blocked.body.includes(alice.id), "the author's userId never leaves the server");
  const again = json(await post(`/pause/messages/${a3}/block-author`, bob.as));
  assert.equal(again.block.id, block.id, "blocking again is the same block");
  assert.equal(await prisma.userBlock.count({ where: { blockerId: bob.id } }), 1);

  await sees(bob.as, [a2, a3], false, "bob blocked alice");
  await sees(bob.as, [c1, b1], true, "bob still sees everyone else");
  await sees(erin.as, [a2, a3], true, "erin did not block alice");
  await sees(anon, [a2, a3], true, "anonymous never blocks");

  const listed = json(await get("/me/blocks", bob.as)).blocks;
  assert.deepEqual(listed, [block]);
  assert.deepEqual(json(await get("/me/blocks", erin.as)).blocks, []);
  assert.equal((await get("/me/blocks", anon)).statusCode, 401);
  pass("6. block-author: own_message/404/401; idempotent; hides all the author's posts for the blocker only");

  // ---- 7. Unblock: scoped to the caller, idempotent ----
  const notHers = await del(`/me/blocks/${block.id}`, erin.as);
  assert.equal(notHers.statusCode, 200);
  assert.equal((json(await get("/me/blocks", bob.as)).blocks as unknown[]).length, 1, "erin can't unblock for bob");
  assert.deepEqual(json(await del(`/me/blocks/${block.id}`, bob.as)), { ok: true });
  assert.deepEqual(json(await get("/me/blocks", bob.as)).blocks, []);
  assert.equal((await del(`/me/blocks/${block.id}`, bob.as)).statusCode, 200, "repeat unblock");
  assert.equal((await del(`/me/blocks/not-a-real-id`, bob.as)).statusCode, 200);
  await sees(bob.as, [a2, a3], true, "unblocked");
  pass("7. DELETE /me/blocks/:id: never touches another member's block; idempotent; feed returns");

  // ---- 8. Pagination stays exact with exclusions ----
  // A dozen messages sharing one createdAt, so the cursor's id tie-break does
  // the work, interleaving a blocked author, a reported message and the rest.
  const at = new Date("2020-01-01T00:00:00.000Z");
  const fixtures = await Promise.all(
    Array.from({ length: 12 }, (_, i) =>
      prisma.peaceMessage.create({
        data: {
          userId: i % 3 === 0 ? alice.id : carol.id,
          displayName: "fixture",
          text: `fixture ${i}`,
          pauseDate: "2020-01-01",
          createdAt: at,
        },
      }),
    ),
  );
  const reportedFixture = fixtures.find((f) => f.userId === carol.id)!;
  await post(`/pause/messages/${reportedFixture.id}/report`, bob.as, { reason: "spam" });
  await post(`/pause/messages/${a2}/block-author`, bob.as);
  const expected = fixtures
    .filter((f) => f.userId === carol.id && f.id !== reportedFixture.id)
    .map((f) => f.id);
  for (const limit of [1, 2, 3, 5]) {
    const pages = await wholeFeed(bob.as, limit);
    const ids = pages.flat().map((m) => m.id);
    assert.equal(new Set(ids).size, ids.length, `limit ${limit}: no message twice`);
    assert.ok(pages.slice(0, -1).every((p) => p.length === limit), `limit ${limit}: pages stay full`);
    assert.ok(!fixtures.some((f) => f.userId === alice.id && ids.includes(f.id)), `limit ${limit}: blocked`);
    assert.ok(!ids.includes(reportedFixture.id), `limit ${limit}: reported`);
    const seen = ids.filter((id) => expected.includes(id));
    assert.deepEqual(seen, [...expected].sort().reverse(), `limit ${limit}: all the rest, in id order`);
  }
  pass("8. keyset pages under exclusions: full, ordered, no gaps, no repeats (limits 1/2/3/5)");

  // ---- 9. Blocking a deleted author ----
  const orphan = await prisma.peaceMessage.create({
    data: { userId: null, displayName: "Gone", text: "old words", pauseDate: "2020-01-01" },
  });
  assert.deepEqual(json(await post(`/pause/messages/${orphan.id}/block-author`, erin.as)), {
    ok: true,
    block: null,
  });
  // An unlinked message survives a block list that is non-empty (SQL NOT IN drops NULLs).
  assert.ok((await feedIds(bob.as)).has(orphan.id), "authorless messages stay visible to blockers");
  pass("9. block-author on a deleted author's message → { ok, block: null }; still visible to blockers");

  // ---- 10. Account deletion cascades through both tables ----
  assert.equal((await del("/me", alice.as)).statusCode, 200);
  assert.equal(await prisma.userBlock.count({ where: { blockedId: alice.id } }), 0, "blocks on her go");
  assert.deepEqual(json(await get("/me/blocks", bob.as)).blocks, []);
  assert.equal((await prisma.peaceMessage.findUnique({ where: { id: a1 } }))!.userId, null);
  assert.equal(await prisma.peaceMessageReport.count({ where: { messageId: a1 } }), 3, "reports on her messages stay");

  await post(`/pause/messages/${c1}/block-author`, bob.as);
  assert.equal((await del("/me", bob.as)).statusCode, 200);
  assert.equal(await prisma.peaceMessageReport.count({ where: { reporterId: bob.id } }), 0);
  assert.equal(await prisma.userBlock.count({ where: { blockerId: bob.id } }), 0);
  assert.equal(await prisma.peaceMessageReport.count({ where: { messageId: a1 } }), 2);
  pass("10. DELETE /me cascades reports and blocks on both sides; reports on survivors' posts stay");

  console.log("\nAll Report and Block checks passed.");
  await app.close();
  await prisma.$disconnect();
}

main().catch(async (e) => {
  console.error("\nFAILED:", e);
  await prisma.$disconnect();
  process.exit(1);
});
