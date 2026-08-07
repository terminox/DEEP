import { test } from "node:test";
import assert from "node:assert/strict";

// Points GEOIP_DB_PATH at a file that doesn't exist *before* env.ts (and
// therefore geoip.ts) is ever imported, since env.ts parses process.env once
// at module-load time. A dynamic import after setting the var — rather than a
// static import, which ESM hoists above this line — is what makes that
// ordering work. node --test runs each test file in its own process, so this
// doesn't leak into other test files.
process.env.GEOIP_DB_PATH = "./__does_not_exist__/GeoLite2-City.mmdb";
const { lookup, isPrivateIP, setFixedLocation } = await import("../src/lib/geoip.js");

test("isPrivateIP classifies loopback/private/link-local ranges", () => {
  const privateIPs = [
    "::ffff:192.168.1.7",
    "10.0.0.1",
    "172.20.1.1",
    "127.0.0.1",
    "192.168.1.1",
    "169.254.1.1",
    "::1",
    "fc00::1",
    "fe80::1",
  ];
  for (const ip of privateIPs) {
    assert.equal(isPrivateIP(ip), true, `expected ${ip} to be classified private`);
  }
});

test("isPrivateIP does not flag public addresses", () => {
  const publicIPs = ["8.8.8.8", "1.1.1.1", "::ffff:8.8.8.8"];
  for (const ip of publicIPs) {
    assert.equal(isPrivateIP(ip), false, `expected ${ip} to NOT be classified private`);
  }
});

test("lookup() returns null for private IPs even with a fixed override unset", async () => {
  assert.equal(await lookup("10.0.0.1"), null);
});

test("lookup() falls back to null when the mmdb file is missing", async () => {
  // GEOIP_DB_PATH points nowhere (set above); a public IP should fail open.
  assert.equal(await lookup("8.8.8.8"), null);
});

test("lookup() rounds fixed-override coordinates to 1 decimal", async () => {
  setFixedLocation({ lat: 35.6895123, lon: 139.6917456 });
  const loc = await lookup("8.8.8.8");
  assert.deepEqual(loc, { lat: 35.7, lon: 139.7, iso: null });
  setFixedLocation(null);
});

test("fixed override applies even to private IPs (dev override wins)", async () => {
  setFixedLocation({ lat: 1.05, lon: 2.05 });
  const loc = await lookup("10.0.0.1");
  assert.deepEqual(loc, { lat: 1.1, lon: 2.1, iso: null });
  setFixedLocation(null);
});
