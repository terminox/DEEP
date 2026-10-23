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

  console.log("\nAll DEEP Premium content-lock checks passed.");
  await app.close();
  await prisma.$disconnect();
}

main().catch(async (e) => {
  console.error("\nFAILED:", e);
  await prisma.$disconnect();
  process.exit(1);
});
