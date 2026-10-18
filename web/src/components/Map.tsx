import { useEffect, useState } from "react";
import { divIcon, geoJSON } from "leaflet";
import type { Feature, FeatureCollection } from "geojson";
import {
  GeoJSON,
  MapContainer,
  Marker,
  Popup,
  TileLayer,
  Tooltip,
  useMap,
  ZoomControl,
} from "react-leaflet";
import "leaflet/dist/leaflet.css";
import { barangayBoundaries } from "../data/barangayBoundaries";
import floodHazardsUrl from "../data/gis/pantukan-flood.geojson?url";
import landslideHazardsUrl from "../data/gis/pantukan-landslide.geojson?url";
import stormSurgeHazardsUrl from "../data/gis/pantukan-storm-surge.geojson?url";
import type { MapFocus, MapPoint } from "../data/mapData";

const pantukan: [number, number] = [7.12682, 125.89714];
const priorityColors: Record<MapPoint["priority"], string> = {
  Critical: "#D92D20",
  High: "#E35A14",
  Moderate: "#C47C00",
  Low: "#2E7D5B",
};
const officialPantukanBounds = geoJSON(barangayBoundaries).getBounds();

const featureValue = (feature: Feature, keys: string[]) => {
  for (const key of keys) {
    const value = feature.properties?.[key];
    if (value !== undefined && value !== null && String(value).trim()) {
      return String(value);
    }
  }
  return "Mapped area";
};

function HazardLayer({
  url,
  title,
  labelKeys,
  color,
  fillColor,
}: {
  url: string;
  title: string;
  labelKeys: string[];
  color: string;
  fillColor: string;
}) {
  const [data, setData] = useState<FeatureCollection | null>(null);

  useEffect(() => {
    const controller = new AbortController();
    fetch(url, { signal: controller.signal })
      .then((response) => response.json() as Promise<FeatureCollection>)
      .then(setData)
      .catch((error: unknown) => {
        if (!(error instanceof DOMException && error.name === "AbortError")) {
          console.error(`Could not load ${title.toLowerCase()} layer.`, error);
        }
      });
    return () => controller.abort();
  }, [title, url]);

  if (!data) return null;

  return (
    <GeoJSON
      data={data}
      style={() => ({
        color,
        weight: 0.8,
        fillColor,
        fillOpacity: 0.16,
      })}
      onEachFeature={(feature, layer) =>
        layer.bindTooltip(
          `${title} · ${featureValue(feature, labelKeys)}`,
          { sticky: true },
        )
      }
    />
  );
}

const incidentMarkerIcon = (color: string, large: boolean) =>
  divIcon({
    className:
      "border-0 bg-transparent [&_span]:block [&_span]:size-full [&_svg]:block [&_svg]:size-full [&_svg]:overflow-visible [&_svg]:drop-shadow-[0_4px_4px_rgba(35,9,15,.28)] [&_path]:fill-[var(--marker-color)] [&_path]:stroke-white [&_path]:stroke-[1.4] [&_circle]:fill-white [&_circle]:stroke-[var(--marker-color)] [&_circle]:stroke-[1.5]",
    html: `<span style="--marker-color:${color}">
      <svg viewBox="0 0 24 30" aria-hidden="true">
        <path d="M12 1.5A10.5 10.5 0 0 0 1.5 12C1.5 20 12 28.5 12 28.5S22.5 20 22.5 12A10.5 10.5 0 0 0 12 1.5Z" />
        <circle cx="12" cy="12" r="4.2" />
      </svg>
    </span>`,
    iconSize: large ? [38, 47] : [32, 40],
    iconAnchor: large ? [19, 45] : [16, 38],
    popupAnchor: large ? [0, -43] : [0, -36],
  });

function MapViewportController({ focus }: { focus: MapFocus | null }) {
  const map = useMap();

  useEffect(() => {
    const timer = window.setTimeout(() => {
      map.invalidateSize();
      if (focus) {
        map.flyTo(focus.position, focus.zoom, { duration: 0.7 });
      } else if (officialPantukanBounds.isValid()) {
        map.fitBounds(officialPantukanBounds, { padding: [24, 24] });
      }
    }, 0);
    return () => window.clearTimeout(timer);
  }, [focus, map]);

  return null;
}

