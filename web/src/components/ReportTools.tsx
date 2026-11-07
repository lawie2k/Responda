import { useEffect, useRef, useState } from 'react';
import { createPortal } from 'react-dom';
import { apiBaseUrl, getAdminIncidentTypes, type AdminReportDetail } from '../api/respondaApi';
import { operations } from '../api/operations';
import { Button } from './ui';
import { MiniMap } from './Map';

function ReportPhoto({ reportId, attachmentId }: { reportId: string; attachmentId: string }) {
  const [url, setUrl] = useState('');
  const [error, setError] = useState('');
  useEffect(() => {
    const controller = new AbortController(); let objectUrl = '';
    fetch(`${apiBaseUrl}/api/v1/admin/reports/${reportId}/attachments/${attachmentId}`, {credentials:'include', cache:'no-store', signal:controller.signal})
      .then(async response=> {if (!response.ok) throw new Error('Photo unavailable or expired.'); return response.blob();})
      .then(blob=> {if (!controller.signal.aborted) {objectUrl=URL.createObjectURL(blob);setUrl(objectUrl);}})
      .catch(caught=> {if (!controller.signal.aborted) setError(caught.message);});
    return ()=> {controller.abort();if(objectUrl) URL.revokeObjectURL(objectUrl);};
  }, [reportId, attachmentId]);
  return error ? <p role="alert">{error}</p> : url ? <a href={url} target="_blank" rel="noreferrer" aria-label="Open report photo at full size"><img className="max-h-48 w-full rounded-lg object-contain" src={url} alt="Photo submitted with this report" /></a> : <p role="status">Loading photo…</p>;
}

