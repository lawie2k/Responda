import { useMemo, useState } from "react";
import {
  reviewAdminReport,
  type AdminUser,
  type ManualIntakeChannel,
  type ReportPriority,
} from "../api/respondaApi";
import { Icon } from "../components/Icon";
import { isAdministratorRole } from "../config/roles";
import { MiniMap } from "../components/Map";
import {
  Badge,
  Button,
  Card,
  PageTitle,
  SectionHead,
  SelectField,
} from "../components/ui";
import { tone, toReport, type Report } from "../data/reports";
import type { MapPoint } from "../data/mapData";
import { useAdminReportDetail, useAdminReports } from "../hooks/useAdminReports";

const checklistItems = [
  "Contact information was reviewed",
  "Location details are accurate",
  "Incident classification is accurate",
  "People and danger indicators were reviewed",
  "Final priority was confirmed",
];

type ReviewForm = {
  reportId: string;
  checks: boolean[];
  notes: string;
  finalPriority: ReportPriority;
  possibleDuplicate: boolean;
  callbackNeeded: boolean;
};

const emptyForm = (report: Report): ReviewForm => ({
  reportId: report.id,
  checks: checklistItems.map(() => false),
  notes: "",
  finalPriority: report.priority.toLowerCase() as ReportPriority,
  possibleDuplicate: false,
  callbackNeeded: false,
});

const mapPriority = (priority: Report["priority"]): MapPoint["priority"] =>
  priority === "CRITICAL" ? "Critical" : priority === "HIGH" ? "High" : "Moderate";

const sourceLabel = (
  source: Report["source"],
  manualChannel?: ManualIntakeChannel | null,
) => {
  if (source === "app_api") return "Mobile app (online)";
  if (source === "app_sms") return "Mobile app (SMS)";
  if (manualChannel === "phone_call") return "Phone call";
  if (manualChannel === "walk_in") return "Walk-in";
  if (manualChannel === "radio_communication") return "Radio communication";
  if (manualChannel === "other_offline") return "Other offline source";
  return "Manually encoded";
};