export function MiniMap({
  large = false,
  layers = [true, true, false, false, false],
  points = [],
  focus = null,
}: {
  large?: boolean;
  layers?: boolean[];
  points?: MapPoint[];
  focus?: MapFocus | null;
}) {
  return (
    <div
      className={`map-canvas relative z-0 isolate h-[250px] overflow-hidden rounded-[14px] bg-[#e8ece8] [&_.leaflet-container]:z-0 [&_.leaflet-container]:h-full [&_.leaflet-container]:w-full [&_.leaflet-container]:rounded-[inherit] [&_.leaflet-container]:bg-[#e8ece8] [&_.leaflet-container]:font-[inherit] [&_.leaflet-control-attribution]:bg-[rgba(255,255,255,.9)] [&_.leaflet-control-attribution]:text-[7px] [&_.leaflet-control-attribution]:text-muted [&_.leaflet-control-attribution_a]:text-maroon [&_.leaflet-control-zoom_a]:border-border [&_.leaflet-control-zoom_a]:text-maroon [&_.leaflet-popup-content-wrapper]:rounded-xl [&_.leaflet-popup-content-wrapper]:shadow-[0_8px_30px_#23090f33] [&_.leaflet-popup-content]:m-3 ${large ? "map-large h-[676px] max-[1180px]:h-[520px] max-[650px]:h-[480px]" : ""}`}
    >
      <MapContainer
        center={pantukan}
        zoom={12}
        scrollWheelZoom={large}
        zoomControl={false}
        preferCanvas
      >
        <TileLayer
          attribution='&copy; <a href="https://www.openstreetmap.org/copyright">OpenStreetMap</a> contributors'
          url="https://tile.openstreetmap.org/{z}/{x}/{y}.png"
        />
        {(large || focus) && <MapViewportController focus={focus} />}
        {large && <ZoomControl position="bottomright" />}
        {large && layers[2] && (
          <HazardLayer
            url={floodHazardsUrl}
            title="Flood hazard"
            labelKeys={["Susc2", "Susc"]}
            color="#2563A8"
            fillColor="#3B82C4"
          />
        )}
        {large && layers[3] && (
          <HazardLayer
            url={landslideHazardsUrl}
            title="Landslide hazard"
            labelKeys={["Susp"]}
            color="#C47C00"
            fillColor="#F0A629"
          />
        )}
        {large && layers[4] && (
          <HazardLayer
            url={stormSurgeHazardsUrl}
            title="Storm surge hazard"
            labelKeys={["Hazard", "Name"]}
            color="#7A1F2B"
            fillColor="#B94B5D"
          />
        )}
        {layers[1] && (
          <GeoJSON
            data={barangayBoundaries}
            style={() => ({
              color: "#7A1F2B",
              weight: large ? 1.4 : 1,
              fillColor: "#7A1F2B",
              fillOpacity: large ? 0.018 : 0.01,
              dashArray: "5 5",
            })}
            onEachFeature={(feature, layer) =>
              layer.bindTooltip(
                `Barangay ${featureValue(feature, ["Barangay", "Name"])}`,
                { sticky: true },
              )
            }
          />
        )}
        {layers[0] &&
          points.map((point) => (
            <Marker
              key={point.id}
              position={point.position}
              icon={incidentMarkerIcon(priorityColors[point.priority], large)}
            >
              <Popup>
                <div
                  className={
                    "grid min-w-[145px] gap-[3px] [&_b]:text-xs [&_span]:text-[9px] [&_span]:font-bold [&_span]:text-maroon [&_small]:text-[9px] [&_small]:text-muted"
                  }
                >
                  <b>{point.name}</b>
                  <span>
                    {point.id} · {point.priority}
                  </span>
                  <small>{point.location}</small>
                  <small>
                    {point.barangay
                      ? `Barangay ${point.barangay}`
                      : "Barangay not determined"}
                  </small>
                  {point.status && <small>Status: {point.status}</small>}
                  {point.source && <small>Source: {point.source}</small>}
                  {point.receivedAt && (
                    <small>Received: {point.receivedAt}</small>
                  )}
                  {point.assignmentState && (
                    <small>
                      Response: {point.assignmentState === "loading"
                        ? "Loading team assignment…"
                        : point.assignmentState === "error"
                          ? "Team status unavailable"
                          : point.assignedTeams?.length
                            ? point.assignedTeams.join(", ")
                            : "Not assigned"}
                    </small>
                  )}
                </div>
              </Popup>
              {large && (
                <Tooltip direction="top" offset={[0, -34]}>
                  {point.name}
                </Tooltip>
              )}
            </Marker>
          ))}
      </MapContainer>
      <div
        className={
          "absolute bottom-[19px] right-[10px] z-[500] flex gap-[9px] rounded-[10px] bg-white p-2 text-[8px] text-muted shadow-[0_2px_9px_#0001] [&_span]:flex [&_span]:items-center [&_span]:gap-1 [&_i]:inline-block [&_i]:size-1.5 [&_i]:rounded-full"
        }
      >
        <span>
          <i className={"bg-priority-red"} />
          Critical
        </span>
        <span>
          <i className={"bg-priority-orange"} />
          High
        </span>
        <span>
          <i className={"bg-priority-amber"} />
          Moderate
        </span>
        <span>
          <i className={"bg-status-green"} />
          Low
        </span>
      </div>
    </div>
  );
}