export function ReportTools({ detail, onSaved }: { detail: AdminReportDetail; onSaved: () => void }) {
  const [editing, setEditing] = useState(false);
  const dialog = useRef<HTMLDialogElement>(null);
  useEffect(() => {
    if (!editing || !dialog.current) return;
    const element = dialog.current;
    const previousOverflow = document.body.style.overflow;
    document.body.style.overflow = 'hidden';
    element.showModal();
    return () => { element.close(); document.body.style.overflow = previousOverflow; };
  }, [editing]);
  const [types, setTypes] = useState<{incident_type_id:string;name:string}[]>([]);
  const [category, setCategory] = useState(detail.incident_type.incident_type_id);
  const [latitude, setLatitude] = useState(detail.location?.latitude?.toString() ?? '');
  const [longitude, setLongitude] = useState(detail.location?.longitude?.toString() ?? '');
  const [landmark, setLandmark] = useState(detail.location?.landmark ?? '');
  const [reason, setReason] = useState('');
  const [error, setError] = useState('');
  const [busy, setBusy] = useState(false);
  useEffect(()=> {const controller = new AbortController();getAdminIncidentTypes(controller.signal).then(data=>setTypes(data.items)).catch(()=>{});return ()=>controller.abort();},[]);
  const valid = reason.trim().length >=3 && category && (latitude !== '' || landmark.trim().length > 0) && ((latitude === '' && longitude === '') || (latitude !== '' && longitude !== '' && Number.isFinite(Number(latitude)) && Number.isFinite(Number(longitude)) && Math.abs(Number(latitude))<=90 && Math.abs(Number(longitude))<=180));
  return <section className="grid w-full gap-3 pt-1 text-[10px] [&>button]:w-full">
    {detail.status !== 'closed' && <Button variant="secondary" disabled={busy} onClick={()=>setEditing(true)}>Correct report location or category</Button>}
    <b>Report photos</b>
    {detail.attachments.filter(item=>item.media_type==='image').map(item=><ReportPhoto key={item.attachment_id} reportId={detail.report_id} attachmentId={item.attachment_id} />)}
    {!detail.attachments.length && <p className="m-0 text-muted">No photos attached.</p>}
    {editing && createPortal(<dialog ref={dialog} aria-labelledby="correct-report-title" onClose={()=>setEditing(false)} onCancel={event=>{if(busy)event.preventDefault();}} className="fixed inset-0 m-auto max-h-[calc(100dvh-40px)] w-[min(1000px,calc(100vw-32px))] overflow-y-auto rounded-2xl border border-border bg-white p-0 text-deep shadow-2xl backdrop:bg-[#23090f80] backdrop:backdrop-blur-sm">
      <div className="sticky top-0 z-10 flex items-start justify-between gap-4 border-b border-border bg-white px-6 py-5">
        <div><h2 id="correct-report-title" className="m-0 text-lg font-semibold">Correct report</h2><p className="mb-0 mt-1 text-[11px] text-muted">Update the location or category and explain the correction.</p></div>
        <button type="button" autoFocus disabled={busy} aria-label="Close report correction" onClick={()=>setEditing(false)} className="grid size-9 shrink-0 place-items-center rounded-lg border border-border bg-soft-gray text-xl disabled:opacity-40">×</button>
      </div>
      <form className="grid gap-4 p-6 text-[11px] [&_.map-canvas]:h-[320px] max-[650px]:[&_.map-canvas]:h-[240px] [&_input]:w-full [&_input]:rounded-md [&_input]:border [&_input]:border-border [&_input]:p-2 [&_select]:w-full [&_select]:border [&_select]:border-border [&_select]:p-2" onSubmit={async event=> {
      event.preventDefault(); if(!valid || busy)return;setBusy(true);setError('');
      try {await operations(`reports/${detail.report_id}/correction`,{expected_updated_at:detail.updated_at,incident_type_id:category,latitude:latitude===''?null:Number(latitude),longitude:longitude===''?null:Number(longitude),landmark,reason},'PATCH');setEditing(false);setReason('');onSaved();}
      catch(caught){setError(caught instanceof Error ? caught.message : 'Correction could not be saved.');}finally{setBusy(false);}
    }}>
      <fieldset disabled={busy} className="grid gap-3 border-0 p-0">
        <label>Incident category<select required disabled={Boolean(detail.incident)} value={category} onChange={e=>setCategory(e.target.value)}>{types.map(type=><option value={type.incident_type_id} key={type.incident_type_id}>{type.name}</option>)}</select></label>
        {detail.incident && <p className="m-0 text-muted">Category is locked after incident linking. Location can still be corrected.</p>}
        <p className="m-0 text-muted">Click the map to plot the corrected location, or enter both coordinates. Original coordinates are preserved in protected history.</p>
        <MiniMap large onLocationPick={position=> {setLatitude(position[0].toFixed(6));setLongitude(position[1].toFixed(6));}} points={latitude && longitude && validPosition(latitude,longitude) ? [{id:'correction', name:'Corrected location',location:landmark,position:[Number(latitude),Number(longitude)],barangay:null,priority:'Moderate',hoursAgo:0}] : []} />
        <label>Latitude<input type="number" step="any" min={-90} max={90} value={latitude} onChange={e=>setLatitude(e.target.value)} /></label>
        <label>Longitude<input type="number" step="any" min={-180} max={180} value={longitude} onChange={e=>setLongitude(e.target.value)} /></label>
        <label>Location description<input maxLength={255} value={landmark} onChange={e=>setLandmark(e.target.value)} /></label>
        <label>Reason for correction<input required minLength={3} maxLength={1000} value={reason} onChange={e=>setReason(e.target.value)} /></label>
        <Button type="submit" disabled={!valid || busy}>{busy?'Saving…':'Save correction'}</Button>
      </fieldset>
      {error && <p role="alert" className="text-priority-red">{error}</p>}
    </form>
    </dialog>, document.body)}
  </section>;
}
function validPosition(latitude:string,longitude:string){return Number.isFinite(Number(latitude))&&Number.isFinite(Number(longitude))&&Math.abs(Number(latitude))<=90&&Math.abs(Number(longitude))<=180;}
