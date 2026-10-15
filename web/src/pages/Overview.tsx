import type { Page } from "../types";
import { reports } from "../data/reports";
import { Icon } from "../components/Icon";
import { MiniMap } from "../components/Map";
import { ReportTable } from "../components/ReportTable";
import { Badge, Button, Card, Metric, SectionHead } from "../components/ui";

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
  firstName,
}: {
  go: (p: Page) => void;
  firstName: string;
}) {
  const hour = new Date().getHours();
  const greeting = hour < 12 ? "Good morning" : hour < 18 ? "Good afternoon" : "Good evening";

  return (
    <>
      <div
        className={
          "flex min-h-[52px] items-center justify-between max-[650px]:flex-col max-[650px]:items-start max-[650px]:gap-2 [&>div]:min-w-0 [&_h2]:m-0 [&_h2]:text-[19px] max-[650px]:[&_h2]:text-[17px] [&_p]:my-1 [&_p]:text-[11px] [&_p]:text-muted"
        }
      >
        <div>
          <h2>{greeting}, {firstName}</h2>
          <p>Here is the current emergency operations picture for Pantukan.</p>
        </div>
        <Badge tone="green">LIVE OPERATIONS</Badge>
      </div>
      <div
        className={
          "flex min-h-[52px] items-center gap-[10px] rounded-[14px] px-3 py-2 max-[650px]:flex-wrap max-[650px]:items-start [&>span]:grid [&>span]:size-8 [&>span]:shrink-0 [&>span]:place-items-center [&>span]:rounded-[10px] [&>span]:bg-white [&>div]:min-w-0 [&>div]:flex-1 [&_b]:text-[11px] [&_p]:my-0.5 [&_p]:text-[9px] [&_p]:text-muted max-[650px]:[&>.button]:w-full bg-amber-soft text-priority-amber"
        }
      >
        <span>
          <Icon name="alert" />
        </span>
        <div>
          <b>3 incoming reports require validation</b>
          <p>
            Confirm location, contact details, and ML-supported classifications
            before dispatch decisions.
          </p>
        </div>
        <Button variant="secondary" onClick={() => go("Report Validation")}>
          Review queue
        </Button>
      </div>
      <div
        className={
          "grid grid-cols-4 gap-4 max-[1180px]:grid-cols-2 max-[650px]:grid-cols-1"
        }
      >
        <Metric
          icon="reports"
          title="Active incidents"
          value="12"
          sub="Across 8 reported locations"
          tone="maroon"
        />
        <Metric
          icon="alert"
          title="Critical priority"
          value="3"
          sub="MDRRMO review required"
          tone="red"
        />
        <Metric
          icon="verify"
          title="Needs validation"
          value="5"
          sub="2 require location review"
          tone="amber"
        />
        <Metric
          icon="users"
          title="Teams deployed"
          value="4"
          sub="2 teams available"
          tone="green"
        />
      </div>
      <div
        className={
          "grid grid-cols-[minmax(0,1.85fr)_minmax(310px,1fr)] gap-4 max-[1180px]:grid-cols-1 max-[650px]:flex max-[650px]:flex-col"
        }
      >
        <Card>
          <SectionHead
            title="Live incident map"
            subtitle="Pantukan reports in the last 24 hours"
            action="Open full map"
            onAction={() => go("Incident Map")}
          />
          <MiniMap />
        </Card>
        <Card>
          <SectionHead
            title="Priority queue"
            subtitle="ML suggestion + safety rules"
            action="View all"
            onAction={() => go("Live Reports")}
          />
          <div className={"grid gap-2"}>
            {[
              ["CRITICAL", "Road accident", "Kingking Highway", "4 min", "red"],
              ["HIGH", "Flash flood", "Magnaga Riverside", "9 min", "orange"],
              [
                "MODERATE",
                "Medical emergency",
                "Matiao Public Market",
                "14 min",
                "amber",
              ],
            ].map((x) => (
              <button
                className={
                  "flex min-h-[61px] items-center gap-[9px] rounded-[13px] border-0 bg-white px-2 py-[7px] text-left hover:bg-soft-gray [&>i]:w-1 [&>i]:self-stretch [&>i]:rounded-sm [&>span]:grid [&>span]:flex-1 [&>span]:gap-[3px] [&_b]:text-[11px] [&_small]:text-[9px] [&_small]:text-muted"
                }
                key={x[1]}
              >
                <i className={colorClasses[x[4]]} />
                <span>
                  <b>{x[1]}</b>
                  <small>
                    {x[2]} • {x[3]}
                  </small>
                </span>
                <Badge tone={x[4]} dot={false}>
                  {x[0]}
                </Badge>
                <Icon name="chevron" size={14} />
              </button>
            ))}
          </div>
          <div
            className={
              "mt-2 flex h-[42px] items-center gap-2 rounded-[11px] bg-blush px-[9px] text-[9px] text-maroon"
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
          <ReportTable rows={reports.slice(0, 3)} />
        </Card>
        <Card>
          <SectionHead
            title="Response overview"
            subtitle="Current team availability"
          />
          <div
            className={
              "mb-[9px] flex h-[62px] items-center justify-between rounded-[14px] bg-maroon px-3 py-[10px] text-white [&_b]:block [&_b]:text-sm [&_div_span]:mt-1 [&_div_span]:block [&_div_span]:text-[9px] [&_div_span]:text-[#f2ccd2] [&>span]:grid [&>span]:size-[38px] [&>span]:place-items-center [&>span]:rounded-xl [&>span]:bg-white [&>span]:text-maroon"
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
            ["Rescue Alpha", "On route", 82, "maroon"],
            ["Medical 1", "Available", 48, "green"],
            ["Flood Unit", "On site", 68, "blue"],
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
                <i
                  className={colorClasses[String(t[3])]}
                  style={{ width: `${t[2]}%` }}
                />
              </div>
              <span>{t[1]}</span>
            </div>
          ))}
        </Card>
      </div>
    </>
  );
}
