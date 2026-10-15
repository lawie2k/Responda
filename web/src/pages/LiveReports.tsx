import { useEffect, useMemo, useRef, useState } from "react";
import { reports, tone } from "../data/reports";
import type { MapPoint } from "../data/mapData";
import { Icon } from "../components/Icon";
import { MiniMap } from "../components/Map";
import { ReportTable } from "../components/ReportTable";
import {
  Badge,
  Button,
  Card,
  PageTitle,
  SectionHead,
  SelectField,
} from "../components/ui";

function ReportDetail({
  report,
  onOpenValidation,
}: {
  report: (typeof reports)[number];
  onOpenValidation: () => void;
}) {
  const canVerify = report.status === "VERIFYING";
  const mapPoint: MapPoint | null = report.position
    ? {
        id: report.id,
        name: report.incident,
        location: report.location,
        position: report.position,
        barangay: report.barangay,
        priority:
          report.priority === "CRITICAL"
            ? "Critical"
            : report.priority === "HIGH"
              ? "High"
              : "Moderate",
        hoursAgo: 1,
      }
    : null;
  const mapFocus = mapPoint
    ? { label: mapPoint.location, position: mapPoint.position, zoom: 14 }
    : null;
  return (
    <Card
      className={
        "flex flex-col gap-[9px] max-[1180px]:grid max-[1180px]:grid-cols-2 max-[650px]:flex max-[1180px]:[&>.section-head]:col-span-full max-[1180px]:[&>.button]:col-span-full max-[1180px]:[&>.button-pair]:col-span-full [&_.map-canvas]:h-[136px]"
      }
    >
      <SectionHead
        title="Report details"
        subtitle={report.id.replace("RSP-", "RSP-2026-")}
      />
      <div
        className={
          "rounded-[13px] bg-red-soft p-[10px] [&>div]:flex [&>div]:items-center [&>div]:justify-between [&>div]:text-[9px] [&>div]:text-priority-red [&_h3]:my-[7px] [&_h3]:mb-[3px] [&_h3]:text-base [&_p]:m-0 [&_p]:text-[10px] [&_p]:text-muted"
        }
      >
        <div>
          <Badge tone={tone(report.priority)}>{report.priority}</Badge>
          <span>{report.time}</span>
        </div>
        <h3>{report.incident}</h3>
        <p>
          {report.location}
          {report.barangay ? ` • Barangay ${report.barangay}` : ""}
        </p>
      </div>
      <MiniMap
        points={mapPoint ? [mapPoint] : []}
        focus={mapFocus}
      />
      <div
        className={
          "rounded-xl bg-soft-gray px-[10px] py-2 [&>div]:flex [&>div]:min-h-[27px] [&>div]:items-center [&>div]:justify-between [&>div]:gap-[10px] [&>div]:text-[9px] [&_span]:text-muted"
        }
      >
        {[
          ["Reporter contact", "0917 123 4567"],
          [
            "People involved",
            report.incident === "Road Accident"
              ? "1 injured • 2 affected"
              : "Details awaiting validation",
          ],
          ["GPS accuracy", "±8 meters"],
          [
            "Detected barangay",
            report.barangay ?? "Outside Pantukan or not determined",
          ],
          ["Submitted via", "Mobile app"],
        ].map((x) => (
          <div key={x[0]}>
            <span>{x[0]}</span>
            <b>{x[1]}</b>
          </div>
        ))}
      </div>
      <div
        className={
          "grid gap-[5px] rounded-[13px] bg-blue-soft px-[10px] py-[9px] [&>b]:text-[9px] [&>b]:text-status-blue [&_p]:m-0 [&_p]:flex [&_p]:justify-between [&_p]:text-[9px] [&_p_span]:text-muted [&>small]:text-muted"
        }
      >
        <b>SYSTEM SUGGESTION</b>
        <p>
          <span>Classification</span>
          <strong>{report.incident} • 94%</strong>
        </p>
        <p>
          <span>Priority suggestion</span>
          <strong>
            {report.priority[0] + report.priority.slice(1).toLowerCase()}
          </strong>
        </p>
        <small>
          System suggestions are decision support and require MDRRMO review.
        </small>
      </div>
      {canVerify ? (
        <Button icon="verify" onClick={onOpenValidation}>
          Open in Report Validation
        </Button>
      ) : (
        <div
          className={
            "flex min-h-[52px] items-center gap-[10px] rounded-xl bg-green-soft px-[11px] py-[9px] text-status-green [&>.icon]:size-[30px] [&>.icon]:rounded-[10px] [&>.icon]:bg-white [&>.icon]:p-1.5 [&_div]:grid [&_div]:gap-0.5 [&_b]:text-[10px] [&_span]:text-[9px] [&_span]:text-muted"
          }
        >
          <Icon name="check" />
          <div>
            <b>
              {report.status === "DISPATCHED"
                ? "Report dispatched"
                : "Report validated"}
            </b>
            <span>Status updated in the active queue.</span>
          </div>
        </div>
      )}
    </Card>
  );
}

