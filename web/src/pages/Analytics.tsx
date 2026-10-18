import { useEffect, useRef, useState } from "react";
import { exportAnalytics, getAnalyticsTypes, type AnalyticsCount, type AnalyticsFilters } from "../api/adminAnalytics";
import type { AdminIncidentType } from "../api/respondaApi";
import { Button, Card, Metric, PageTitle, SectionHead, SelectField } from "../components/ui";
import { useAdminAnalytics } from "../hooks/useAdminAnalytics";
import type { Page } from "../types";

function preset(days: number): AnalyticsFilters {
  const parts = new Intl.DateTimeFormat("en", {
    timeZone: "Asia/Manila", year: "numeric", month: "2-digit", day: "2-digit",
  }).formatToParts(new Date());
  const part = (name: string) => parts.find((value) => value.type === name)?.value;
  const end = `${part("year")}-${part("month")}-${part("day")}`;
  const start = new Date(`${end}T00:00:00Z`);
  start.setUTCDate(start.getUTCDate() - days + 1);
  return { dateFrom: start.toISOString().slice(0, 10), dateTo: end };
}

const dateLabel = (value: string) => new Intl.DateTimeFormat("en-PH", {
  timeZone: "Asia/Manila", month: "short", day: "numeric", year: "numeric",
}).format(new Date(`${value}T00:00:00+08:00`));

function Breakdown({ title, subtitle, rows, total }: {
  title: string; subtitle: string; rows: AnalyticsCount[]; total: number;
}) {
  return <Card>
    <SectionHead title={title} subtitle={subtitle} />
    <div className="grid gap-4">
      {rows.map((row) => <div key={row.key}>
        <div className="mb-2 flex justify-between gap-3 text-[10px]">
          <span>{row.label}</span><b>{row.count} <span className="font-normal text-muted">· {total ? Math.round(row.count / total * 100) : 0}%</span></b>
        </div>
        <div className="h-1.5 overflow-hidden rounded bg-soft-gray">
          <div className="h-full rounded bg-maroon" style={{ width: `${total ? row.count / total * 100 : 0}%` }} />
        </div>
      </div>)}
    </div>
    {!total && <p className="mb-0 mt-4 text-[10px] text-muted">No matching records in this period.</p>}
  </Card>;
}

