// End-to-end proof of DEEP Premium content locks: premium audio URLs never
// leave the server for a non-member, while the catalogue stays fully visible.
//
// Drives the real HTTP routes with fastify inject() against a THROWAWAY
// database, and refuses to run against anything not named *_verify / *_test.
// Membership is flipped with the dev route (POST /dev/premium), the same lever
// QA uses on a simulator.
//
//   createdb deep_verify
//   DATABASE_URL="postgresql://.../deep_verify" npx prisma migrate deploy
//   DATABASE_URL="postgresql://.../deep_verify" npm run verify:premium
import assert from "node:assert/strict";
import crypto from "node:crypto";

const dbName = (process.env.DATABASE_URL ?? "").split("?")[0]?.split("/").pop() ?? "";
if (!/_(verify|test)$/.test(dbName)) {
  console.error(
    `Refusing to run against database "${dbName}": name must end in _verify or _test.`,
  );
  process.exit(1);
}

// env.ts parses process.env once at import, so configure before importing
// anything that reaches it. (Real env vars beat .env, which never overrides.)
process.env.ALLOW_DEV_ENTITLEMENT = "true";

const { buildApp } = await import("../src/app.js");
const { prisma } = await import("../src/prisma.js");
const { hashPassword } = await import("../src/auth/password.js");

const pass = (msg: string) => console.log(`  ok  ${msg}`);
const json = (res: { body: string }) => JSON.parse(res.body);

type Track = {
  id: string;
  title: string;
  durationSeconds: number;
  audioUrl: string | null;
  isPremium: boolean;
  isLocked: boolean;
  lyricsLanguages: string[];
};
type Collection = {
  id: string;
  title: string;
  imageUrl: string | null;
  isPremium: boolean;
  isLocked: boolean;
  trackCount: number;
  tracks?: Track[];
};
type Category = { id: string; collections?: Collection[] };

