import { useMemo, useState } from "react";
import {
  Badge,
  Button,
  Card,
  Metric,
  PageTitle,
  SectionHead,
  SelectField,
} from "../components/ui";
import type { Page } from "../types";

const colorClasses: Record<string, string> = {
  green: "bg-status-green",
  blue: "bg-status-blue",
  maroon: "bg-maroon",
};

const incidentTypes = [
  "Road Accident",
  "Flash Flood",
  "Medical",
  "Fire",
  "Landslide",
  "Fallen Tree",
];
const sampleLocations = [
  "Kingking Highway",
  "Magnaga Riverside",
  "Matiao Public Market",
  "Bongabong Slope",
  "Pantukan Highway",
];
const ranges = ["August 2026", "July 2026", "Last 7 days"];

type AnalyticsRecord = {
  day: number;
  incident: string;
  location: string;
  reports: number;
  validated: number;
  critical: number;
  response: number;
};

function makeRecords(range: string): AnalyticsRecord[] {
  const days = range === "Last 7 days" ? 7 : 31;
  const offset = range === "July 2026" ? 3 : range === "Last 7 days" ? 5 : 0;

  return Array.from({ length: days }, (_, index) => {
    const day = index + 1;
    const reports = 5 + ((day * 7 + offset) % 9);
    const validationRate = 0.68 + ((day + offset) % 5) * 0.035;
    return {
      day,
      incident: incidentTypes[(index + offset) % incidentTypes.length],
      location: sampleLocations[(index * 2 + offset) % sampleLocations.length],
      reports,
      validated: Math.min(reports, Math.round(reports * validationRate)),
      critical: (day + offset) % 4 === 0 ? 2 : (day + offset) % 3 === 0 ? 1 : 0,
      response: 7.1 + ((day * 3 + offset) % 8) * 0.42,
    };
  });
}

const sum = (values: number[]) =>
  values.reduce((total, value) => total + value, 0);

