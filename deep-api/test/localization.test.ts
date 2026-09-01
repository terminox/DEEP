import { test } from "node:test";
import assert from "node:assert/strict";
import { negotiateLanguage, requestLanguage } from "../src/lib/requestLanguage.js";
import {
  invalidateTranslations,
  seedTranslationCache,
  translate,
} from "../src/lib/translations.js";

// ---- Accept-Language negotiation -------------------------------------------

test("negotiateLanguage picks Thai from a plain header", () => {
  assert.equal(negotiateLanguage("th"), "th");
  assert.equal(negotiateLanguage("th-TH"), "th");
  assert.equal(negotiateLanguage("TH"), "th");
});

test("negotiateLanguage serves English for anything untranslated", () => {
  assert.equal(negotiateLanguage("en-US"), null);
  assert.equal(negotiateLanguage("ja,ko"), null);
  assert.equal(negotiateLanguage(undefined), null);
  assert.equal(negotiateLanguage(""), null);
});

test("negotiateLanguage honours quality ordering rather than header order", () => {
  // Thai is listed second but outranks English, so Thai wins.
  assert.equal(negotiateLanguage("en;q=0.5, th;q=0.9"), "th");
  // The reverse: English is preferred, so no translation is applied.
  assert.equal(negotiateLanguage("en;q=0.9, th;q=0.5"), null);
});

test("negotiateLanguage ignores languages the client has excluded", () => {
  // q=0 means "not acceptable".
  assert.equal(negotiateLanguage("th;q=0, en"), null);
});

test("negotiateLanguage degrades rather than throwing on a malformed header", () => {
  assert.equal(negotiateLanguage(";;;"), null);
  assert.equal(negotiateLanguage("th;q=banana"), "th");
});

test("a wildcard leaves the source language in place", () => {
  assert.equal(negotiateLanguage("*"), null);
});

// ---- Resolution and fallback -----------------------------------------------

test("translate returns the source text when no language is requested", () => {
  invalidateTranslations();
  seedTranslationCache("th", [
    { entity: "PLANT", entityId: "oak", fields: { name: "โอ๊ก" } },
  ]);
  requestLanguage.run(null, () => {
    assert.equal(translate("PLANT", "oak", "name", "Oak"), "Oak");
  });
});

test("translate returns the Thai text when one exists", () => {
  invalidateTranslations();
  seedTranslationCache("th", [
    { entity: "PLANT", entityId: "oak", fields: { name: "โอ๊ก" } },
  ]);
  requestLanguage.run("th", () => {
    assert.equal(translate("PLANT", "oak", "name", "Oak"), "โอ๊ก");
  });
});

test("an untranslated field falls back to English rather than rendering blank", () => {
  invalidateTranslations();
  seedTranslationCache("th", [
    // The name is translated; the tagline is not.
    { entity: "PLANT", entityId: "oak", fields: { name: "โอ๊ก" } },
  ]);
  requestLanguage.run("th", () => {
    assert.equal(translate("PLANT", "oak", "tagline", "Steady & Strong"), "Steady & Strong");
    assert.equal(translate("PLANT", "sakura", "name", "Sakura"), "Sakura");
  });
});

test("an empty translation is treated as missing, not as empty copy", () => {
  invalidateTranslations();
  seedTranslationCache("th", [
    { entity: "PLANT", entityId: "oak", fields: { name: "" } },
  ]);
  requestLanguage.run("th", () => {
    assert.equal(translate("PLANT", "oak", "name", "Oak"), "Oak");
  });
});

test("entities are keyed apart, so ids never collide across tables", () => {
  invalidateTranslations();
  seedTranslationCache("th", [
    { entity: "PLANT", entityId: "shared-id", fields: { name: "ต้นไม้" } },
    { entity: "SOUND_TRACK", entityId: "shared-id", fields: { title: "เพลง" } },
  ]);
  requestLanguage.run("th", () => {
    assert.equal(translate("PLANT", "shared-id", "name", "Plant"), "ต้นไม้");
    assert.equal(translate("SOUND_TRACK", "shared-id", "title", "Track"), "เพลง");
  });
});

test("invalidating the cache falls back to English until it reloads", () => {
  seedTranslationCache("th", [
    { entity: "PLANT", entityId: "oak", fields: { name: "โอ๊ก" } },
  ]);
  invalidateTranslations("th");
  requestLanguage.run("th", () => {
    assert.equal(translate("PLANT", "oak", "name", "Oak"), "Oak");
  });
});

test("a null source stays null rather than becoming a string", () => {
  invalidateTranslations();
  seedTranslationCache("th", []);
  requestLanguage.run("th", () => {
    assert.equal(translate("SOUND_COLLECTION", "c1", "subtitle", null), null);
  });
});
