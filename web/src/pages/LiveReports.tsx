import { useEffect, useMemo, useRef, useState } from "react";
import {
  createAdminIncident,
  linkAdminReportToIncident,
  type AdminIncidentListItem,
  type AdminReportDetail,
  type AdminUser,
  type ReportPriority,
} from "../api/respondaApi";
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
import { tone, toReport, type Report } from "../data/reports";
import type { MapPoint } from "../data/mapData";
import { useAdminIncidents } from "../hooks/useAdminIncidents";
import { useAdminReportDetail, useAdminReports } from "../hooks/useAdminReports";

type ReportTab = "All" | "Needs validation" | "Critical" | "Dispatched";

const sourceLabel = (source: Report["source"]) =>
  source === "app_api"
    ? "Mobile app (online)"
    : source === "app_sms"
      ? "Mobile app (SMS)"
      : "Manually encoded";

function IncidentManagement({
  report,
  detail,
  incidents,
  incidentStatus,
  incidentError,
  retryIncidents,
  onComplete,
}: {
  report: Report;
  detail: AdminReportDetail;
  incidents: AdminIncidentListItem[];
  incidentStatus: "idle" | "loading" | "ready" | "error";
  incidentError: string | null;
  retryIncidents: () => void;
  onComplete: (message: string) => void;
}) {
  const [summary, setSummary] = useState(
    `${report.incident} at ${report.location}`,
  );
  const [incidentId, setIncidentId] = useState("");
  const [submitting, setSubmitting] = useState<"create" | "link" | null>(null);
  const [error, setError] = useState("");

  const createIncident = async () => {
    const normalizedSummary = summary.trim();
    if (!normalizedSummary) {
      setError("Add a short operational summary before creating the incident.");
      return;
    }
    setSubmitting("create");
    setError("");
    try {
      const result = await createAdminIncident({
        report_id: detail.report_id,
        expected_report_updated_at: detail.updated_at,
        summary: normalizedSummary,
      });
      onComplete(
        `${report.reference} created incident INC-${result.incident_id.slice(0, 8).toUpperCase()}.`,
      );
    } catch (caught) {
      setError(
        caught instanceof Error ? caught.message : "The incident could not be created.",
      );
    } finally {
      setSubmitting(null);
    }
  };

  const linkIncident = async () => {
    if (!incidentId) {
      setError("Select an existing incident first.");
      return;
    }
    setSubmitting("link");
    setError("");
    try {
      const result = await linkAdminReportToIncident(incidentId, {
        report_id: detail.report_id,
        expected_report_updated_at: detail.updated_at,
      });
      onComplete(
        `${report.reference} was linked to INC-${result.incident_id.slice(0, 8).toUpperCase()}.`,
      );
    } catch (caught) {
      setError(
        caught instanceof Error
          ? caught.message
          : "The report could not be linked to the incident.",
      );
    } finally {
      setSubmitting(null);
    }
  };

  return (
    <div className="grid gap-3 rounded-[13px] border border-[#ead3d7] bg-blush p-3">
      <div>
        <b className="block text-[10px] text-maroon">CONFIRM AS INCIDENT</b>
        <span className="text-[9px] leading-[1.45] text-muted">
          Create a new operational incident or connect this verified report to a
          matching active incident.
        </span>
      </div>
      <label className="grid gap-1.5 text-[9px] font-semibold text-[#1c1c1e]">
        New incident summary
        <textarea
          className="min-h-20 resize-y rounded-[10px] border border-border bg-white p-[10px] text-[10px] font-normal outline-0 focus:border-maroon"
          value={summary}
          maxLength={2000}
          disabled={submitting !== null}
          onChange={(event) => setSummary(event.target.value)}
        />
      </label>
      <Button
        icon="plus"
        disabled={submitting !== null || !summary.trim()}
        onClick={() => void createIncident()}
      >
        {submitting === "create" ? "Creating…" : "Create incident"}
      </Button>
      <div className="border-t border-[#dfc4c9] pt-3">
        <b className="mb-2 block text-[9px] text-muted">OR LINK EXISTING</b>
        {incidentStatus === "error" ? (
          <div className="grid gap-2 rounded-[10px] bg-red-soft p-2 text-[9px] text-priority-red">
            <span>{incidentError}</span>
            <Button variant="secondary" onClick={retryIncidents}>
              Reload incidents
            </Button>
          </div>
        ) : (
          <div className="grid gap-2">
            <SelectField
              label={
                incidentStatus === "loading"
                  ? "Loading matching incidents…"
                  : incidents.length
                    ? "Select matching incident"
                    : "No matching active incidents"
              }
              value={incidentId}
              options={incidents.map((incident) => ({
                value: incident.incident_id,
                label: `INC-${incident.incident_id.slice(0, 8).toUpperCase()} • ${incident.summary}`,
              }))}
              onChange={(value) => {
                setIncidentId(value);
                setError("");
              }}
            />
            <Button
              variant="secondary"
              disabled={submitting !== null || !incidentId}
              onClick={() => void linkIncident()}
            >
              {submitting === "link" ? "Linking…" : "Link to selected incident"}
            </Button>
          </div>
        )}
      </div>
      {error && (
        <div className="rounded-[10px] bg-red-soft px-3 py-2 text-[9px] text-priority-red" role="alert">
          {error}
        </div>
      )}
    </div>
  );
}