export function ReportValidation({
  selectedReportId,
  userRole,
  onReportReviewed,
}: {
  selectedReportId?: string | null;
  userRole: AdminUser["role"];
  onReportReviewed: () => void;
}) {
  const queue = useAdminReports({
    pageSize: 100,
    verificationStatuses: ["pending"],
    reportStatuses: ["new", "under_review", "linked"],
    sort: "oldest",
  });
  const [selectedId, setSelectedId] = useState<string | null>(null);
  const [completedIds, setCompletedIds] = useState<string[]>([]);
  const [storedForm, setStoredForm] = useState<ReviewForm | null>(null);
  const [search, setSearch] = useState("");
  const [priorityFilter, setPriorityFilter] = useState("");
  const [oldestFirst, setOldestFirst] = useState(true);
  const [feedback, setFeedback] = useState("");
  const [feedbackTone, setFeedbackTone] = useState<"success" | "error">(
    "success",
  );
  const [submitting, setSubmitting] = useState(false);

  const reports = useMemo(
    () =>
      (queue.data?.items.map(toReport) ?? []).filter(
        (report) => !completedIds.includes(report.id),
      ),
    [completedIds, queue.data],
  );
  const filteredReports = useMemo(() => {
    const normalizedSearch = search.trim().toLowerCase();
    return reports
      .filter(
        (report) =>
          (!normalizedSearch ||
            `${report.reference} ${report.id} ${report.incident} ${report.location} ${report.barangay ?? ""}`
              .toLowerCase()
              .includes(normalizedSearch)) &&
          (!priorityFilter || report.priority === priorityFilter),
      )
      .sort((left, right) =>
        oldestFirst
          ? new Date(left.receivedAt).getTime() - new Date(right.receivedAt).getTime()
          : new Date(right.receivedAt).getTime() - new Date(left.receivedAt).getTime(),
      );
  }, [oldestFirst, priorityFilter, reports, search]);

  const requestedId = selectedId ?? selectedReportId;
  const selected =
    filteredReports.find((report) => report.id === requestedId) ??
    filteredReports[0] ??
    null;
  const detail = useAdminReportDetail(selected?.id ?? null);
  const form = selected
    ? storedForm?.reportId === selected.id
      ? storedForm
      : emptyForm(selected)
    : null;
  const canReview = isAdministratorRole(userRole);
  const notesPresent = Boolean(form?.notes.trim());

  const updateForm = (change: Partial<ReviewForm>) => {
    if (!selected || !form) return;
    setStoredForm({ ...form, ...change, reportId: selected.id });
    setFeedback("");
  };

  const selectReport = (report: Report) => {
    setSelectedId(report.id);
    setStoredForm(emptyForm(report));
    setFeedback("");
  };

  const submitDecision = async (
    decision: "verified" | "unverified" | "invalid",
  ) => {
    if (!selected || !form || !detail.data || !canReview) return;
    if (!notesPresent) {
      setFeedbackTone("error");
      setFeedback("Add reviewer notes before saving this decision.");
      return;
    }
    setSubmitting(true);
    setFeedback("");
    try {
      await reviewAdminReport(selected.id, {
        expected_updated_at: detail.data.updated_at,
        decision,
        final_priority: form.finalPriority,
        location_accurate: form.checks[1],
        possible_duplicate: form.possibleDuplicate,
        callback_needed: form.callbackNeeded,
        notes: form.notes.trim(),
      });
      setCompletedIds((current) => [...current, selected.id]);
      setSelectedId(null);
      setStoredForm(null);
      setFeedbackTone("success");
      setFeedback(
        `${selected.reference} was ${decision === "verified" ? "validated" : decision === "invalid" ? "marked invalid" : "marked unverified"}.`,
      );
      queue.refetch();
      onReportReviewed();
    } catch (error) {
      setFeedbackTone("error");
      setFeedback(
        error instanceof Error ? error.message : "The review could not be saved.",
      );
      queue.refetch();
    } finally {
      setSubmitting(false);
    }
  };

  const mapPoint: MapPoint | null =
    selected?.position != null
      ? {
          id: selected.reference,
          name: selected.incident,
          location: selected.location,
          position: selected.position,
          barangay: selected.barangay,
          priority: mapPriority(selected.priority),
          hoursAgo: 0,
        }
      : null;
  const assessment = detail.data?.priority_assessments[0];

  return (
    <>
      <PageTitle
        title="Report Validation"
        subtitle="Confirm pending report details before changing their verification status."
      />

      {!canReview && (
        <div className="flex min-h-12 items-center gap-2 rounded-xl bg-amber-soft px-3 text-[10px] text-priority-amber">
          <Icon name="alert" />
          This account can view reports but only authorized administrators can
          submit review decisions.
        </div>
      )}

      <Card className="flex min-h-14 items-center gap-2 overflow-x-auto px-[10px] py-2 [&_.validation-search]:min-w-[220px] [&_.validation-search]:flex-1">
        {reports.length > 0 && (
          <Badge tone="amber">{reports.length} NEED VALIDATION</Badge>
        )}
        <label className="filter-search validation-search flex h-[38px] min-w-[170px] items-center gap-[7px] rounded-[10px] border border-border bg-white px-[10px] text-muted [&_input]:w-full [&_input]:border-0 [&_input]:bg-transparent [&_input]:text-[9px] [&_input]:text-[#1c1c1e] [&_input]:outline-0">
          <Icon name="search" size={15} />
          <input
            aria-label="Search validation queue"
            value={search}
            onChange={(event) => setSearch(event.target.value)}
            placeholder="Search report, incident, or location"
          />
        </label>
        <SelectField
          label="All priorities"
          value={priorityFilter}
          options={["CRITICAL", "HIGH", "MEDIUM", "LOW"]}
          onChange={setPriorityFilter}
        />
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
          className={`flex min-h-11 items-center gap-2 rounded-xl px-3 py-[9px] text-[10px] font-bold ${feedbackTone === "error" ? "bg-red-soft text-priority-red" : "bg-green-soft text-status-green"}`}
          role="status"
        >
          <Icon name={feedbackTone === "error" ? "alert" : "check"} />
          {feedback}
        </div>
      )}

      <div className="grid min-h-[420px] flex-1 grid-cols-[400px_minmax(0,1fr)] items-stretch gap-4 max-[1180px]:grid-cols-[340px_1fr] max-[850px]:grid-cols-1">
        <Card>
          <SectionHead
            title="Needs validation"
            subtitle={`${filteredReports.length} reports match the current filters`}
          />
          {queue.status === "error" && !reports.length ? (
            <QueueMessage
              icon="alert"
              title="Validation queue unavailable"
              detail={queue.error}
              action="Try again"
              onAction={queue.refetch}
            />
          ) : queue.status === "loading" && !reports.length ? (
            <QueueMessage
              icon="clock"
              title="Loading validation queue"
              detail="Retrieving pending reports from the backend."
            />
          ) : filteredReports.length ? (
            <div className="grid gap-2 [&>button]:min-h-[104px] [&>button]:rounded-[13px] [&>button]:border [&>button]:border-transparent [&>button]:bg-soft-gray [&>button]:px-[11px] [&>button]:py-[9px] [&>button]:text-left [&>button.selected]:border-maroon [&>button.selected]:bg-blush [&_button>div]:flex [&_button>div]:items-center [&_button>div]:justify-between [&_h4]:my-[7px] [&_h4]:mb-[3px] [&_h4]:text-xs [&_p]:m-0 [&_p]:text-[9px] [&_p]:text-muted [&_small]:mt-2 [&_small]:flex [&_small]:justify-between [&_small]:text-[8px] [&_small]:text-status-green">
              {filteredReports.map((report) => (
                <button
                  className={report.id === selected?.id ? "selected" : ""}
                  onClick={() => selectReport(report)}
                  key={report.id}
                >
                  <div>
                    <b>{report.reference}</b>
                    <Badge tone={tone(report.priority)} dot={false}>
                      {report.priority}
                    </Badge>
                  </div>
                  <h4>{report.incident}</h4>
                  <p>
                    {report.location}
                    {report.barangay ? ` • Brgy. ${report.barangay}` : ""}
                  </p>
                  <small>
                    {report.time} <Icon name="chevron" />
                  </small>
                </button>
              ))}
            </div>
          ) : (
            <QueueMessage
              icon="check"
              title={reports.length ? "No reports match these filters" : "Queue is clear"}
              detail={
                reports.length
                  ? "Change the search or priority filter."
                  : "No pending reports currently require validation."
              }
              action={reports.length ? "Reset filters" : undefined}
              onAction={
                reports.length
                  ? () => {
                      setSearch("");
                      setPriorityFilter("");
                    }
                  : undefined
              }
            />
          )}
        </Card>

        {selected && form ? (
          <Card className="flex flex-col gap-[10px]">
            <div className="flex items-center justify-between gap-3 [&_h3]:m-0 [&_h3]:text-[15px] [&_p]:my-[3px] [&_p]:text-[9px] [&_p]:text-muted">
              <div>
                <h3>Review {selected.reference}</h3>
                <p>
                  {sourceLabel(selected.source)} • {selected.time}
                </p>
              </div>
              <Badge tone="amber">FOR VALIDATION</Badge>
            </div>

            {detail.status === "error" ? (
              <div className="rounded-xl bg-red-soft p-3 text-[10px] text-priority-red">
                {detail.error}
              </div>
            ) : detail.status === "loading" ? (
              <div className="grid min-h-[360px] place-items-center text-[10px] text-muted">
                Loading protected report details…
              </div>
            ) : detail.data ? (
              <>
                <div className="grid grid-cols-2 gap-3 max-[1180px]:grid-cols-1 [&>div]:flex [&>div]:flex-col [&>div]:gap-[9px] [&_.map-canvas]:h-[190px]">
                  <div>
                    <div className="rounded-xl bg-soft-gray px-[10px] py-2 [&>div]:flex [&>div]:min-h-[27px] [&>div]:items-center [&>div]:justify-between [&>div]:gap-[10px] [&>div]:text-[9px] [&_span]:text-muted">
                      <b className="text-[9px] text-muted">SUBMITTED INFORMATION</b>
                      {[
                        ["Incident", selected.incident],
                        ["Reporter", detail.data.reporter.full_name],
                        [
                          "Contact",
                          detail.data.reporter.phone_number ||
                            detail.data.reporter.email ||
                            "Not provided",
                        ],
                        [
                          "People need help",
                          detail.data.people_need_help ? "Yes" : "No",
                        ],
                        [
                          "Additional assistance",
                          detail.data.additional_assistance ? "Yes" : "No",
                        ],
                        [
                          "Immediate danger",
                          detail.data.immediate_danger ? "Yes" : "No",
                        ],
                        ["Location", selected.location],
                        [
                          "Submitted via",
                          sourceLabel(
                            selected.source,
                            detail.data.manual_intake_channel,
                          ),
                        ],
                      ].map(([label, value]) => (
                        <div key={label}>
                          <span>{label}</span>
                          <b className="text-right">{value}</b>
                        </div>
                      ))}
                    </div>
                    {mapPoint ? (
                      <MiniMap
                        points={[mapPoint]}
                        focus={{
                          label: mapPoint.location,
                          position: mapPoint.position,
                          zoom: 15,
                        }}
                      />
                    ) : (
                      <div className="grid min-h-[120px] place-items-center rounded-xl bg-soft-gray text-[9px] text-muted">
                        No report coordinates were provided.
                      </div>
                    )}
                  </div>

                  <div>
                    <div className="grid gap-[5px] rounded-[13px] bg-blue-soft px-[10px] py-[9px] [&_p]:m-0 [&_p]:flex [&_p]:justify-between [&_p]:text-[9px] [&_p_span]:text-muted">
                      <b className="text-[9px] text-status-blue">SYSTEM SUGGESTIONS</b>
                      <p>
                        <span>Classification</span>
                        <strong>{selected.incident}</strong>
                      </p>
                      <p>
                        <span>Suggested priority</span>
                        <strong>{selected.priority}</strong>
                      </p>
                      <p>
                        <span>Model confidence</span>
                        <strong>
                          {assessment
                            ? `${Math.round(assessment.confidence * 100)}%`
                            : "Not available"}
                        </strong>
                      </p>
                      <p>
                        <span>Detected language</span>
                        <strong>{detail.data.original_language ?? "Unknown"}</strong>
                      </p>
                    </div>

                    <div className="grid gap-1.5 rounded-[13px] bg-soft-gray px-[10px] py-[9px] [&_label]:flex [&_label]:items-center [&_label]:gap-[7px] [&_label]:text-[9px] [&_input]:size-[17px] [&_input]:accent-status-green">
                      <div>
                        <b className="block text-[9px] text-muted">
                          OPTIONAL REVIEW CHECKLIST
                        </b>
                        <span className="text-[8px] text-muted">
                          Check only the items you confirmed. Unchecked items do
                          not block a decision.
                        </span>
                      </div>
                      {checklistItems.map((item, index) => (
                        <label key={item}>
                          <input
                            type="checkbox"
                            checked={form.checks[index]}
                            disabled={!canReview || submitting}
                            onChange={() =>
                              updateForm({
                                checks: form.checks.map((checked, itemIndex) =>
                                  itemIndex === index ? !checked : checked,
                                ),
                              })
                            }
                          />
                          {item}
                        </label>
                      ))}
                    </div>
                  </div>
                </div>

                <div className="grid grid-cols-2 gap-3 max-[650px]:grid-cols-1">
                  <SelectField
                    label="Final priority"
                    value={form.finalPriority}
                    options={[
                      { label: "Critical", value: "critical" },
                      { label: "High", value: "high" },
                      { label: "Medium", value: "medium" },
                      { label: "Low", value: "low" },
                    ]}
                    onChange={(value) =>
                      updateForm({ finalPriority: value as ReportPriority })
                    }
                  />
                  <div className="flex flex-wrap gap-3 rounded-xl bg-soft-gray px-3 py-2 [&_label]:flex [&_label]:items-center [&_label]:gap-2 [&_label]:text-[9px] [&_input]:accent-maroon">
                    <label>
                      <input
                        type="checkbox"
                        checked={form.possibleDuplicate}
                        disabled={!canReview || submitting}
                        onChange={() =>
                          updateForm({
                            possibleDuplicate: !form.possibleDuplicate,
                          })
                        }
                      />
                      Possible duplicate
                    </label>
                    <label>
                      <input
                        type="checkbox"
                        checked={form.callbackNeeded}
                        disabled={!canReview || submitting}
                        onChange={() =>
                          updateForm({ callbackNeeded: !form.callbackNeeded })
                        }
                      />
                      Callback needed
                    </label>
                  </div>
                </div>

                <textarea
                  aria-label="Reviewer notes"
                  className="min-h-24 resize-y rounded-xl border border-border p-[10px] text-[9px] outline-0 focus:border-maroon"
                  value={form.notes}
                  disabled={!canReview || submitting}
                  maxLength={2000}
                  onChange={(event) => updateForm({ notes: event.target.value })}
                  placeholder="Document what was confirmed, what could not be verified, and any follow-up required."
                />

                <div className="flex flex-wrap justify-end gap-2">
                  <Button
                    icon="verify"
                    disabled={!canReview || submitting}
                    onClick={() => void submitDecision("verified")}
                  >
                    {submitting ? "Saving…" : "Validate report"}
                  </Button>
                  <Button
                    variant="secondary"
                    disabled={!canReview || submitting}
                    onClick={() => void submitDecision("unverified")}
                  >
                    Could not validate
                  </Button>
                  <Button
                    variant="danger"
                    icon="alert"
                    disabled={!canReview || submitting}
                    onClick={() => void submitDecision("invalid")}
                  >
                    Mark invalid
                  </Button>
                </div>
              </>
            ) : null}
          </Card>
        ) : (
          <Card className="grid min-h-[420px] place-items-center px-8 text-center text-[10px] text-muted">
            Select a pending report when one becomes available.
          </Card>
        )}
      </div>
    </>
  );
}

function QueueMessage({
  icon,
  title,
  detail,
  action,
  onAction,
}: {
  icon: "alert" | "clock" | "check";
  title: string;
  detail: string | null;
  action?: string;
  onAction?: () => void;
}) {
  return (
    <div className="flex min-h-80 flex-col items-center justify-center gap-2 px-5 text-center text-muted [&>.icon]:size-11 [&>.icon]:rounded-[13px] [&>.icon]:bg-soft-gray [&>.icon]:p-[9px] [&>.icon]:text-maroon [&_b]:text-[11px] [&_b]:text-[#1c1c1e] [&_span]:text-[9px]">
      <Icon name={icon} size={26} />
      <b>{title}</b>
      <span>{detail}</span>
      {action && onAction && (
        <Button variant="secondary" onClick={onAction}>
          {action}
        </Button>
      )}
    </div>
  );
}
