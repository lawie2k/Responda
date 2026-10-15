import { useMemo, useState } from "react";
import { Icon } from "../../components/Icon";
import { Badge, Button, Card, PageTitle } from "../../components/ui";
import {
  initialMobileAccounts,
  type MobileAccount,
  type MobileAccountStatus,
} from "../../data/mobileAccounts";

const accentClasses: Record<string, string> = {
  blue: "bg-blue-soft text-status-blue",
  amber: "bg-amber-soft text-priority-amber",
  green: "bg-green-soft text-status-green",
  rose: "bg-blush text-maroon",
};

const statusLabel: Record<MobileAccountStatus, string> = {
  ACTIVE: "ACTIVE",
  NEEDS_ATTENTION: "NEEDS ATTENTION",
  SUSPENDED: "SUSPENDED",
};

const statusTone = (status: MobileAccountStatus) =>
  status === "ACTIVE" ? "green" : status === "SUSPENDED" ? "red" : "amber";

const displayName = (account: MobileAccount) =>
  account.fullName || "Name not provided";

export function MobileAccounts() {
  const [accounts, setAccounts] = useState(initialMobileAccounts);
  const [selectedId, setSelectedId] = useState(initialMobileAccounts[0].id);
  const [statusFilter, setStatusFilter] = useState("ALL");
  const [search, setSearch] = useState("");
  const [notes, setNotes] = useState("");
  const [feedback, setFeedback] = useState("");

  const filteredAccounts = useMemo(
    () =>
      accounts.filter((account) => {
        const query = search.trim().toLowerCase();
        return (
          (!query ||
            `${account.fullName} ${account.phone} ${account.id} ${account.barangay}`
              .toLowerCase()
              .includes(query)) &&
          (statusFilter === "ALL" || account.status === statusFilter)
        );
      }),
    [accounts, search, statusFilter],
  );

  const selected =
    accounts.find((account) => account.id === selectedId) ??
    filteredAccounts[0] ??
    accounts[0];

  const counts = {
    ALL: accounts.length,
    ACTIVE: accounts.filter((account) => account.status === "ACTIVE").length,
    NEEDS_ATTENTION: accounts.filter(
      (account) => account.status === "NEEDS_ATTENTION",
    ).length,
    SUSPENDED: accounts.filter((account) => account.status === "SUSPENDED")
      .length,
  };

  const selectAccount = (account: MobileAccount) => {
    setSelectedId(account.id);
    setNotes("");
    setFeedback("");
  };

  const updateStatus = (status: MobileAccountStatus) => {
    if (!notes.trim()) return;
    setAccounts((current) =>
      current.map((account) =>
        account.id === selected.id ? { ...account, status } : account,
      ),
    );
    setFeedback(
      `${displayName(selected)} was marked ${statusLabel[status].toLowerCase()}.`,
    );
    setNotes("");
  };

  return (
    <>
      <PageTitle
        title="Mobile Accounts"
        subtitle="Monitor accounts activated through mobile-number OTP verification."
      />

      <div className="flex min-h-[58px] items-center gap-3 rounded-[16px] bg-blue-soft px-4 py-3 text-status-blue max-[650px]:items-start">
        <Icon name="phone" />
        <div className="min-w-0 flex-1">
          <b className="block text-[10px]">Phone OTP activates the account</b>
          <span className="mt-1 block text-[9px] leading-[1.45] text-[#315f86]">
            Users no longer submit a valid ID or face photo. MDRRMO staff do not
            approve account creation; this page is for account monitoring and
            administrative flags.
          </span>
        </div>
        <Badge tone="green">OTP FLOW</Badge>
      </div>

      <Card className="flex min-h-[58px] items-center gap-[9px] overflow-x-auto px-[10px] py-2 max-[650px]:items-stretch [&_.account-search]:min-w-[230px] [&_.account-search]:flex-1 max-[650px]:[&_.account-search]:shrink-0">
        <div className="flex gap-[3px] rounded-[11px] bg-soft-gray p-[3px] [&>button]:h-8 [&>button]:rounded-[9px] [&>button]:border-0 [&>button]:bg-transparent [&>button]:px-3 [&>button]:text-[9px] [&>button]:text-muted [&>button.active]:bg-white [&>button.active]:text-maroon [&>button.active]:shadow-[0_2px_6px_#0001]">
          {(
            ["ALL", "ACTIVE", "NEEDS_ATTENTION", "SUSPENDED"] as const
          ).map((status) => (
            <button
              className={statusFilter === status ? "active" : ""}
              onClick={() => setStatusFilter(status)}
              key={status}
            >
              {status === "NEEDS_ATTENTION"
                ? "Needs attention"
                : status[0] + status.slice(1).toLowerCase()} {counts[status]}
            </button>
          ))}
        </div>
        <label className="account-search flex h-[38px] min-w-[170px] items-center gap-[7px] rounded-[10px] border border-border bg-white px-[10px] text-muted [&_input]:w-full [&_input]:border-0 [&_input]:bg-transparent [&_input]:text-[9px] [&_input]:text-[#1c1c1e] [&_input]:outline-0">
          <Icon name="search" size={15} />
          <input
            aria-label="Search mobile accounts"
            value={search}
            onChange={(event) => setSearch(event.target.value)}
            placeholder="Search name, phone, barangay, or reference"
          />
        </label>
      </Card>

      {feedback && (
        <div className="flex min-h-[42px] items-center gap-2 rounded-xl bg-green-soft px-3 text-[10px] font-semibold text-status-green" role="status">
          <Icon name="check" />
          {feedback}
        </div>
      )}

      <div className="grid grid-cols-[minmax(300px,.78fr)_minmax(520px,1.7fr)] items-start gap-4 max-[1180px]:grid-cols-[340px_minmax(0,1fr)] max-[900px]:grid-cols-1">
        <Card className="flex flex-col gap-3">
          <div className="flex items-center gap-[10px] [&>div]:flex-1 [&_h3]:m-0 [&_h3]:text-[15px] [&_p]:mb-0 [&_p]:mt-[3px] [&_p]:text-[9px] [&_p]:text-muted">
            <div>
              <h3>Registered accounts</h3>
              <p>{filteredAccounts.length} accounts shown</p>
            </div>
            <Badge tone="green">{counts.ACTIVE} ACTIVE</Badge>
          </div>

          <div className="grid gap-2 max-[900px]:grid-cols-2 max-[650px]:grid-cols-1 [&>button]:flex [&>button]:min-h-[78px] [&>button]:items-center [&>button]:gap-[9px] [&>button]:rounded-[13px] [&>button]:border [&>button]:border-transparent [&>button]:bg-soft-gray [&>button]:p-[9px] [&>button]:text-left [&>button:hover]:border-[rgba(122,31,43,.35)] [&>button:hover]:bg-blush [&>button.selected]:border-[rgba(122,31,43,.35)] [&>button.selected]:bg-blush">
            {filteredAccounts.length ? (
              filteredAccounts.map((account) => (
                <button
                  className={selected.id === account.id ? "selected" : ""}
                  onClick={() => selectAccount(account)}
                  key={account.id}
                >
                  <span className={`grid size-[42px] shrink-0 place-items-center rounded-[13px] text-[11px] font-extrabold ${accentClasses[account.accent] ?? accentClasses.rose}`}>
                    {account.initials}
                  </span>
                  <span className="grid min-w-0 flex-1 gap-[3px] [&_em]:overflow-hidden [&_em]:text-ellipsis [&_em]:whitespace-nowrap [&_em]:text-[8px] [&_em]:not-italic [&_em]:text-status-blue [&_small]:overflow-hidden [&_small]:text-ellipsis [&_small]:whitespace-nowrap [&_small]:text-[8px] [&_small]:text-muted [&_strong]:overflow-hidden [&_strong]:text-ellipsis [&_strong]:whitespace-nowrap [&_strong]:text-[10px]">
                    <strong>{displayName(account)}</strong>
                    <small>Joined {account.joined}</small>
                    <em>{account.phone}</em>
                  </span>
                  <Badge tone={statusTone(account.status)} dot={false}>
                    {statusLabel[account.status]}
                  </Badge>
                  <Icon name="chevron" size={14} />
                </button>
              ))
            ) : (
              <div className="flex min-h-60 flex-col items-center justify-center gap-2 text-center text-muted [&_b]:text-[11px] [&_b]:text-[#1c1c1e] [&_span]:text-[9px]">
                <Icon name="users" size={28} />
                <b>No mobile accounts found</b>
                <span>Change the filters or search text.</span>
              </div>
            )}
          </div>
        </Card>

        <Card className="flex flex-col gap-3">
          <div className="flex items-center gap-[10px] [&>div]:flex-1 [&_h3]:m-0 [&_h3]:text-[15px] [&_p]:mb-0 [&_p]:mt-[3px] [&_p]:text-[9px] [&_p]:text-muted">
            <span className={`grid size-12 shrink-0 place-items-center rounded-[14px] text-[12px] font-extrabold ${accentClasses[selected.accent] ?? accentClasses.rose}`}>
              {selected.initials}
            </span>
            <div>
              <span className="block text-[9px] font-bold tracking-[.04em] text-muted">{selected.id}</span>
              <h3>{displayName(selected)}</h3>
              <p>Account created {selected.joined} from the mobile app</p>
            </div>
            <Badge tone={statusTone(selected.status)}>
              {statusLabel[selected.status]}
            </Badge>
          </div>

          <div className="grid grid-cols-2 gap-3 max-[650px]:grid-cols-1">
            <div className="flex min-h-[116px] flex-col gap-2 rounded-[14px] bg-green-soft p-3">
              <div className="flex items-center justify-between gap-2">
                <span className="grid size-9 place-items-center rounded-[11px] bg-white text-status-green"><Icon name="phone" size={17} /></span>
                <Badge tone="green">OTP VERIFIED</Badge>
              </div>
              <b className="text-[12px]">{selected.phone}</b>
              <span className="text-[8px] text-muted">Verified {selected.phoneVerified}</span>
            </div>
            <div className="flex min-h-[116px] flex-col gap-2 rounded-[14px] bg-blue-soft p-3">
              <div className="flex items-center justify-between gap-2">
                <span className="grid size-9 place-items-center rounded-[11px] bg-white text-status-blue"><Icon name="shield" size={17} /></span>
                <Badge tone="blue" dot={false}>CONSENT SAVED</Badge>
              </div>
              <b className="text-[11px]">Privacy notice accepted</b>
              <span className="text-[8px] text-muted">{selected.privacyAccepted}</span>
            </div>
          </div>

          <div className="grid grid-cols-2 gap-3 max-[650px]:grid-cols-1">
            <div className="rounded-[14px] bg-soft-gray p-3">
              <span className="block text-[8px] font-extrabold tracking-[.05em] text-muted">OPTIONAL PROFILE</span>
              <div className="mt-3 grid gap-3 text-[9px] [&>div]:flex [&>div]:justify-between [&>div]:gap-4 [&_b]:text-right">
                <div><span className="text-muted">Full name</span><b>{selected.fullName || "Not provided"}</b></div>
                <div><span className="text-muted">Barangay</span><b>{selected.barangay || "Not provided"}</b></div>
              </div>
            </div>
            <div className="rounded-[14px] bg-soft-gray p-3">
              <span className="block text-[8px] font-extrabold tracking-[.05em] text-muted">ACCOUNT ACTIVITY</span>
              <div className="mt-3 grid gap-3 text-[9px] [&>div]:flex [&>div]:justify-between [&>div]:gap-4 [&_b]:text-right">
                <div><span className="text-muted">Last active</span><b>{selected.lastActive}</b></div>
                <div><span className="text-muted">Reports submitted</span><b>{selected.reportsSubmitted}</b></div>
              </div>
            </div>
          </div>

          <div className="flex flex-col gap-2 rounded-[14px] bg-soft-gray p-[11px] [&_textarea]:min-h-[74px] [&_textarea]:resize-y [&_textarea]:rounded-[10px] [&_textarea]:border [&_textarea]:border-border [&_textarea]:bg-white [&_textarea]:p-[9px] [&_textarea]:text-[9px]">
            <span className="block text-[9px] font-bold tracking-[.04em] text-muted">ADMIN ACCOUNT NOTE</span>
            <textarea
              value={notes}
              onChange={(event) => setNotes(event.target.value)}
              placeholder="Add a required note before changing the account status…"
            />
          </div>

          <div className="flex min-h-16 items-center gap-[10px] rounded-[14px] bg-soft-gray px-3 py-[10px] max-[650px]:flex-col max-[650px]:items-stretch [&>div]:flex-1 [&_b]:block [&_b]:text-[10px] [&_span]:mt-[3px] [&_span]:block [&_span]:text-[8px] [&_span]:text-muted max-[650px]:[&_.button]:w-full">
            <div>
              <b>Administrative account status</b>
              <span>OTP verification stays recorded. A note is required for status changes.</span>
            </div>
            {selected.status === "ACTIVE" ? (
              <>
                <Button variant="secondary" icon="alert" disabled={!notes.trim()} onClick={() => updateStatus("NEEDS_ATTENTION")}>
                  Mark needs attention
                </Button>
                <Button variant="danger" icon="alert" disabled={!notes.trim()} onClick={() => updateStatus("SUSPENDED")}>
                  Suspend
                </Button>
              </>
            ) : (
              <Button icon="check" disabled={!notes.trim()} onClick={() => updateStatus("ACTIVE")}>
                Restore active account
              </Button>
            )}
          </div>
        </Card>
      </div>
    </>
  );
}