function ReportDetail({
  report,
  detail,
  detailStatus,
  detailError,
  userRole,
  incidents,
  incidentStatus,
  incidentError,
  retryIncidents,
  onOpenValidation,
  onIncidentChanged,
}: {
  report: Report;
  detail: AdminReportDetail | null;
  detailStatus: "idle" | "loading" | "ready" | "error";
  detailError: string | null;
  userRole: AdminUser["role"];
  incidents: AdminIncidentListItem[];
  incidentStatus: "idle" | "loading" | "ready" | "error";
  incidentError: string | null;
  retryIncidents: () => void;
  onOpenValidation: () => void;
  onIncidentChanged: (message: string) => void;
}) {
  const canVerify = report.verificationStatus === "pending";
  const canManageIncidents = userRole === "admin" || userRole === "dispatcher";
  const isReadyForIncident = Boolean(
    detail?.verification_status === "verified" &&
      detail.status === "under_review" &&
      !detail.incident,
  );
  const mapPoint: MapPoint | null = report.position
    ? {
        id: report.reference,
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
        hoursAgo: 0,
      }
    : null;
  const assessment = detail?.priority_assessments[0];
  const reporterContact = detail
    ? detail.reporter.phone_number || detail.reporter.email || "Not provided"
    : "Loading…";

  return (
    <Card className="flex flex-col gap-[9px] max-[1180px]:grid max-[1180px]:grid-cols-2 max-[650px]:flex max-[1180px]:[&>.section-head]:col-span-full max-[1180px]:[&>.button]:col-span-full [&_.map-canvas]:h-[136px]">
      <SectionHead title="Report details" subtitle={report.reference} />
      <div className="rounded-[13px] bg-red-soft p-[10px] [&>div]:flex [&>div]:items-center [&>div]:justify-between [&>div]:text-[9px] [&>div]:text-priority-red [&_h3]:my-[7px] [&_h3]:mb-[3px] [&_h3]:text-base [&_p]:m-0 [&_p]:text-[10px] [&_p]:text-muted">
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
      <p className="m-0 rounded-xl bg-soft-gray px-[10px] py-2 text-[9px] leading-[1.55] text-[#3d3d42]">
        {report.description}
      </p>
      <MiniMap
        points={mapPoint ? [mapPoint] : []}
        focus={
          mapPoint
            ? { label: mapPoint.location, position: mapPoint.position, zoom: 14 }
            : null
        }
      />
      {detailStatus === "error" ? (
        <div className="rounded-xl bg-red-soft px-[10px] py-3 text-[9px] text-priority-red">
          {detailError}
        </div>
      ) : (
        <div className="rounded-xl bg-soft-gray px-[10px] py-2 [&>div]:flex [&>div]:min-h-[27px] [&>div]:items-center [&>div]:justify-between [&>div]:gap-[10px] [&>div]:text-[9px] [&_span]:text-muted">
          {[
            ["Reporter", detail?.reporter.full_name ?? "Loading…"],
            ["Reporter contact", reporterContact],
            [
              "People need help",
              detail ? (detail.people_need_help ? "Yes" : "No") : "Loading…",
            ],
            [
              "GPS accuracy",
              detail?.location?.accuracy_meters != null
                ? `±${detail.location.accuracy_meters} meters`
                : "Not provided",
            ],
            ["Detected barangay", report.barangay ?? "Not determined"],
            ["Submitted via", sourceLabel(report.source)],
          ].map(([label, value]) => (
            <div key={label}>
              <span>{label}</span>
              <b className="text-right">{value}</b>
            </div>
          ))}
        </div>
      )}
      <div className="grid gap-[5px] rounded-[13px] bg-blue-soft px-[10px] py-[9px] [&>b]:text-[9px] [&>b]:text-status-blue [&_p]:m-0 [&_p]:flex [&_p]:justify-between [&_p]:text-[9px] [&_p_span]:text-muted [&>small]:text-muted">
        <b>SYSTEM SUGGESTION</b>
        <p>
          <span>Classification</span>
          <strong>{report.incident}</strong>
        </p>
        <p>
          <span>Priority suggestion</span>
          <strong>
            {assessment?.suggested_priority.toUpperCase() ?? report.priority}
          </strong>
        </p>
        <p>
          <span>Model confidence</span>
          <strong>
            {assessment
              ? `${Math.round(assessment.confidence * 100)}%`
              : "Not available"}
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
      ) : detail?.incident ? (
        <div className="flex min-h-[62px] items-center gap-[10px] rounded-xl bg-green-soft px-[11px] py-[9px] text-status-green [&>.icon]:size-[30px] [&>.icon]:rounded-[10px] [&>.icon]:bg-white [&>.icon]:p-1.5 [&_div]:grid [&_div]:gap-0.5 [&_b]:text-[10px] [&_span]:text-[9px] [&_span]:text-muted">
          <Icon name="check" />
          <div>
            <b>Linked to INC-{detail.incident.incident_id.slice(0, 8).toUpperCase()}</b>
            <span>{detail.incident.summary}</span>
          </div>
        </div>
      ) : isReadyForIncident && canManageIncidents && detail ? (
        <IncidentManagement
          key={report.id}
          report={report}
          detail={detail}
          incidents={incidents}
          incidentStatus={incidentStatus}
          incidentError={incidentError}
          retryIncidents={retryIncidents}
          onComplete={onIncidentChanged}
        />
      ) : isReadyForIncident ? (
        <div className="rounded-xl bg-amber-soft px-[11px] py-[10px] text-[9px] text-priority-amber">
          This report is verified. An administrator or dispatcher must create or
          link its incident.
        </div>
      ) : (
        <div className="flex min-h-[52px] items-center gap-[10px] rounded-xl bg-green-soft px-[11px] py-[9px] text-status-green [&>.icon]:size-[30px] [&>.icon]:rounded-[10px] [&>.icon]:bg-white [&>.icon]:p-1.5 [&_div]:grid [&_div]:gap-0.5 [&_b]:text-[10px] [&_span]:text-[9px] [&_span]:text-muted">
          <Icon name="check" />
          <div>
            <b>{report.status.replaceAll("_", " ")}</b>
            <span>Status from the live report record.</span>
          </div>
        </div>
      )}
    </Card>
  );
}

