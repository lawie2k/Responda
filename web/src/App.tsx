import { useEffect, useMemo, useRef, useState } from "react";
import type { AdminSession } from "./api/respondaApi";
import respondaLogo from "./assets/responda-logo.png";
import { BackendStatus } from "./components/BackendStatus";
import { Icon } from "./components/Icon";
import { ReportModal } from "./components/ReportModal";
import { Sidebar } from "./components/Sidebar";
import { Button } from "./components/ui";
import { pageInfo } from "./config/navigation";
import { canAccessDashboardPage } from "./config/roles";
import { toReport } from "./data/reports";
import { useAdminReports } from "./hooks/useAdminReports";
import { Analytics } from "./pages/Analytics";
import { MobileAccounts } from "./pages/mobile-accounts/MobileAccounts";
import { HistoricalRecords } from "./pages/HistoricalRecords";
import { IncidentMap } from "./pages/IncidentMap";
import { LiveReports } from "./pages/LiveReports";
import { Overview } from "./pages/Overview";
import { Login } from "./pages/Login";
import { ReportValidation } from "./pages/ReportValidation";
import { ResponseTeams } from "./pages/ResponseTeams";
import { Settings } from "./pages/Settings";
import { useAdminSession } from "./hooks/useAdminSession";
import type { Page } from "./types";

type Notification = {
  id: number;
  title: string;
  detail: string;
  time: string;
  page: Page;
  read: boolean;
};

export default function App() {
  const { state, login, logout } = useAdminSession();

  if (state.status === "checking") {
    return (
      <main className="grid min-h-screen place-items-center bg-[#f7f4f5]">
        <div className="grid justify-items-center gap-4 text-center">
          <span className="grid size-16 place-items-center rounded-[20px] bg-white p-2.5 shadow-[0_14px_38px_rgba(84,19,29,.12)]">
            <img
              src={respondaLogo}
              alt="RESPONDA logo"
              className="size-full object-contain"
            />
          </span>
          <div>
            <b className="block text-sm tracking-[.08em] text-deep">RESPONDA</b>
            <span className="mt-1 block text-[9px] text-muted">
              Verifying secure session…
            </span>
          </div>
          <i className="size-5 animate-spin rounded-full border-2 border-maroon/20 border-t-maroon" />
        </div>
      </main>
    );
  }

  if (state.status === "signed-out") {
    return <Login onLogin={login} />;
  }

  return (
    <Dashboard
      key={`${state.session.user.user_id}:${state.session.expires_at}`}
      session={state.session}
      onLogout={logout}
    />
  );
}