export function Analytics({ go }: { go?: (page: Page) => void }) {
  const [range, setRange] = useState("August 2026");
  const [incident, setIncident] = useState("");
  const [detailsOpen, setDetailsOpen] = useState(false);
  const [exported, setExported] = useState(false);

  const filtered = useMemo(
    () =>
      makeRecords(range).filter(
        (record) => !incident || record.incident === incident,
      ),
    [range, incident],
  );

  const totalReports = sum(filtered.map((record) => record.reports));
  const validated = sum(filtered.map((record) => record.validated));
  const critical = sum(filtered.map((record) => record.critical));
  const validationRate = totalReports
    ? Math.round((validated / totalReports) * 100)
    : 0;
  const medianResponse = filtered.length
    ? filtered.reduce((total, record) => total + record.response, 0) /
      filtered.length
    : 0;
  const maxReports = Math.max(1, ...filtered.map((record) => record.reports));

  const incidentMix = incidentTypes
    .map((name) => ({
      name,
      count: sum(
        filtered
          .filter((record) => record.incident === name)
          .map((record) => record.validated),
      ),
    }))
    .filter((item) => item.count > 0)
    .sort((a, b) => b.count - a.count);
  const topMix = incidentMix.slice(0, 3);
  const otherMix = sum(incidentMix.slice(3).map((item) => item.count));
  const mixItems = [
    ...topMix,
    ...(otherMix ? [{ name: "Other", count: otherMix }] : []),
  ];
  const mixColors = ["#d92d20", "#2563a8", "#1f8a4c", "#d5d5d9"];
  let mixCursor = 0;
  const mixGradient = mixItems.length
    ? `conic-gradient(${mixItems
        .map((item, index) => {
          const start = mixCursor;
          mixCursor += validated ? (item.count / validated) * 100 : 0;
          return `${mixColors[index]} ${start}% ${mixCursor}%`;
        })
        .join(",")})`
    : "#ececef";

  const exportReport = () => {
    const rows = [
      [
        "Day",
        "Incident type",
        "Location",
        "Reports",
        "Validated",
        "Critical",
        "Response minutes",
      ],
      ...filtered.map((record) => [
        record.day,
        record.incident,
        record.location,
        record.reports,
        record.validated,
        record.critical,
        record.response.toFixed(1),
      ]),
    ];
    const csv = rows
      .map((row) => row.map((cell) => `"${cell}"`).join(","))
      .join("\n");
    const url = URL.createObjectURL(new Blob([csv], { type: "text/csv" }));
    const link = document.createElement("a");
    link.href = url;
    link.download = `responda-analytics-${range.toLowerCase().replaceAll(" ", "-")}.csv`;
    link.click();
    URL.revokeObjectURL(url);
    setExported(true);
  };

  return (
    <>
      <PageTitle
        title="Analytics"
        subtitle="Measure patterns and improve MDRRMO response planning."
        action="Export report"
        onAction={exportReport}
      />
      <Card className="flex min-h-14 items-center gap-2 overflow-x-auto px-[10px] py-2">
        <SelectField
          label="Date range"
          value={range}
          options={ranges}
          onChange={setRange}
        />
        <SelectField
          label="All incident types"
          value={incident}
          options={incidentTypes}
          onChange={setIncident}
        />
        {incident && (
          <Button variant="secondary" onClick={() => setIncident("")}>
            Clear filters
          </Button>
        )}
        <i className="flex-1 max-[650px]:hidden" />
        <Badge tone={exported ? "blue" : "green"}>
          {exported ? "REPORT EXPORTED" : "DATA UPDATED"}
        </Badge>
      </Card>

      <div className="grid grid-cols-4 gap-4 max-[1180px]:grid-cols-2 max-[650px]:grid-cols-1">
        <Metric
          icon="reports"
          title="Total reports"
          value={String(totalReports)}
          sub={`${filtered.length} reporting days`}
          tone="maroon"
        />
        <Metric
          icon="check"
          title="Validated incidents"
          value={String(validated)}
          sub={`${validationRate}% validation rate`}
          tone="green"
        />
        <Metric
          icon="clock"
          title="Median response"
          value={`${medianResponse.toFixed(1)}m`}
          sub="Across matching incidents"
          tone="blue"
        />
        <Metric
          icon="alert"
          title="Critical incidents"
          value={String(critical)}
          sub={`${totalReports ? ((critical / totalReports) * 100).toFixed(1) : 0}% of reports`}
          tone="red"
        />
      </div>

      <div className="grid grid-cols-[minmax(0,1.8fr)_minmax(310px,1fr)] gap-4 max-[1180px]:grid-cols-1 max-[650px]:flex max-[650px]:flex-col">
        <Card>
          <SectionHead
            title="Incident volume"
            subtitle="Daily reports compared with validated incidents"
            action="View details"
            onAction={() => setDetailsOpen(true)}
          />
          <div className="my-2 flex gap-[18px] text-[9px] text-muted [&_span]:flex [&_span]:items-center [&_span]:gap-1 [&_i]:inline-block [&_i]:size-1.5 [&_i]:rounded-full">
            <span>
              <i className="bg-maroon" />
              All reports
            </span>
            <span>
              <i className="bg-status-green" />
              Validated
            </span>
          </div>
          <div className="flex h-[190px] items-end gap-[5px] overflow-hidden border-b border-border px-2 py-[10px] [background:repeating-linear-gradient(to_bottom,transparent_0,transparent_46px,#f0f0f1_47px)] [&>div]:flex [&>div]:h-full [&>div]:min-w-1 [&>div]:flex-1 [&>div]:items-end [&>div]:gap-px [&_i]:w-1/2 [&_i]:rounded-t [&_i]:bg-maroon [&_em]:w-1/2 [&_em]:rounded-t [&_em]:bg-status-green [&_em]:opacity-65">
            {filtered.map((record) => (
              <div
                key={`${record.day}-${record.incident}`}
                title={`Day ${record.day}: ${record.reports} reports, ${record.validated} validated`}
              >
                <i
                  style={{ height: `${(record.reports / maxReports) * 100}%` }}
                />
                <em
                  style={{
                    height: `${(record.validated / maxReports) * 100}%`,
                  }}
                />
              </div>
            ))}
          </div>
          <div className="mt-[7px] flex justify-between text-[8px] text-muted">
            <span>Day 1</span>
            <span>Day {Math.max(1, Math.ceil(filtered.length / 2))}</span>
            <span>Day {filtered.length || 1}</span>
          </div>
          {!filtered.length && (
            <p className="py-6 text-center text-[10px] text-muted">
              No data matches these filters.
            </p>
          )}
        </Card>

        <Card>
          <SectionHead
            title="Incident mix"
            subtitle="Share of validated incidents"
          />
          <div className="grid grid-cols-[125px_1fr] items-center gap-4 [&>div:last-child_p]:grid [&>div:last-child_p]:grid-cols-[7px_1fr_auto] [&>div:last-child_p]:gap-[7px] [&>div:last-child_p]:text-[9px] [&_i]:inline-block [&_i]:size-1.5 [&_i]:rounded-full">
            <div
              className="relative grid size-[116px] place-items-center rounded-full before:absolute before:size-[72px] before:rounded-full before:bg-white [&>span]:relative [&>span]:text-center [&>span]:text-[7px] [&>span]:text-muted [&_b]:block [&_b]:text-lg [&_b]:text-[#1c1c1e]"
              style={{ background: mixGradient }}
            >
              <span>
                <b>{validationRate}%</b>VALIDATED
              </span>
            </div>
            <div>
              {mixItems.map((item, index) => (
                <p key={item.name}>
                  <i style={{ backgroundColor: mixColors[index] }} />
                  <span>{item.name}</span>
                  <b>
                    {validated ? Math.round((item.count / validated) * 100) : 0}
                    %
                  </b>
                </p>
              ))}
              {!mixItems.length && (
                <p className="text-muted">No matching data</p>
              )}
            </div>
          </div>
          <div className="rounded-[13px] bg-blush p-[10px] [&>b]:text-[8px] [&>b]:text-maroon [&_p]:text-[10px] [&_p]:leading-[1.5]">
            <b>OPERATIONAL INSIGHT</b>
            <p>
              {topMix[0]
                ? `${topMix[0].name} is the most common validated incident for the selected filters.`
                : "Select a wider filter range to generate an operational insight."}
            </p>
          </div>
        </Card>
      </div>

      <div className="grid grid-cols-2 gap-4 max-[1180px]:grid-cols-1 max-[650px]:flex max-[650px]:flex-col">
        <Card>
          <SectionHead
            title="Response performance"
            subtitle="Target completion by response stage"
          />
          {[
            [
              "Validation within 5 min",
              Math.min(100, validationRate + 7),
              "Target 85%",
              "maroon",
            ],
            [
              "Dispatch within 10 min",
              Math.max(0, Math.min(100, Math.round(95 - medianResponse * 2))),
              "Target 80%",
              "blue",
            ],
            [
              "On scene within 20 min",
              Math.max(0, Math.min(100, Math.round(90 - medianResponse * 2))),
              "Target 75%",
              "green",
            ],
          ].map((item) => (
            <div
              className="grid h-[38px] grid-cols-[190px_1fr_38px] items-center gap-[10px] max-[650px]:grid-cols-[140px_1fr_35px] [&_span]:grid [&_b]:text-[9px] [&_small]:text-[8px] [&_small]:text-muted"
              key={String(item[0])}
            >
              <span>
                <b>{item[0]}</b>
                <small>{item[2]}</small>
              </span>
              <div className="h-[7px] overflow-hidden rounded-[10px] bg-soft-gray [&_i]:block [&_i]:h-full [&_i]:rounded-[10px]">
                <i
                  className={colorClasses[String(item[3])]}
                  style={{ width: `${item[1]}%` }}
                />
              </div>
              <strong>{item[1]}%</strong>
            </div>
          ))}
        </Card>
        <Card>
          <SectionHead
            title="Operational summary"
            subtitle="Current performance for the selected period"
            action="Open map"
            onAction={() => go?.("Incident Map")}
          />
          {[
            ["Critical reports", critical],
            ["Other priority reports", Math.max(0, totalReports - critical)],
            ["Validated reports", validated],
            [
              "Average daily volume",
              filtered.length ? Math.round(totalReports / filtered.length) : 0,
            ],
          ].map(([label, value], index) => (
            <div
              className="grid h-[31px] grid-cols-[28px_1fr_90px] items-center text-[9px] [&>b]:grid [&>b]:size-[23px] [&>b]:place-items-center [&>b]:rounded-lg [&>b]:bg-soft-gray [&>b]:text-maroon [&_span]:text-right [&_span]:text-muted"
              key={String(label)}
            >
              <b>{index + 1}</b>
              <strong>{label}</strong>
              <span>{value}</span>
            </div>
          ))}
        </Card>
      </div>

      {detailsOpen && (
        <div
          className="fixed inset-0 z-[110] grid place-items-center bg-[#23090f7a] p-5 backdrop-blur"
          onMouseDown={() => setDetailsOpen(false)}
        >
          <Card className="max-h-[calc(100vh-40px)] w-[min(720px,100%)] overflow-auto p-6">
            <div onMouseDown={(event) => event.stopPropagation()}>
              <div className="flex items-start justify-between gap-4 border-b border-border pb-4">
                <div>
                  <h2 className="m-0 text-lg">Incident volume details</h2>
                  <p className="mt-1 text-[10px] text-muted">
                    {range} • {totalReports} matching reports
                  </p>
                </div>
                <button
                  className="grid size-10 shrink-0 place-items-center rounded-xl border-0 bg-soft-gray text-xl text-maroon"
                  onClick={() => setDetailsOpen(false)}
                >
                  ×
                </button>
              </div>
              <div className="mt-4 min-w-[520px]">
                <div className="grid grid-cols-[55px_1fr_1.2fr_70px_70px] gap-3 rounded-lg bg-soft-gray px-3 py-2 text-[8px] font-bold text-muted">
                  <span>DAY</span>
                  <span>INCIDENT</span>
                  <span>LOCATION</span>
                  <span>REPORTS</span>
                  <span>VALIDATED</span>
                </div>
                {filtered.map((record) => (
                  <div
                    className="grid grid-cols-[55px_1fr_1.2fr_70px_70px] gap-3 border-b border-border px-3 py-3 text-[9px]"
                    key={`detail-${record.day}`}
                  >
                    <span>{record.day}</span>
                    <b>{record.incident}</b>
                    <span>{record.location}</span>
                    <span>{record.reports}</span>
                    <span>{record.validated}</span>
                  </div>
                ))}
              </div>
              <div className="mt-5 flex justify-end">
                <Button
                  variant="secondary"
                  onClick={() => setDetailsOpen(false)}
                >
                  Close
                </Button>
              </div>
            </div>
          </Card>
        </div>
      )}
    </>
  );
}
