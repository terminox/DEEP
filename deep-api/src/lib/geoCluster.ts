// Bins raw participant coordinates into 1°x1° grid cells so the globe never
// has to render more points than it can usefully show. Pure and side-effect
// free — no imports beyond the types it operates on.

export interface ClusteredPoint {
  lat: number;
  lon: number;
  count: number;
}

const MAX_POINTS = 96;

function round1(v: number): number {
  return Math.round(v * 10) / 10;
}

export function clusterPoints(locs: { lat: number; lon: number }[]): ClusteredPoint[] {
  const cells = new Map<string, { sumLat: number; sumLon: number; count: number }>();

  for (const { lat, lon } of locs) {
    const key = `${Math.floor(lat)}:${Math.floor(lon)}`;
    const cell = cells.get(key);
    if (cell) {
      cell.sumLat += lat;
      cell.sumLon += lon;
      cell.count += 1;
    } else {
      cells.set(key, { sumLat: lat, sumLon: lon, count: 1 });
    }
  }

  return Array.from(cells.entries())
    .map(([key, cell]) => ({
      key,
      lat: round1(cell.sumLat / cell.count),
      lon: round1(cell.sumLon / cell.count),
      count: cell.count,
    }))
    .sort((a, b) => b.count - a.count || (a.key < b.key ? -1 : a.key > b.key ? 1 : 0))
    .slice(0, MAX_POINTS)
    .map(({ lat, lon, count }) => ({ lat, lon, count }));
}