export function LiveReports({
  query,
  summaryReports,
  openModal,
  openValidation,
  userRole,
  onReportsChanged,
}: {
  query: string;
  summaryReports: Report[];
  openModal: () => void;
  openValidation: (reportId: string) => void;
  userRole: AdminUser["role"];
  onReportsChanged: () => void;
}) {
  const [tab, setTab] = useState<ReportTab>("All");
  const [localSearch, setLocalSearch] = useState("");
  const [search, setSearch] = useState("");
  const [incidentTypeId, setIncidentTypeId] = useState("");
  const [priorities, setPriorities] = useState<Report["priority"][]>([]);
  const [filtersOpen, setFiltersOpen] = useState(false);
  const [selectedId, setSelectedId] = useState<string | null>(null);
  const [feedback, setFeedback] = useState("");
  const [page, setPage] = useState(1);
  const filtersRef = useRef<HTMLDivElement>(null);

  useEffect(() => {
    const searchValue = `${query} ${localSearch}`.trim().replace(/^RSP-/i, "");
    const timer = window.setTimeout(() => {
      setSearch(searchValue);
      setPage(1);
    }, 250);
    return () => window.clearTimeout(timer);
  }, [localSearch, query]);

  useEffect(() => {
    const closeFilters = (event: MouseEvent) => {
      if (!filtersRef.current?.contains(event.target as Node)) {
        setFiltersOpen(false);
      }
    };
    document.addEventListener("mousedown", closeFilters);
    return () => document.removeEventListener("mousedown", closeFilters);
  }, []);

  const reportQuery = useAdminReports({
    page,
    pageSize: 20,
    search: search || undefined,
    incidentTypeId: incidentTypeId || undefined,
    reportStatuses: ["new", "under_review", "linked"],
    verificationStatuses: tab === "Needs validation" ? ["pending"] : undefined,
    priorities:
      tab === "Critical"
        ? ["critical"]
        : (priorities.map((value) => value.toLowerCase()) as ReportPriority[]),
    incidentStatuses: tab === "Dispatched" ? ["dispatched"] : undefined,
  });
  const rows = useMemo(
    () => reportQuery.data?.items.map(toReport) ?? [],
    [reportQuery.data],
  );

  const effectiveSelectedId = rows.some((report) => report.id === selectedId)
    ? selectedId
    : (rows[0]?.id ?? null);
  const selected =
    rows.find((report) => report.id === effectiveSelectedId) ?? null;
  const detailState = useAdminReportDetail(selected?.id ?? null);
  const canManageSelectedIncident = Boolean(
    (userRole === "admin" || userRole === "dispatcher") &&
      detailState.data?.verification_status === "verified" &&
      detailState.data.status === "under_review" &&
      !detailState.data.incident,
  );
  const incidentQuery = useAdminIncidents(
    {
      pageSize: 100,
      incidentTypeId: selected?.incidentTypeId,
      statuses: ["open", "dispatched", "responding"],
    },
    canManageSelectedIncident,
  );
  const counts = [
    summaryReports.length,
    summaryReports.filter((report) => report.status === "VERIFYING").length,
    summaryReports.filter((report) => report.priority === "CRITICAL").length,
    summaryReports.filter((report) => report.status === "DISPATCHED").length,
  ];
  const incidentTypes = [
    ...new Map(
      summaryReports.map((report) => [
        report.incidentTypeId,
        { label: report.incident, value: report.incidentTypeId },
      ]),
    ).values(),
  ];

  const resetFilters = () => {
    setLocalSearch("");
    setIncidentTypeId("");
    setPriorities([]);
    setTab("All");
    setPage(1);
  };
  const exportRows = () => {
    const csv = [
      [
        "Reference",
        "Incident",
        "Location",
        "Detected barangay",
        "Priority",
        "Status",
        "Reported",
      ],
      ...rows.map((report) => [
        report.reference,
        report.incident,
        report.location,
        report.barangay ?? "Not determined",
        report.priority,
        report.status,
        report.time,
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
    link.click();
    window.setTimeout(() => URL.revokeObjectURL(url), 1000);
    setFeedback(`${rows.length} reports from this page exported to CSV.`);
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
      <Card className="relative flex min-h-14 flex-wrap items-center gap-2 overflow-visible px-[10px] py-2 [&_.filter-search]:min-w-[210px]">
        <div className="flex gap-[3px] rounded-[11px] bg-soft-gray p-[3px] [&>button]:h-8 [&>button]:rounded-[9px] [&>button]:border-0 [&>button]:bg-transparent [&>button]:px-3 [&>button]:text-[9px] [&>button]:text-muted [&>button.active]:bg-white [&>button.active]:text-maroon [&>button.active]:shadow-[0_2px_6px_#0001]">
          {(
            ["All", "Needs validation", "Critical", "Dispatched"] as ReportTab[]
          ).map((value, index) => (
            <button
              className={tab === value ? "active" : ""}
              onClick={() => {
                setTab(value);
                setPage(1);
              }}
              key={value}
            >
              {value} <b>{counts[index]}</b>
            </button>
          ))}
        </div>
        <label className="filter-search flex h-[38px] min-w-[170px] items-center gap-[7px] rounded-[10px] border border-border bg-white px-[10px] text-muted [&_input]:w-full [&_input]:border-0 [&_input]:bg-transparent [&_input]:text-[9px] [&_input]:text-[#1c1c1e] [&_input]:outline-0 max-[650px]:w-[170px] max-[650px]:shrink-0">
          <Icon name="search" size={15} />
          <input
            aria-label="Search live reports"
            value={localSearch}
            onChange={(event) => setLocalSearch(event.target.value)}
            placeholder="Search reports"
          />
        </label>
        <SelectField
          label="All incident types"
          value={incidentTypeId}
          onChange={(value) => {
            setIncidentTypeId(value);
            setPage(1);
          }}
          options={incidentTypes}
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
            <div className="absolute right-0 top-[calc(100%+8px)] z-[80] w-[290px] rounded-[16px] border border-border bg-white p-4 shadow-[0_16px_40px_rgba(28,28,30,.16)]">
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
              <div className="my-2 grid grid-cols-4 gap-1.5 [&_button]:h-8 [&_button]:rounded-[9px] [&_button]:border [&_button]:border-border [&_button]:bg-white [&_button]:px-1 [&_button]:text-[8px] [&_button]:font-bold [&_button]:text-muted [&_button.active]:border-maroon [&_button.active]:bg-blush [&_button.active]:text-maroon">
                {(
                  ["CRITICAL", "HIGH", "MEDIUM", "LOW"] as Report["priority"][]
                ).map((value) => (
                  <button
                    className={priorities.includes(value) ? "active" : ""}
                    onClick={() => {
                      setPriorities((current) =>
                        current.includes(value)
                          ? current.filter((item) => item !== value)
                          : [...current, value],
                      );
                      setPage(1);
                    }}
                    key={value}
                  >
                    {value}
                  </button>
                ))}
              </div>
              <div className="mt-4 flex items-center justify-between border-t border-border pt-3">
                <span className="text-[9px] text-muted">
                  {reportQuery.data?.total ?? 0} matching reports
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
          className="flex min-h-[42px] items-center gap-2 rounded-xl bg-green-soft px-3 text-[10px] font-semibold text-status-green"
          role="status"
        >
          <Icon name="check" />
          {feedback}
        </div>
      )}
      <div className="grid grid-cols-[minmax(0,1fr)_348px] gap-4 max-[1180px]:grid-cols-1 [&>.card:first-child]:overflow-auto">
        <Card>
          <SectionHead
            title="Active report queue"
            subtitle={`${reportQuery.data?.total ?? 0} matching • Sorted by latest`}
            action="Export page CSV"
            onAction={exportRows}
          />
          {reportQuery.status === "error" && !rows.length ? (
            <div className="flex min-h-[310px] flex-col items-center justify-center gap-2 text-center text-priority-red">
              <Icon name="alert" />
              <b className="text-xs">Report queue unavailable</b>
              <span className="text-[9px]">{reportQuery.error}</span>
              <Button variant="secondary" onClick={reportQuery.refetch}>
                Try again
              </Button>
            </div>
          ) : reportQuery.status === "loading" && !rows.length ? (
            <div className="grid min-h-[310px] place-items-center text-[10px] text-muted">
              Loading reports…
            </div>
          ) : rows.length ? (
            <>
              <ReportTable
                rows={rows}
                onSelect={setSelectedId}
                selectedId={selected?.id}
              />
              <div className="mt-3 flex items-center justify-between border-t border-border pt-3 text-[9px] text-muted">
                <span>
                  Page {reportQuery.data?.page ?? page} of{" "}
                  {Math.max(reportQuery.data?.total_pages ?? 0, 1)}
                </span>
                <div className="flex gap-2">
                  <Button
                    variant="secondary"
                    disabled={page <= 1}
                    onClick={() => setPage((value) => Math.max(1, value - 1))}
                  >
                    Previous
                  </Button>
                  <Button
                    variant="secondary"
                    disabled={page >= (reportQuery.data?.total_pages ?? 0)}
                    onClick={() => setPage((value) => value + 1)}
                  >
                    Next
                  </Button>
                </div>
              </div>
            </>
          ) : (
            <div className="flex min-h-[310px] flex-col items-center justify-center gap-[7px] text-center text-muted">
              <Icon name="search" />
              <b className="text-xs text-[#1c1c1e]">
                No reports match these filters
              </b>
              <span className="text-[9px]">
                The database has no matching report records.
              </span>
              <Button variant="secondary" onClick={resetFilters}>
                Reset filters
              </Button>
            </div>
          )}
        </Card>
        {selected ? (
          <ReportDetail
            report={selected}
            detail={detailState.data}
            detailStatus={detailState.status}
            detailError={detailState.error}
            userRole={userRole}
            incidents={incidentQuery.data?.items ?? []}
            incidentStatus={incidentQuery.status}
            incidentError={incidentQuery.error}
            retryIncidents={incidentQuery.refetch}
            onOpenValidation={() => openValidation(selected.id)}
            onIncidentChanged={(message) => {
              setFeedback(message);
              reportQuery.refetch();
              detailState.refetch();
              incidentQuery.refetch();
              onReportsChanged();
            }}
          />
        ) : (
          <Card className="grid min-h-[310px] place-items-center px-6 text-center text-[10px] text-muted">
            Select a report to view its protected details.
          </Card>
        )}
      </div>
    </>
  );
}
