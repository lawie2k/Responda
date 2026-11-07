import { useEffect, useState } from 'react';
import { operations, type HeatCell } from '../api/operations';
import { getAdminIncidentTypes } from '../api/respondaApi';
import { MiniMap } from './Map';
import { Button, Card, SectionHead } from './ui';
import { getBarangayForPosition } from '../data/barangayBoundaries';
const date = (offset = 0) => new Date(Date.now() - offset * 86400000).toLocaleDateString('en-CA', { timeZone: 'Asia/Manila' });

export function HotspotAnalysis() {
  const [from, setFrom] = useState(() => date(29));
  const [to, setTo] = useState(() => date());
  const [category, setCategory] = useState('');
  const [types, setTypes] = useState<{ incident_type_id: string; name: string }[]>([]);
  const [version, setVersion] = useState(0);
  const [data, setData] = useState<{ cells: HeatCell[]; total: number } | null>(null);
  const [error, setError] = useState('');
  const [busy, setBusy] = useState(false);
  const [appliedCategory, setAppliedCategory] = useState('');
  useEffect(() => { const controller = new AbortController(); getAdminIncidentTypes(controller.signal).then(result => setTypes(result.items)).catch(() => {}); return () => controller.abort(); }, []);
  useEffect(() => {
    const controller = new AbortController();
    // Refresh only after Apply so editing filters never changes the displayed analysis halfway through.
    const params = new URLSearchParams({date_from: from, date_to: to, ...(category ? {incident_type_id: category} : {})});
    void operations<{ cells: HeatCell[]; total: number }>(`spatial/heatmap?${params}`, undefined, 'GET', controller.signal)
      .then(value => { setData(value); setAppliedCategory(category); setError(''); }).catch(caught => { if (!controller.signal.aborted) { setError(String(caught.message)); setData(null); } }).finally(() => { if (!controller.signal.aborted) setBusy(false); });
    return () => controller.abort();
    // Inputs are applied together on submission.
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [version]);
  const valid = from && to && from <= to && (new Date(to).getTime() - new Date(from).getTime()) / 86400000 < 366;
  const kind = types.find(type=>type.incident_type_id===appliedCategory)?.name.toLowerCase() ?? '';
  const suggestion = kind.includes('flood') ? 'Inspect drainage and waterways, review evacuation routes, and coordinate flood preparedness outreach.'
    : kind.includes('fire') ? 'Review fire access and water availability, arrange fire-safety inspections, and reinforce evacuation and extinguisher training.'
    : kind.includes('accident') ? 'Review road hazards, lighting and traffic controls with the responsible road and traffic offices.'
    : kind.includes('drown') ? 'Review water-access hazards, warning signs, rescue equipment and water-safety outreach.'
    : kind.includes('medical') ? 'Review first-aid coverage, access routes and coordination with local health services.'
    : 'Review the incident mix, inspect recurring hazards, and assess preventive outreach and response-resource readiness with MDRRMO.';
  return <Card>
    <SectionHead title="Incident density heatmap" subtitle="Verified reports grouped into approximately 550 m cells. Linked duplicate reports count as one incident." />
    <form className="mb-4 flex flex-wrap items-end gap-3 text-[10px]" onSubmit={e => {e.preventDefault(); setBusy(true); setVersion(v => v+1);}}>
      <label>From<input aria-label="Heatmap start date" className="ml-2 border border-border p-2" type="date" required value={from} onChange={e=>setFrom(e.target.value)} /></label>
      <label>To<input aria-label="Heatmap end date" className="ml-2 border border-border p-2" type="date" required value={to} onChange={e=>setTo(e.target.value)} /></label>
      <select aria-label="Heatmap incident category" className="border border-border p-2" value={category} onChange={e=>setCategory(e.target.value)}><option value="">All incident categories</option>{types.map(type=><option key={type.incident_type_id} value={type.incident_type_id}>{type.name}</option>)}</select>
      <Button type="submit" disabled={!valid || busy}>{busy ? 'Loading…' : 'Apply analysis filters'}</Button>
    </form>
    {error && <p role="alert" className="text-[11px] text-priority-red">{error}</p>}
    {data && <>
      <MiniMap large heatCells={data.cells} layers={[false, true, false, false, false]} />
      <p className="text-[10px] text-muted">Blue → green → red indicates increasing relative density. {data.total} distinct incidents or unlinked verified reports. {data.total === 0 ? 'No matching incidents with coordinates.' : ''}</p>
      <SectionHead title="Recurring hotspots and suggested actions" subtitle="Rule-based planning suggestions for staff review; these are not ML predictions or approved dispatch instructions." />
      {data.cells.filter(cell=>cell.count >= 3).slice(0,10).map(cell=><div className="mb-3 border-l-2 border-maroon pl-3 text-[11px]" key={`${cell.latitude}:${cell.longitude}`}>
        <b>Near {getBarangayForPosition([cell.latitude, cell.longitude]) || 'mapped area'} · {cell.count} incidents</b>
        <p className="my-1 text-muted">Near {cell.latitude.toFixed(4)}, {cell.longitude.toFixed(4)}. {suggestion}</p>
      </div>)}
      {!data.cells.some(cell=>cell.count>=3) && <p className="text-[11px] text-muted">No cell has at least three incidents in this period. Widen the period to examine recurrence.</p>}
    </>}
  </Card>;
}
