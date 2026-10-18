import { useEffect, useRef, useState } from "react";
import { getStaffPolicy, revokeStaffSessions, saveStaff, type Staff, type StaffPolicy } from "../api/adminStaff";
import { administratorRoleLabel } from "../config/roles";
import { Badge, Button, Card, PageTitle, SectionHead, SelectField } from "../components/ui";
import { useAdminStaff } from "../hooks/useAdminStaff";

const inputClass = "h-[38px] w-full rounded-[7px] border border-border bg-white px-3 text-[11px] outline-maroon";
const stamp = (value: string) => new Intl.DateTimeFormat("en-PH", {
  timeZone: "Asia/Manila", dateStyle: "medium", timeStyle: "short",
}).format(new Date(value));

export function Settings() {
  const [tab, setTab] = useState<"staff" | "rules">("staff");
  const [search, setSearch] = useState("");
  const [query, setQuery] = useState({ page: 1, search: "", active: "" });
  const roster = useAdminStaff(query);
  const [policy, setPolicy] = useState<StaffPolicy | null>(null);
  const [policyError, setPolicyError] = useState("");
  const [policyVersion, setPolicyVersion] = useState(0);
  const [editor, setEditor] = useState<{ user: Staff | null } | null>(null);
  const [name, setName] = useState("");
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [confirmation, setConfirmation] = useState("");
  const [active, setActive] = useState(true);
  const [pending, setPending] = useState<{ action: "deactivate" | "revoke"; user: Staff } | null>(null);
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState("");
  const [notice, setNotice] = useState("");
  const mutation = useRef<AbortController | null>(null);

  useEffect(() => {
    const controller = new AbortController();
    getStaffPolicy(controller.signal)
      .then((data) => { if (!controller.signal.aborted) { setPolicy(data); setPolicyError(""); } })
      .catch((caught: unknown) => { if (!controller.signal.aborted) setPolicyError(caught instanceof Error ? caught.message : "System rules could not be loaded."); });
    return () => controller.abort();
  }, [policyVersion]);
  useEffect(() => () => mutation.current?.abort(), []);

  const closeEditor = () => { setEditor(null); setPassword(""); setConfirmation(""); };
  const openEditor = (user: Staff | null) => {
    setEditor({ user }); setName(user?.full_name ?? ""); setEmail(user?.email ?? "");
    setActive(user?.is_active ?? true); setPassword(""); setConfirmation("");
    setPending(null); setError(""); setNotice("");
  };
  const refresh = () => { roster.refetch(); setPolicyVersion((value) => value + 1); };
  const perform = async (action: (signal: AbortSignal) => Promise<Staff>, success: string) => {
    if (mutation.current) return;
    const controller = new AbortController(); mutation.current = controller;
    setBusy(true); setError(""); setNotice("");
    try {
      await action(controller.signal);
      if (!controller.signal.aborted) {
        closeEditor(); setPending(null); setNotice(success); roster.refetch();
      }
    } catch (caught) {
      if (!controller.signal.aborted) setError(caught instanceof Error ? caught.message : "The account could not be saved.");
    } finally {
      if (!controller.signal.aborted) { mutation.current = null; setBusy(false); }
    }
  };
  const submit = () => {
    if (!editor) return;
    if (!editor.user && password !== confirmation) { setError("Passwords do not match."); return; }
    if (editor.user?.is_active && !active) { setPending({ action: "deactivate", user: editor.user }); return; }
    void persist();
  };
  const persist = () => {
    if (!editor) return Promise.resolve();
    return perform((signal) => saveStaff(editor.user?.user_id ?? null, {
      full_name: name.trim(), email: email.trim(),
      ...(editor.user ? { is_active: active, expected_updated_at: editor.user.updated_at } : { password }),
    }, signal), editor.user ? "Administrator account updated." : "Administrator account created.");
  };
  const changed = editor && (editor.user
    ? name.trim() !== editor.user.full_name || email.trim().toLowerCase() !== editor.user.email || active !== editor.user.is_active
    : Boolean(name.trim() && email.trim() && password && confirmation));

  return <>
    <PageTitle title="Settings" subtitle="Manage staff access and review current system rules."
      action="Create Administrator" onAction={() => { setTab("staff"); openEditor(null); }} actionDisabled={busy} />
    <div role="tablist" aria-label="Settings sections" className="flex gap-2 border-b border-border">
      {([ ["staff", "Users & roles"], ["rules", "System rules"] ] as const).map(([key, label]) => <button
        key={key} role="tab" aria-selected={tab === key} disabled={busy}
        className={`border-0 border-b-2 bg-transparent px-4 py-3 text-[11px] font-semibold ${tab === key ? "border-maroon text-maroon" : "border-transparent text-muted"}`}
        onClick={() => { setTab(key); closeEditor(); setPending(null); setError(""); }}
      >{label}</button>)}
    </div>
    {error && <Card><p role="alert" className="m-0 text-[11px] text-priority-red">{error}</p></Card>}
    {notice && <Card><p role="status" className="m-0 text-[11px] text-status-green">{notice}</p></Card>}
    {pending && <Card>
      <SectionHead title={pending.action === "revoke" ? "Sign out this Administrator?" : "Deactivate this Administrator?"} />
      <p className="text-[11px] leading-relaxed">{pending.user.full_name} will be signed out of all current sessions.{pending.action === "deactivate" ? " This account cannot sign in again until reactivated." : " They can sign in again with their existing credentials."}</p>
      <div className="flex gap-2">
        <Button variant="danger" disabled={busy} onClick={() => {
          if (pending.action === "deactivate") void persist();
          else void perform((signal) => revokeStaffSessions(pending.user, signal), "Administrator sessions revoked.");
        }}>{busy ? "Saving…" : pending.action === "deactivate" ? "Confirm deactivation" : "Confirm sign out"}</Button>
        <Button variant="secondary" disabled={busy} onClick={() => setPending(null)}>Cancel</Button>
      </div>
    </Card>}
    {tab === "staff" && <>
      {editor && <Card>
        <SectionHead title={editor.user ? "Edit Administrator" : "Create Administrator"} subtitle="Normal Administrators manage reports, incidents, and response teams." />
        <form onSubmit={(event) => { event.preventDefault(); submit(); }}>
          <fieldset disabled={busy || pending !== null} className="m-0 grid grid-cols-2 gap-4 border-0 p-0 max-[650px]:grid-cols-1">
            <label className="grid gap-2 text-[10px] text-muted">Full name<input className={inputClass} required maxLength={150} value={name} onChange={(event) => setName(event.target.value)} autoComplete="name" /></label>
            <label className="grid gap-2 text-[10px] text-muted">Staff email<input className={inputClass} type="email" required maxLength={255} value={email} onChange={(event) => setEmail(event.target.value)} autoComplete="off" /></label>
            {!editor.user && <>
              <label className="grid gap-2 text-[10px] text-muted">Password<input className={inputClass} type="password" required minLength={policy?.password_min_length ?? 8} maxLength={policy?.password_max_length ?? 1024} value={password} onChange={(event) => setPassword(event.target.value)} autoComplete="new-password" /></label>
              <label className="grid gap-2 text-[10px] text-muted">Confirm password<input className={inputClass} type="password" required maxLength={policy?.password_max_length ?? 1024} value={confirmation} onChange={(event) => setConfirmation(event.target.value)} autoComplete="new-password" /></label>
            </>}
            {editor.user && <label className="flex items-center gap-2 text-[11px]"><input type="checkbox" checked={active} onChange={(event) => setActive(event.target.checked)} />Account active</label>}
          </fieldset>
          <p className="text-[10px] leading-relaxed text-muted">{editor.user ? "Changing the email or active status revokes all existing sessions." : `Use at least ${policy?.password_min_length ?? 8} characters. Share credentials directly with the staff member through your approved channel.`}</p>
          <div className="flex gap-2"><button type="submit" disabled={busy || !changed || pending !== null} className="rounded-[7px] border border-maroon bg-maroon px-4 py-3 text-[11px] font-semibold text-white disabled:cursor-not-allowed disabled:opacity-45">{busy ? "Saving…" : editor.user ? "Save account" : "Create account"}</button>
            <Button variant="secondary" disabled={busy} onClick={() => { closeEditor(); setPending(null); setError(""); }}>Cancel edit</Button></div>
        </form>
      </Card>}
      <Card>
        <form className="flex flex-wrap items-center gap-3" onSubmit={(event) => { event.preventDefault(); setQuery({ ...query, search, page: 1 }); }}>
          <input aria-label="Search staff accounts" className={`${inputClass} min-w-[200px] flex-1`} placeholder="Search name or email" maxLength={100} value={search} onChange={(event) => setSearch(event.target.value)} />
          <SelectField label="All account statuses" value={query.active} options={[{ value: "true", label: "Active" }, { value: "false", label: "Inactive" }]} onChange={(value) => setQuery({ ...query, active: value, page: 1 })} />
          <button type="submit" className="rounded-[7px] border border-border bg-white px-4 py-3 text-[10px]">Search</button>
          <button type="button" className="rounded-[7px] border border-border bg-white px-4 py-3 text-[10px]" onClick={() => { setSearch(""); setQuery({ page: 1, search: "", active: "" }); }}>Clear</button>
          <Button variant="secondary" disabled={busy || roster.status === "loading"} onClick={refresh}>Refresh</Button>
        </form>
      </Card>
      <Card>
        <SectionHead title="Staff accounts" subtitle="Super Admin accounts are protected. Only normal Administrator accounts can be edited here." />
        {roster.status === "loading" && <p role="status" className="text-[11px] text-muted">Loading staff accounts…</p>}
        {roster.status === "error" && <div role="alert" className="flex items-center justify-between gap-3 text-[11px] text-priority-red">{roster.error}<Button variant="secondary" onClick={roster.refetch}>Retry</Button></div>}
        {roster.data && <>
          {!roster.data.items.length && <p role="status" className="py-8 text-center text-[11px] text-muted">No staff accounts match these filters.</p>}
          <div className="overflow-x-auto"><table className="w-full min-w-[670px] border-collapse text-left text-[11px]">
            <thead className="bg-soft-gray text-[9px] text-muted"><tr>{["STAFF MEMBER", "ROLE", "STATUS", "UPDATED", "ACTIONS"].map((label) => <th key={label} className="p-3 font-semibold">{label}</th>)}</tr></thead>
            <tbody>{roster.data.items.map((user) => <tr key={user.user_id} className="border-b border-border">
              <td className="p-3"><b className="block">{user.full_name}</b><span className="mt-1 block text-[10px] text-muted">{user.email ?? "Email not recorded"}</span></td>
              <td className="p-3">{administratorRoleLabel(user.role)}</td><td className="p-3"><Badge tone={user.is_active ? "green" : "amber"}>{user.is_active ? "ACTIVE" : "INACTIVE"}</Badge></td><td className="p-3 text-[10px] text-muted">{stamp(user.updated_at)}</td>
              <td className="p-3">{user.role === "admin" ? <span className="text-[10px] text-muted">Protected account</span> : <div className="flex flex-wrap gap-2">
                <Button variant="secondary" disabled={busy} onClick={() => openEditor(user)}>Edit account</Button>
                <Button variant="secondary" disabled={busy} onClick={() => { closeEditor(); setPending({ action: "revoke", user }); setError(""); setNotice(""); }}>Sign out sessions</Button>
              </div>}</td>
            </tr>)}</tbody>
          </table></div>
          <nav aria-label="Staff pagination" className="mt-4 flex items-center justify-between gap-3 border-t border-border pt-4 text-[10px]">
            <span>{roster.data.total ? `Page ${roster.data.page} of ${roster.data.total_pages}` : "No pages"} · {roster.data.total} staff accounts</span>
            <div className="flex gap-2"><Button variant="secondary" disabled={busy || query.page <= 1} onClick={() => setQuery({ ...query, page: query.page - 1 })}>Previous</Button><Button variant="secondary" disabled={busy || query.page >= roster.data.total_pages} onClick={() => setQuery({ ...query, page: query.page + 1 })}>Next</Button></div>
          </nav>
        </>}
      </Card>
    </>}
    {tab === "rules" && <>
      <Card><SectionHead title="Session and login policy" subtitle="Current server configuration" />
        {policyError && <div role="alert" className="flex items-center justify-between gap-3 text-[11px] text-priority-red">{policyError}<Button variant="secondary" onClick={() => setPolicyVersion((value) => value + 1)}>Retry policy</Button></div>}
        {!policy && !policyError && <p role="status" className="text-[11px] text-muted">Loading current policy…</p>}
        {policy && <dl className="m-0 grid grid-cols-2 gap-4 text-[11px] max-[650px]:grid-cols-1 [&_dt]:text-muted [&_dd]:m-0 [&_dd]:mt-1 [&_dd]:font-semibold">
          {[["Password minimum", `${policy.password_min_length} characters`], ["Session duration", `${policy.session_ttl_seconds / 3600} hours`], ["Maximum concurrent sessions", String(policy.max_sessions_per_user)], ["Login throttling", `${policy.login_attempts} attempts per ${policy.login_window_seconds} seconds, per IP and email`], ["Secure cookies", policy.secure_cookies ? "Enabled" : "Disabled for local development"], ["Operational timezone", policy.timezone]].map(([label, value]) => <div key={label}><dt>{label}</dt><dd>{value}</dd></div>)}
        </dl>}
      </Card>
      <Card><SectionHead title="Operational access and records" />
        <ul className="m-0 grid gap-3 pl-4 text-[11px] leading-relaxed text-muted">
          <li>Super Admins manage normal Administrator accounts. Both administrator tiers handle reports, validation, incidents, and response teams.</li>
          <li>Verified reports require staff notes and a final priority. Review checklists are optional.</li>
          <li>Response teams are assigned to incidents. Administrators record acknowledgment, responding, and completion.</li>
          <li>Operational records use soft deletion. Audit and processing history are retained. Automated retention deletion is not configured.</li>
          <li>Mobile OTP, report submission, SMS ingestion, and advisory ML integration are pending implementation.</li>
        </ul>
      </Card>
    </>}
  </>;
}
