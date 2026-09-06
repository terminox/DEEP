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
  //
  // The schedule is now a config (timezone + audio, shared) plus a list of
  // session times, one row each. Every rule below is a rule about the *set*,
  // which is why they are checked here end to end rather than field by field.
  const scheduleOf = async () =>
    json(await app.inject({ method: "GET", url: "/pause/schedule" }));
  const meditationStarts = (schedule: {
    upcoming: { meditationStartsAt: string }[];
  }) => schedule.upcoming.map((o) => o.meditationStartsAt);

  const slotsOf = async () => {
    const body = await json(
      await app.inject({ method: "GET", url: "/admin/pause/slots", headers: auth() }),
    );
    return body.slots as { id: string; meditationStart: string }[];
  };

  const beforeSchedule = await scheduleOf();
  assert.equal(beforeSchedule.phases.length, 4, "/pause/schedule resolves one occurrence");
  const liveSlots = await slotsOf();
  assert.equal(liveSlots.length, 1, "a fresh database has exactly one session");
  const eveningId = liveSlots[0]!.id;

  const addSlot = (payload: Record<string, unknown>) =>
    app.inject({
      method: "POST",
      url: "/admin/pause/slots",
      headers: auth(),
      payload,
    });

  const badTimes = await addSlot({
    lobbyStart: "22:00:00",
    welcomeStart: "21:00:00", // out of order
    meditationStart: "21:10:00",
    windowEnd: "21:30:00",
  });
  assert.equal(badTimes.statusCode, 400, "out-of-order phases still rejected");
  pass("6. out-of-order phase times are refused at save");

  // The meditation ends where its track does, so the window has to have room
  // for it. global-pause.mp3 is 132s; this window leaves 60.
  const overrun = await addSlot({
    lobbyStart: "19:00:00",
    welcomeStart: "19:09:50",
    meditationStart: "19:10:00",
    windowEnd: "19:11:00",
  });
  assert.equal(overrun.statusCode, 400, "a track longer than the window is refused");
  assert.match(JSON.parse(overrun.body).error?.code ?? "", /invalid_pause_schedule/);
  assert.equal(await prisma.contentDraft.count(), 0, "and nothing was staged");
  pass("6a. a session whose window cannot hold the track is refused, and stages nothing");

  // The live session runs 20:30-21:00; this one opens inside it.
  const overlapping = await addSlot({
    lobbyStart: "20:45:00",
    welcomeStart: "20:49:50",
    meditationStart: "20:50:00",
    windowEnd: "21:20:00",
  });
  assert.equal(overlapping.statusCode, 400, "an overlapping session is refused");
  assert.match(JSON.parse(overlapping.body).error?.message ?? "", /cannot overlap/);
  assert.equal(await prisma.contentDraft.count(), 0, "and nothing was staged");
  pass("6b. a session overlapping another is refused, and stages nothing");

  const added = await addSlot({
    lobbyStart: "08:00:00",
    welcomeStart: "08:09:50",
    meditationStart: "08:10:00",
    windowEnd: "09:00:00",
  });
  assert.equal(added.statusCode, 200, "a well-formed morning session stages");
  const morningId = JSON.parse(added.body).slot.id as string;

  const afterStage = await scheduleOf();
  assert.deepEqual(
    meditationStarts(afterStage),
    meditationStarts(beforeSchedule),
    "the app still sees only the published sessions while a new one is staged",
  );
  pass("6c. a staged session does not appear in the app's schedule");

  const slotChanges = await json(
    await app.inject({ method: "GET", url: "/admin/changes", headers: auth() }),
  );
  const staged = slotChanges.changes.find(
    (c: { entity: string }) => c.entity === "PAUSE_SLOT",
  );
  assert.ok(staged, "the new session is listed as a pending change");
  assert.match(staged.label, /08:10/, "and is labelled by the time it runs");

  await app.inject({
    method: "POST",
    url: "/admin/changes/publish",
    headers: auth(),
    payload: { refs: [`PAUSE_SLOT:${morningId}`] },
  });
  const afterPublish = await scheduleOf();
  assert.equal(
    afterPublish.upcoming.length,
    beforeSchedule.upcoming.length + 1,
    "publishing adds the session to the app's schedule",
  );
  assert.equal(
    afterPublish.nextMeditationStartsAt != null,
    true,
    "and the payload names the meditation after the resolved one",
  );
  pass("6d. publishing the session puts it on the app's schedule");

  // Deleting the last remaining session would leave the Global Pause with no
  // times at all, which is not a state the product has.
  await app.inject({
    method: "DELETE",
    url: `/admin/pause/slots/${morningId}`,
    headers: auth(),
  });
  const lastOne = await app.inject({
    method: "DELETE",
    url: `/admin/pause/slots/${eveningId}`,
    headers: auth(),
  });
  assert.equal(lastOne.statusCode, 400, "the last session cannot be removed");
  assert.match(JSON.parse(lastOne.body).error?.message ?? "", /at least one session/);
  pass("6e. the last session time cannot be deleted");

  // A longer track can overrun some sessions' windows and not others, so the
  // config write is judged against every session — including a staged one.
  await app.inject({
    method: "POST",
    url: "/admin/changes/discard",
    headers: auth(),
    payload: { refs: [`PAUSE_SLOT:${morningId}`] },
  });
  const tightSlot = await addSlot({
    lobbyStart: "06:00:00",
    welcomeStart: "06:09:50",
    meditationStart: "06:10:00",
    windowEnd: "06:13:00", // room for 180s
  });
  assert.equal(tightSlot.statusCode, 200, "a session with 3 minutes of room stages");
  const tightId = JSON.parse(tightSlot.body).slot.id as string;

  const longTrack = await app.inject({
    method: "PUT",
    url: "/admin/pause/config",
    headers: auth(),
    payload: {
      timezone: "Asia/Bangkok",
      lobbyAudioPath: "https://cdn.example.com/lobby.mp3",
      lobbyDurationSeconds: 262,
      meditationAudioPath: "https://cdn.example.com/nineteen-minutes.mp3",
      meditationDurationSeconds: 19 * 60,
    },
  });
  assert.equal(longTrack.statusCode, 400, "a track no session's window can hold is refused");
  assert.match(JSON.parse(longTrack.body).error?.message ?? "", /the 06:10 session/);
  pass("6f. a meditation track that overruns a session's window is refused, and names it");

  await app.inject({
    method: "POST",
    url: "/admin/changes/discard",
    headers: auth(),
    payload: { refs: [`PAUSE_SLOT:${tightId}`] },
  });

  // The case only the publish path can catch. Widening the evening window and
  // uploading a longer track are coherent *together*, so both stage happily —
  // the admin screen validates against everything staged, which is what it is
  // looking at. Publishing only one of them is a different set, and it is the
  // one the app would actually get.
  const widened = await app.inject({
    method: "PATCH",
    url: `/admin/pause/slots/${eveningId}`,
    headers: auth(),
    payload: { windowEnd: "21:30:00" },
  });
  assert.equal(widened.statusCode, 200, "widening the evening window stages");

  const longerTrack = await app.inject({
    method: "PUT",
    url: "/admin/pause/config",
    headers: auth(),
    payload: {
      timezone: "Asia/Bangkok",
      lobbyAudioPath: "https://cdn.example.com/lobby.mp3",
      lobbyDurationSeconds: 262,
      meditationAudioPath: "https://cdn.example.com/twenty-five.mp3",
      meditationDurationSeconds: 25 * 60,
    },
  });
  assert.equal(longerTrack.statusCode, 200, "a track that fits the widened window stages");

  const halfway = await json(
    await app.inject({
      method: "POST",
      url: "/admin/changes/validate",
      headers: auth(),
      payload: { refs: ["PAUSE_CONFIG:1"] },
    }),
  );
  assert.ok(
    halfway.blockers.some((b: string) => /the 20:40 session/.test(b)),
    "publishing the track without the window it needs is blocked",
  );
  const together = await json(
    await app.inject({
      method: "POST",
      url: "/admin/changes/validate",
      headers: auth(),
      payload: { refs: ["PAUSE_CONFIG:1", `PAUSE_SLOT:${eveningId}`] },
    }),
  );
  assert.deepEqual(together.blockers, [], "publishing both together is fine");
  pass("6g. publishing half a schedule change is blocked; publishing both is not");

  await app.inject({
    method: "POST",
    url: "/admin/changes/discard",
    headers: auth(),
    payload: { refs: ["PAUSE_CONFIG:1", `PAUSE_SLOT:${eveningId}`] },
  });

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

  // ---- 10. A saved sound follows the same visibility rule as the shelves ----
  // Playlists arrived in a separate branch, so this is the seam between the two:
  // hiding content has to reach the sounds a listener already kept, or a saved
  // row would keep offering a track that /sound/collections/:id and the
  // completion award both refuse.
  const keptCat = await prisma.soundCategory.create({
    data: { slug: "kept", title: "Kept", displayOrder: 1 },
  });
  const keptCol = await prisma.soundCollection.create({
    data: {
      categoryId: keptCat.id,
      title: "Kept collection",
      subtitle: "For the playlist check",
      palette: "tide",
      displayOrder: 0,
    },
  });
  const keptTrack = await prisma.soundTrack.create({
    data: {
      collectionId: keptCol.id,
      title: "Kept sound",
      durationSeconds: 120,
      audioPath: "/media/audio/global-pause.mp3",
      displayOrder: 0,
    },
  });

  const memberLogin = await json(
    await app.inject({
      method: "POST",
      url: "/auth/login",
      payload: { email: "member@deep.test", password: "password123" },
    }),
  );
  const member = { authorization: `Bearer ${memberLogin.accessToken}` };

  const lists = await json(
    await app.inject({ method: "GET", url: "/me/playlists", headers: member }),
  );
  const listId = lists.playlists[0].id;
  const saved = await json(
    await app.inject({
      method: "POST",
      url: `/me/playlists/${listId}/items`,
      headers: member,
      payload: { trackId: keptTrack.id },
    }),
  );
  assert.equal(saved.playlist.items.length, 1, "a visible sound can be kept");

  await app.inject({
    method: "PATCH",
    url: `/admin/collections/${keptCol.id}`,
    headers: auth(),
    payload: { isActive: false },
  });
  const whileStaged = await json(
    await app.inject({ method: "GET", url: "/me/playlists", headers: member }),
  );
  assert.equal(whileStaged.playlists[0].items.length, 1, "still kept while only staged");

  await app.inject({
    method: "POST",
    url: "/admin/changes/publish",
    headers: auth(),
    payload: { all: true },
  });
  const afterHide = await json(
    await app.inject({ method: "GET", url: "/me/playlists", headers: member }),
  );
  assert.equal(afterHide.playlists[0].items.length, 0, "hidden sound leaves the playlist");
  assert.equal(
    await prisma.playlistItem.count({ where: { trackId: keptTrack.id } }),
    1,
    "the kept row survives, so unhiding brings the sound back",
  );

  const reSave = await app.inject({
    method: "POST",
    url: `/me/playlists/${listId}/items`,
    headers: member,
    payload: { trackId: keptTrack.id },
  });
  assert.equal(reSave.statusCode, 404, "a hidden sound cannot be kept");
  pass("10. hiding content reaches saved playlists, without deleting what was kept");

  console.log("\nAll end-to-end checks passed.");
  await app.close();
  await prisma.$disconnect();
}

main().catch(async (e) => {
  console.error("\nFAILED:", e);
  await prisma.$disconnect();
  process.exit(1);
});
