import { useEffect, useRef, useState } from "react";
import {
  exportHistory,
  getHistoryTypes,
  type HistoricalIncident,
  type HistoryFilters,
  type HistoryPage,
} from "../api/adminHistory";
import type { AdminIncidentType } from "../api/respondaApi";
import { Icon } from "../components/Icon";
import { Badge, Button, Card, PageTitle, SectionHead, SelectField } from "../components/ui";
import { tone } from "../data/reports";
import { useAdminHistory, useAdminHistoryDetail } from "../hooks/useAdminHistory";

const formatDate = (value: string | null, compact = false) => value
  ? new Intl.DateTimeFormat("en-PH", {
      timeZone: "Asia/Manila",
      year: "numeric", month: "short", day: "numeric",
      ...(compact ? {} : { hour: "numeric", minute: "2-digit" }),
    }).format(new Date(value))
  : "Not recorded";

const sourceNames = { app_api: "Mobile app", app_sms: "App SMS", manual: "Manual intake" };
const eventNames: Record<string, string> = {
  "report.created": "Report received",
  "report.reviewed": "Staff review recorded",
  "report.incident_created": "Incident created from report",
  "report.incident_linked": "Report linked to incident",
  "response.assigned": "Response team assigned",
  "response.acknowledged": "Assignment acknowledged",
  "response.responding": "Team responding",
  "response.completed": "Response completed",
  "response.cancelled": "Assignment cancelled",
};

function Pager({
  data, onPage, label,
}: {
  data: Omit<HistoryPage<unknown>, "items">;
  onPage: (page: number) => void;
  label: string;
}) {
  if (!data.total_pages) return null;
  return (
    <nav aria-label={`${label} pagination`} className="mt-4 flex flex-wrap items-center justify-between gap-2 border-t border-border pt-3">
      <span className="text-[9px] text-muted">
        Page {data.page} of {data.total_pages} · {data.total} {label.toLowerCase()}
      </span>
      <div className="flex gap-2">
        <button
          className="rounded-[6px] border border-border bg-white px-3 py-2 text-[9px] disabled:opacity-40"
          aria-label={`Previous ${label.toLowerCase()} page`}
          disabled={data.page <= 1}
          onClick={() => onPage(data.page - 1)}
        >Previous</button>
        <button
          className="rounded-[6px] border border-border bg-white px-3 py-2 text-[9px] disabled:opacity-40"
          aria-label={`Next ${label.toLowerCase()} page`}
          disabled={data.page >= data.total_pages}
          onClick={() => onPage(data.page + 1)}
        >Next</button>
      </div>
    </nav>
  );
}

function ErrorNotice({ message, retry }: { message: string; retry?: () => void }) {
  return (
    <div role="alert" className="flex items-center gap-3 rounded-[7px] border border-[#efc7c4] bg-red-soft px-3 py-3 text-[10px] text-priority-red">
      <Icon name="alert" size={16} />
      <span className="min-w-0 flex-1">{message}</span>
      {retry && <Button variant="secondary" onClick={retry}>Retry</Button>}
    </div>
  );
}

