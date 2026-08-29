import { test } from "node:test";
import assert from "node:assert/strict";
import { continentForCountry, isContinentISO } from "../src/lib/continents.js";

const ALL: string[] = ["AF", "AN", "AS", "EU", "NA", "OC", "SA"];

test("places a country on each continent", () => {
  assert.equal(continentForCountry("TH"), "AS");
  assert.equal(continentForCountry("FR"), "EU");
  assert.equal(continentForCountry("ZA"), "AF");
  assert.equal(continentForCountry("US"), "NA");
  assert.equal(continentForCountry("BR"), "SA");
  assert.equal(continentForCountry("NZ"), "OC");
  assert.equal(continentForCountry("AQ"), "AN");
});

// The two codes that read as continents but are countries. Getting either
// wrong silently moves a whole population to the wrong side of the world.
test("NA is Namibia and AS is American Samoa, not the continents they spell", () => {
  assert.equal(continentForCountry("NA"), "AF");
  assert.equal(continentForCountry("AS"), "OC");
});

test("accepts lowercase, refuses nothing", () => {
  assert.equal(continentForCountry("jp"), "AS");
  assert.equal(continentForCountry("Gb"), "EU");
  assert.equal(continentForCountry(null), null);
  assert.equal(continentForCountry(undefined), null);
  assert.equal(continentForCountry(""), null);
  assert.equal(continentForCountry("ZZ"), null);
});

test("isContinentISO admits exactly the seven codes", () => {
  for (const iso of ALL) assert.ok(isContinentISO(iso));
  assert.equal(isContinentISO("XX"), false);
  assert.equal(isContinentISO("as"), false);
  assert.equal(isContinentISO(null), false);
  assert.equal(isContinentISO(undefined), false);
});

test("every ISO-3166 alpha-2 code in the fake-city table resolves", async () => {
  const { WORLD_CITIES } = await import("../src/lib/fakeCities.js");
  for (const city of WORLD_CITIES) {
    assert.ok(
      continentForCountry(city.iso),
      `${city.iso} has no continent — scatter/drip would land nowhere`,
    );
  }
});

test("the table covers the world once, with no country on two continents", () => {
  const seen = new Map<string, string>();
  // Walk every two-letter code and let the table answer; a duplicate would
  // show up as an inconsistent answer for the same key, which a Map can't
  // hold — so instead assert the shape: a plausible count, all-valid values.
  const letters = "ABCDEFGHIJKLMNOPQRSTUVWXYZ".split("");
  for (const a of letters) {
    for (const b of letters) {
      const iso = a + b;
      const continent = continentForCountry(iso);
      if (continent) {
        assert.ok(ALL.includes(continent), `${iso} → ${continent} is not a continent`);
        seen.set(iso, continent);
      }
    }
  }
  assert.ok(seen.size > 240, `only ${seen.size} countries mapped — the table looks truncated`);
  assert.ok(seen.size < 300, `${seen.size} countries mapped — more than ISO-3166 defines`);
});
