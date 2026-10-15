import { useState } from "react";
import { Button } from "./ui";

const safetyQuestions = [
  "Are there more people who need help?",
  "Does anyone need additional assistance?",
  "Is it still dangerous there?",
];

export function ReportModal({ close }: { close: () => void }) {
  const [incidentType, setIncidentType] = useState("");
  const [location, setLocation] = useState("");
  const [reporterContact, setReporterContact] = useState("");
  const [reportSource, setReportSource] = useState("");
  const [incidentDetails, setIncidentDetails] = useState("");
  const [answers, setAnswers] = useState<(boolean | null)[]>([
    null,
    null,
    null,
  ]);

  const answerQuestion = (index: number, answer: boolean) => {
    setAnswers((current) =>
      current.map((value, questionIndex) =>
        questionIndex === index ? answer : value,
      ),
    );
  };

  const canCreate = Boolean(
    incidentType &&
    location.trim() &&
    reporterContact.trim() &&
    reportSource &&
    incidentDetails.trim() &&
    answers.every((answer) => answer !== null),
  );

  return (
    <div
      className={
        "fixed inset-0 z-[100] grid place-items-center bg-[#23090f7a] p-5 backdrop-blur"
      }
      onMouseDown={close}
    >
      <div
        className={
          "max-h-[calc(100vh-32px)] w-[min(540px,100%)] overflow-y-auto rounded-[20px] bg-white p-[22px] shadow-[0_24px_80px_#28060e3d] [&>label]:my-[11px] [&>label]:grid [&>label]:gap-1.5 [&>label]:text-[9px] [&>label]:font-semibold [&_input]:w-full [&_input]:rounded-[10px] [&_input]:border [&_input]:border-border [&_input]:px-3 [&_input]:py-[10px] [&_input]:text-[11px] [&_select]:w-full [&_select]:rounded-[10px] [&_select]:border [&_select]:border-border [&_select]:px-3 [&_select]:py-[10px] [&_select]:text-[11px] [&_textarea]:h-[90px] [&_textarea]:w-full [&_textarea]:rounded-[10px] [&_textarea]:border [&_textarea]:border-border [&_textarea]:px-3 [&_textarea]:py-[10px] [&_textarea]:text-[11px]"
        }
        onMouseDown={(e) => e.stopPropagation()}
      >
        <div
          className={
            "mb-5 flex justify-between [&_h2]:m-0 [&_h2]:text-xl [&_p]:text-[10px] [&_p]:text-muted [&>button]:size-8 [&>button]:rounded-[10px] [&>button]:border-0 [&>button]:bg-soft-gray [&>button]:text-xl"
          }
        >
          <div>
            <h2>Encode a report</h2>
            <p>
              Manually record a report received through a phone call, walk-in,
              radio, or another offline channel.
            </p>
          </div>
          <button onClick={close}>×</button>
        </div>
        <label>
          Incident type
          <select
            required
            value={incidentType}
            onChange={(event) => setIncidentType(event.target.value)}
          >
            <option value="" disabled>
              Select incident type
            </option>
            <option value="Road accident">Road accident</option>
            <option value="Flood">Flood</option>
            <option value="Medical emergency">Medical emergency</option>
            <option value="Fire">Fire</option>
          </select>
        </label>
        <label>
          Location
          <input
            required
            value={location}
            onChange={(event) => setLocation(event.target.value)}
            placeholder="Street, road, building, or nearby area"
          />
        </label>
        <div className={"grid grid-cols-2 gap-3 max-[650px]:grid-cols-1"}>
          <label className="grid gap-1.5 text-[9px] font-semibold">
            Reporter contact
            <input
              required
              value={reporterContact}
              onChange={(event) => setReporterContact(event.target.value)}
              placeholder="09XX XXX XXXX"
            />
          </label>
          <label className="grid gap-1.5 text-[9px] font-semibold">
            Report source
            <select
              required
              value={reportSource}
              onChange={(event) => setReportSource(event.target.value)}
            >
              <option value="" disabled>
                Select report source
              </option>
              <option value="Phone call">Phone call</option>
              <option value="Walk-in">Walk-in</option>
              <option value="Radio communication">Radio communication</option>
              <option value="Other offline source">Other offline source</option>
            </select>
          </label>
        </div>
        <label>
          Incident details
          <textarea
            required
            value={incidentDetails}
            onChange={(event) => setIncidentDetails(event.target.value)}
            placeholder="Describe what happened and who needs help…"
          />
        </label>
        <div className="mb-3 grid gap-2 rounded-[14px] bg-soft-gray p-3">
          <div>
            <b className="block text-[10px]">Safety questions</b>
            <span className="text-[9px] text-muted">
              These answers help the ML workflow assess urgency.
            </span>
          </div>
          {safetyQuestions.map((question, index) => (
            <div
              className="flex min-h-10 items-center gap-3 rounded-[10px] bg-white px-[10px] py-2 max-[650px]:items-start"
              key={question}
            >
              <span className="flex-1 text-[10px] font-medium leading-[1.4]">
                {question}
              </span>
              <div className="flex shrink-0 gap-1.5">
                {[true, false].map((answer) => (
                  <button
                    aria-pressed={answers[index] === answer}
                    className={`h-7 min-w-[46px] rounded-lg border px-2 text-[9px] font-bold transition-colors ${answers[index] === answer ? (answer ? "border-status-green bg-green-soft text-status-green" : "border-maroon bg-blush text-maroon") : "border-border bg-white text-muted hover:border-maroon hover:text-maroon"}`}
                    key={String(answer)}
                    onClick={() => answerQuestion(index, answer)}
                    type="button"
                  >
                    {answer ? "Yes" : "No"}
                  </button>
                ))}
              </div>
            </div>
          ))}
        </div>
        <div
          className={
            "rounded-xl bg-blue-soft px-3 py-[10px] text-[9px] leading-[1.5] text-status-blue"
          }
        >
          <b className="block text-[10px]">
            Priority is assigned automatically
          </b>
          The ML workflow will determine the suggested priority after this
          report is created. MDRRMO staff can review it in Report Validation.
        </div>
        <div
          className={
            "mt-[18px] flex items-center justify-end gap-2 max-[650px]:flex-wrap"
          }
        >
          {!canCreate && (
            <span className="mr-auto text-[8px] text-muted max-[650px]:w-full">
              Complete every field and safety question to create the report.
            </span>
          )}
          <Button variant="secondary" onClick={close}>
            Cancel
          </Button>
          <Button icon="plus" disabled={!canCreate} onClick={close}>
            Create report
          </Button>
        </div>
      </div>
    </div>
  );
}
