import { useEffect, useMemo, useRef, useState } from "react";
import { Icon } from "../components/Icon";
import { MiniMap } from "../components/Map";
import type { MapFocus, MapPoint } from "../data/mapData";
import { isMappableActiveReport, type Report } from "../data/reports";
import { useActiveAdminAssignments } from "../hooks/useAdminAssignments";
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
const priorityLabel = (priority: Report["priority"]): MapPoint["priority"] =>
  priority === "CRITICAL"
    ? "Critical"
    : priority === "HIGH"
      ? "High"
      : priority === "MEDIUM"
        ? "Moderate"
        : "Low";

const operationalStatus = (report: Report) =>
  report.incidentStatus === "responding"
    ? "Responding"
    : report.incidentStatus === "dispatched"
      ? "Dispatched"
      : report.incidentStatus === "open"
        ? "Open"
        : "Verified";

const sourceLabel = (source: Report["source"]) =>
  source === "app_api"
    ? "Mobile app"
    : source === "app_sms"
      ? "Signed SMS"
      : "Manual";

const receivedLabel = (value: string) =>
  new Intl.DateTimeFormat("en-PH", {
    month: "short",
    day: "numeric",
    hour: "numeric",
    minute: "2-digit",
  }).format(new Date(value));

export function IncidentMap({
  reports,
  reportStatus,
  reportError,
  retryReports,
  focus,
}: {
  reports: Report[];
  reportStatus: "loading" | "ready" | "error";
  reportError: string | null;
  retryReports: () => void;
  focus: MapFocus | null;
}) {
  const assignments = useActiveAdminAssignments();
  const [layers, setLayers] = useState([true, true, false, false, false]);
  const [timeRange, setTimeRange] = useState("24");
  const [priority, setPriority] = useState("");
  const [incidentType, setIncidentType] = useState("");
  const [incidentStatus, setIncidentStatus] = useState("");
  const [fullScreen, setFullScreen] = useState(false);
  const [layersOpen, setLayersOpen] = useState(false);
  const [mapClock, setMapClock] = useState(() => Date.now());
  const layersRef = useRef<HTMLDivElement>(null);

  const operationalReports = useMemo(
    () =>
      reports.filter(
        isMappableActiveReport,
      ),
    [reports],
  );
  const teamsByIncident = useMemo(() => {
    const teams = new Map<string, string[]>();
    for (const assignment of assignments.data ?? []) {
      const names = teams.get(assignment.incident_id) ?? [];
      if (!names.includes(assignment.unit.name)) names.push(assignment.unit.name);
      teams.set(assignment.incident_id, names);
    }
    return teams;
  }, [assignments.data]);
  const mapPoints = useMemo(() => {
    return operationalReports.flatMap((report) => {
      if (!report.position) return [];
      return [
        {
          id: report.reference,
          name: report.incident,
          location: report.location,
          position: report.position,
          barangay: report.barangay,
          priority: priorityLabel(report.priority),
          hoursAgo: Math.max(
            0,
            (mapClock - new Date(report.receivedAt).getTime()) / 3_600_000,
          ),
          status: operationalStatus(report),
          source: sourceLabel(report.source),
          receivedAt: receivedLabel(report.receivedAt),
          assignedTeams: report.incidentId
            ? teamsByIncident.get(report.incidentId) ?? []
            : [],
          assignmentState: report.incidentId
            ? assignments.status === "error"
              ? "error"
              : assignments.status === "ready"
                ? "ready"
                : "loading"
            : "ready",
        } satisfies MapPoint,
      ];
    });
  }, [assignments.status, mapClock, operationalReports, teamsByIncident]);
  const incidentTypeOptions = useMemo(
    () =>
      [...new Set(operationalReports.map((report) => report.incident))].sort(),
    [operationalReports],
  );
  const filteredIncidents = useMemo(
    () =>
      mapPoints.filter(
        (point) =>
          point.hoursAgo <= Number(timeRange) &&
          (!priority || point.priority === priority) &&
          (!incidentType || point.name === incidentType) &&
          (!incidentStatus || point.status === incidentStatus),
      ),
    [incidentStatus, incidentType, mapPoints, priority, timeRange],
  );
  const activeIncidentCount = new Set(
    operationalReports.flatMap((report) =>
      report.incidentId ? [report.incidentId] : [],
    ),
  ).size;
  const awaitingDispatchCount = operationalReports.filter(
    (report) => !report.incidentId,
  ).length;
  const unmappedCount = operationalReports.filter(
    (report) => !report.position,
  ).length;
  const resetFilters = () => {
    setTimeRange("24");
    setPriority("");
    setIncidentType("");
    setIncidentStatus("");
  };
  const refreshData = () => {
    setMapClock(Date.now());
    retryReports();
    assignments.refetch();
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
        subtitle="Monitor verified reports, active incidents, and deployed response teams across Pantukan."
      />
      {reportStatus === "error" && (
        <div className="flex min-h-[52px] items-center gap-3 rounded-[10px] border border-[#efc7c4] bg-red-soft px-3 py-2 text-priority-red">
          <Icon name="alert" />
          <div className="min-w-0 flex-1">
            <b className="block text-[11px]">Live incident data is unavailable</b>
            <p className="mb-0 mt-1 text-[9px] text-muted">
              {reportError ?? "The report list could not be loaded."}
            </p>
          </div>
          <Button variant="secondary" onClick={refreshData}>
            Retry
          </Button>
        </div>
      )}
      {assignments.status === "error" && reportStatus !== "error" && (
        <div className="flex min-h-[46px] items-center gap-3 rounded-[10px] border border-[#e5d8bb] bg-[#fffdf8] px-3 py-2 text-priority-amber">
          <Icon name="alert" />
          <span className="flex-1 text-[10px]">
            Incident locations are current, but response-team assignments could
            not be refreshed.
          </span>
          <Button variant="secondary" onClick={() => assignments.refetch()}>
            Retry teams
          </Button>
        </div>
      )}
      <Card className="map-filterbar relative flex min-h-14 flex-wrap items-center gap-2 overflow-visible px-[10px] py-2">
        <SelectField
          label="Time range"
          value={timeRange}
          options={[
            { label: "Last 24 hours", value: "24" },
            { label: "Last 7 days", value: "168" },
            { label: "Last 30 days", value: "720" },
          ]}
          onChange={setTimeRange}
        />
        <SelectField
          label="All priorities"
          value={priority}
          options={["Critical", "High", "Moderate", "Low"]}
          onChange={setPriority}
        />
        <SelectField
          label="All incident types"
          value={incidentType}
          options={incidentTypeOptions}
          onChange={setIncidentType}
        />
        <SelectField
          label="All statuses"
          value={incidentStatus}
          options={["Verified", "Open", "Dispatched", "Responding"]}
          onChange={setIncidentStatus}
        />
        <i className="flex-1 max-[650px]:hidden" />
        <Button
          variant="secondary"
          onClick={refreshData}
          disabled={
            reportStatus === "loading" || assignments.status === "loading"
          }
        >
          {reportStatus === "loading" ? "Loading…" : "Refresh"}
        </Button>
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
                  aria-label="Close map layers"
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
      {reportStatus === "loading" && !reports.length && (
        <div
          className="flex min-h-[52px] items-center gap-3 rounded-[10px] border border-border bg-white px-3 text-[10px] text-muted"
          role="status"
        >
          <i className="size-4 animate-spin rounded-full border-2 border-maroon/20 border-t-maroon" />
          Loading live incident locations…
        </div>
      )}
      {reportStatus !== "loading" &&
        !operationalReports.length &&
        reportStatus !== "error" && (
          <div className="flex min-h-[58px] items-center gap-3 rounded-[10px] border border-border bg-white px-3 py-2">
            <span className="grid size-8 place-items-center text-status-green">
              <Icon name="check" />
            </span>
            <div>
              <b className="block text-[11px]">No active incidents to map</b>
              <p className="mb-0 mt-1 text-[9px] text-muted">
                Verified reports will appear here when coordinates are
                available.
              </p>
            </div>
          </div>
        )}
      {!!mapPoints.length && !filteredIncidents.length && (
        <div className="flex min-h-[52px] items-center gap-[10px] rounded-[10px] border border-[#e5d8bb] bg-[#fffdf8] px-3 py-2 max-[650px]:flex-wrap">
          <span className="grid size-8 shrink-0 place-items-center text-priority-amber">
            <Icon name="filter" />
          </span>
          <div className="min-w-0 flex-1">
            <b className="block text-[11px]">
              No incidents match the selected filters
            </b>
            <p className="mb-0 mt-1 text-[9px] text-muted">
              Reset the filters to restore mapped incidents.
            </p>
          </div>
          <Button variant="secondary" onClick={resetFilters}>
            Reset filters
          </Button>
        </div>
      )}
      <div className="grid grid-cols-[minmax(0,2.25fr)_minmax(300px,1fr)] gap-4 max-[1180px]:grid-cols-1">
        <Card className="operations-map-card">
          <SectionHead
            title="Pantukan operations map"
            subtitle={`${filteredIncidents.length} mapped reports • Live PostgreSQL data`}
            action="Full screen"
            onAction={() => setFullScreen(true)}
          />
          <MiniMap large layers={layers} points={filteredIncidents} focus={focus} />
        </Card>
        <div className="side-stack flex flex-col gap-3 max-[1180px]:grid max-[1180px]:grid-cols-2 max-[650px]:grid-cols-1">
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
              [
                "Low priority",
                filteredIncidents.filter((point) => point.priority === "Low")
                  .length,
                "green",
              ],
              ["Total mapped", filteredIncidents.length, "maroon"],
            ].map((item) => (
              <div
                className="flex min-h-[30px] items-center justify-between gap-[10px] text-[9px] [&_span]:text-muted"
                key={item[0]}
              >
                <span>{item[0]}</span>
                <Badge tone={String(item[2])} dot={false}>
                  {item[1]}
                </Badge>
              </div>
            ))}
          </Card>
          <Card>
            <SectionHead
              title="Operational coverage"
              subtitle="Current active workload"
            />
            {[
              ["Active incidents", activeIncidentCount, "blue"],
              ["Verified, awaiting dispatch", awaitingDispatchCount, "amber"],
              ["Reports without coordinates", unmappedCount, "maroon"],
            ].map((item) => (
              <div
                className="flex min-h-[34px] items-center justify-between gap-[10px] border-b border-border text-[9px] last:border-b-0 [&_span]:text-muted"
                key={item[0]}
              >
                <span>{item[0]}</span>
                <Badge tone={String(item[2])} dot={false}>
                  {item[1]}
                </Badge>
              </div>
            ))}
            <p className="mb-0 mt-3 text-[8px] leading-relaxed text-muted">
              Reports without GPS remain available in Live Reports and are not
              placed on the map.
            </p>
          </Card>
        </div>
      </div>
      {fullScreen && (
        <div
          className="fixed inset-0 z-[1200] bg-[rgba(35,9,15,.76)] p-[18px] backdrop-blur-[5px]"
          role="dialog"
          aria-modal="true"
          aria-label="Full screen incident map"
        >
          <div className="flex h-full w-full flex-col rounded-[20px] bg-white p-[14px] shadow-[0_30px_100px_rgba(35,9,15,.35)] [&_.map-large]:h-auto [&_.map-large]:flex-1">
            <div className="flex min-h-[54px] items-center gap-4 px-1 pb-[10px] [&>div]:flex-1 [&_h2]:m-0 [&_h2]:text-lg [&_p]:mb-0 [&_p]:mt-1 [&_p]:text-[9px] [&_p]:text-muted [&>button]:size-[38px] [&>button]:rounded-[11px] [&>button]:border-0 [&>button]:bg-soft-gray [&>button]:text-[23px] [&>button]:text-maroon">
              <div>
                <h2>Pantukan operations map</h2>
                <p>
                  {filteredIncidents.length} mapped reports • Live operational
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
            <MiniMap large layers={layers} points={filteredIncidents} focus={focus} />
          </div>
        </div>
      )}
    </>
  );
}