export function Analytics({ go }: { go?: (page: Page) => void }) {
  const [draft, setDraft] = useState<AnalyticsFilters>(() => preset(30));
  const [filters, setFilters] = useState(draft);
  const [types, setTypes] = useState<AdminIncidentType[]>([]);
  const [typeError, setTypeError] = useState(false);
  const [typeVersion, setTypeVersion] = useState(0);
  const [detailsOpen, setDetailsOpen] = useState(false);
  const [error, setError] = useState("");
  const [notice, setNotice] = useState("");
  const [exporting, setExporting] = useState(false);
  const exportController = useRef<AbortController | null>(null);
  const analytics = useAdminAnalytics(filters);
  const data = analytics.data;

  useEffect(() => {
    const controller = new AbortController();
    getAnalyticsTypes(controller.signal)
      .then((items) => { if (!controller.signal.aborted) { setTypes(items); setTypeError(false); } })
      .catch(() => { if (!controller.signal.aborted) setTypeError(true); });
    return () => controller.abort();
  }, [typeVersion]);
  useEffect(() => () => exportController.current?.abort(), []);

  const apply = () => {
    const span = Date.parse(draft.dateTo) - Date.parse(draft.dateFrom);
    if (!Number.isFinite(span) || span < 0 || span / 86400000 >= 366) {
      setError("Choose a start date on or before the end date, within a 366-day range.");
      return;
    }
    setError(""); setNotice(""); setFilters({ ...draft });
  };
  const download = async () => {
    if (exportController.current && !exportController.current.signal.aborted) return;
    const controller = new AbortController();
    exportController.current = controller;
    setExporting(true); setError(""); setNotice("");
    try {
      const blob = await exportAnalytics(filters, controller.signal);
      if (controller.signal.aborted) return;
      const url = URL.createObjectURL(blob);
      const link = document.createElement("a");
      link.href = url; link.download = "responda-analytics.csv";
      document.body.appendChild(link); link.click(); link.remove();
      window.setTimeout(() => URL.revokeObjectURL(url), 1000);
      setNotice("Daily aggregate CSV downloaded using the applied filters.");
    } catch (caught) {
      if (!controller.signal.aborted) setError(caught instanceof Error ? caught.message : "The export could not be created.");
    } finally {
      if (!controller.signal.aborted) { setExporting(false); exportController.current = null; }
    }
  };
  const refresh = () => { analytics.refetch(); setTypeVersion((value) => value + 1); };
  const max = Math.max(1, ...(data?.daily.map((day) => day.reports) ?? []));
  const summary = data?.summary;
  const verifiedRate = summary?.reports ? Math.round(summary.verified_reports / summary.reports * 100) : 0;
  const canApply = JSON.stringify(draft) !== JSON.stringify(filters) && Boolean(draft.dateFrom && draft.dateTo);

  return <>
    <PageTitle title="Analytics" subtitle="Review reporting patterns and recorded response activity."
      action={exporting ? "Exporting…" : "Export daily CSV"} onAction={() => void download()}
      actionDisabled={exporting || !data || (!data.summary.reports && !data.summary.incidents)} />
    <Card>
      <form className="flex flex-wrap items-end gap-3" onSubmit={(event) => { event.preventDefault(); apply(); }}>
        <div className="flex gap-2">
          {[7, 30, 90].map((days) => <button type="button" key={days}
            className="h-[38px] rounded-[7px] border border-border bg-white px-3 text-[10px] hover:border-maroon"
            onClick={() => { const dates = { ...preset(days), incidentTypeId: draft.incidentTypeId }; setDraft(dates); setFilters(dates); setError(""); setNotice(""); }}
          >Last {days} days</button>)}
        </div>
        {(["dateFrom", "dateTo"] as const).map((key) => <label key={key} className="grid gap-2 text-[9px] text-muted">
          {key === "dateFrom" ? "From" : "To"}
          <input type="date" required min="1900-01-01" max="9999-12-30" value={draft[key]}
            className="h-[38px] rounded-[7px] border border-border bg-white px-3 text-[10px] outline-maroon"
            onChange={(event) => setDraft({ ...draft, [key]: event.target.value })} />
        </label>)}
        <SelectField label="All incident types" value={draft.incidentTypeId ?? ""}
          options={types.map((kind) => ({ value: kind.incident_type_id, label: kind.name }))}
          onChange={(incidentTypeId) => setDraft({ ...draft, incidentTypeId })} />
        <button type="submit" disabled={!canApply}
          className="h-[38px] rounded-[7px] border border-maroon bg-maroon px-4 text-[10px] font-semibold text-white disabled:cursor-not-allowed disabled:opacity-45">Apply filters</button>
        <button type="button" className="h-[38px] rounded-[7px] border border-border bg-white px-3 text-[10px]" onClick={() => { const dates = preset(30); setDraft(dates); setFilters(dates); setError(""); setNotice(""); }}>Reset</button>
        <i className="flex-1" />
        <button type="button" disabled={analytics.status === "loading"} onClick={refresh}
          className="h-[38px] rounded-[7px] border border-border bg-white px-3 text-[10px] disabled:opacity-45">Refresh</button>
      </form>
      <p className="mb-0 mt-3 text-[9px] leading-relaxed text-muted">Reports use their received date; incidents use their opened date. Verification and incident status reflect their current state. All dates use Philippine time. Maximum range: 366 days.</p>
      {typeError && <div role="alert" className="mt-3 flex items-center justify-between gap-3 text-[10px] text-priority-red">Incident-type options could not be loaded.<Button variant="secondary" onClick={() => setTypeVersion((value) => value + 1)}>Retry types</Button></div>}
    </Card>
    {error && <p role="alert" className="text-[11px] text-priority-red">{error}</p>}
    {notice && <p role="status" className="text-[11px] text-status-green">{notice}</p>}
    {analytics.status === "loading" && <Card><p role="status" className="py-10 text-center text-[11px] text-muted">Loading analytics…</p></Card>}
    {analytics.status === "error" && <Card><div role="alert" className="flex items-center justify-between gap-3 text-[11px] text-priority-red">{analytics.error}<Button variant="secondary" onClick={refresh}>Retry</Button></div></Card>}
    {data && summary && <>
      <p className="m-0 text-[9px] text-muted">{dateLabel(data.date_from)} – {dateLabel(data.date_to)} · Updated {new Intl.DateTimeFormat("en-PH", { timeZone: "Asia/Manila", dateStyle: "medium", timeStyle: "short" }).format(new Date(data.generated_at))}</p>
      {!summary.reports && !summary.incidents && <Card><p role="status" className="m-0 text-[11px] text-muted">No reports or incidents match these filters. Try a wider date range or another incident type.</p></Card>}
      <div className="grid grid-cols-4 gap-4 max-[1180px]:grid-cols-2 max-[650px]:grid-cols-1">
        <Metric icon="reports" title="Reports received" value={String(summary.reports)} sub={`${data.daily.length} calendar days`} tone="maroon" />
        <Metric icon="check" title="Verified reports" value={String(summary.verified_reports)} sub={`${verifiedRate}% of matching reports`} tone="green" />
        <Metric icon="alert" title="Incidents opened" value={String(summary.incidents)} sub={`${summary.critical_incidents} critical · ${summary.completed_incidents} resolved or closed`} tone="maroon" />
        <Metric icon="clock" title="Average dispatch time" value={summary.average_dispatch_minutes === null ? "—" : `${summary.average_dispatch_minutes.toFixed(1)}m`}
          sub={summary.dispatch_samples ? `${summary.dispatch_samples} incidents with a team assignment` : "No qualifying team assignments"} tone="blue" />
      </div>
      <div className="grid grid-cols-[minmax(0,1.8fr)_minmax(300px,1fr)] gap-4 max-[1180px]:grid-cols-1">
        <Card>
          <SectionHead title="Daily reporting volume" subtitle="Reports received and their current verification state"
            action={detailsOpen ? "Hide daily counts" : "View daily counts"} onAction={() => setDetailsOpen((value) => !value)} />
          <div className="mb-4 flex gap-4 text-[9px] text-muted"><span>Maroon · All reports</span><span>Gray · Verified reports</span></div>
          <div className="flex h-[200px] items-end gap-[3px] border-b border-border py-2" role="img" aria-label={`Daily volume: ${summary.reports} reports, ${summary.verified_reports} verified. Use View daily counts for the accessible table.`}>
            {data.daily.map((day) => <div key={day.date} className="flex h-full min-w-0 flex-1 items-end gap-px"
              title={`${dateLabel(day.date)}: ${day.reports} reports, ${day.verified_reports} verified, ${day.incidents} incidents`}>
              <i className="min-w-0 flex-1 rounded-t bg-maroon" style={{ height: `${day.reports / max * 100}%` }} />
              <i className="min-w-0 flex-1 rounded-t bg-[#99908e]" style={{ height: `${day.verified_reports / max * 100}%` }} />
            </div>)}
          </div>
          <div className="mt-2 flex justify-between text-[9px] text-muted"><span>{dateLabel(data.date_from)}</span><span>{dateLabel(data.date_to)}</span></div>
          {detailsOpen && <div className="mt-5 max-h-[360px] overflow-auto"><table className="w-full border-collapse text-left text-[10px]">
            <caption className="pb-3 text-left font-semibold">Daily counts · Philippine calendar dates</caption>
            <thead className="bg-soft-gray"><tr>{["Date", "Reports", "Verified", "Incidents opened"].map((label) => <th key={label} className="p-2 font-semibold">{label}</th>)}</tr></thead>
            <tbody>{data.daily.map((day) => <tr key={day.date} className="border-b border-border"><td className="p-2">{dateLabel(day.date)}</td><td className="p-2">{day.reports}</td><td className="p-2">{day.verified_reports}</td><td className="p-2">{day.incidents}</td></tr>)}</tbody>
          </table></div>}
        </Card>
        <Card>
          <SectionHead title="Incident types" subtitle="Distinct incidents opened and reports received" />
          <table className="w-full border-collapse text-left text-[10px]"><thead><tr className="border-b border-border text-[9px] text-muted"><th className="py-2">Type</th><th className="p-2 text-right">Reports</th><th className="py-2 text-right">Incidents</th></tr></thead>
            <tbody>{data.incident_types.map((kind) => <tr key={kind.incident_type_id} className="border-b border-border"><td className="py-3">{kind.name}</td><td className="p-2 text-right">{kind.reports}</td><td className="py-3 text-right font-semibold">{kind.incidents}</td></tr>)}</tbody>
          </table>
          {!data.incident_types.length && <p className="text-[10px] text-muted">No matching incident types.</p>}
          <p className="mb-0 mt-4 text-[9px] leading-relaxed text-muted">Several reports can belong to one incident, so report and incident totals can differ.</p>
        </Card>
      </div>
      <div className="grid grid-cols-3 gap-4 max-[1180px]:grid-cols-1">
        <Breakdown title="Report sources" subtitle="Share of reports received" rows={data.sources} total={summary.reports} />
        <Breakdown title="Incident priorities" subtitle="Current priority of incidents opened in this period" rows={data.priorities} total={summary.incidents} />
        <Breakdown title="Incident statuses" subtitle="Current state of incidents opened in this period" rows={data.statuses} total={summary.incidents} />
      </div>
      <Card><SectionHead title="About dispatch timing" /><p className="mb-4 text-[10px] leading-relaxed text-muted">Average dispatch time measures incident opening to its first qualifying team assignment. Cancelled and deleted assignments or units, and assignments dated before incident opening, are excluded. An em dash means no timing samples are available.</p>
        {go && <Button variant="secondary" onClick={() => go("Historical Records")}>Open Historical Records</Button>}
      </Card>
    </>}
  </>;
}