export function LiveReports({
  query,
  openModal,
  openValidation,
}: {
  query: string;
  openModal: () => void;
  openValidation: (reportId: string) => void;
}) {
  const allRows = reports;
  const [tab, setTab] = useState("All");
  const [localSearch, setLocalSearch] = useState("");
  const [incident, setIncident] = useState("");
  const [priorities, setPriorities] = useState<string[]>([]);
  const [filtersOpen, setFiltersOpen] = useState(false);
  const filtersRef = useRef<HTMLDivElement>(null);
  const [selectedId, setSelectedId] = useState(reports[0].id);
  const [feedback, setFeedback] = useState("");
  useEffect(() => {
    const closeFilters = (event: MouseEvent) => {
      if (!filtersRef.current?.contains(event.target as Node)) {
        setFiltersOpen(false);
      }
    };
    document.addEventListener("mousedown", closeFilters);
    return () => document.removeEventListener("mousedown", closeFilters);
  }, []);
  const rows = useMemo(
    () =>
      allRows.filter((r) => {
        const search = `${query} ${localSearch}`.trim().toLowerCase();
        return (
          (!search ||
            `${r.id} ${r.incident} ${r.location} ${r.barangay ?? ""}`
              .toLowerCase()
              .includes(search)) &&
          (!incident || r.incident === incident) &&
          (!priorities.length || priorities.includes(r.priority)) &&
          (tab === "All" ||
            (tab === "Critical" && r.priority === "CRITICAL") ||
            (tab === "Needs validation" && r.status === "VERIFYING") ||
            (tab === "Dispatched" && r.status === "DISPATCHED"))
        );
      }),
    [allRows, query, localSearch, incident, priorities, tab],
  );
  const selected =
    rows.find((report) => report.id === selectedId) ?? rows[0] ?? allRows[0];
  const counts = [
    allRows.length,
    allRows.filter((r) => r.status === "VERIFYING").length,
    allRows.filter((r) => r.priority === "CRITICAL").length,
    allRows.filter((r) => r.status === "DISPATCHED").length,
  ];
  const resetFilters = () => {
    setLocalSearch("");
    setIncident("");
    setPriorities([]);
    setTab("All");
  };
  const exportRows = () => {
    const headers = [
      "Reference",
      "Incident",
      "Location",
      "Detected barangay",
      "Priority",
      "Status",
      "Reported",
    ];
    const csv = [
      headers,
      ...rows.map((r) => [
        r.id,
        r.incident,
        r.location,
        r.barangay ?? "Not determined",
        r.priority,
        r.status,
        r.time,
      ]),
    ]
      .map((line) =>
        line
          .map((value) => `"${String(value).replaceAll('"', '""')}"`)
          .join(","),
      )
      .join("\n");
    const url = URL.createObjectURL(
      new Blob([csv], { type: "text/csv;charset=utf-8" }),
    );
    const link = document.createElement("a");
    link.href = url;
    link.download = "responda-live-reports.csv";
    link.style.display = "none";
    document.body.appendChild(link);
    link.click();
    link.remove();
    window.setTimeout(() => URL.revokeObjectURL(url), 1000);
    setFeedback(`${rows.length} reports exported to CSV.`);
    window.setTimeout(() => setFeedback(""), 2800);
  };
  return (
    <>
      <PageTitle
        title="Live Reports"
        subtitle="Monitor, filter, and open active incident submissions."
        action="Encode a report"
        onAction={openModal}
      />
      <Card
        className={
          "relative flex min-h-14 flex-wrap items-center gap-2 overflow-visible px-[10px] py-2 [&_.filter-search]:min-w-[210px]"
        }
      >
        <div
          className={
            "flex gap-[3px] rounded-[11px] bg-soft-gray p-[3px] [&>button]:h-8 [&>button]:rounded-[9px] [&>button]:border-0 [&>button]:bg-transparent [&>button]:px-3 [&>button]:text-[9px] [&>button]:text-muted [&>button.active]:bg-white [&>button.active]:text-maroon [&>button.active]:shadow-[0_2px_6px_#0001]"
          }
        >
          {["All", "Needs validation", "Critical", "Dispatched"].map((x, i) => (
            <button
              className={tab === x ? "active" : ""}
              onClick={() => setTab(x)}
              key={x}
            >
              {x} <b>{counts[i]}</b>
            </button>
          ))}
        </div>
        <label
          className={
            "filter-search flex h-[38px] min-w-[170px] items-center gap-[7px] rounded-[10px] border border-border bg-white px-[10px] text-muted [&_input]:w-full [&_input]:border-0 [&_input]:bg-transparent [&_input]:text-[9px] [&_input]:text-[#1c1c1e] [&_input]:outline-0 max-[650px]:w-[170px] max-[650px]:shrink-0"
          }
        >
          <Icon name="search" size={15} />
          <input
            aria-label="Search live reports"
            value={localSearch}
            onChange={(e) => setLocalSearch(e.target.value)}
            placeholder="Search reports"
          />
        </label>
        <SelectField
          label="All incident types"
          value={incident}
          onChange={setIncident}
          options={[...new Set(allRows.map((r) => r.incident))]}
        />
        <div className="relative ml-auto shrink-0" ref={filtersRef}>
          <Button
            variant="secondary"
            icon="filter"
            onClick={() => setFiltersOpen((value) => !value)}
          >
            Filters{priorities.length ? ` (${priorities.length})` : ""}
          </Button>
          {filtersOpen && (
            <div className="absolute right-0 top-[calc(100%+8px)] z-[80] w-[290px] rounded-[16px] border border-border bg-white p-4 shadow-[0_16px_40px_rgba(28,28,30,.16)] max-[650px]:right-[-4px] max-[650px]:w-[min(290px,calc(100vw-40px))]">
              <div className="mb-4 flex items-start justify-between gap-3">
                <div>
                  <b className="block text-[11px]">Filter reports</b>
                  <span className="text-[9px] text-muted">
                    Narrow the queue by priority
                  </span>
                </div>
                <button
                  className="grid size-7 place-items-center rounded-lg border-0 bg-soft-gray text-base text-maroon"
                  onClick={() => setFiltersOpen(false)}
                >
                  ×
                </button>
              </div>
              <span className="block text-[8px] font-bold tracking-[.04em] text-muted">
                PRIORITY LEVEL
              </span>
              <div className="my-2 grid grid-cols-3 gap-1.5 [&_button]:h-8 [&_button]:rounded-[9px] [&_button]:border [&_button]:border-border [&_button]:bg-white [&_button]:px-2 [&_button]:text-[8px] [&_button]:font-bold [&_button]:text-muted [&_button.active]:border-maroon [&_button.active]:bg-blush [&_button.active]:text-maroon">
                {["CRITICAL", "HIGH", "MODERATE"].map((value) => (
                  <button
                    className={priorities.includes(value) ? "active" : ""}
                    onClick={() =>
                      setPriorities((current) =>
                        current.includes(value)
                          ? current.filter((item) => item !== value)
                          : [...current, value],
                      )
                    }
                    key={value}
                  >
                    {value}
                  </button>
                ))}
              </div>
              <div className="mt-4 flex items-center justify-between border-t border-border pt-3">
                <span className="text-[9px] text-muted">
                  {rows.length} matching reports
                </span>
                <Button variant="secondary" onClick={resetFilters}>
                  Reset all
                </Button>
              </div>
            </div>
          )}
        </div>
      </Card>
      {feedback && (
        <div
          className={
            "flex min-h-[42px] items-center gap-2 rounded-xl bg-green-soft px-3 text-[10px] font-semibold text-status-green"
          }
          role="status"
        >
          <Icon name="check" />
          {feedback}
        </div>
      )}
      <div
        className={
          "grid grid-cols-[minmax(0,1fr)_348px] gap-4 max-[1180px]:grid-cols-1 [&>.card:first-child]:overflow-auto"
        }
      >
        <Card>
          <SectionHead
            title="Active report queue"
            subtitle={`${rows.length} shown • Sorted by latest`}
            action="Export CSV"
            onAction={exportRows}
          />
          {rows.length ? (
            <ReportTable
              rows={rows}
              onSelect={setSelectedId}
              selectedId={selected.id}
            />
          ) : (
            <div
              className={
                "flex min-h-[310px] flex-col items-center justify-center gap-[7px] text-center text-muted [&>.icon]:size-[42px] [&>.icon]:rounded-[14px] [&>.icon]:bg-soft-gray [&>.icon]:p-[11px] [&>.icon]:text-maroon [&_b]:text-xs [&_b]:text-[#1c1c1e] [&_span]:text-[9px] [&_.button]:mt-1.5"
              }
            >
              <Icon name="search" />
              <b>No reports match these filters</b>
              <span>Reset the filters or try a different search.</span>
              <Button variant="secondary" onClick={resetFilters}>
                Reset filters
              </Button>
            </div>
          )}
        </Card>
        <ReportDetail
          report={selected}
          onOpenValidation={() => openValidation(selected.id)}
        />
      </div>
    </>
  );
}