function RecordDetails({ record }: { record: HistoricalIncident }) {
  const [tab, setTab] = useState<"reports" | "assignments" | "events">("reports");
  const [pages, setPages] = useState({ reportPage: 1, assignmentPage: 1, eventPage: 1 });
  const detail = useAdminHistoryDetail(record.incident_id, pages);
  const incident = detail.data?.incident ?? record;
  const pageKeys = { reports: "reportPage", assignments: "assignmentPage", events: "eventPage" } as const;
  return (
    <Card className="self-start">
      <SectionHead title={incident.reference} subtitle="Completed incident detail" />
      <div className="flex flex-wrap items-center justify-between gap-2">
        <h3 className="m-0 text-[17px] font-semibold">{incident.incident_type_name}</h3>
        <Badge tone={incident.status === "resolved" ? "green" : "maroon"}>
          {incident.status.toUpperCase()}
        </Badge>
      </div>
      <p className="mb-4 mt-2 break-words text-[10px] leading-relaxed text-muted">
        {incident.location ?? "Location not recorded"}
      </p>
      <dl className="m-0 grid grid-cols-2 gap-x-4 gap-y-3 border-y border-border py-4 text-[9px] [&_dt]:text-muted [&_dd]:m-0 [&_dd]:mt-1 [&_dd]:font-semibold">
        <div><dt>Priority</dt><dd>{incident.priority.toUpperCase()}</dd></div>
        <div><dt>Completed assignments</dt><dd>{incident.completed_assignments}</dd></div>
        <div><dt>Opened</dt><dd>{formatDate(incident.opened_at)}</dd></div>
        <div><dt>Resolved</dt><dd>{formatDate(incident.resolved_at)}</dd></div>
        <div><dt>Closed</dt><dd>{formatDate(incident.closed_at)}</dd></div>
        <div><dt>Linked reports / teams</dt><dd>{incident.report_count} / {incident.team_count}</dd></div>
      </dl>
      <h4 className="mb-2 mt-4 text-[10px] font-semibold">Incident summary</h4>
      <p className="m-0 whitespace-pre-wrap break-words text-[10px] leading-relaxed text-muted">{incident.summary}</p>
      <div role="tablist" aria-label="Incident history details" className="mb-4 mt-5 flex gap-1 border-b border-border">
        {([
          ["reports", "Reports"], ["assignments", "Assignments"], ["events", "Timeline"],
        ] as const).map(([key, label]) => (
          <button
            key={key} id={`history-${key}-tab`} role="tab" aria-selected={tab === key}
            aria-controls="history-detail-panel"
            className={`border-0 border-b-2 bg-transparent px-2 py-3 text-[10px] font-semibold ${tab === key ? "border-maroon text-maroon" : "border-transparent text-muted"}`}
            onClick={() => setTab(key)}
          >{label}</button>
        ))}
      </div>
      <div id="history-detail-panel" role="tabpanel" aria-labelledby={`history-${tab}-tab`}>
        {detail.status === "loading" && <p role="status" className="text-[10px] text-muted">Loading incident history…</p>}
        {detail.status === "error" && <ErrorNotice message={detail.error ?? "The record could not be loaded."} retry={detail.refetch} />}
        {detail.data && (
          <>
            {tab === "reports" && (
              <div className="grid gap-3">
                {!detail.data.reports.total && <p className="text-[10px] text-muted">No linked reports are available.</p>}
                {detail.data.reports.items.map((report) => (
                  <article key={report.report_id} className="border-b border-border pb-3 last:border-b-0">
                    <div className="flex flex-wrap items-center justify-between gap-2">
                      <b className="text-[10px] text-maroon">{report.reference}</b>
                      <Badge tone="blue">{report.verification_status.toUpperCase()}</Badge>
                    </div>
                    <p className="my-2 text-[8px] text-muted">{sourceNames[report.source]} · {formatDate(report.received_at)}</p>
                    <p className="my-2 break-words text-[9px] text-muted">{report.location ?? "Location not recorded"}</p>
                    <p className="mb-0 whitespace-pre-wrap break-words text-[10px] leading-relaxed">{report.description}</p>
                  </article>
                ))}
              </div>
            )}
            {tab === "assignments" && (
              <div className="grid gap-3">
                {!detail.data.assignments.total && <p className="text-[10px] text-muted">No response assignments are recorded.</p>}
                {detail.data.assignments.items.map((assignment) => (
                  <article key={assignment.assignment_id} className="border-b border-border pb-3 last:border-b-0">
                    <div className="flex flex-wrap items-center justify-between gap-2">
                      <div><b className="block text-[11px]">{assignment.unit_name}</b><small className="text-[8px] text-muted">{assignment.unit_type}</small></div>
                      <Badge tone={assignment.status === "completed" ? "green" : "amber"}>{assignment.status.toUpperCase()}</Badge>
                    </div>
                    <dl className="mb-0 mt-3 grid gap-2 text-[9px] [&>div]:flex [&>div]:justify-between [&>div]:gap-3 [&_dt]:text-muted [&_dd]:m-0 [&_dd]:text-right">
                      {([
                        ["Assigned", assignment.assigned_at], ["Acknowledged", assignment.acknowledged_at],
                        ["Responding", assignment.responding_at], ["Completed", assignment.completed_at],
                        ["Cancelled", assignment.cancelled_at],
                      ] as const).filter(([, value]) => value !== null).map(([label, value]) => (
                        <div key={label}><dt>{label}</dt><dd>{formatDate(value)}</dd></div>
                      ))}
                    </dl>
                  </article>
                ))}
              </div>
            )}
            {tab === "events" && (
              <ol className="m-0 grid list-none gap-3 p-0">
                {!detail.data.events.total && <li className="text-[10px] text-muted">No report events are recorded.</li>}
                {detail.data.events.items.map((event) => (
                  <li key={event.event_id} className="border-l-2 border-maroon/30 py-1 pl-3">
                    <b className="block text-[10px]">{eventNames[event.event_type] ?? event.event_type.replaceAll("_", " ")}</b>
                    <span className="mt-1 block text-[8px] text-muted">{event.report_reference} · {formatDate(event.created_at)}</span>
                  </li>
                ))}
              </ol>
            )}
            <Pager
              data={detail.data[tab]}
              label={tab === "events" ? "Events" : tab === "reports" ? "Reports" : "Assignments"}
              onPage={(page) => setPages((current) => ({ ...current, [pageKeys[tab]]: page }))}
            />
          </>
        )}
      </div>
    </Card>
  );
}

