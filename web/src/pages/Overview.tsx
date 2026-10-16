import type { Page } from "../types";
import { tone, type Report } from "../data/reports";
import type { MapPoint } from "../data/mapData";
import { Icon } from "../components/Icon";
import { MiniMap } from "../components/Map";
import { ReportTable } from "../components/ReportTable";
import {
  Badge,
  Button,
  Card,
  SectionHead,
} from "../components/ui";

const colorClasses: Record<string, string> = {
  red: "bg-priority-red",
  orange: "bg-priority-orange",
  amber: "bg-priority-amber",
  green: "bg-status-green",
  blue: "bg-status-blue",
  maroon: "bg-maroon",
};

export function Overview({
  go,
  reports,
  reportStatus,
  reportError,
  retryReports,
}: {
  go: (p: Page) => void;
  firstName: string;
  reports: Report[];
  reportStatus: "loading" | "ready" | "error";
  reportError: string | null;
  retryReports: () => void;
}) {
  const criticalReports = reports.filter((report) => report.priority === "CRITICAL");
  const pendingReports = reports.filter((report) => report.status === "VERIFYING");
  const activeReports = reports.filter((report) => report.status !== "CLOSED");
  const reportedLocations = new Set(
    activeReports.map((report) => report.location),
  ).size;
  const currentDate = new Intl.DateTimeFormat("en-PH", {
    weekday: "long",
    month: "long",
    day: "numeric",
  }).format(new Date());
  const mapPoints: MapPoint[] = reports.flatMap((report) =>
    report.position
      ? [
          {
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
          } satisfies MapPoint,
        ]
      : [],
  );
  const priorityQueue = [...reports]
    .sort(
      (left, right) =>
        ["CRITICAL", "HIGH", "MEDIUM", "LOW"].indexOf(left.priority) -
          ["CRITICAL", "HIGH", "MEDIUM", "LOW"].indexOf(right.priority) ||
        new Date(right.receivedAt).getTime() - new Date(left.receivedAt).getTime(),
    )
    .slice(0, 3);

  return (
    <>
      <div className="min-h-[98px] border-b border-[#dcd7d4] pb-5">
        <div>
          <span className="mb-2 block text-[8px] font-bold tracking-[.16em] text-maroon">
            MUNICIPAL EMERGENCY OPERATIONS
          </span>
          <h2 className="m-0 text-[28px] font-semibold tracking-[-.035em] max-[650px]:text-[23px]">
            Pantukan operations overview
          </h2>
          <p className="mb-0 mt-2 text-[10px] text-muted">
            {currentDate} · Live MDRRMO incident coordination
          </p>
        </div>
      </div>
      {pendingReports.length > 0 && (
        <div
          className={
            "flex min-h-[58px] items-center gap-[10px] border border-[#e5d8bb] border-l-[3px] border-l-priority-amber bg-[#fffdf8] px-3 py-2 max-[650px]:flex-wrap max-[650px]:items-start [&>span]:grid [&>span]:size-8 [&>span]:shrink-0 [&>span]:place-items-center [&>span]:text-priority-amber [&>div]:min-w-0 [&>div]:flex-1 [&_b]:text-[11px] [&_b]:text-[#2d2527] [&_p]:my-0.5 [&_p]:text-[9px] [&_p]:text-muted max-[650px]:[&>.button]:w-full"
          }
        >
          <span>
            <Icon name="alert" />
          </span>
          <div>
            <b>
              {pendingReports.length} incoming{" "}
              {pendingReports.length === 1
                ? "report requires"
                : "reports require"}{" "}
              validation
            </b>
            <p>
              Confirm location, contact details, and ML-supported classifications
              before dispatch decisions.
            </p>
          </div>
          <Button variant="secondary" onClick={() => go("Live Reports")}>
            Review queue
          </Button>
        </div>
      )}
      <Card className="overflow-hidden p-0">
        <div className="grid grid-cols-[minmax(0,1.45fr)_minmax(300px,1fr)] max-[900px]:grid-cols-1">
          <div className="flex min-h-[238px] flex-col border-t-[3px] border-t-maroon px-6 py-5 max-[650px]:min-h-[205px] max-[650px]:px-5">
            <span className="text-[8px] font-bold tracking-[.11em] text-muted">
              ACTIVE REPORTS · CURRENT OPEN QUEUE
            </span>
            <strong className="mt-5 block text-[52px] font-semibold leading-none tracking-[-.06em] text-[#211b1d]">
              {activeReports.length}
            </strong>
            <p className="mb-0 mt-2 text-[10px] text-muted">
              Reports currently requiring monitoring or action
            </p>
            <div className="mt-auto grid grid-cols-2 gap-5 border-t border-border pt-4">
              <div>
                <b className="block text-[16px]">{reportedLocations}</b>
                <span className="mt-1 block text-[8px] uppercase tracking-[.07em] text-muted">
                  Reported locations
                </span>
              </div>
              <div>
                <b className="block text-[16px]">{mapPoints.length}</b>
                <span className="mt-1 block text-[8px] uppercase tracking-[.07em] text-muted">
                  Mapped reports
                </span>
              </div>
            </div>
          </div>
          <div className="grid grid-rows-3 border-l border-border max-[900px]:grid-cols-3 max-[900px]:grid-rows-none max-[900px]:border-l-0 max-[900px]:border-t max-[650px]:grid-cols-1">
            {[
              {
                label: "CRITICAL PRIORITY",
                value: criticalReports.length,
                detail: "Requires MDRRMO attention",
              },
              pendingReports.length > 0
                ? {
                    label: "AWAITING VALIDATION",
                    value: pendingReports.length,
                    detail: "Pending staff confirmation",
                  }
                : {
                    label: "CLOSED REPORTS",
                    value: reports.length - activeReports.length,
                    detail: "Completed incident records",
                  },
              {
                label: "TEAMS DEPLOYED",
                value: 4,
                detail: "2 teams remain available",
              },
            ].map((item, index) => (
              <div
                className={`grid grid-cols-[minmax(0,1fr)_auto] items-center gap-4 px-5 py-4 max-[900px]:min-h-[112px] max-[900px]:grid-cols-1 max-[900px]:items-start max-[650px]:min-h-0 max-[650px]:grid-cols-[minmax(0,1fr)_auto] max-[650px]:items-center ${index > 0 ? "border-t border-border max-[900px]:border-l max-[900px]:border-t-0 max-[650px]:border-l-0 max-[650px]:border-t" : ""}`}
                key={item.label}
              >
                <div>
                  <span className="block text-[8px] font-bold tracking-[.1em] text-muted">
                    {item.label}
                  </span>
                  <p className="mb-0 mt-1.5 text-[8px] text-muted">
                    {item.detail}
                  </p>
                </div>
                <strong className="text-[24px] font-semibold leading-none tracking-[-.04em] text-[#211b1d]">
                  {item.value}
                </strong>
              </div>
            ))}
          </div>
        </div>
      </Card>
      <div
        className={
          "grid grid-cols-[minmax(0,1.9fr)_minmax(320px,1fr)] gap-4 max-[1180px]:grid-cols-1 max-[650px]:flex max-[650px]:flex-col"
        }
      >
        <Card className="[&_.map-canvas]:h-[310px] max-[650px]:[&_.map-canvas]:h-[270px]">
          <SectionHead
            title="Live incident map"
            subtitle="Pantukan reports in the last 24 hours"
            action="Open full map"
            onAction={() => go("Incident Map")}
          />
          <MiniMap points={mapPoints} />
        </Card>
        <Card>
          <SectionHead
            title="Priority queue"
            subtitle="ML suggestion + safety rules"
            action="View all"
            onAction={() => go("Live Reports")}
          />
          <div className={"grid gap-2"}>
            {priorityQueue.map((report, index) => (
              <button
                className={
                  "grid min-h-[72px] grid-cols-[26px_3px_minmax(0,1fr)_auto_14px] items-center gap-[9px] border-0 border-b border-border bg-white px-1 py-2.5 text-left hover:bg-soft-gray [&>i]:h-8 [&>i]:w-[3px] [&>i]:rounded-sm [&>span]:grid [&>span]:gap-[3px] [&_b]:text-[11px] [&_small]:text-[9px] [&_small]:text-muted"
                }
                key={report.id}
                onClick={() => go("Live Reports")}
              >
                <em className="text-[9px] not-italic text-muted">
                  {String(index + 1).padStart(2, "0")}
                </em>
                <i className={colorClasses[tone(report.priority)]} />
                <span>
                  <b>{report.incident}</b>
                  <small>
                    {report.location} • {report.time}
                  </small>
                </span>
                <Badge tone={tone(report.priority)} dot={false}>
                  {report.priority}
                </Badge>
                <Icon name="chevron" size={14} />
              </button>
            ))}
            {!priorityQueue.length && (
              <div className="grid min-h-[150px] place-items-center rounded-[13px] bg-soft-gray px-5 text-center text-[10px] text-muted">
                No active reports are in the database yet.
              </div>
            )}
          </div>
          <div
            className={
              "mt-3 flex min-h-[42px] items-center gap-2 border-l-2 border-maroon bg-[#fbf7f7] px-[10px] text-[9px] text-[#574b4e]"
            }
          >
            <Icon name="verify" />
            Priority suggestions remain reviewable by MDRRMO.
          </div>
        </Card>
      </div>
      <div
        className={
          "grid grid-cols-[minmax(0,1.85fr)_minmax(310px,1fr)] gap-4 max-[1180px]:grid-cols-1 max-[650px]:flex max-[650px]:flex-col bottom"
        }
      >
        <Card>
          <SectionHead
            title="Recent reports"
            subtitle="Latest app and manually encoded entries"
            action="View reports"
            onAction={() => go("Live Reports")}
          />
          {reportStatus === "error" && !reports.length ? (
            <div className="grid min-h-[150px] place-items-center gap-2 rounded-[13px] bg-red-soft px-5 text-center text-[10px] text-priority-red">
              <span>{reportError}</span>
              <Button variant="secondary" onClick={retryReports}>
                Try again
              </Button>
            </div>
          ) : reportStatus === "loading" && !reports.length ? (
            <div className="grid min-h-[150px] place-items-center text-[10px] text-muted">
              Loading reports…
            </div>
          ) : reports.length ? (
            <ReportTable rows={reports.slice(0, 3)} />
          ) : (
            <div className="grid min-h-[150px] place-items-center rounded-[13px] bg-soft-gray px-5 text-center text-[10px] text-muted">
              No reports have been received yet.
            </div>
          )}
        </Card>
        <Card>
          <SectionHead
            title="Response overview"
            subtitle="Current team availability"
          />
          <div
            className={
              "mb-[9px] flex min-h-[72px] items-center justify-between border border-border border-l-[3px] border-l-maroon bg-[#fbfaf9] px-4 py-3 [&_b]:block [&_b]:text-[18px] [&_div_span]:mt-1 [&_div_span]:block [&_div_span]:text-[9px] [&_div_span]:text-muted [&>span]:grid [&>span]:size-[38px] [&>span]:place-items-center [&>span]:text-[#81787a]"
            }
          >
            <div>
              <b>6 response teams</b>
              <span>4 deployed • 2 available</span>
            </div>
            <span>
              <Icon name="users" />
            </span>
          </div>
          {[
            ["Rescue Alpha", "On route", 82],
            ["Medical 1", "Available", 48],
            ["Flood Unit", "On site", 68],
          ].map((t) => (
            <div
              className={
                "grid h-8 grid-cols-[90px_1fr_62px] items-center gap-2 text-[9px] [&>span]:text-right [&>span]:text-muted"
              }
              key={t[0]}
            >
              <b>{t[0]}</b>
              <div
                className={
                  "h-[7px] overflow-hidden rounded-[10px] bg-soft-gray [&_i]:block [&_i]:h-full [&_i]:rounded-[10px]"
                }
              >
                <i className="bg-maroon" style={{ width: `${t[2]}%` }} />
              </div>
              <span>{t[1]}</span>
            </div>
          ))}
        </Card>
      </div>
    </>
  );
}
