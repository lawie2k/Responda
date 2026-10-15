import type { Feature, FeatureCollection, Geometry, Position } from "geojson";
import barangayBoundariesText from "./gis/pantukan-barangays.geojson?raw";

export const barangayBoundaries = JSON.parse(
  barangayBoundariesText,
) as FeatureCollection;

const pointOnSegment = (
  point: [number, number],
  start: Position,
  end: Position,
) => {
  const cross =
    (point[1] - start[1]) * (end[0] - start[0]) -
    (point[0] - start[0]) * (end[1] - start[1]);
  if (Math.abs(cross) > 1e-10) return false;
  return (
    point[0] >= Math.min(start[0], end[0]) - 1e-10 &&
    point[0] <= Math.max(start[0], end[0]) + 1e-10 &&
    point[1] >= Math.min(start[1], end[1]) - 1e-10 &&
    point[1] <= Math.max(start[1], end[1]) + 1e-10
  );
};

const ringContainsPoint = (
  point: [number, number],
  ring: Position[],
) => {
  let inside = false;
  for (let current = 0, previous = ring.length - 1; current < ring.length; previous = current++) {
    const start = ring[current];
    const end = ring[previous];
    if (pointOnSegment(point, start, end)) return true;
    const crossesRay =
      start[1] > point[1] !== end[1] > point[1] &&
      point[0] <
        ((end[0] - start[0]) * (point[1] - start[1])) /
          (end[1] - start[1]) +
          start[0];
    if (crossesRay) inside = !inside;
  }
  return inside;
};

const polygonContainsPoint = (
  point: [number, number],
  rings: Position[][],
) =>
  Boolean(rings.length) &&
  ringContainsPoint(point, rings[0]) &&
  !rings.slice(1).some((hole) => ringContainsPoint(point, hole));

const geometryContainsPoint = (
  geometry: Geometry | null,
  point: [number, number],
) => {
  if (!geometry) return false;
  if (geometry.type === "Polygon") {
    return polygonContainsPoint(point, geometry.coordinates);
  }
  if (geometry.type === "MultiPolygon") {
    return geometry.coordinates.some((polygon) =>
      polygonContainsPoint(point, polygon),
    );
  }
  return false;
};

const featureArea = (feature: Feature) => {
  const area = Number(feature.properties?.Area);
  return Number.isFinite(area) ? area : Number.POSITIVE_INFINITY;
};

export const getBarangayForPosition = (
  position: [number, number] | null | undefined,
) => {
  if (!position || !position.every(Number.isFinite)) return null;
  const point: [number, number] = [position[1], position[0]];
  const match = barangayBoundaries.features
    .filter((feature) => geometryContainsPoint(feature.geometry, point))
    .sort((left, right) => featureArea(left) - featureArea(right))[0];
  const name = match?.properties?.Barangay ?? match?.properties?.Name;
  return name ? String(name) : null;
};