export function HistoricalRecords() {
  const [draft, setDraft] = useState<HistoryFilters>({});
  const [filters, setFilters] = useState<HistoryFilters>({});
  const [page, setPage] = useState(1);
  const [selectedId, setSelectedId] = useState<string | null>(null);
  const [types, setTypes] = useState<AdminIncidentType[]>([]);
  const [typeError, setTypeError] = useState(false);
  const [typesVersion, setTypesVersion] = useState(0);
  const [exporting, setExporting] = useState(false);
  const [notice, setNotice] = useState("");
  const [error, setError] = useState("");
  const exportController = useRef<AbortController | null>(null);
  const records = useAdminHistory({ ...filters, page });
  const selected = records.data?.items.find((record) => record.incident_id === selectedId)
    ?? records.data?.items[0] ?? null;

  useEffect(() => {
    const controller = new AbortController();
    getHistoryTypes(controller.signal)
      .then((data) => { if (!controller.signal.aborted) { setTypes(data); setTypeError(false); } })
      .catch(() => { if (!controller.signal.aborted) setTypeError(true); });
    return () => controller.abort();
  }, [typesVersion]);
  useEffect(() => () => exportController.current?.abort(), []);

  const applyFilters = () => {
    setError("");
    setNotice("");
    if (draft.dateFrom && draft.dateTo && draft.dateFrom > draft.dateTo) {
      setError("The start date must be on or before the end date.");
      return;
    }
    setFilters({ ...draft });
    setPage(1);
    setSelectedId(null);
  };
  const clearFilters = () => {
    setDraft({}); setFilters({}); setPage(1); setSelectedId(null); setError(""); setNotice("");
  };
  const download = async () => {
    if (exporting) return;
    const controller = new AbortController();
    exportController.current = controller;
    setExporting(true); setError(""); setNotice("");
    try {
      const blob = await exportHistory(filters, controller.signal);
      if (controller.signal.aborted) return;
      const url = URL.createObjectURL(blob);
      const link = document.createElement("a");
      link.href = url; link.download = "responda-history.csv";
      document.body.appendChild(link); link.click(); link.remove();
      window.setTimeout(() => URL.revokeObjectURL(url), 1000);
      setNotice("CSV downloaded using the applied filters.");
    } catch (caught) {
      if (!controller.signal.aborted) {
        setError(caught instanceof Error ? caught.message : "The CSV export could not be created.");
      }
    } finally {
      if (!controller.signal.aborted) setExporting(false);
    }
  };

  return (
    <>
      <PageTitle
        title="Historical Records"
        subtitle="Review resolved and closed incidents, linked reports, and response history."
        action={exporting ? "Exporting…" : "Export CSV"}
        onAction={() => void download()}
        actionDisabled={exporting || records.status !== "ready" || !records.data?.total}
      />
      <Card>
        <form onSubmit={(event) => { event.preventDefault(); applyFilters(); }} className="grid gap-3">
          <div className="flex flex-wrap items-end gap-2">
            <label className="flex min-w-[220px] flex-1 flex-col gap-2 text-[9px] text-muted">
              Search completed incidents
              <span className="flex h-[38px] items-center gap-2 rounded-[7px] border border-border bg-white px-3 focus-within:border-maroon">
                <Icon name="search" size={14} />
                <input
                  aria-label="Search historical records" maxLength={100}
                  className="w-full border-0 bg-transparent text-[10px] outline-none"
                  value={draft.search ?? ""}
                  onChange={(event) => setDraft({ ...draft, search: event.target.value })}
                  placeholder="Incident / report reference, type, location, or team"
                />
              </span>
            </label>
            <SelectField label="All incident types" value={draft.incidentTypeId ?? ""}
              options={types.map((kind) => ({ value: kind.incident_type_id, label: kind.name }))}
              onChange={(incidentTypeId) => setDraft({ ...draft, incidentTypeId })} />
            <SelectField label="All priorities" value={draft.priority ?? ""}
              options={[{ value: "critical", label: "Critical" }, { value: "high", label: "High" }, { value: "medium", label: "Medium" }, { value: "low", label: "Low" }]}
              onChange={(priority) => setDraft({ ...draft, priority: priority as HistoryFilters["priority"] })} />
            <SelectField label="All final statuses" value={draft.status ?? ""}
              options={[{ value: "resolved", label: "Resolved" }, { value: "closed", label: "Closed" }]}
              onChange={(status) => setDraft({ ...draft, status: status as HistoryFilters["status"] })} />
          </div>
          <div className="flex flex-wrap items-end gap-3 border-t border-border pt-3">
            {(["dateFrom", "dateTo"] as const).map((key) => (
              <label key={key} className="grid gap-2 text-[9px] text-muted">
                {key === "dateFrom" ? "Record date from" : "Record date to"}
                <input
                  type="date" value={draft[key] ?? ""} min="1900-01-01" max="9999-12-30"
                  className="h-[38px] rounded-[7px] border border-border bg-white px-3 text-[10px] outline-maroon"
                  onChange={(event) => setDraft({ ...draft, [key]: event.target.value })}
                />
              </label>
            ))}
            <SelectField label="Sort order" value={draft.sort ?? "newest"}
              options={[{ value: "newest", label: "Newest first" }, { value: "oldest", label: "Oldest first" }]}
              onChange={(sort) => setDraft({ ...draft, sort: sort as HistoryFilters["sort"] })} />
            <button type="submit" className="h-[38px] rounded-[7px] border border-maroon bg-maroon px-4 text-[10px] font-semibold text-white">Apply filters</button>
            <button type="button" className="h-[38px] rounded-[7px] border border-border bg-white px-4 text-[10px] font-semibold" onClick={clearFilters}>Clear</button>
            <i className="flex-1" />
            <button type="button" className="h-[38px] rounded-[7px] border border-border bg-white px-4 text-[10px] font-semibold disabled:opacity-40" onClick={() => { records.refetch(); setTypesVersion((version) => version + 1); }} disabled={records.status === "loading"}>Refresh</button>
          </div>
        </form>
        <p className="mb-0 mt-3 text-[8px] leading-relaxed text-muted">
          Dates use Philippine time and the incident’s closed or resolved date; older records without either use their last update.
          CSV exports include up to 5,000 matching incidents and exclude personal contacts, report text, and exact locations.
        </p>
        {typeError && <div className="mt-3"><ErrorNotice message="Incident-type filters could not be loaded." retry={() => setTypesVersion((value) => value + 1)} /></div>}
      </Card>
      {error && <ErrorNotice message={error} />}
      {notice && <div role="status" className="rounded-[7px] border border-[#c4decf] bg-green-soft px-4 py-3 text-[10px] text-status-green">{notice}</div>}
      <div className="grid grid-cols-3 gap-4 max-[650px]:gap-2">
        {[
          ["Matching incidents", records.data?.total],
          ["Resolved", records.data?.counts.resolved],
          ["Closed", records.data?.counts.closed],
        ].map(([label, count]) => (
          <Card key={label}>
            <span className="block text-[9px] text-muted">{label}</span>
            <b className="mt-2 block text-[24px] font-semibold">{count ?? "—"}</b>
          </Card>
        ))}
      </div>
      {records.status === "error" && <ErrorNotice message={records.error ?? "Historical records could not be loaded."} retry={records.refetch} />}
      <div className="grid grid-cols-[minmax(0,1.8fr)_minmax(340px,1fr)] items-start gap-4 max-[1180px]:grid-cols-1">
        <Card>
          <SectionHead title="Completed incident records" subtitle="One record per incident, including all linked reports" />
          {records.status === "loading" && <p role="status" className="py-8 text-center text-[11px] text-muted">Loading historical records…</p>}
          {records.status === "ready" && !records.data.total && (
            <div className="grid justify-items-center gap-3 px-4 py-12 text-center">
              <Icon name="records" size={24} />
              <b className="text-[12px]">No completed incidents match these filters</b>
              <p className="m-0 text-[10px] text-muted">Resolved and closed incidents will appear here.</p>
              <Button variant="secondary" onClick={clearFilters}>Clear filters</Button>
            </div>
          )}
          {!!records.data?.items.length && (
            <div className="overflow-x-auto">
              <table className="w-full min-w-[700px] border-collapse text-left text-[9px]">
                <thead className="border-b border-border bg-soft-gray text-[8px] text-muted">
                  <tr>{["INCIDENT", "RECORD DATE", "TYPE / LOCATION", "PRIORITY", "STATUS", "TEAMS"].map((heading) => <th className="px-2 py-3 font-semibold" key={heading}>{heading}</th>)}</tr>
                </thead>
                <tbody>
                  {records.data.items.map((record) => (
                    <tr key={record.incident_id} className={`border-b border-border ${selected?.incident_id === record.incident_id ? "bg-blush" : "hover:bg-soft-gray"}`}>
                      <td className="px-2 py-4">
                        <button className="border-0 bg-transparent p-0 text-[9px] font-bold text-maroon underline-offset-4 hover:underline" aria-label={`Open ${record.reference}`} onClick={() => setSelectedId(record.incident_id)}>{record.reference}</button>
                        <small className="mt-1 block text-[8px] text-muted">{record.report_count} report{record.report_count === 1 ? "" : "s"}</small>
                      </td>
                      <td className="px-2 py-4">{formatDate(record.recorded_at, true)}</td>
                      <td className="max-w-[220px] px-2 py-4"><b className="block">{record.incident_type_name}</b><small className="mt-1 block break-words text-[8px] text-muted">{record.location ?? "Location not recorded"}</small></td>
                      <td className="px-2 py-4"><Badge tone={tone(record.priority.toUpperCase())}>{record.priority.toUpperCase()}</Badge></td>
                      <td className="px-2 py-4"><Badge tone={record.status === "resolved" ? "green" : "maroon"}>{record.status.toUpperCase()}</Badge></td>
                      <td className="px-2 py-4">{record.first_team ?? "None recorded"}{record.team_count > 1 && <small className="mt-1 block text-muted">+{record.team_count - 1} more</small>}</td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          )}
          {records.data && <Pager data={records.data} label="Incidents" onPage={(value) => { setPage(value); setSelectedId(null); }} />}
        </Card>
        {selected ? <RecordDetails key={selected.incident_id} record={selected} /> : (
          <Card><SectionHead title="Incident detail" /><p className="text-[10px] text-muted">Select a completed incident to view its reports, assignments, and timeline.</p></Card>
        )}
      </div>
    </>
  );
}
