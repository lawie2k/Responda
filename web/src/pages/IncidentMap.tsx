import { useEffect, useMemo, useRef, useState } from "react";
import { Icon } from "../components/Icon";
import { MiniMap } from "../components/Map";
import { incidents } from "../data/mapData";
import {
  Badge,
  Button,
  Card,
  PageTitle,
  SectionHead,
  SelectField,
  Switch,
} from "../components/ui";

const layerDotClasses = [
  "bg-priority-red",
  "bg-maroon",
  "bg-status-blue",
  "bg-priority-amber",
  "bg-[#b94b5d]",
];
const layerNames = [
  "Active incidents",
  "Barangay boundaries",
  "Flood hazard",
  "Landslide hazard",
  "Storm surge hazard",
];

export function IncidentMap() {
  const [layers, setLayers] = useState([true, true, false, false, false]);
  const [timeRange, setTimeRange] = useState("Last 24 hours");
  const [priority, setPriority] = useState("");
  const [incidentType, setIncidentType] = useState("");
  const [fullScreen, setFullScreen] = useState(false);
  const [layersOpen, setLayersOpen] = useState(false);
  const layersRef = useRef<HTMLDivElement>(null);
  const filteredIncidents = useMemo(() => {
    const maxHours =
      timeRange === "Last 24 hours"
        ? 24
        : timeRange === "Last 7 days"
          ? 168
          : 720;
    return incidents.filter(
      (point) =>
        point.hoursAgo <= maxHours &&
        (!priority || point.priority === priority) &&
        (!incidentType || point.name === incidentType),
    );
  }, [incidentType, priority, timeRange]);
  const resetFilters = () => {
    setTimeRange("Last 24 hours");
    setPriority("");
    setIncidentType("");
  };
  useEffect(() => {
    if (!fullScreen) return;
    const closeOnEscape = (event: KeyboardEvent) => {
      if (event.key === "Escape") setFullScreen(false);
    };
    window.addEventListener("keydown", closeOnEscape);
    return () => window.removeEventListener("keydown", closeOnEscape);
  }, [fullScreen]);

  useEffect(() => {
    const closeLayers = (event: MouseEvent) => {
      if (!layersRef.current?.contains(event.target as Node)) {
        setLayersOpen(false);
      }
    };
    document.addEventListener("mousedown", closeLayers);
    return () => document.removeEventListener("mousedown", closeLayers);
  }, []);

  return (
    <>
      <PageTitle
        title="Incident Map"
        subtitle="View active incidents with official barangay and hazard boundaries."
      />
      <Card
        className={
          "map-filterbar relative flex min-h-14 flex-wrap items-center gap-2 overflow-visible px-[10px] py-2"
        }
      >
        <SelectField
          label="Time range"
          value={timeRange}
          options={["Last 24 hours", "Last 7 days", "Last 30 days"]}
          onChange={setTimeRange}
        />
        <SelectField
          label="All priorities"
          value={priority}
          options={["Critical", "High", "Moderate"]}
          onChange={setPriority}
        />
        <SelectField
          label="All incident types"
          value={incidentType}
          options={incidents.map((point) => point.name)}
          onChange={setIncidentType}
        />
        <i className={"flex-1 max-[650px]:hidden"} />
        <div className="relative shrink-0" ref={layersRef}>
          <Button
            variant="secondary"
            icon="filter"
            onClick={() => setLayersOpen((open) => !open)}
          >
            Map layers ({layers.filter(Boolean).length})
          </Button>
          {layersOpen && (
            <div className="absolute right-0 top-[calc(100%+8px)] z-[80] w-[290px] rounded-[16px] border border-border bg-white p-4 shadow-[0_16px_40px_rgba(28,28,30,.16)] max-[650px]:right-[-4px] max-[650px]:w-[min(290px,calc(100vw-40px))]">
              <div className="mb-3 flex items-start justify-between gap-3">
                <div>
                  <b className="block text-[11px]">Map layers</b>
                  <span className="text-[9px] text-muted">
                    Show or hide operational data
                  </span>
                </div>
                <button
                  className="grid size-7 place-items-center rounded-lg border-0 bg-soft-gray text-base text-maroon"
                  onClick={() => setLayersOpen(false)}
                >
                  ×
                </button>
              </div>
              <div className="border-t border-border pt-2">
                {layerNames.map((name, index) => (
                  <div
                    className="flex h-10 items-center justify-between text-[10px] [&>span]:flex [&>span]:items-center [&>span]:gap-[7px]"
                    key={name}
                  >
                    <span>
                      <i
                        className={`size-2 rounded-full ${layerDotClasses[index]}`}
                      />
                      {name}
                    </span>
                    <Switch
                      ariaLabel={`${layers[index] ? "Hide" : "Show"} ${name}`}
                      value={layers[index]}
                      onChange={() =>
                        setLayers((values) =>
                          values.map((value, layerIndex) =>
                            index === layerIndex ? !value : value,
                          ),
                        )
                      }
                    />
                  </div>
                ))}
              </div>
              <div className="mt-2 flex items-center justify-between border-t border-border pt-3">
                <span className="text-[9px] text-muted">
                  {layers.filter(Boolean).length} layers visible
                </span>
                <Button
                  variant="secondary"
                  onClick={() =>
                    setLayers([true, true, false, false, false])
                  }
                >
                  Reset
                </Button>
              </div>
            </div>
          )}
        </div>
      </Card>
      {!filteredIncidents.length && (
        <div
          className={
            "flex min-h-[52px] items-center gap-[10px] rounded-[14px] px-3 py-2 max-[650px]:flex-wrap max-[650px]:items-start [&>span]:grid [&>span]:size-8 [&>span]:shrink-0 [&>span]:place-items-center [&>span]:rounded-[10px] [&>span]:bg-white [&>div]:min-w-0 [&>div]:flex-1 [&_b]:text-[11px] [&_p]:my-0.5 [&_p]:text-[9px] [&_p]:text-muted max-[650px]:[&>.button]:w-full bg-amber-soft text-priority-amber"
          }
        >
          <span>
            <Icon name="filter" />
          </span>
          <div>
            <b>No incidents match the selected filters</b>
            <p>Reset the filters to restore all mapped incidents.</p>
          </div>
          <Button variant="secondary" onClick={resetFilters}>
            Reset filters
          </Button>
        </div>
      )}
      <div
        className={
          "grid grid-cols-[minmax(0,2.25fr)_minmax(300px,1fr)] gap-4 max-[1180px]:grid-cols-1"
        }
      >
        <Card className={"operations-map-card"}>
          <SectionHead
            title="Pantukan operations map"
            subtitle={`${filteredIncidents.length} mapped incidents • Official MDRRMO boundary data`}
            action="Full screen"
            onAction={() => setFullScreen(true)}
          />
          <MiniMap large layers={layers} points={filteredIncidents} />
        </Card>
        <div
          className={
            "side-stack flex flex-col gap-3 max-[1180px]:grid max-[1180px]:grid-cols-1"
          }
        >
          <Card>
            <SectionHead
              title="Live map summary"
              subtitle="Current filtered view"
            />
            {[
              [
                "Critical incidents",
                filteredIncidents.filter(
                  (point) => point.priority === "Critical",
                ).length,
                "red",
              ],
              [
                "High priority",
                filteredIncidents.filter((point) => point.priority === "High")
                  .length,
                "orange",
              ],
              [
                "Moderate priority",
                filteredIncidents.filter(
                  (point) => point.priority === "Moderate",
                ).length,
                "amber",
              ],
              ["Total mapped", filteredIncidents.length, "maroon"],
            ].map((x) => (
              <div
                className={
                  "flex min-h-[27px] items-center justify-between gap-[10px] text-[9px] [&_span]:text-muted"
                }
                key={x[0]}
              >
                <span>{x[0]}</span>
                <Badge tone={String(x[2])} dot={false}>
                  {x[1]}
                </Badge>
              </div>
            ))}
          </Card>
        </div>
      </div>
      {fullScreen && (
        <div
          className={
            "fixed inset-0 z-[1200] bg-[rgba(35,9,15,.76)] p-[18px] backdrop-blur-[5px]"
          }
          role="dialog"
          aria-modal="true"
        >
          <div
            className={
              "flex h-full w-full flex-col rounded-[20px] bg-white p-[14px] shadow-[0_30px_100px_rgba(35,9,15,.35)] [&_.map-large]:h-auto [&_.map-large]:flex-1"
            }
          >
            <div
              className={
                "flex min-h-[54px] items-center gap-4 px-1 pb-[10px] [&>div]:flex-1 [&_h2]:m-0 [&_h2]:text-lg [&_p]:mt-1 [&_p]:mb-0 [&_p]:text-[9px] [&_p]:text-muted [&>button]:size-[38px] [&>button]:rounded-[11px] [&>button]:border-0 [&>button]:bg-soft-gray [&>button]:text-[23px] [&>button]:text-maroon"
              }
            >
              <div>
                <h2>Pantukan operations map</h2>
                <p>
                  {filteredIncidents.length} mapped incidents • Live operational
                  layers
                </p>
              </div>
              <button
                aria-label="Close full screen map"
                onClick={() => setFullScreen(false)}
              >
                ×
              </button>
            </div>
            <MiniMap large layers={layers} points={filteredIncidents} />
          </div>
        </div>
      )}
    </>
  );
}
