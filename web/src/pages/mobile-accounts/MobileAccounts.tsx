import { useEffect, useRef, useState } from "react";
import { changeMobileAccountStatus, type AccountReason, type MobileAccount } from "../../api/adminMobileAccounts";
import type { AdminUser } from "../../api/respondaApi";
import { Badge, Button, Card, PageTitle, SectionHead } from "../../components/ui";
import { useAdminMobileAccounts } from "../../hooks/useAdminMobileAccounts";

const inputClass = "h-[38px] rounded-[7px] border border-border bg-white px-3 text-[11px] outline-maroon";
const stamp = (value: string | null) => value ? new Intl.DateTimeFormat("en-PH", {
  timeZone: "Asia/Manila", dateStyle: "medium", timeStyle: "short",
}).format(new Date(value)) : "Not recorded";
const name = (account: MobileAccount) => account.full_name || "Name not provided";
const reasons = { suspected_misuse: "Suspected misuse", account_security: "Account security", review_completed: "Review completed" };

export function MobileAccounts({ userRole }: { userRole: AdminUser["role"] }) {
  const [query, setQuery] = useState({ page: 1, search: "", active: "" });
  const [search, setSearch] = useState("");
  const roster = useAdminMobileAccounts(query);
  const [selectedId, setSelectedId] = useState<string | null>(null);
  const selected = roster.data?.items.find(item => item.user_id === selectedId) ?? roster.data?.items[0] ?? null;
  const [pending, setPending] = useState<{ account: MobileAccount; isActive: boolean } | null>(null);
  const [reason, setReason] = useState<AccountReason | "">("");
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState("");
  const [notice, setNotice] = useState("");
  const mutation = useRef<AbortController | null>(null);
  const canManage = userRole === "admin";
  useEffect(() => () => mutation.current?.abort(), []);

  const closePending = () => { setPending(null); setReason(""); setError(""); };
  const changeQuery = (next: typeof query) => { closePending(); setSelectedId(null); setNotice(""); setQuery(next); };
  const select = (account: MobileAccount) => { closePending(); setSelectedId(account.user_id); setNotice(""); };
  const perform = async () => {
    if (!pending || !reason || mutation.current || !canManage) return;
    const controller = new AbortController(); mutation.current = controller;
    setBusy(true); setError(""); setNotice("");
    try {
      await changeMobileAccountStatus(pending.account, pending.isActive, reason, controller.signal);
      if (!controller.signal.aborted) {
        setNotice(pending.isActive ? "Account restored. The citizen can sign in again with OTP." : "Account suspended and all sessions signed out.");
        closePending(); roster.refetch();
      }
    } catch (caught) {
      if (!controller.signal.aborted) setError(caught instanceof Error ? caught.message : "The account could not be updated.");
    } finally {
      if (!controller.signal.aborted) { mutation.current = null; setBusy(false); }
    }
  };

  return <>
    <PageTitle title="Mobile Accounts" subtitle="Monitor citizens registered through phone OTP verification." />
    <div className="border border-border border-l-[3px] border-l-maroon bg-white px-4 py-3 text-[11px] leading-relaxed text-muted">
      Phone OTP activates accounts. Name and barangay are optional. Phone numbers stay masked in this workspace.
    </div>

    {roster.data && <div className="grid grid-cols-3 gap-3 max-[650px]:grid-cols-1">
      {[["Registered accounts", roster.data.counts.total], ["Active", roster.data.counts.active], ["Suspended", roster.data.counts.suspended]].map(([label, value]) => <Card key={label} className="py-3">
        <span className="text-[10px] text-muted">{label}</span><b className="mt-1 block text-[23px]">{value}</b>
      </Card>)}
    </div>}

    <Card>
      <form className="flex flex-wrap items-end gap-3" onSubmit={event => { event.preventDefault(); changeQuery({ ...query, page: 1, search: search.trim() }); }}>
        <label className="grid min-w-[220px] flex-1 gap-1 text-[10px] font-semibold">Search accounts
          <input className={inputClass} aria-label="Search mobile accounts" maxLength={100} value={search}
            disabled={busy} onChange={event => setSearch(event.target.value)} placeholder="Name, barangay, full phone number or account ID" />
        </label>
        <label className="grid gap-1 text-[10px] font-semibold">Status
          <select className={inputClass} aria-label="Account status filter" value={query.active} disabled={busy}
            onChange={event => changeQuery({ ...query, page: 1, active: event.target.value })}>
            <option value="">All accounts</option><option value="true">Active</option><option value="false">Suspended</option>
          </select>
        </label>
        <Button type="submit" disabled={busy || roster.status === "loading"}>Search</Button>
        <Button variant="secondary" disabled={busy} onClick={() => { setSearch(""); changeQuery({ page: 1, search: "", active: "" }); roster.refetch(); }}>Reset</Button>
        <Button variant="secondary" disabled={busy || roster.status === "loading"} onClick={() => { closePending(); roster.refetch(); }}>Refresh</Button>
      </form>
    </Card>
    {notice && <div role="status" className="border border-border bg-white p-3 text-[11px]">{notice}</div>}
    {error && <div role="alert" className="border border-status-red p-3 text-[11px] text-status-red">{error} Refresh to load the latest account state.</div>}
    {roster.status === "loading" && <Card><p role="status" className="text-[12px] text-muted">Loading mobile accounts…</p></Card>}
    {roster.status === "error" && <Card><p role="alert" className="text-[12px] text-status-red">{roster.error}</p><Button variant="secondary" onClick={roster.refetch}>Retry</Button></Card>}
    {roster.data && <div className="grid flex-1 grid-cols-[minmax(300px,.85fr)_minmax(420px,1.3fr)] items-stretch gap-4 max-[1000px]:flex-none max-[1000px]:grid-cols-1">
      <Card className="flex flex-col gap-3">
        <SectionHead title="Registered accounts" subtitle={`${roster.data.total} accounts match the current view`} />
        <div className="grid gap-2">
          {roster.data.items.map(account => <button key={account.user_id} disabled={busy} onClick={() => select(account)}
            aria-pressed={selected?.user_id === account.user_id}
            className={`flex items-center justify-between gap-3 rounded-lg border p-3 text-left disabled:opacity-50 ${selected?.user_id === account.user_id ? "border-maroon bg-blush" : "border-border bg-white hover:bg-soft-gray"}`}>
            <span className="grid min-w-0 gap-1"><b className="truncate text-[12px]">{name(account)}</b>
              <span className="text-[11px] text-muted">{account.masked_phone}</span>
              <span className="text-[10px] text-muted">{account.barangay || "Barangay not provided"}</span></span>
            <Badge tone={account.is_active ? "green" : "red"}>{account.is_active ? "ACTIVE" : "SUSPENDED"}</Badge>
          </button>)}
          {!roster.data.items.length && <p className="py-12 text-center text-[12px] text-muted">{roster.data.total ? "No accounts on this page. Go to the previous page." : "No registered mobile accounts match this view."}</p>}
        </div>
        <div className="mt-auto flex flex-wrap items-center justify-between gap-2 border-t border-border pt-3">
          <span className="text-[10px] text-muted">Page {roster.data.page} of {roster.data.total_pages || 1} · {roster.data.total} accounts</span>
          <div className="flex gap-2">
            <Button variant="secondary" disabled={busy || query.page <= 1} onClick={() => changeQuery({ ...query, page: query.page - 1 })}>Previous</Button>
            <Button variant="secondary" disabled={busy || query.page >= roster.data.total_pages} onClick={() => changeQuery({ ...query, page: query.page + 1 })}>Next</Button>
          </div>
        </div>
      </Card>

      <Card className="flex flex-col gap-4">
        {selected ? <>
          <div className="flex items-start justify-between gap-3">
            <SectionHead title={name(selected)} subtitle="Mobile account details" />
            <Badge tone={selected.is_active ? "green" : "red"}>{selected.is_active ? "ACTIVE" : "SUSPENDED"}</Badge>
          </div>
          <span className="break-all text-[10px] text-muted">Account ID · {selected.user_id}</span>
          <dl className="grid grid-cols-2 gap-4 border-y border-border py-4 text-[11px] max-[650px]:grid-cols-1 [&_dt]:mb-1 [&_dt]:text-muted [&_dd]:m-0 [&_dd]:font-semibold">
            <div><dt>Phone number</dt><dd>{selected.masked_phone}</dd></div>
            <div><dt>Barangay</dt><dd>{selected.barangay || "Not provided"}</dd></div>
            <div><dt>Account created</dt><dd>{stamp(selected.created_at)}</dd></div>
            <div><dt>Phone verified</dt><dd>{stamp(selected.phone_verified_at)}</dd></div>
            <div><dt>Privacy notice accepted</dt><dd>{stamp(selected.privacy_notice_accepted_at)}</dd></div>
            <div><dt>Last sign-in</dt><dd>{stamp(selected.last_sign_in_at)}</dd></div>
            <div><dt>App reports submitted</dt><dd>{selected.reports_submitted}</dd></div>
          </dl>
          <p className="m-0 text-[11px] leading-relaxed text-muted">Phone verification stays recorded when an account is suspended. Suspension prevents sign-in and signs out existing sessions. Restoration permits OTP sign-in again.</p>
          {canManage ? <>
            {!pending && <Button variant={selected.is_active ? "danger" : "secondary"} disabled={busy} onClick={() => {
              setPending({ account: selected, isActive: !selected.is_active });
              setReason(selected.is_active ? "" : "review_completed"); setError(""); setNotice("");
            }}>{selected.is_active ? "Suspend account" : "Restore account"}</Button>}
            {pending && <div className="grid gap-3 border border-border bg-soft-gray p-4" role="group" aria-label="Confirm account status change">
              <b className="text-[12px]">{pending.isActive ? "Restore this account?" : "Suspend this account?"}</b>
              <label className="grid gap-1 text-[11px]">Reason
                <select aria-label="Account status reason" className={inputClass} value={reason} disabled={busy} onChange={event => setReason(event.target.value as AccountReason | "")}>
                  <option value="">Choose a reason</option>
                  {(pending.isActive ? ["review_completed"] as const : ["suspected_misuse", "account_security"] as const).map(value => <option value={value} key={value}>{reasons[value]}</option>)}
                </select>
              </label>
              <div className="flex gap-2"><Button variant={pending.isActive ? "primary" : "danger"} disabled={busy || !reason} onClick={() => void perform()}>{busy ? "Saving…" : "Confirm change"}</Button>
                <Button variant="secondary" disabled={busy} onClick={closePending}>Cancel</Button></div>
            </div>}
          </> : <p className="text-[11px] text-muted">Only Super Admins can suspend or restore citizen accounts.</p>}
        </> : <p className="py-12 text-center text-[12px] text-muted">Select a registered account to view its details.</p>}
      </Card>
    </div>}
  </>;
}
