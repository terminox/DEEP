import { test } from "node:test";
import assert from "node:assert/strict";
import { clusterPoints } from "../src/lib/geoCluster.js";

test("bins points that fall in the same 1x1 cell into one point", () => {
  const points = clusterPoints([
    { lat: 35.1, lon: 139.2 },
    { lat: 35.9, lon: 139.8 },
  ]);
  assert.equal(points.length, 1);
  assert.equal(points[0]!.count, 2);
});

test("keeps points in different cells separate", () => {
  const points = clusterPoints([
    { lat: 35.1, lon: 139.2 },
    { lat: 51.5, lon: -0.1 },
  ]);
  assert.equal(points.length, 2);
  for (const p of points) assert.equal(p.count, 1);
});

test("centroid is the count-weighted mean of member coords, rounded to 0.1", () => {
  const points = clusterPoints([
    { lat: 35.0, lon: 139.0 },
    { lat: 35.5, lon: 139.9 },
  ]);
  assert.equal(points.length, 1);
  // mean(35.0, 35.5) = 35.25 -> rounds to 35.3 (Math.round(352.5)/10 = 35.3)
  assert.equal(points[0]!.lat, 35.3);
  // mean(139.0, 139.9) = 139.45 -> Math.round(1394.5)/10 = 139.5
  assert.equal(points[0]!.lon, 139.5);
});

test("sorts by count descending", () => {
  const points = clusterPoints([
    { lat: 10.0, lon: 10.0 }, // cell A: 1
    { lat: 20.0, lon: 20.0 }, // cell B: 1
    { lat: 20.1, lon: 20.1 }, // cell B: 2
    { lat: 20.2, lon: 20.2 }, // cell B: 3
  ]);
  assert.equal(points.length, 2);
  assert.equal(points[0]!.count, 3);
  assert.equal(points[1]!.count, 1);
});

test("ties on count break by cell key string ascending", () => {
  // Cell keys are "<floor(lat)>:<floor(lon)>" — "10:10" < "20:20" as strings.
  const points = clusterPoints([
    { lat: 20.0, lon: 20.0 },
    { lat: 10.0, lon: 10.0 },
  ]);
  assert.equal(points.length, 2);
  assert.equal(points[0]!.lat, 10);
  assert.equal(points[1]!.lat, 20);
});

test("caps output at 96 points, keeping the highest-count cells", () => {
  const locs: { lat: number; lon: number }[] = [];
  // 120 distinct cells, cell i gets (i + 1) points so counts are all
  // distinct and the top 96 by count are deterministically cells 24..119.
  for (let i = 0; i < 120; i++) {
    const lat = -60 + i; // stays inside [-90, 90] for i in [0, 120)
    for (let j = 0; j <= i; j++) {
      locs.push({ lat: lat + 0.1, lon: 0.1 });
    }
  }
  const points = clusterPoints(locs);
  assert.equal(points.length, 96);
  // Highest-count cell (i = 119, count = 120) must be present.
  assert.equal(points[0]!.count, 120);
  // Lowest-count retained cell is i = 24 (count = 25); i = 23 (count = 24) is dropped.
  assert.ok(points.some((p) => p.count === 25));
  assert.ok(!points.some((p) => p.count === 24));
});