function Dashboard({
  session,
  onLogout,
}: {
  session: AdminSession;
  onLogout: () => Promise<void>;
}) {
  const [page, setPage] = useState<Page>("Overview");
  const [query, setQuery] = useState("");
  const [sidebarOpen, setSidebarOpen] = useState(false);
  const [reportModalOpen, setReportModalOpen] = useState(false);
  const [reportRefreshVersion, setReportRefreshVersion] = useState(0);
  const [reportNotice, setReportNotice] = useState("");
  const [validationTarget, setValidationTarget] = useState<string | null>(null);
  const [searchOpen, setSearchOpen] = useState(false);
  const [notificationsOpen, setNotificationsOpen] = useState(false);
  const [notifications, setNotifications] = useState<Notification[]>([
    {
      id: 2,
      title: "New phone-verified account",
      detail: "A mobile user completed OTP verification and account setup.",
      time: "12 min ago",
      page: "Mobile Accounts",
      read: false,
    },
    {
      id: 3,
      title: "Team status updated",
      detail: "Rescue Alpha is now on route to an incident.",
      time: "25 min ago",
      page: "Response Teams",
      read: false,
    },
  ]);
  const searchRef = useRef<HTMLDivElement>(null);
  const notificationsRef = useRef<HTMLDivElement>(null);
  const reportQuery = useAdminReports(
    { pageSize: 100 },
    page === "Live Reports" ? 5000 : 0,
  );
  const dashboardReports = useMemo(
    () => reportQuery.data?.items.map(toReport) ?? [],
    [reportQuery.data],
  );
  const info = pageInfo[page];
  const normalizedQuery = query.trim().toLowerCase();
  const matchingReports = useMemo(
    () =>
      normalizedQuery
        ? dashboardReports
            .filter((report) =>
              `${report.reference} ${report.id} ${report.incident} ${report.location} ${report.barangay ?? ""} ${report.priority} ${report.status}`
                .toLowerCase()
                .includes(normalizedQuery),
            )
            .slice(0, 5)
        : [],
    [dashboardReports, normalizedQuery],
  );
  const matchingPages = useMemo(
    () =>
      normalizedQuery
        ? (Object.keys(pageInfo) as Page[])
            .filter((name) =>
              canAccessDashboardPage(session.user.role, name),
            )
            .filter((name) =>
              `${name} ${pageInfo[name][1]}`
                .toLowerCase()
                .includes(normalizedQuery),
            )
            .slice(0, 4)
        : [],
    [normalizedQuery, session.user.role],
  );
  const unreadCount = notifications.filter(
    (notification) => !notification.read,
  ).length;

  useEffect(() => {
    const closeHeaderMenus = (event: MouseEvent) => {
      const target = event.target as Node;
      if (!searchRef.current?.contains(target)) setSearchOpen(false);
      if (!notificationsRef.current?.contains(target)) {
        setNotificationsOpen(false);
      }
    };
    document.addEventListener("mousedown", closeHeaderMenus);
    return () => document.removeEventListener("mousedown", closeHeaderMenus);
  }, []);

  useEffect(() => {
    if (!reportNotice) return;
    const timer = window.setTimeout(() => setReportNotice(""), 4500);
    return () => window.clearTimeout(timer);
  }, [reportNotice]);

  return (
    <div className="dashboard-shell flex min-h-screen bg-[#f4f2f0]">
      <Sidebar
        page={page}
        go={setPage}
        open={sidebarOpen}
        close={() => setSidebarOpen(false)}
        user={session.user}
        onLogout={onLogout}
      />
      <main
        className={
          "ml-60 min-w-0 w-[calc(100%-15rem)] bg-[#f4f2f0] max-[1100px]:ml-0 max-[1100px]:w-full"
        }
      >
        <header
          className={
            "sticky top-0 z-[100] flex h-[72px] items-center gap-5 border-b border-[#dcd7d4] bg-[#fdfcfb]/95 px-7 backdrop-blur-sm max-[1100px]:px-4 max-[650px]:h-auto max-[650px]:min-h-[72px] max-[650px]:flex-wrap max-[650px]:gap-2 max-[650px]:py-3"
          }
        >
          <button
            aria-label="Open navigation"
            className={
              "hidden size-10 shrink-0 place-items-center rounded-[7px] border border-[#d9d5d2] bg-white text-[#1c1c1e] max-[1100px]:grid"
            }
            onClick={() => setSidebarOpen(true)}
          >
            <Icon name="menu" />
          </button>
          <div
            className={
              "min-w-0 flex-1 [&_h1]:m-0 [&_h1]:truncate [&_h1]:text-[12px] [&_h1]:font-semibold [&_p]:mb-0 [&_p]:mt-1 [&_p]:truncate [&_p]:text-[8px] [&_p]:font-bold [&_p]:tracking-[.12em] [&_p]:text-maroon max-[650px]:[&_h1]:text-[11px]"
            }
          >
            <h1>{info[0]}</h1>
            <p>RESPONDA OPERATIONS</p>
          </div>
          <BackendStatus />
          <div
            className={
              "flex items-center gap-[10px] max-[650px]:w-full max-[650px]:[&>.button]:hidden"
            }
          >
            <div
              className="relative w-[248px] max-[1100px]:w-[180px] max-[650px]:flex-1"
              ref={searchRef}
            >
              <label className="flex h-10 w-full items-center gap-2 rounded-[7px] border border-[#d9d5d2] bg-white px-3 text-muted [&_input]:w-full [&_input]:border-0 [&_input]:bg-transparent [&_input]:text-[10px] [&_input]:outline-0">
                <Icon name="search" />
                <input
                  aria-label="Search RESPONDA"
                  value={query}
                  onFocus={() => setSearchOpen(true)}
                  onChange={(event) => {
                    setQuery(event.target.value);
                    setSearchOpen(true);
                  }}
                  onKeyDown={(event) => {
                    if (event.key === "Enter" && query.trim()) {
                      setPage("Live Reports");
                      setSearchOpen(false);
                    }
                    if (event.key === "Escape") setSearchOpen(false);
                  }}
                  placeholder="Search reports or pages…"
                />
                {query && (
                  <button
                    type="button"
                    className="border-0 bg-transparent p-0 text-base text-muted"
                    onClick={() => {
                      setQuery("");
                      setSearchOpen(false);
                    }}
                  >
                    ×
                  </button>
                )}
              </label>
              {searchOpen && normalizedQuery && (
                <div className="absolute right-0 top-[calc(100%+8px)] z-[120] w-[360px] overflow-hidden rounded-[10px] border border-[#d9d5d2] bg-white p-2 shadow-[0_16px_40px_rgba(28,28,30,.14)] max-[650px]:left-0 max-[650px]:right-auto max-[650px]:w-[min(360px,calc(100vw-70px))]">
                  {!!matchingPages.length && (
                    <div>
                      <span className="block px-2 pb-1 pt-1 text-[8px] font-bold tracking-[.06em] text-muted">
                        PAGES
                      </span>
                      {matchingPages.map((name) => (
                        <button
                          className="flex min-h-10 w-full items-center gap-2 rounded-[6px] border-0 bg-white px-2 text-left hover:bg-soft-gray"
                          key={name}
                          onClick={() => {
                            setPage(name);
                            setQuery("");
                            setSearchOpen(false);
                          }}
                        >
                          <Icon name="chevron" size={14} />
                          <span className="grid gap-0.5">
                            <b className="text-[10px]">{name}</b>
                            <small className="text-[8px] text-muted">
                              {pageInfo[name][1]}
                            </small>
                          </span>
                        </button>
                      ))}
                    </div>
                  )}
                  {!!matchingReports.length && (
                    <div
                      className={
                        matchingPages.length
                          ? "mt-1 border-t border-border pt-1"
                          : ""
                      }
                    >
                      <span className="block px-2 pb-1 pt-1 text-[8px] font-bold tracking-[.06em] text-muted">
                        REPORTS
                      </span>
                      {matchingReports.map((report) => (
                        <button
                          className="flex min-h-11 w-full items-center gap-2 rounded-[6px] border-0 bg-white px-2 text-left hover:bg-soft-gray"
                          key={report.id}
                          onClick={() => {
                            setQuery(report.reference);
                            setPage("Live Reports");
                            setSearchOpen(false);
                          }}
                        >
                          <span className="grid size-8 shrink-0 place-items-center text-maroon">
                            <Icon name="reports" size={15} />
                          </span>
                          <span className="grid flex-1 gap-0.5">
                            <b className="text-[10px]">
                              {report.incident} · {report.reference}
                            </b>
                            <small className="text-[8px] text-muted">
                              {report.location}
                              {report.barangay
                                ? ` · Barangay ${report.barangay}`
                                : ""} {" "}
                              · {report.status}
                            </small>
                          </span>
                        </button>
                      ))}
                    </div>
                  )}
                  {!matchingPages.length && !matchingReports.length && (
                    <div className="px-3 py-6 text-center">
                      <b className="block text-[10px]">No results found</b>
                      <span className="mt-1 block text-[9px] text-muted">
                        Try a report ID, incident type, or page name.
                      </span>
                    </div>
                  )}
                </div>
              )}
            </div>
            <div className="relative shrink-0" ref={notificationsRef}>
              <button
                aria-label="Notifications"
                className="relative grid size-10 place-items-center rounded-[7px] border border-[#d9d5d2] bg-white text-[#1c1c1e]"
                onClick={() => {
                  setNotificationsOpen((open) => !open);
                  setSearchOpen(false);
                }}
              >
                <Icon name="bell" />
                {unreadCount > 0 && (
                  <i className="absolute right-[7px] top-[7px] size-[7px] rounded-full border border-white bg-priority-red" />
                )}
              </button>
              {notificationsOpen && (
                <div className="absolute right-0 top-[calc(100%+8px)] z-[120] w-[350px] overflow-hidden rounded-[10px] border border-[#d9d5d2] bg-white shadow-[0_16px_40px_rgba(28,28,30,.14)] max-[650px]:right-[-52px] max-[650px]:w-[min(350px,calc(100vw-24px))]">
                  <div className="flex items-center justify-between border-b border-border px-4 py-3">
                    <div>
                      <b className="block text-[12px]">Notifications</b>
                      <span className="text-[8px] text-muted">
                        {unreadCount} unread
                      </span>
                    </div>
                    <button
                      className="border-0 bg-transparent text-[9px] font-semibold text-maroon disabled:opacity-40"
                      disabled={!unreadCount}
                      onClick={() =>
                        setNotifications((items) =>
                          items.map((item) => ({ ...item, read: true })),
                        )
                      }
                    >
                      Mark all read
                    </button>
                  </div>
                  <div className="p-2">
                    {notifications.map((notification) => (
                      <button
                        className={`flex min-h-[66px] w-full gap-3 rounded-[6px] border-0 border-l-2 px-3 py-2.5 text-left hover:bg-soft-gray ${notification.read ? "border-l-transparent bg-white" : "border-l-maroon bg-[#fbf6f7]"}`}
                        key={notification.id}
                        onClick={() => {
                          setNotifications((items) =>
                            items.map((item) =>
                              item.id === notification.id
                                ? { ...item, read: true }
                                : item,
                            ),
                          );
                          setPage(notification.page);
                          setNotificationsOpen(false);
                        }}
                      >
                        <span className="relative mt-0.5 grid size-8 shrink-0 place-items-center text-maroon">
                          <Icon name="bell" size={15} />
                          {!notification.read && (
                            <i className="absolute -right-0.5 -top-0.5 size-2 rounded-full border border-white bg-priority-red" />
                          )}
                        </span>
                        <span className="grid flex-1 gap-0.5">
                          <b className="text-[10px]">{notification.title}</b>
                          <small className="text-[8px] leading-[1.4] text-muted">
                            {notification.detail}
                          </small>
                          <small className="text-[8px] text-maroon">
                            {notification.time}
                          </small>
                        </span>
                      </button>
                    ))}
                  </div>
                </div>
              )}
            </div>
            <Button icon="plus" onClick={() => setReportModalOpen(true)}>
              Encode a report
            </Button>
          </div>
        </header>
        <div
          className={
            page === "Mobile Accounts"
              ? "mx-auto flex min-h-[calc(100vh-72px)] max-w-[1600px] flex-col gap-5 px-7 pt-7 pb-5 max-[1100px]:px-4 max-[1100px]:pt-5 max-[650px]:px-3 max-[650px]:pt-4 max-[1000px]:min-h-0"
              : "mx-auto flex max-w-[1600px] flex-col gap-5 px-7 py-7 pb-10 max-[1100px]:px-4 max-[1100px]:py-5 max-[650px]:px-3 max-[650px]:py-4"
          }
        >
          {reportNotice && (
            <div
              className="flex min-h-[42px] items-center gap-2 rounded-xl bg-green-soft px-3 text-[10px] font-semibold text-status-green"
              role="status"
            >
              <Icon name="check" />
              {reportNotice}
            </div>
          )}
          {page === "Overview" && (
            <Overview
              go={setPage}
              firstName={session.user.full_name.split(/\s+/)[0] || "Staff"}
              reports={dashboardReports}
              reportStatus={reportQuery.status}
              reportError={reportQuery.error}
              retryReports={reportQuery.refetch}
            />
          )}
          {page === "Live Reports" && (
            <LiveReports
              key={`live-reports-${reportRefreshVersion}`}
              query={query}
              summaryReports={dashboardReports}
              userRole={session.user.role}
              onReportsChanged={reportQuery.refetch}
              openModal={() => setReportModalOpen(true)}
              openValidation={(reportId) => {
                setValidationTarget(reportId);
                setPage("Report Validation");
              }}
            />
          )}
          {page === "Incident Map" && (
            <IncidentMap
              reports={dashboardReports}
              reportStatus={reportQuery.status}
              reportError={reportQuery.error}
              retryReports={reportQuery.refetch}
            />
          )}
          {page === "Report Validation" && (
            <ReportValidation
              selectedReportId={validationTarget}
              userRole={session.user.role}
              onReportReviewed={reportQuery.refetch}
            />
          )}
          {page === "Mobile Accounts" && <MobileAccounts userRole={session.user.role} />}
          {page === "Response Teams" && (
            <ResponseTeams
              role={session.user.role}
              onAssignmentsChanged={reportQuery.refetch}
            />
          )}
          {page === "Analytics" && <Analytics go={setPage} />}
          {page === "Historical Records" && <HistoricalRecords />}
          {page === "Settings" && <Settings />}
        </div>
      </main>
      {reportModalOpen && (
        <ReportModal
          close={() => setReportModalOpen(false)}
          onCreated={(result) => {
            setReportModalOpen(false);
            setReportNotice(
              `Report RSP-${result.report_id.slice(0, 8).toUpperCase()} was created and sent to validation.`,
            );
            reportQuery.refetch();
            setReportRefreshVersion((value) => value + 1);
            setPage("Live Reports");
          }}
        />
      )}
    </div>
  );
}
