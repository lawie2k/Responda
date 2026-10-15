import { useMemo, useState } from "react";
import { Icon } from "../components/Icon";
import { tone } from "../data/reports";
import {
  Badge,
  Button,
  Card,
  Metric,
  PageTitle,
  SectionHead,
  SelectField,
} from "../components/ui";

type HistoricalRecord = {
  id: string;
  date: string;
  dateValue: string;
  incident: string;
  location: string;
  priority: string;
  status: string;
  outcome: string;
  reporter: string;
  team: string;
  dispatchTime: string;
  closedTime: string;
  validator: string;
  source: string;
  summary: string;
};

const records: HistoricalRecord[] = [
  {
    id: "RSP-00841",
    date: "Aug 30",
    dateValue: "2026-08-30",
    incident: "Flash Flood",
    location: "Magnaga Riverside",
    priority: "CRITICAL",
    status: "VERIFIED",
    outcome: "Residents evacuated",
    reporter: "Juan Dela Cruz",
    team: "Flood Unit",
    dispatchTime: "6 min 18 sec",
    closedTime: "8:42 PM",
    validator: "Maria Santos",
    source: "App report",
    summary:
      "Residents near the riverside were evacuated safely before water levels increased.",
  },
  {
    id: "RSP-00828",
    date: "Aug 28",
    dateValue: "2026-08-28",
    incident: "Road Accident",
    location: "Kingking Highway",
    priority: "HIGH",
    status: "VERIFIED",
    outcome: "Patient transferred",
    reporter: "Ana Reyes",
    team: "Rescue Alpha",
    dispatchTime: "7 min 04 sec",
    closedTime: "6:15 PM",
    validator: "Maria Santos",
    source: "Phone call",
    summary:
      "One injured passenger was stabilized and transferred to the district hospital.",
  },
  {
    id: "RSP-00812",
    date: "Aug 25",
    dateValue: "2026-08-25",
    incident: "Landslide",
    location: "Bongabong Slope",
    priority: "HIGH",
    status: "VALIDATED",
    outcome: "Road cleared",
    reporter: "Marco Lim",
    team: "Clearing Team",
    dispatchTime: "9 min 31 sec",
    closedTime: "4:08 PM",
    validator: "Joel Garcia",
    source: "App report",
    summary:
      "Debris blocking one lane was removed and the road was reopened to traffic.",
  },
  {
    id: "RSP-00796",
    date: "Aug 22",
    dateValue: "2026-08-22",
    incident: "Medical Emergency",
    location: "Matiao Public Market",
    priority: "CRITICAL",
    status: "VERIFIED",
    outcome: "Patient assisted",
    reporter: "Liza Ramos",
    team: "Medical 1",
    dispatchTime: "5 min 42 sec",
    closedTime: "11:26 AM",
    validator: "Maria Santos",
    source: "Walk-in report",
    summary:
      "The patient received first aid and was brought to the municipal health unit.",
  },
  {
    id: "RSP-00783",
    date: "Aug 19",
    dateValue: "2026-08-19",
    incident: "Fallen Tree",
    location: "Pantukan Highway",
    priority: "MODERATE",
    status: "VERIFIED",
    outcome: "Obstruction cleared",
    reporter: "Rico Mendoza",
    team: "Clearing Team",
    dispatchTime: "12 min 10 sec",
    closedTime: "9:04 AM",
    validator: "Joel Garcia",
    source: "Radio report",
    summary: "The fallen tree was cut and removed with no injuries reported.",
  },
  {
    id: "RSP-00758",
    date: "Jul 29",
    dateValue: "2026-07-29",
    incident: "Fire",
    location: "Kingking Highway",
    priority: "CRITICAL",
    status: "VERIFIED",
    outcome: "Fire contained",
    reporter: "Nina Cruz",
    team: "Fire Unit",
    dispatchTime: "4 min 55 sec",
    closedTime: "10:18 PM",
    validator: "Maria Santos",
    source: "Phone call",
    summary:
      "A small commercial fire was contained without spreading to nearby structures.",
  },
  {
    id: "RSP-00734",
    date: "Jul 18",
    dateValue: "2026-07-18",
    incident: "Flash Flood",
    location: "Magnaga Riverside",
    priority: "HIGH",
    status: "VALIDATED",
    outcome: "Area monitored",
    reporter: "Paolo Diaz",
    team: "Flood Unit",
    dispatchTime: "8 min 27 sec",
    closedTime: "7:35 PM",
    validator: "Joel Garcia",
    source: "App report",
    summary:
      "Water levels subsided and the area remained under monitoring for two hours.",
  },
];

const ranges = ["August 2026", "July 2026", "All dates"];
const priorities = ["CRITICAL", "HIGH", "MODERATE"];
const statuses = ["VERIFIED", "VALIDATED"];

