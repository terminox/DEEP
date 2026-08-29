// End-to-end proof that unpublished admin edits cannot reach the app.
//
// Drives the real HTTP routes with fastify inject() against a THROWAWAY
// database, so it exercises the actual wiring rather than the engine in
// isolation. It creates fixtures and publishes them, so it refuses to run
// against anything but a database named *_verify or *_test.
//
//   createdb deep_verify
//   DATABASE_URL="postgresql://.../deep_verify" npx prisma migrate deploy
//   DATABASE_URL="postgresql://.../deep_verify" npm run verify:safe-publish
import assert from "node:assert/strict";
import { buildApp } from "../src/app.js";
import { prisma } from "../src/prisma.js";
import { hashPassword } from "../src/auth/password.js";

// This script writes content and publishes it. Pointing it at deep_dev would
// quietly pollute real development data, so the name has to say it is scratch.
const dbName = (process.env.DATABASE_URL ?? "").split("?")[0]?.split("/").pop() ?? "";
if (!/_(verify|test)$/.test(dbName)) {
  console.error(
    `Refusing to run against database "${dbName}": name must end in _verify or _test.`,
  );
  process.exit(1);
}


const app = buildApp();
let token = "";

function auth() {
  return { authorization: `Bearer ${token}` };
}

const pass = (msg: string) => console.log(`  ok  ${msg}`);

async function json(res: { body: string }) {
  return JSON.parse(res.body);
}