async function main() {
  const app = buildApp();
  await app.ready();
  const tag = crypto.randomBytes(4).toString("hex");

  // ---- Content fixtures (written live: the app reads live tables) ----
  //   free collection:    free track + a premium track (locked on its own)
  //   premium collection: two free tracks (locked by the collection)
  const category = await prisma.soundCategory.create({
    data: { slug: `premium-verify-${tag}`, title: "Premium verify" },
  });
  const freeCol = await prisma.soundCollection.create({
    data: {
      categoryId: category.id,
      title: "Open Field",
      subtitle: "Free to all",
      palette: "mist",
      imageUrl: "/media/uploads/images/open.jpg",
      displayOrder: 0,
    },
  });
  const premiumCol = await prisma.soundCollection.create({
    data: {
      categoryId: category.id,
      title: "Inner Garden",
      subtitle: "DEEP Premium",
      palette: "dusk",
      imageUrl: "/media/uploads/images/inner.jpg",
      isPremium: true,
      displayOrder: 1,
    },
  });
  const mkTrack = (collectionId: string, title: string, isPremium: boolean, order: number) =>
    prisma.soundTrack.create({
      data: {
        collectionId,
        title,
        durationSeconds: 300 + order,
        audioPath: `/media/audio/${tag}-${order}.mp3`,
        isPremium,
        displayOrder: order,
        kind: "GUIDED",
      },
    });
  const freeTrack = await mkTrack(freeCol.id, "Open Breath", false, 0);
  const premiumTrack = await mkTrack(freeCol.id, "Paid Breath", true, 1);
  const inheritA = await mkTrack(premiumCol.id, "Inner One", false, 2);
  const inheritB = await mkTrack(premiumCol.id, "Inner Two", false, 3);
  await prisma.trackLyrics.create({
    data: { trackId: inheritA.id, languageCode: "en", content: "Breathe in." },
  });
  const lockedIds = new Set([premiumTrack.id, inheritA.id, inheritB.id]);

  // ---- People: a non-member, a member, an admin ----
  const signup = async (name: string) => {
    const res = await app.inject({
      method: "POST",
      url: "/auth/signup",
      payload: { email: `${name}-${tag}@deep.test`, password: "password123", displayName: name },
    });
    assert.equal(res.statusCode, 200, `signup ${name}`);
    return json(res);
  };
  const nora = await signup("nora"); // never a member
  const mia = await signup("mia"); // becomes a member
  const asNora = { authorization: `Bearer ${nora.accessToken}` };
  const asMia = { authorization: `Bearer ${mia.accessToken}` };
  const setPremium = async (userId: string, active: boolean) => {
    const res = await app.inject({
      method: "POST",
      url: "/dev/premium",
      payload: { userId, active },
    });
    assert.equal(res.statusCode, 200, "dev premium flip");
    assert.equal(json(res).entitlement.active, active);
  };
  await setPremium(mia.user.id, true);

  await prisma.user.create({
    data: {
      email: `admin-${tag}@deep.test`,
      passwordHash: await hashPassword("password123"),
      displayName: "Admin",
      role: "ADMIN",
    },
  });
  const adminLogin = json(
    await app.inject({
      method: "POST",
      url: "/admin/auth/login",
      payload: { email: `admin-${tag}@deep.test`, password: "password123" },
    }),
  );
  const asAdmin = { authorization: `Bearer ${adminLogin.accessToken}` };

  const get = (url: string, headers: Record<string, string> = {}) =>
    app.inject({ method: "GET", url, headers });

  /** Our fixture's two collections out of a /sound/home body. */
  const shelf = (body: { categories: Category[] }) => {
    const cat = body.categories.find((c) => c.id === category.id);
    assert.ok(cat, "fixture category present");
    const byId = new Map(cat.collections!.map((c) => [c.id, c]));
    return { free: byId.get(freeCol.id)!, premium: byId.get(premiumCol.id)! };
  };
  const tracksOf = (...cols: Collection[]) => cols.flatMap((c) => c.tracks ?? []);

  /** Asserts the locked view: every locked track has no URL, every other has one. */
  const assertLockedView = (cols: Collection[], who: string) => {
    for (const t of tracksOf(...cols)) {
      if (lockedIds.has(t.id)) {
        assert.equal(t.audioUrl, null, `${who}: ${t.title} withheld`);
        assert.equal(t.isLocked, true, `${who}: ${t.title} locked`);
      } else {
        assert.ok(t.audioUrl, `${who}: ${t.title} playable`);
        assert.equal(t.isLocked, false, `${who}: ${t.title} open`);
      }
    }
  };
  const assertUnlockedView = (cols: Collection[], who: string) => {
    for (const t of tracksOf(...cols)) {
      assert.ok(t.audioUrl?.endsWith(".mp3"), `${who}: ${t.title} playable`);
      assert.equal(t.isLocked, false, `${who}: ${t.title} open`);
    }
    for (const c of cols) assert.equal(c.isLocked, false, `${who}: ${c.title} open`);
  };

  // ---- 1. Anonymous: catalogue visible, premium URLs withheld ----
  let res = await get("/sound/home");
  assert.equal(res.statusCode, 200);
  let s = shelf(json(res));
  assertLockedView([s.free, s.premium], "anonymous");
  assert.equal(s.premium.isLocked, true);
  assert.equal(s.premium.isPremium, true);
  assert.equal(s.free.isLocked, false);
  pass("1. anonymous /sound/home: premium audio withheld, isLocked set, free audio playable");

  // ---- 2. Locked content is still fully described ----
  assert.equal(s.premium.title, "Inner Garden");
  assert.ok(s.premium.imageUrl?.endsWith("/media/uploads/images/inner.jpg"), "artwork kept");
  assert.equal(s.premium.trackCount, 2);
  const lockedA = s.premium.tracks!.find((t) => t.id === inheritA.id)!;
  assert.equal(lockedA.title, "Inner One");
  assert.equal(lockedA.durationSeconds, 302);
  assert.deepEqual(lockedA.lyricsLanguages, ["en"]);
  assert.equal(lockedA.isPremium, false, "the track's own flag is unchanged");
  pass("2. locked content keeps title, artwork, duration, track count and lyric languages");

  // ---- 3. Inheritance both ways ----
  assert.deepEqual(
    s.premium.tracks!.map((t) => [t.isPremium, t.isLocked]),
    [
      [false, true],
      [false, true],
    ],
    "a premium collection locks its free tracks",
  );
  assert.deepEqual(
    s.free.tracks!.map((t) => [t.title, t.isLocked]),
    [
      ["Open Breath", false],
      ["Paid Breath", true],
    ],
    "a premium track in a free collection is locked alone",
  );
  pass("3. a premium collection locks its free tracks; a premium track in a free one locks alone");

  // ---- 4. Signed-in non-member: same locked view ----
  s = shelf(json(await get("/sound/home", asNora)));
  assertLockedView([s.free, s.premium], "non-member");
  const detail = json(await get(`/sound/collections/${premiumCol.id}`, asNora)).collection;
  assertLockedView([detail], "non-member detail");
  assert.equal(detail.isLocked, true);
  const anonDetail = json(await get(`/sound/collections/${freeCol.id}`)).collection;
  assertLockedView([anonDetail], "anonymous detail");
  pass("4. signed-in non-member (home + detail) and anonymous detail get the locked view");

  // ---- 5. Member: every URL ----
  s = shelf(json(await get("/sound/home", asMia)));
  assertUnlockedView([s.free, s.premium], "member");
  assertUnlockedView(
    [json(await get(`/sound/collections/${premiumCol.id}`, asMia)).collection],
    "member detail",
  );
  pass("5. a DEEP Premium member receives every audio URL (home + detail)");

  // ---- 6. A stale token 401s instead of silently downgrading ----
  res = await get("/sound/home", { authorization: "Bearer not-a-token" });
  assert.equal(res.statusCode, 401);
  res = await get(`/sound/collections/${freeCol.id}`, { authorization: "Bearer not-a-token" });
  assert.equal(res.statusCode, 401);
  pass("6. /sound/home and collection detail 401 a present-but-invalid token");

  // ---- 7. Admin sees every URL, whatever the admin's own standing ----
  const adminDetail = json(await get(`/admin/collections/${premiumCol.id}`, asAdmin)).collection;
  assertUnlockedView([adminDetail], "admin detail");
  const adminFree = json(await get(`/admin/collections/${freeCol.id}`, asAdmin)).collection;
  assertUnlockedView([adminFree], "admin free detail");
  const adminList = json(await get("/admin/collections", asAdmin)).collections as Collection[];
  assert.equal(adminList.find((c) => c.id === premiumCol.id)?.isLocked, false);
  const patched = json(
    await app.inject({
      method: "PATCH",
      url: `/admin/tracks/${premiumTrack.id}`,
      headers: asAdmin,
      payload: { title: "Paid Breath (edited)" },
    }),
  ).track;
  assert.ok(patched.audioUrl, "admin write echo carries the URL");
  await app.inject({ method: "POST", url: "/admin/changes/discard", headers: asAdmin, payload: { all: true } });
  pass("7. admin responses still carry every URL");

  // ---- 8. Global Pause home locks the same content ----
  const pause = json(await get("/pause/home"));
  const pauseCat = (pause.categories as Category[]).find((c) => c.id === category.id)!;
  assertLockedView(pauseCat.collections!, "anonymous pause");
  const pauseSections = (pause.sections as { collections: Collection[] }[]).flatMap((x) => x.collections);
  assertLockedView(pauseSections, "anonymous pause sections");
  const pauseMember = json(await get("/pause/home", asMia));
  assertUnlockedView(
    (pauseMember.categories as Category[]).find((c) => c.id === category.id)!.collections!,
    "member pause",
  );
  pass("8. /pause/home withholds premium URLs from non-members and serves them to members");

  // ---- 9. Listening to a locked track earns nothing ----
  const listen = (trackId: string, headers: Record<string, string>) =>
    app.inject({ method: "POST", url: "/me/sound/listens", headers, payload: { trackId } });
  for (const id of [premiumTrack.id, inheritA.id]) {
    res = await listen(id, asNora);
    assert.equal(res.statusCode, 403);
    assert.equal(json(res).error.code, "premium_locked");
  }
  assert.equal(
    await prisma.award.count({ where: { userId: nora.user.id, kind: "TRACK_COMPLETED" } }),
    0,
    "no award recorded",
  );
  res = await listen(freeTrack.id, asNora);
  assert.equal(res.statusCode, 200, "a free track still counts");
  assert.equal(json(res).award.granted, true);
  res = await listen(inheritA.id, asMia);
  assert.equal(res.statusCode, 200, "a member's premium listen counts");
  assert.equal(json(res).award.granted, true);
  pass("9. a listen for a locked track is refused with premium_locked and earns nothing");

  // ---- 10. Playlists: keep anything, play only what you may ----
  const playlists = json(await get("/me/playlists", asNora)).playlists;
  const playlistId: string = playlists[0].id;
  res = await app.inject({
    method: "POST",
    url: `/me/playlists/${playlistId}/items`,
    headers: asNora,
    payload: { trackId: inheritB.id },
  });
  assert.equal(res.statusCode, 200, "a non-member may keep a premium track");
  const kept = json(res).playlist.items[0];
  assert.equal(kept.track.id, inheritB.id);
  assert.equal(kept.track.audioUrl, null);
  assert.equal(kept.track.isLocked, true);
  assert.equal(kept.collection.isLocked, true);
  // Nora joins: the same saved row now plays.
  await setPremium(nora.user.id, true);
  const unlockedKept = json(await get("/me/playlists", asNora)).playlists[0].items[0];
  assert.ok(unlockedKept.track.audioUrl, "a member's kept premium track plays");
  assert.equal(unlockedKept.track.isLocked, false);
  await setPremium(nora.user.id, false);
  pass("10. a premium track can be kept by anyone; the playlist withholds its URL until membership");

  // ---- 11. Auth-varying responses are uncacheable and vary by Authorization ----
  for (const [url, headers] of [
    ["/sound/home", {}],
    ["/sound/home", asMia],
    [`/sound/collections/${premiumCol.id}`, {}],
    ["/pause/home", {}],
    ["/me/playlists", asNora],
  ] as const) {
    res = await get(url, { ...headers, origin: "http://localhost:5173" });
    assert.equal(res.statusCode, 200, url);
    assert.equal(res.headers["cache-control"], "no-store", `${url} cache-control`);
    const vary = String(res.headers.vary ?? "")
      .split(",")
      .map((v) => v.trim().toLowerCase());
    assert.ok(vary.includes("authorization"), `${url} varies by Authorization (${res.headers.vary})`);
    assert.ok(vary.includes("origin"), `${url} keeps the CORS Vary: Origin`);
  }
  pass("11. auth-varying responses send Cache-Control: no-store and Vary: Authorization");

  // ---- 12. Lyrics stay public ----
  res = await get(`/sound/tracks/${inheritA.id}/lyrics`);
  assert.equal(res.statusCode, 200);
  assert.equal(json(res).lyrics[0].content, "Breathe in.");
  pass("12. lyrics of a locked track stay public");

  // =========================================================================
  // Mind Garden: premium plants visible and locked (#30)
  // =========================================================================
  //
  // The premium plant is ALSO flagged isDefault and sorted FIRST, so any path
  // that forgot its free-only filter (starter, sunlight fallback, onboarding)
  // would pick it and fail loudly here.
  const mkPlant = (id: string, isPremium: boolean, isDefault: boolean, displayOrder: number) =>
    prisma.plant.create({
      data: {
        id,
        name: id,
        tagline: "verify",
        palette: "mist",
        isPremium,
        isDefault,
        displayOrder,
        stages: { create: [{ name: "Seed", displayOrder: 0, sunlightRequired: 0 }] },
      },
    });
  const lotus = await mkPlant(`v-lotus-${tag}`, true, true, -1);
  const oak = await mkPlant(`v-oak-${tag}`, false, true, 0);
  const fern = await mkPlant(`v-fern-${tag}`, false, false, 1);

  type PlantOut = { id: string; isPremium: boolean; isLocked: boolean };
  const plantsFor = async (headers: Record<string, string> = {}) => {
    const r = await get("/garden/plants", headers);
    assert.equal(r.statusCode, 200);
    const byId = new Map((json(r).plants as PlantOut[]).map((p) => [p.id, p]));
    return { lotus: byId.get(lotus.id), oak: byId.get(oak.id), fern: byId.get(fern.id), res: r };
  };
  const choose = (plantId: string, headers: Record<string, string>) =>
    app.inject({ method: "PUT", url: "/me/garden/plant", headers, payload: { plantId } });

  // ---- 13. Visible to everyone, locked for non-members ----
  let p = await plantsFor();
  assert.ok(p.lotus, "premium plant listed for anonymous");
  assert.equal(p.lotus.isPremium, true);
  assert.equal(p.lotus.isLocked, true);
  assert.equal(p.oak?.isLocked, false);
  assert.equal(p.res.headers["cache-control"], "no-store");
  assert.match(String(p.res.headers.vary), /authorization/i);
  p = await plantsFor(asNora);
  assert.equal(p.lotus?.isLocked, true, "non-member sees it locked");
  res = await get("/garden/plants", { authorization: "Bearer not-a-token" });
  assert.equal(res.statusCode, 401);
  pass("13. a premium plant is listed for everyone, isLocked for anonymous and non-members");

  // ---- 14. A non-member cannot select it ----
  res = await choose(lotus.id, asNora);
  assert.equal(res.statusCode, 403);
  assert.equal(json(res).error.code, "premium_locked");
  assert.equal(
    (await prisma.user.findUnique({ where: { id: nora.user.id } }))!.selectedPlantId,
    null,
    "selection unchanged",
  );
  assert.equal(
    await prisma.userPlantProgress.count({ where: { userId: nora.user.id, plantId: lotus.id } }),
    0,
    "no progress row minted by a refused selection",
  );
  pass("14. selecting a premium plant as a non-member is refused with premium_locked");

  // ---- 15. The starter, the sunlight fallback and onboarding stay free-only ----
  const sam = await signup("sam");
  const asSam = { authorization: `Bearer ${sam.accessToken}` };
  const samGarden = json(await get("/me/garden", asSam)).garden;
  assert.equal(samGarden.selectedPlant.id, oak.id, "starter skips the premium default");
  assert.equal(samGarden.selectedPlant.isLocked, false);

  await setPremium(sam.user.id, true);
  const lee = await signup("lee");
  await setPremium(lee.user.id, true);
  const asLee = { authorization: `Bearer ${lee.accessToken}` };
  res = await listen(freeTrack.id, asLee);
  assert.equal(json(res).award.plantId, oak.id, "sunlight fallback is free-only, even for a member");
  assert.equal(
    (await prisma.user.findUnique({ where: { id: lee.user.id } }))!.selectedPlantId,
    oak.id,
  );

  const config = json(await get("/onboarding/config"));
  const trees = (config.mindTrees as { id: string }[]).map((t) => t.id);
  assert.ok(trees.includes(oak.id));
  assert.ok(!trees.includes(lotus.id), "onboarding tree list stays free-only");
  const ola = await signup("ola");
  await setPremium(ola.user.id, true);
  res = await app.inject({
    method: "PUT",
    url: "/me/onboarding",
    headers: { authorization: `Bearer ${ola.accessToken}` },
    payload: { quizAnswers: {}, mindTree: lotus.id, completed: true },
  });
  assert.equal(res.statusCode, 200);
  assert.equal(
    (await prisma.user.findUnique({ where: { id: ola.user.id } }))!.selectedPlantId,
    null,
    "onboarding never seeds a premium plant",
  );
  pass("15. starter plant, sunlight fallback and onboarding stay free-only, member or not");

  // ---- 16. A member can select it and grow it ----
  p = await plantsFor(asMia);
  assert.equal(p.lotus?.isLocked, false, "a member sees it unlocked");
  res = await choose(lotus.id, asMia);
  assert.equal(res.statusCode, 200);
  let garden = json(res).garden;
  assert.equal(garden.selectedPlant.id, lotus.id);
  assert.equal(garden.selectedPlant.isLocked, false);
  res = await listen(premiumTrack.id, asMia);
  assert.equal(json(res).award.plantId, lotus.id, "sunlight lands on the premium plant");
  const grown = (await prisma.userPlantProgress.findUnique({
    where: { userId_plantId: { userId: mia.user.id, plantId: lotus.id } },
  }))!.sunlight;
  assert.ok(grown > 0);
  pass("16. a member selects the premium plant and it receives sunlight");

  // ---- 17. After a lapse the grown plant stays theirs ----
  await setPremium(mia.user.id, false);
  garden = json(await get("/me/garden", asMia)).garden;
  assert.equal(garden.selectedPlant.id, lotus.id, "keeps serving");
  assert.equal(garden.selectedPlant.isLocked, false, "never serializes as locked");
  assert.equal(garden.sunlight, grown);
  p = await plantsFor(asMia);
  assert.equal(p.lotus?.isLocked, false, "grandfathered in the picker");
  assert.equal((await plantsFor(asNora)).lotus?.isLocked, true, "still locked for others");
  res = await listen(freeTrack.id, asMia);
  assert.equal(json(res).award.plantId, lotus.id, "a lapsed member's premium plant still grows");

  res = await choose(fern.id, asMia);
  assert.equal(res.statusCode, 200, "switch away");
  assert.equal(json(res).garden.selectedPlant.id, fern.id);
  res = await choose(lotus.id, asMia);
  assert.equal(res.statusCode, 200, "and back, after the lapse");
  garden = json(res).garden;
  assert.equal(garden.selectedPlant.id, lotus.id);
  assert.equal(garden.sunlight, grown + 1, "sunlight preserved across the switch");
  pass("17. after a lapse the grown plant serves unlocked and can be switched away from and back to");

  // ---- 18. Grandfathering is per plant, not a blanket pass ----
  const lily = await mkPlant(`v-lily-${tag}`, true, false, 2);
  res = await choose(lily.id, asMia);
  assert.equal(res.statusCode, 403, "a lapsed member cannot pick a premium plant they never grew");
  assert.equal(json(res).error.code, "premium_locked");
  assert.equal((await plantsFor(asMia)).fern?.isLocked, false);
  const mixed = await plantsFor(asMia);
  assert.equal(mixed.lotus?.isLocked, false);
  assert.equal(
    (json(mixed.res).plants as PlantOut[]).find((x) => x.id === lily.id)?.isLocked,
    true,
  );
  pass("18. grandfathering covers only plants the person has grown");

  console.log("\nAll DEEP Premium content-lock checks passed.");
  await app.close();
  await prisma.$disconnect();
}

main().catch(async (e) => {
  console.error("\nFAILED:", e);
  await prisma.$disconnect();
  process.exit(1);
});
