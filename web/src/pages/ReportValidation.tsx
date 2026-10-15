import { useMemo, useState } from "react";
import { Icon } from "../components/Icon";
import { MiniMap } from "../components/Map";
import {
  Badge,
  Button,
  Card,
  PageTitle,
  SectionHead,
  SelectField,
} from "../components/ui";
import {
  initialValidationReports,
  type ValidationReport,
} from "../data/validationReports";

const checklistItems = [
  "Contact information is available",
  "Location details are consistent",
  "Incident classification is accurate",
  "People counts are reasonable",
  "Priority factors were reviewed",
];

export function ReportValidation({
  selectedReportId,
}: {
  selectedReportId?: string | null;
}) {
  const [reports, setReports] = useState(initialValidationReports);
  const [selectedId, setSelectedId] = useState(
    selectedReportId &&
      initialValidationReports.some((report) => report.id === selectedReportId)
      ? selectedReportId
      : initialValidationReports[0].id,
  );
  const [checks, setChecks] = useState(checklistItems.map(() => false));
  const [notes, setNotes] = useState("");
  const [search, setSearch] = useState("");
  const [priority, setPriority] = useState("");
  const [reason, setReason] = useState("");
  const [oldestFirst, setOldestFirst] = useState(true);
  const [feedback, setFeedback] = useState("");
  const reviewComplete = checks.every(Boolean) && Boolean(notes.trim());
  const rejectionReady = Boolean(notes.trim());

  const pendingReports = reports.filter(
    (report) => report.status === "PENDING",
  );
  const filteredReports = useMemo(
    () =>
      pendingReports
        .filter((report) => {
          const query = search.trim().toLowerCase();
          return (
            (!query ||
              `${report.id} ${report.incident} ${report.location} ${report.barangay ?? ""} ${report.reporter}`
                .toLowerCase()
                .includes(query)) &&
            (!priority || report.priority === priority) &&
            (!reason || report.reason === reason)
          );
        })
        .sort((a, b) =>
          oldestFirst
            ? b.minutesAgo - a.minutesAgo
            : a.minutesAgo - b.minutesAgo,
        ),
    [oldestFirst, pendingReports, priority, reason, search],
  );

  const selected =
    reports.find((report) => report.id === selectedId) ??
    filteredReports[0] ??
    reports[0];
  const mapFocus = useMemo(
    () => ({
      label: selected.location,
      position: selected.position,
      zoom: 15,
    }),
    [selected.location, selected.position],
  );

  const selectReport = (report: ValidationReport) => {
    setSelectedId(report.id);
    setChecks(checklistItems.map(() => false));
    setNotes("");
    setFeedback("");
  };

  const decide = (status: "VALIDATED" | "REJECTED") => {
    if (status === "VALIDATED" && !reviewComplete) {
      setFeedback(
        "Complete every checklist item and add reviewer notes before validating.",
      );
      return;
    }
    if (status === "REJECTED" && !rejectionReady) return;

    setReports((current) =>
      current.map((report) =>
        report.id === selected.id ? { ...report, status } : report,
      ),
    );
    const next = pendingReports.find((report) => report.id !== selected.id);
    if (next) setSelectedId(next.id);
    setChecks(checklistItems.map(() => false));
    setNotes("");
    setFeedback(
      `${selected.id} was ${status === "VALIDATED" ? "validated" : "marked as unable to validate"}.`,
    );
  };

  const resetFilters = () => {
    setSearch("");
    setPriority("");
    setReason("");
  };

  const mapPoint = {
    id: selected.id,
    name: selected.incident,
    location: selected.location,
    position: selected.position,
    barangay: selected.barangay,
    priority: selected.priority,
    hoursAgo: Math.max(1, Math.ceil(selected.minutesAgo / 60)),
  };

  return (
    <>
      <PageTitle
        title="Report Validation"
        subtitle="Confirm incident details before changing report or response status."
      />

      <Card
        className={
          "flex min-h-14 items-center gap-2 overflow-x-auto px-[10px] py-2 [&_.validation-search]:min-w-[220px] [&_.validation-search]:flex-1"
        }
      >
        <Badge tone="amber">{pendingReports.length} NEED VALIDATION</Badge>
        <label
          className={
            "filter-search flex h-[38px] min-w-[170px] items-center gap-[7px] rounded-[10px] border border-border bg-white px-[10px] text-muted [&_input]:w-full [&_input]:border-0 [&_input]:bg-transparent [&_input]:text-[9px] [&_input]:text-[#1c1c1e] [&_input]:outline-0 max-[650px]:w-[170px] max-[650px]:shrink-0 validation-search"
          }
        >
          <Icon name="search" size={15} />
          <input
            aria-label="Search validation queue"
            value={search}
            onChange={(event) => setSearch(event.target.value)}
            placeholder="Search report, location, or reporter"
          />
        </label>
        <SelectField
          label="All priorities"
          value={priority}
          options={["Critical", "High", "Moderate"]}
          onChange={setPriority}
        />
        <SelectField
          label="All reasons"
          value={reason}
          options={[...new Set(reports.map((report) => report.reason))]}
          onChange={setReason}
        />
        <i className={"flex-1 max-[650px]:hidden"} />
        <Button
          variant="secondary"
          icon="clock"
          onClick={() => setOldestFirst((current) => !current)}
        >
          {oldestFirst ? "Oldest first" : "Newest first"}
        </Button>
      </Card>

      {feedback && (
        <div
          className={`flex min-h-11 items-center gap-2 rounded-xl px-3 py-[9px] text-[10px] font-bold ${feedback.startsWith("Complete") ? "bg-amber-soft text-priority-amber" : "bg-green-soft text-status-green"}`}
          role="status"
        >
          <Icon name={feedback.startsWith("Complete") ? "alert" : "check"} />
          {feedback}
        </div>
      )}

      <div
        className={
          "grid grid-cols-[444px_minmax(0,1fr)] gap-4 max-[1180px]:grid-cols-[360px_1fr] max-[850px]:grid-cols-1"
        }
      >
        <Card>
          <SectionHead
            title="Needs validation"
            subtitle={`${filteredReports.length} reports match the current filters`}
          />
          {filteredReports.length ? (
            <div
              className={
                "grid gap-2 [&>button]:h-[106px] [&>button]:rounded-[13px] [&>button]:border [&>button]:border-transparent [&>button]:bg-soft-gray [&>button]:px-[11px] [&>button]:py-[9px] [&>button]:text-left [&>button.selected]:border-maroon [&>button.selected]:bg-blush [&_button>div]:flex [&_button>div]:items-center [&_button>div]:justify-between [&_h4]:my-[7px] [&_h4]:mb-[3px] [&_h4]:text-xs [&_p]:m-0 [&_p]:text-[9px] [&_p]:text-muted [&_small]:mt-2 [&_small]:flex [&_small]:justify-between [&_small]:text-[8px] [&_small]:text-status-green"
              }
            >
              {filteredReports.map((report) => (
                <button
                  className={report.id === selected.id ? "selected" : ""}
                  onClick={() => selectReport(report)}
                  key={report.id}
                >
                  <div>
                    <b>{report.id}</b>
                    <Badge tone={report.reasonTone} dot={false}>
                      {report.reason.toUpperCase()}
                    </Badge>
                  </div>
                  <h4>{report.incident}</h4>
                  <p>
                    {report.location}
                    {report.barangay ? ` • Brgy. ${report.barangay}` : ""} • {" "}
                    {report.minutesAgo} min ago
                  </p>
                  <small>
                    {report.priority} priority <Icon name="chevron" />
                  </small>
                </button>
              ))}
            </div>
          ) : (
            <div
              className={
                "flex min-h-80 flex-col items-center justify-center gap-2 text-center text-muted [&>.icon]:size-11 [&>.icon]:rounded-[13px] [&>.icon]:bg-soft-gray [&>.icon]:p-[9px] [&>.icon]:text-maroon [&_b]:text-[11px] [&_b]:text-[#1c1c1e] [&_span]:text-[9px]"
              }
            >
              <Icon name="search" size={26} />
              <b>No reports match these filters</b>
              <span>Reset the filters to restore the queue.</span>
              <Button variant="secondary" onClick={resetFilters}>
                Reset filters
              </Button>
            </div>
          )}
        </Card>

        <Card className={"flex flex-col gap-[10px]"}>
          <div
            className={
              "flex items-center justify-between [&_h3]:m-0 [&_h3]:text-[15px] [&_p]:my-[3px] [&_p]:text-[9px] [&_p]:text-muted"
            }
          >
            <div>
              <h3>Review {selected.id}</h3>
              <p>
                Submitted from the mobile app • {selected.minutesAgo} minutes
                ago
              </p>
            </div>
            <Badge tone="amber">FOR VALIDATION</Badge>
          </div>

          <div
            className={
              "flex min-h-[52px] items-center gap-[10px] rounded-[14px] px-3 py-2 max-[650px]:flex-wrap max-[650px]:items-start [&>span]:grid [&>span]:size-8 [&>span]:shrink-0 [&>span]:place-items-center [&>span]:rounded-[10px] [&>span]:bg-white [&>div]:min-w-0 [&>div]:flex-1 [&_b]:text-[11px] [&_p]:my-0.5 [&_p]:text-[9px] [&_p]:text-muted max-[650px]:[&>.button]:w-full bg-blue-soft text-status-blue"
            }
          >
            <Icon name="verify" />
            <p>
              System classification and priority suggestions support the
              decision. Authorized MDRRMO staff must confirm or reject them.
            </p>
          </div>

          <div
            className={
              "grid grid-cols-2 gap-3 max-[1180px]:grid-cols-1 [&>div]:flex [&>div]:flex-col [&>div]:gap-[9px] [&_.map-canvas]:h-[178px] max-[1180px]:[&_.map-canvas]:hidden max-[650px]:grid-cols-1 [&_textarea]:min-h-20 [&_textarea]:resize-y [&_textarea]:rounded-xl [&_textarea]:border [&_textarea]:border-border [&_textarea]:p-[10px] [&_textarea]:text-[9px]"
            }
          >
            <div>
              <div
                className={
                  "rounded-xl bg-soft-gray px-[10px] py-2 [&>div]:flex [&>div]:min-h-[27px] [&>div]:items-center [&>div]:justify-between [&>div]:gap-[10px] [&>div]:text-[9px] [&_span]:text-muted"
                }
              >
                <span
                  className={
                    "block text-[9px] font-bold tracking-[.04em] text-muted"
                  }
                >
                  SUBMITTED INFORMATION
                </span>
                {[
                  ["Incident", selected.incident],
                  ["Reporter", selected.reporter],
                  ["Contact", selected.contact],
                  ["People", selected.people],
                  ["Location", selected.location],
                  [
                    "Detected barangay",
                    selected.barangay ?? "Outside Pantukan or not determined",
                  ],
                ].map(([label, value]) => (
                  <div
                    className={
                      "flex min-h-[27px] items-center justify-between gap-[10px] text-[9px] [&_span]:text-muted"
                    }
                    key={label}
                  >
                    <span>{label}</span>
                    <b>{value}</b>
                  </div>
                ))}
              </div>
              <MiniMap points={[mapPoint]} focus={mapFocus} />
            </div>

            <div>
              <div
                className={
                  "grid gap-[5px] rounded-[13px] bg-blue-soft px-[10px] py-[9px] [&>b]:text-[9px] [&>b]:text-status-blue [&_p]:m-0 [&_p]:flex [&_p]:justify-between [&_p]:text-[9px] [&_p_span]:text-muted [&>small]:text-muted"
                }
              >
                <b>SYSTEM SUGGESTIONS</b>
                {[
                  [
                    "Classification",
                    `${selected.incident} • ${selected.confidence}%`,
                  ],
                  ["Suggested priority", selected.priority],
                  ["Language detected", selected.language],
                  ["Review reason", selected.reason],
                ].map(([label, value]) => (
                  <p key={label}>
                    <span>{label}</span>
                    <strong>{value}</strong>
                  </p>
                ))}
              </div>

              <div
                className={
                  "grid gap-1.5 rounded-[13px] bg-soft-gray px-[10px] py-[9px] [&_label]:flex [&_label]:items-center [&_label]:gap-[7px] [&_label]:text-[9px] [&_input]:size-[17px] [&_input]:accent-status-green"
                }
              >
                <span
                  className={
                    "block text-[9px] font-bold tracking-[.04em] text-muted"
                  }
                >
                  VALIDATION CHECKLIST
                </span>
                {checklistItems.map((item, index) => (
                  <label key={item}>
                    <input
                      type="checkbox"
                      checked={checks[index]}
                      onChange={() =>
                        setChecks((current) =>
                          current.map((checked, itemIndex) =>
                            itemIndex === index ? !checked : checked,
                          ),
                        )
                      }
                    />
                    {item}
                  </label>
                ))}
              </div>
              <textarea
                required
                value={notes}
                onChange={(event) => setNotes(event.target.value)}
                placeholder="Add required reviewer notes…"
              />
            </div>
          </div>

          <div
            className={
              "rounded-[13px] bg-soft-gray px-[10px] py-[9px] [&>span]:text-[9px] [&>span]:text-muted [&>div]:mt-2 [&>div]:grid [&>div]:grid-cols-2 [&>div]:gap-2 max-[650px]:[&>div]:grid-cols-1 [&_.button]:w-full"
            }
          >
            <span>
              {checks.filter(Boolean).length} of {checks.length} checks
              completed • Reviewer notes required
            </span>
            <div>
              <Button
                icon="verify"
                disabled={!reviewComplete}
                onClick={() => decide("VALIDATED")}
              >
                Validate report
              </Button>
              <Button
                variant="danger"
                icon="alert"
                disabled={!rejectionReady}
                onClick={() => decide("REJECTED")}
              >
                Could not validate
              </Button>
            </div>
          </div>
        </Card>
      </div>
    </>
  );
}