async function main() {
  await app.ready();

  // ---- Fixtures ----
  await prisma.user.create({
    data: {
      email: "admin@deep.test",
      passwordHash: await hashPassword("password123"),
      displayName: "Admin",
      role: "ADMIN",
    },
  });

  const cat = await prisma.soundCategory.create({
    data: { slug: "calm", title: "Calm", displayOrder: 0 },
  });
  const col = await prisma.soundCollection.create({
    data: {
      categoryId: cat.id,
      title: "Rain",
      subtitle: "Soft rain",
      palette: "tide",
      displayOrder: 0,
    },
  });
  await prisma.soundTrack.create({
    data: {
      collectionId: col.id,
      title: "Light rain",
      durationSeconds: 300,
      audioPath: "/media/audio/global-pause.mp3",
      displayOrder: 0,
    },
  });
  await prisma.pauseConfig.create({ data: { id: 1 } });

  const login = await json(
    await app.inject({
      method: "POST",
      url: "/admin/auth/login",
      payload: { email: "admin@deep.test", password: "password123" },
    }),
  );
  token = login.accessToken;
  assert.ok(token, "admin logged in");
  pass("admin login");

  // ---- 1. Editing live content does not reach the app ----
  await app.inject({
    method: "PATCH",
    url: `/admin/collections/${col.id}`,
    headers: auth(),
    payload: { title: "Heavy rain" },
  });

  let home = await json(await app.inject({ method: "GET", url: "/sound/home" }));
  assert.equal(
    home.categories[0].collections[0].title,
    "Rain",
    "app must still see the published title",
  );
  pass("1. edit staged — /sound/home still shows the old title");

  let adminCols = await json(
    await app.inject({ method: "GET", url: "/admin/collections", headers: auth() }),
  );
  assert.equal(adminCols.collections[0].title, "Heavy rain", "admin sees the draft");
  assert.equal(adminCols.collections[0].pending.op, "UPDATE");
  assert.deepEqual(adminCols.collections[0].pending.changedFields, ["title"]);
  pass("1b. admin sees the edit with an Edited marker");

  // ---- 2. Publishing flips it ----
  const pub = await json(
    await app.inject({
      method: "POST",
      url: "/admin/changes/publish",
      headers: auth(),
      payload: { refs: [`SOUND_COLLECTION:${col.id}`] },
    }),
  );
  assert.equal(pub.published, 1);
  home = await json(await app.inject({ method: "GET", url: "/sound/home" }));
  assert.equal(home.categories[0].collections[0].title, "Heavy rain");
  assert.equal(await prisma.contentDraft.count(), 0, "draft consumed");
  pass("2. publish — /sound/home now shows the new title");

  // ---- 3. Editing back to the live value leaves no pending change ----
  await app.inject({
    method: "PATCH",
    url: `/admin/collections/${col.id}`,
    headers: auth(),
    payload: { title: "Storm" },
  });
  assert.equal(await prisma.contentDraft.count(), 1);
  await app.inject({
    method: "PATCH",
    url: `/admin/collections/${col.id}`,
    headers: auth(),
    payload: { title: "Heavy rain" },
  });
  assert.equal(await prisma.contentDraft.count(), 0, "reverted edit clears the draft");
  pass("3. edit-and-revert leaves no phantom pending change");

  // ---- 4. New tree publishes together, never half-live ----
  const newCat = await json(
    await app.inject({
      method: "POST",
      url: "/admin/categories",
      headers: auth(),
      payload: { slug: "sleep", title: "Sleep" },
    }),
  );
  const newCol = await json(
    await app.inject({
      method: "POST",
      url: "/admin/collections",
      headers: auth(),
      payload: {
        categoryId: newCat.category.id,
        title: "Night",
        subtitle: "For sleep",
        palette: "dusk",
      },
    }),
  );
  const newTrack = await json(
    await app.inject({
      method: "POST",
      url: "/admin/tracks",
      headers: auth(),
      payload: {
        collectionId: newCol.collection.id,
        title: "Deep night",
        durationSeconds: 600,
      },
    }),
  );

  home = await json(await app.inject({ method: "GET", url: "/sound/home" }));
  assert.equal(home.categories.length, 1, "unpublished category is invisible to the app");
  pass("4. new content is invisible to the app while staged");

  // Publish ONLY the track: its ancestors must be pulled in.
  const report = await json(
    await app.inject({
      method: "POST",
      url: "/admin/changes/validate",
      headers: auth(),
      payload: { refs: [`SOUND_TRACK:${newTrack.track.id}`] },
    }),
  );
  assert.equal(report.resolved.length, 3, "ancestor closure pulls in collection + category");
  assert.equal(report.addedByDependency.length, 2);
  assert.ok(
    report.warnings.some((w: string) => w.includes("no audio file")),
    "warns about the missing audio",
  );
  pass("4b. publishing a track pulls in its unpublished collection and category");

  await app.inject({
    method: "POST",
    url: "/admin/changes/publish",
    headers: auth(),
    payload: { refs: [`SOUND_TRACK:${newTrack.track.id}`] },
  });
  home = await json(await app.inject({ method: "GET", url: "/sound/home" }));
  const sleep = home.categories.find((c: { slug: string }) => c.slug === "sleep");
  assert.ok(sleep, "category is live");
  assert.equal(sleep.collections[0].title, "Night");
  assert.equal(sleep.collections[0].tracks[0].title, "Deep night");
  pass("4c. all three went live together, never half-published");

  // ---- 5. Delete is staged, with its cascade named ----
  await app.inject({
    method: "DELETE",
    url: `/admin/categories/${newCat.category.id}`,
    headers: auth(),
  });
  const changes = await json(
    await app.inject({ method: "GET", url: "/admin/changes", headers: auth() }),
  );
  const del = changes.changes.find((c: { op: string }) => c.op === "DELETE");
  assert.ok(del, "deletion is staged");
  assert.deepEqual(
    del.cascade,
    [
      { noun: "collection", count: 1 },
      { noun: "track", count: 1 },
    ],
    "cascade impact is shown before publishing",
  );

  home = await json(await app.inject({ method: "GET", url: "/sound/home" }));
  assert.equal(home.categories.length, 2, "app unaffected until the delete is published");
  pass("5. staged delete names its cascade and leaves the app untouched");

  await app.inject({
    method: "POST",
    url: "/admin/changes/publish",
    headers: auth(),
    payload: { refs: [del.key] },
  });
  home = await json(await app.inject({ method: "GET", url: "/sound/home" }));
  assert.equal(home.categories.length, 1, "delete applied on publish");
  pass("5b. published delete removes it");

  // ---- 6. Global Pause schedule ----
  const lobbyStartOf = (schedule: { phases: { key: string; startsAt: string }[] }) => {
    const lobby = schedule.phases.find((p) => p.key === "lobby");
    assert.ok(lobby, "/pause/schedule returns a lobby phase");
    return lobby.startsAt;
  };
  const beforeSchedule = await json(
    await app.inject({ method: "GET", url: "/pause/schedule" }),
  );
  const beforeLobby = lobbyStartOf(beforeSchedule);
  const badTimes = await app.inject({
    method: "PUT",
    url: "/admin/pause/config",
    headers: auth(),
    payload: {
      timezone: "Asia/Bangkok",
      lobbyStart: "22:00:00",
      welcomeStart: "21:00:00", // out of order
      meditationStart: "21:10:00",
      feedbackStart: "21:20:00",
      windowEnd: "21:30:00",
      lobbyAudioPath: "/media/audio/global-pause.mp3",
      meditationAudioPath: "/media/audio/global-pause.mp3",
      meditationDurationSeconds: 132,
    },
  });
  assert.equal(badTimes.statusCode, 400, "out-of-order phases still rejected");
  pass("6. out-of-order phase times are refused at save");

  await app.inject({
    method: "PUT",
    url: "/admin/pause/config",
    headers: auth(),
    payload: {
      timezone: "Asia/Bangkok",
      lobbyStart: "19:00:00",
      welcomeStart: "19:09:50",
      meditationStart: "19:10:00",
      feedbackStart: "19:12:12",
      windowEnd: "19:30:00",
      lobbyAudioPath: "/media/audio/global-pause.mp3",
      meditationAudioPath: "/media/audio/global-pause.mp3",
      meditationDurationSeconds: 132,
    },
  });
  const afterStage = await json(await app.inject({ method: "GET", url: "/pause/schedule" }));
  assert.equal(
    lobbyStartOf(afterStage),
    beforeLobby,
    "tonight's event is unchanged while the new schedule is staged",
  );
  pass("6b. a staged schedule does not move tonight's Global Pause");

  const cfgChanges = await json(
    await app.inject({ method: "GET", url: "/admin/changes", headers: auth() }),
  );
  const cfg = cfgChanges.changes.find((c: { entity: string }) => c.entity === "PAUSE_CONFIG");
  assert.ok(cfg, "schedule change is listed");
  assert.ok(
    cfg.fields.some((f: { field: string }) => f.field === "lobbyStart"),
    "diff names the changed phase",
  );
  await app.inject({
    method: "POST",
    url: "/admin/changes/publish",
    headers: auth(),
    payload: { refs: ["PAUSE_CONFIG:1"] },
  });
  const afterPublish = await json(await app.inject({ method: "GET", url: "/pause/schedule" }));
  assert.notEqual(lobbyStartOf(afterPublish), beforeLobby);
  pass("6c. publishing the schedule moves it");

  // ---- 7. Visibility: hide live content without deleting it ----
  await app.inject({
    method: "PATCH",
    url: `/admin/collections/${col.id}`,
    headers: auth(),
    payload: { isActive: false },
  });
  home = await json(await app.inject({ method: "GET", url: "/sound/home" }));
  assert.equal(home.categories[0].collections.length, 1, "still visible while staged");

  await app.inject({
    method: "POST",
    url: "/admin/changes/publish",
    headers: auth(),
    payload: { all: true },
  });
  home = await json(await app.inject({ method: "GET", url: "/sound/home" }));
  assert.equal(home.categories[0].collections.length, 0, "hidden after publish");

  const pauseHome = await json(await app.inject({ method: "GET", url: "/pause/home" }));
  const stillThere = JSON.stringify(pauseHome).includes("Heavy rain");
  assert.equal(stillThere, false, "hidden collection is gone from /pause/home shelves too");

  const direct = await app.inject({ method: "GET", url: `/sound/collections/${col.id}` });
  assert.equal(direct.statusCode, 404, "direct fetch of a hidden collection 404s");
  assert.equal(await prisma.soundCollection.count({ where: { id: col.id } }), 1, "row kept");
  pass("7. hide pulls content from /sound/home, /pause/home and direct fetch, row intact");

  // ---- 8. Peace-message moderation stays immediate ----
  const user = await prisma.user.create({
    data: {
      email: "member@deep.test",
      passwordHash: await hashPassword("password123"),
      displayName: "Member",
    },
  });
  const msg = await prisma.peaceMessage.create({
    data: { userId: user.id, displayName: "Member", text: "peace", pauseDate: "2026-08-29" },
  });
  await app.inject({
    method: "PATCH",
    url: `/admin/pause/messages/${msg.id}`,
    headers: auth(),
    payload: { status: "HIDDEN" },
  });
  const row = await prisma.peaceMessage.findUnique({ where: { id: msg.id } });
  assert.equal(row!.status, "HIDDEN", "moderation applied immediately");
  assert.equal(await prisma.contentDraft.count(), 0, "and staged nothing");
  pass("8. peace-message moderation is immediate, not staged");

  // ---- 9. Discarding a staged parent takes its staged children ----
  const dCat = await json(
    await app.inject({
      method: "POST",
      url: "/admin/categories",
      headers: auth(),
      payload: { slug: "focus", title: "Focus" },
    }),
  );
  await app.inject({
    method: "POST",
    url: "/admin/collections",
    headers: auth(),
    payload: {
      categoryId: dCat.category.id,
      title: "Flow",
      subtitle: "Focus music",
      palette: "mist",
    },
  });
  assert.equal(await prisma.contentDraft.count(), 2);
  await app.inject({
    method: "POST",
    url: "/admin/changes/discard",
    headers: auth(),
    payload: { refs: [`SOUND_CATEGORY:${dCat.category.id}`] },
  });
  assert.equal(await prisma.contentDraft.count(), 0, "child draft discarded with its parent");
  pass("9. discarding a staged parent discards its staged children");

  console.log("\nAll end-to-end checks passed.");
  await app.close();
  await prisma.$disconnect();
}

main().catch(async (e) => {
  console.error("\nFAILED:", e);
  await prisma.$disconnect();
  process.exit(1);
});