function downloadFile(name: string, contents: string, type = "text/plain") {
  const url = URL.createObjectURL(new Blob([contents], { type }));
  const link = document.createElement("a");
  link.href = url;
  link.download = name;
  link.click();
  URL.revokeObjectURL(url);
}

export function HistoricalRecords() {
  const [query, setQuery] = useState("");
  const [range, setRange] = useState("August 2026");
  const [outcome, setOutcome] = useState("");
  const [priority, setPriority] = useState("");
  const [status, setStatus] = useState("");
  const [moreFilters, setMoreFilters] = useState(false);
  const [newestFirst, setNewestFirst] = useState(true);
  const [selectedId, setSelectedId] = useState(records[0].id);
  const [completeRecordOpen, setCompleteRecordOpen] = useState(false);
  const [exportCount, setExportCount] = useState(42);
  const [downloaded, setDownloaded] = useState("");

  const outcomes = [...new Set(records.map((record) => record.outcome))];
  const filtered = useMemo(() => {
    const normalizedQuery = query.trim().toLowerCase();
    return records
      .filter((record) => {
        const searchable =
          `${record.id} ${record.incident} ${record.location} ${record.reporter} ${record.outcome}`.toLowerCase();
        const inRange =
          range === "All dates" ||
          (range === "August 2026"
            ? record.dateValue.startsWith("2026-08")
            : record.dateValue.startsWith("2026-07"));
        return (
          (!normalizedQuery || searchable.includes(normalizedQuery)) &&
          inRange &&
          (!outcome || record.outcome === outcome) &&
          (!priority || record.priority === priority) &&
          (!status || record.status === status)
        );
      })
      .sort((a, b) =>
        newestFirst
          ? b.dateValue.localeCompare(a.dateValue)
          : a.dateValue.localeCompare(b.dateValue),
      );
  }, [query, range, outcome, priority, status, newestFirst]);

  const selected =
    filtered.find((record) => record.id === selectedId) ??
    filtered[0] ??
    records[0];
  const resolvedCount = filtered.filter((record) =>
    ["VERIFIED", "VALIDATED"].includes(record.status),
  ).length;

  const clearFilters = () => {
    setQuery("");
    setRange("All dates");
    setOutcome("");
    setPriority("");
    setStatus("");
  };

  const exportRecords = () => {
    const rows = [
      [
        "Report ID",
        "Date",
        "Incident",
        "Location",
        "Priority",
        "Status",
        "Outcome",
      ],
      ...filtered.map((record) => [
        record.id,
        record.dateValue,
        record.incident,
        record.location,
        record.priority,
        record.status,
        record.outcome,
      ]),
    ];
    downloadFile(
      "responda-historical-records.csv",
      rows.map((row) => row.map((cell) => `"${cell}"`).join(",")).join("\n"),
      "text/csv",
    );
    setExportCount((count) => count + 1);
  };

  const evidence = [
    [`${selected.id.toLowerCase()}-incident-summary.txt`, "2 KB"],
    [`${selected.id.toLowerCase()}-validation-log.txt`, "1 KB"],
    [`${selected.id.toLowerCase()}-dispatch-timeline.csv`, "1 KB"],
  ];

  return (
    <>
      <PageTitle
        title="Historical Records"
        subtitle="Audit resolved reports and retrieve evidence for planning or documentation."
        action="Export records"
        onAction={exportRecords}
      />

      <Card className="flex min-h-14 flex-wrap items-center gap-2 px-[10px] py-2">
        <label className="flex h-[38px] min-w-[210px] flex-1 items-center gap-2 rounded-[10px] border border-border bg-white px-[10px] text-muted focus-within:border-maroon focus-within:shadow-[0_0_0_3px_rgba(122,31,43,.08)] [&_input]:w-full [&_input]:border-0 [&_input]:bg-transparent [&_input]:text-[9px] [&_input]:outline-0">
          <Icon name="search" size={14} />
          <input
            value={query}
            onChange={(event) => setQuery(event.target.value)}
            placeholder="Search report ID or keyword"
          />
        </label>
        <SelectField
          label="Date range"
          value={range}
          options={ranges}
          onChange={setRange}
        />
        <SelectField
          label="All outcomes"
          value={outcome}
          options={outcomes}
          onChange={setOutcome}
        />
        <Button
          variant="secondary"
          icon="filter"
          onClick={() => setMoreFilters((open) => !open)}
        >
          {moreFilters ? "Hide filters" : "More filters"}
        </Button>
        {(query || outcome || priority || status || range !== "All dates") && (
          <Button variant="secondary" onClick={clearFilters}>
            Clear
          </Button>
        )}
        {moreFilters && (
          <div className="flex w-full flex-wrap gap-2 border-t border-border pt-2">
            <SelectField
              label="All priorities"
              value={priority}
              options={priorities}
              onChange={setPriority}
            />
            <SelectField
              label="All statuses"
              value={status}
              options={statuses}
              onChange={setStatus}
            />
          </div>
        )}
      </Card>

      <div className="grid grid-cols-4 gap-4 max-[1180px]:grid-cols-2 max-[650px]:grid-cols-1">
        <Metric
          icon="records"
          title="Matching records"
          value={String(filtered.length)}
          sub="Current filter result"
          tone="maroon"
        />
        <Metric
          icon="check"
          title="Resolved"
          value={String(resolvedCount)}
          sub={`${filtered.length ? Math.round((resolvedCount / filtered.length) * 100) : 0}% completion rate`}
          tone="green"
        />
        <Metric
          icon="download"
          title="Exported this month"
          value={String(exportCount)}
          sub="CSV record packages"
          tone="blue"
        />
        <Metric
          icon="shield"
          title="Retention status"
          value="Healthy"
          sub="No overdue disposals"
          tone="amber"
        />
      </div>

      {downloaded && (
        <div className="flex items-center justify-between rounded-xl bg-green-soft px-4 py-3 text-[10px] text-status-green">
          <b>{downloaded} downloaded.</b>
          <button
            className="border-0 bg-transparent text-status-green"
            onClick={() => setDownloaded("")}
          >
            ×
          </button>
        </div>
      )}

      <div className="grid grid-cols-[minmax(0,2.3fr)_342px] gap-4 max-[1180px]:grid-cols-1 [&>.card:first-child]:overflow-auto max-[1180px]:[&>.side-stack]:grid-cols-3 [&_.side-stack_.card>.button]:mt-2 [&_.side-stack_.card>.button]:w-full">
        <Card>
          <SectionHead
            title="Completed incident records"
            subtitle={`${filtered.length} matching records`}
            action={`Sort: ${newestFirst ? "newest" : "oldest"}`}
            onAction={() => setNewestFirst((newest) => !newest)}
          />
          <div className="min-w-[700px]">
            <div className="head grid min-h-7 w-full grid-cols-[88px_65px_1.45fr_90px_92px_1fr] items-center gap-[7px] rounded-lg border-0 border-b border-[#eee] bg-soft-gray px-2 py-[5px] text-left text-[7px] font-bold text-muted">
              <span>REPORT ID</span>
              <span>DATE</span>
              <span>INCIDENT / AREA</span>
              <span>PRIORITY</span>
              <span>STATUS</span>
              <span>OUTCOME</span>
            </div>
            {filtered.map((record) => (
              <button
                className={`grid min-h-[58px] w-full grid-cols-[88px_65px_1.45fr_90px_92px_1fr] items-center gap-[7px] border-0 border-b border-[#eee] px-2 py-[5px] text-left text-[9px] [&>b]:text-maroon [&_span_strong]:block [&_span_small]:mt-[3px] [&_span_small]:block [&_span_small]:text-muted ${selected.id === record.id ? "bg-blush" : "bg-white hover:bg-soft-gray"}`}
                key={record.id}
                onClick={() => setSelectedId(record.id)}
              >
                <b>{record.id}</b>
                <span>{record.date}</span>
                <span>
                  <strong>{record.incident}</strong>
                  <small>{record.location}</small>
                </span>
                <Badge tone={tone(record.priority)}>{record.priority}</Badge>
                <Badge tone="green">{record.status}</Badge>
                <span>{record.outcome}</span>
              </button>
            ))}
            {!filtered.length && (
              <p className="py-10 text-center text-[10px] text-muted">
                No historical records match these filters.
              </p>
            )}
          </div>
        </Card>

        <div className="side-stack flex flex-col gap-3 max-[1180px]:grid max-[1180px]:grid-cols-3 max-[900px]:grid-cols-1">
          <Card>
            <div className="flex items-center justify-between [&_h3]:m-0 [&_h3]:text-[13px] [&_p]:text-[8px] [&_p]:text-muted">
              <div>
                <h3>{selected.id}</h3>
                <p>
                  Closed {selected.date}, 2026 • {selected.closedTime}
                </p>
              </div>
              <Badge tone="green">{selected.status}</Badge>
            </div>
            <div className="my-[9px] grid gap-1 rounded-xl bg-blush px-[10px] py-[9px] [&>b]:text-[9px] [&>b]:text-maroon [&_strong]:text-xs [&_span]:text-[8px] [&_span]:text-muted">
              <b>{selected.incident.toUpperCase()}</b>
              <strong>{selected.location}</strong>
              <span>
                {selected.priority} priority • {selected.source}
              </span>
            </div>
            {[
              ["Reporter", selected.reporter],
              ["Response team", selected.team],
              ["Time to dispatch", selected.dispatchTime],
              ["Final outcome", selected.outcome],
            ].map(([label, value]) => (
              <div
                className="flex min-h-[27px] items-center justify-between gap-[10px] text-[9px] [&_span]:text-muted"
                key={label}
              >
                <span>{label}</span>
                <b className="text-right">{value}</b>
              </div>
            ))}
            <Button icon="reports" onClick={() => setCompleteRecordOpen(true)}>
              Open complete record
            </Button>
          </Card>

          <Card>
            <SectionHead
              title="Evidence & documents"
              subtitle="Attached to this record"
            />
            {evidence.map(([name, size], index) => (
              <button
                className="mt-1.5 flex h-[34px] w-full items-center gap-1.5 rounded-lg border-0 bg-soft-gray px-2 text-left text-[8px] text-maroon [&_b]:flex-1 [&_b]:text-[#1c1c1e] [&_span]:text-muted"
                key={name}
                onClick={() => {
                  const contents =
                    index === 2
                      ? `stage,time\nreported,${selected.date}\ndispatched,${selected.dispatchTime}\nclosed,${selected.closedTime}`
                      : `${selected.id}\n${selected.incident}\n${selected.location}\n${selected.summary}`;
                  downloadFile(
                    name,
                    contents,
                    index === 2 ? "text/csv" : "text/plain",
                  );
                  setDownloaded(name);
                }}
              >
                <Icon name="download" />
                <b>{name}</b>
                <span>{size}</span>
              </button>
            ))}
          </Card>

          <div className="grid gap-[5px] rounded-[14px] bg-blue-soft px-3 py-[10px] [&>b]:text-[9px] [&>b]:text-status-blue [&_strong]:text-[10px] [&_p]:m-0 [&_p]:text-[9px] [&_p]:leading-[1.5] [&_p]:text-muted">
            <b>AUDIT TRAIL</b>
            <strong>Validated by {selected.validator}</strong>
            <p>
              Status closed by Rescue Desk at {selected.closedTime}. Record is
              locked and retained under MDRRMO policy.
            </p>
          </div>
        </div>
      </div>

      {completeRecordOpen && (
        <div
          className="fixed inset-0 z-[110] grid place-items-center bg-[#23090f7a] p-5 backdrop-blur"
          onMouseDown={() => setCompleteRecordOpen(false)}
        >
          <Card className="max-h-[calc(100vh-40px)] w-[min(680px,100%)] overflow-y-auto p-6">
            <div onMouseDown={(event) => event.stopPropagation()}>
              <div className="flex items-start justify-between gap-4 border-b border-border pb-5">
                <div>
                  <span className="text-[9px] font-bold text-maroon">
                    {selected.id}
                  </span>
                  <h2 className="my-1 text-xl">{selected.incident}</h2>
                  <p className="m-0 text-[10px] text-muted">
                    {selected.location} • Closed {selected.date}, 2026
                  </p>
                </div>
                <button
                  className="grid size-10 shrink-0 place-items-center rounded-xl border-0 bg-soft-gray text-xl text-maroon"
                  onClick={() => setCompleteRecordOpen(false)}
                >
                  ×
                </button>
              </div>
              <div className="my-5 flex flex-col gap-4">
                <div>
                  <b className="text-[9px] text-muted">INCIDENT SUMMARY</b>
                  <p className="mb-0 text-[11px] leading-6">
                    {selected.summary}
                  </p>
                </div>
                {[
                  ["Priority", selected.priority],
                  ["Status", selected.status],
                  ["Source", selected.source],
                  ["Reporter", selected.reporter],
                  ["Response team", selected.team],
                  ["Dispatch time", selected.dispatchTime],
                  ["Final outcome", selected.outcome],
                  ["Validated by", selected.validator],
                ].map(([label, value]) => (
                  <div
                    className="flex justify-between gap-5 border-b border-border pb-3 text-[10px]"
                    key={label}
                  >
                    <span className="text-muted">{label}</span>
                    <b className="text-right">{value}</b>
                  </div>
                ))}
              </div>
              <div className="flex justify-end gap-2 border-t border-border pt-5">
                <Button
                  variant="secondary"
                  onClick={() => setCompleteRecordOpen(false)}
                >
                  Close
                </Button>
                <Button
                  icon="download"
                  onClick={() => {
                    downloadFile(
                      `${selected.id.toLowerCase()}-complete-record.txt`,
                      `${selected.id}\n${selected.incident}\n${selected.location}\n${selected.summary}\nOutcome: ${selected.outcome}`,
                    );
                    setDownloaded("Complete record");
                    setCompleteRecordOpen(false);
                  }}
                >
                  Download record
                </Button>
              </div>
            </div>
          </Card>
        </div>
      )}
    </>
  );
}
