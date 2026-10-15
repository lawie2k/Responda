import { useState, type ReactNode } from "react";
import { Icon } from "../components/Icon";
import type { IconName } from "../types";
import {
  Badge,
  Button,
  Card,
  PageTitle,
  SectionHead,
  SelectField,
  Switch,
} from "../components/ui";

const tabs = [
  ["General", "settings"],
  ["Notifications", "bell"],
  ["Users & roles", "users"],
  ["Data & retention", "records"],
] as const;

const workspaceSections = [
  ["Organization", "settings"],
  ["Report handling", "reports"],
  ["Validation rules", "shield"],
  ["Dispatch defaults", "users"],
  ["Manual intake", "phone"],
  ["Integrations", "map"],
] as const;

const inputClass =
  "h-[38px] min-w-[220px] rounded-[10px] border border-border bg-white px-[10px] text-[9px] outline-0 focus:border-maroon focus:shadow-[0_0_0_3px_rgba(122,31,43,.08)] max-[650px]:w-full";

type AdminUser = {
  name: string;
  email: string;
  role: string;
  active: boolean;
};

function downloadSettings(contents: string) {
  const url = URL.createObjectURL(
    new Blob([contents], { type: "application/json" }),
  );
  const link = document.createElement("a");
  link.href = url;
  link.download = "responda-settings.json";
  link.click();
  URL.revokeObjectURL(url);
}

export function Settings() {
  const [activeTab, setActiveTab] = useState("General");
  const [activeSection, setActiveSection] = useState("Organization");
  const [dirty, setDirty] = useState(false);
  const [saved, setSaved] = useState(false);
  const [feedback, setFeedback] = useState("");
  const [guideOpen, setGuideOpen] = useState(false);
  const [officeName, setOfficeName] = useState("Pantukan MDRRMO");
  const [municipality, setMunicipality] = useState("Pantukan, Davao de Oro");
  const [timezone, setTimezone] = useState("Asia/Manila (UTC+8)");
  const [mapRadius, setMapRadius] = useState("10 kilometers");
  const [confidence, setConfidence] = useState("70%");
  const [dispatchTeam, setDispatchTeam] = useState("Best available team");
  const [acknowledgement, setAcknowledgement] = useState("5 minutes");
  const [notificationEmail, setNotificationEmail] = useState(
    "operations@pantukan.gov.ph",
  );
  const [retention, setRetention] = useState("5 years");
  const [toggles, setToggles] = useState<Record<string, boolean>>({
    criticalValidation: true,
    duplicateFlagging: true,
    manualReports: true,
    mandatoryNotes: true,
    photoEvidence: false,
    teamNotification: true,
    phoneCalls: true,
    walkIns: true,
    radioReports: true,
    otherSources: true,
    mobileApi: true,
    weatherAlerts: false,
    openStreetMap: true,
    soundAlert: true,
    queueReminder: true,
    dailySummary: false,
    accountApprovals: true,
    autoArchive: true,
    auditLogs: true,
  });
  const [admins, setAdmins] = useState<AdminUser[]>([
    {
      name: "Maria Santos",
      email: "maria.santos@pantukan.gov.ph",
      role: "Administrator",
      active: true,
    },
    {
      name: "Joel Garcia",
      email: "joel.garcia@pantukan.gov.ph",
      role: "Validator",
      active: true,
    },
    {
      name: "Ana Reyes",
      email: "ana.reyes@pantukan.gov.ph",
      role: "Dispatcher",
      active: true,
    },
  ]);

  const changed = () => {
    setDirty(true);
    setSaved(false);
    setFeedback("");
  };

  const setText = (setter: (value: string) => void, value: string) => {
    setter(value);
    changed();
  };

  const toggle = (key: string) => {
    setToggles((values) => ({ ...values, [key]: !values[key] }));
    changed();
  };

  const row = (label: string, description: string, control: ReactNode) => (
    <div
      className="flex min-h-[62px] items-center justify-between gap-5 border-t border-[#eee] max-[650px]:flex-col max-[650px]:items-start max-[650px]:py-3 [&_b]:text-[10px] [&_p]:my-[3px] [&_p]:text-[9px] [&_p]:text-muted"
      key={label}
    >
      <div>
        <b>{label}</b>
        <p>{description}</p>
      </div>
      {control}
    </div>
  );

  const switchControl = (key: string) => (
    <Switch value={toggles[key]} onChange={() => toggle(key)} />
  );

  const saveChanges = () => {
    const configuration = {
      officeName,
      municipality,
      timezone,
      mapRadius,
      confidence,
      dispatchTeam,
      acknowledgement,
      notificationEmail,
      retention,
      toggles,
      admins,
    };
    localStorage.setItem(
      "responda-admin-settings",
      JSON.stringify(configuration),
    );
    setDirty(false);
    setSaved(true);
    setFeedback("Settings saved successfully.");
  };

  const generalContent = () => {
    if (activeSection === "Organization") {
      return (
        <Card>
          <SectionHead
            title="Organization profile"
            subtitle="Identity shown across reports and exports"
          />
          {row(
            "Office name",
            "Name displayed in the admin workspace",
            <input
              className={inputClass}
              value={officeName}
              onChange={(event) => setText(setOfficeName, event.target.value)}
            />,
          )}
          {row(
            "Municipality",
            "Primary operational area",
            <input
              className={inputClass}
              value={municipality}
              onChange={(event) => setText(setMunicipality, event.target.value)}
            />,
          )}
          {row(
            "Operations timezone",
            "Used for reports, logs, and dispatch times",
            <SelectField
              label="Timezone"
              value={timezone}
              options={["Asia/Manila (UTC+8)", "UTC"]}
              onChange={(value) => setText(setTimezone, value)}
            />,
          )}
        </Card>
      );
    }

    if (activeSection === "Report handling") {
      return (
        <Card>
          <SectionHead
            title="Report handling"
            subtitle="How reports enter the validation workflow"
          />
          {row(
            "Require validation for critical reports",
            "Critical incidents must be reviewed before dispatch",
            switchControl("criticalValidation"),
          )}
          {row(
            "Automatically flag possible duplicates",
            "Compare incident type, time, and nearby location",
            switchControl("duplicateFlagging"),
          )}
          {row(
            "Allow manually encoded reports",
            "Accept phone, walk-in, radio, and other offline reports",
            switchControl("manualReports"),
          )}
          {row(
            "Default map radius",
            "Operational area shown around incidents",
            <SelectField
              label="Map radius"
              value={mapRadius}
              options={["5 kilometers", "10 kilometers", "20 kilometers"]}
              onChange={(value) => setText(setMapRadius, value)}
            />,
          )}
        </Card>
      );
    }

    if (activeSection === "Validation rules") {
      return (
        <Card>
          <SectionHead
            title="Validation rules"
            subtitle="Required checks before an incident is approved"
          />
          {row(
            "Minimum ML confidence",
            "Flag suggestions below this level for closer review",
            <SelectField
              label="Confidence"
              value={confidence}
              options={["60%", "70%", "80%", "90%"]}
              onChange={(value) => setText(setConfidence, value)}
            />,
          )}
          {row(
            "Require validation notes",
            "Reviewers must explain every decision",
            switchControl("mandatoryNotes"),
          )}
          {row(
            "Require photo evidence",
            "Reports without a photo stay pending",
            switchControl("photoEvidence"),
          )}
        </Card>
      );
    }

    if (activeSection === "Dispatch defaults") {
      return (
        <Card>
          <SectionHead
            title="Dispatch defaults"
            subtitle="Default behavior when assigning response teams"
          />
          {row(
            "Preferred team selection",
            "Initial option in the dispatch form",
            <SelectField
              label="Default team"
              value={dispatchTeam}
              options={[
                "Best available team",
                "Nearest available team",
                "Manual selection",
              ]}
              onChange={(value) => setText(setDispatchTeam, value)}
            />,
          )}
          {row(
            "Notify team automatically",
            "Send assignment details immediately after dispatch",
            switchControl("teamNotification"),
          )}
          {row(
            "Acknowledgement timeout",
            "Time before an unanswered dispatch is escalated",
            <SelectField
              label="Timeout"
              value={acknowledgement}
              options={["3 minutes", "5 minutes", "10 minutes"]}
              onChange={(value) => setText(setAcknowledgement, value)}
            />,
          )}
        </Card>
      );
    }

    if (activeSection === "Manual intake") {
      return (
        <Card>
          <SectionHead
            title="Manual intake sources"
            subtitle="Offline channels admins can encode into RESPONDA"
          />
          {row(
            "Phone calls",
            "Reports received through an emergency phone call",
            switchControl("phoneCalls"),
          )}
          {row(
            "Walk-in reports",
            "Reports given directly at the MDRRMO office",
            switchControl("walkIns"),
          )}
          {row(
            "Radio reports",
            "Reports received from authorized radio operators",
            switchControl("radioReports"),
          )}
          {row(
            "Other offline sources",
            "Other verified sources outside the mobile app",
            switchControl("otherSources"),
          )}
        </Card>
      );
    }

    return (
      <Card>
        <SectionHead
          title="Integrations"
          subtitle="External services used by the admin workspace"
        />
        {row(
          "Mobile app API",
          "Receive submitted incident and account-verification data",
          switchControl("mobileApi"),
        )}
        {row(
          "Weather alert feed",
          "Show official severe-weather advisories",
          switchControl("weatherAlerts"),
        )}
        {row(
          "OpenStreetMap",
          "Provide map tiles and geographic context",
          switchControl("openStreetMap"),
        )}
        <div className="mt-3 flex justify-end">
          <Button
            variant="secondary"
            onClick={() =>
              setFeedback("Integration connection test completed.")
            }
          >
            Test connections
          </Button>
        </div>
      </Card>
    );
  };

  const tabContent = () => {
    if (activeTab === "General") return generalContent();

    if (activeTab === "Notifications") {
      return (
        <div className="grid gap-3">
          <Card>
            <SectionHead
              title="Alerts and escalation"
              subtitle="Notifications for time-sensitive activity"
            />
            {row(
              "Critical incident sound alert",
              "Play a priority alert on active admin sessions",
              switchControl("soundAlert"),
            )}
            {row(
              "Validation queue reminder",
              "Notify reviewers after five minutes",
              switchControl("queueReminder"),
            )}
            {row(
              "Daily operations summary",
              "Email a daily MDRRMO activity summary",
              switchControl("dailySummary"),
            )}
            {row(
              "Account approval notifications",
              "Notify admins when a new account needs review",
              switchControl("accountApprovals"),
            )}
          </Card>
          <Card>
            <SectionHead
              title="Notification destination"
              subtitle="Recipient for system-generated summaries"
            />
            {row(
              "Operations email",
              "Daily summaries and administrative alerts",
              <input
                type="email"
                className={inputClass}
                value={notificationEmail}
                onChange={(event) =>
                  setText(setNotificationEmail, event.target.value)
                }
              />,
            )}
            <div className="mt-3 flex justify-end">
              <Button
                variant="secondary"
                icon="bell"
                onClick={() => setFeedback("Test notification sent.")}
              >
                Send test notification
              </Button>
            </div>
          </Card>
        </div>
      );
    }

    if (activeTab === "Users & roles") {
      return (
        <Card>
          <SectionHead
            title="Admin users and roles"
            subtitle="Control access to the RESPONDA admin workspace"
          />
          {admins.map((admin, index) => (
            <div
              className="grid min-h-[70px] grid-cols-[1fr_180px_55px] items-center gap-3 border-t border-border max-[650px]:grid-cols-1 max-[650px]:py-3"
              key={admin.email}
            >
              <div>
                <b className="block text-[10px]">{admin.name}</b>
                <span className="text-[9px] text-muted">{admin.email}</span>
              </div>
              <SelectField
                label="Role"
                value={admin.role}
                options={["Administrator", "Validator", "Dispatcher", "Viewer"]}
                onChange={(role) => {
                  setAdmins((users) =>
                    users.map((user, userIndex) =>
                      userIndex === index ? { ...user, role } : user,
                    ),
                  );
                  changed();
                }}
              />
              <Switch
                value={admin.active}
                onChange={() => {
                  setAdmins((users) =>
                    users.map((user, userIndex) =>
                      userIndex === index
                        ? { ...user, active: !user.active }
                        : user,
                    ),
                  );
                  changed();
                }}
              />
            </div>
          ))}
        </Card>
      );
    }

    return (
      <Card>
        <SectionHead
          title="Data and retention"
          subtitle="Control archiving, audit history, and configuration backups"
        />
        {row(
          "Incident record retention",
          "How long completed records remain available",
          <SelectField
            label="Retention period"
            value={retention}
            options={["1 year", "3 years", "5 years", "10 years"]}
            onChange={(value) => setText(setRetention, value)}
          />,
        )}
        {row(
          "Automatic archiving",
          "Archive completed cases after 30 days",
          switchControl("autoArchive"),
        )}
        {row(
          "Retain audit logs",
          "Preserve administrator actions with every record",
          switchControl("auditLogs"),
        )}
        <div className="mt-3 flex justify-end">
          <Button
            variant="secondary"
            icon="download"
            onClick={() => {
              downloadSettings(
                JSON.stringify(
                  { officeName, municipality, timezone, retention, toggles },
                  null,
                  2,
                ),
              );
              setFeedback("Settings backup downloaded.");
            }}
          >
            Export configuration
          </Button>
        </div>
      </Card>
    );
  };

  return (
    <>
      <PageTitle
        title="Settings"
        subtitle="Configure the RESPONDA admin workspace for Pantukan MDRRMO."
        action="Save changes"
        onAction={saveChanges}
        actionDisabled={
          !dirty ||
          !officeName.trim() ||
          !municipality.trim() ||
          !notificationEmail.trim()
        }
      />

      {(saved || feedback) && (
        <div className="flex items-center justify-between rounded-xl bg-green-soft px-4 py-3 text-[10px] text-status-green">
          <b>{feedback || "Settings saved successfully."}</b>
          <button
            className="border-0 bg-transparent text-status-green"
            onClick={() => {
              setSaved(false);
              setFeedback("");
            }}
          >
            ×
          </button>
        </div>
      )}

      <Card className="flex h-[54px] items-center gap-1.5 overflow-auto px-2 py-1.5 [&_button]:flex [&_button]:h-[34px] [&_button]:items-center [&_button]:gap-1.5 [&_button]:whitespace-nowrap [&_button]:rounded-[9px] [&_button]:border-0 [&_button]:bg-transparent [&_button]:px-4 [&_button]:text-[9px] [&_button]:text-muted [&_button.active]:bg-blush [&_button.active]:text-maroon">
        {tabs.map(([label, icon]) => (
          <button
            className={activeTab === label ? "active" : ""}
            key={label}
            onClick={() => setActiveTab(label)}
          >
            <Icon name={icon as IconName} />
            {label}
          </button>
        ))}
      </Card>

      <div
        className={
          activeTab === "General"
            ? "grid grid-cols-[260px_minmax(0,1fr)] gap-4 max-[900px]:grid-cols-1"
            : "grid grid-cols-1 gap-4"
        }
      >
        {activeTab === "General" && (
          <Card className="flex flex-col items-stretch gap-[7px] max-[900px]:flex-row max-[900px]:overflow-x-auto [&>button]:flex [&>button]:h-[42px] [&>button]:w-full [&>button]:shrink-0 [&>button]:items-center [&>button]:justify-start [&>button]:gap-[9px] [&>button]:rounded-[10px] [&>button]:border-0 [&>button]:bg-transparent [&>button]:px-[10px] [&>button]:text-left [&>button]:text-[9px] [&>button.active]:bg-blush [&>button.active]:text-maroon max-[900px]:[&>button]:w-auto">
            <span className="block w-full px-[10px] text-left text-[9px] font-bold tracking-[.04em] text-muted max-[900px]:hidden">
              WORKSPACE SETTINGS
            </span>
            {workspaceSections.map(([label, icon]) => (
              <button
                className={activeSection === label ? "active" : ""}
                key={label}
                onClick={() => setActiveSection(label)}
              >
                <Icon name={icon as IconName} />
                {label}
                {activeSection === label && (
                  <span className="ml-auto">
                    <Icon name="chevron" />
                  </span>
                )}
              </button>
            ))}
            <div className="mt-auto grid gap-[7px] rounded-[14px] bg-deep p-3 text-white max-[900px]:hidden [&>b]:text-[8px] [&>b]:text-[#eaced3] [&_strong]:text-[10px] [&_p]:text-[8px] [&_p]:text-[#eaced3] [&_.button]:w-full">
              <b>NEED HELP?</b>
              <strong>Configuration affects all MDRRMO admins.</strong>
              <p>Review changes before saving.</p>
              <Button variant="secondary" onClick={() => setGuideOpen(true)}>
                Open admin guide
              </Button>
            </div>
          </Card>
        )}
        <div className="grid gap-3">{tabContent()}</div>
      </div>

      {guideOpen && (
        <div
          className="fixed inset-0 z-[110] grid place-items-center bg-[#23090f7a] p-5 backdrop-blur"
          onMouseDown={() => setGuideOpen(false)}
        >
          <Card className="w-[min(560px,100%)] p-6">
            <div onMouseDown={(event) => event.stopPropagation()}>
              <div className="flex items-start justify-between gap-4 border-b border-border pb-4">
                <div>
                  <Badge tone="blue">ADMIN GUIDE</Badge>
                  <h2 className="mb-0 mt-2 text-lg">
                    Managing RESPONDA settings
                  </h2>
                </div>
                <button
                  className="grid size-10 shrink-0 place-items-center rounded-xl border-0 bg-soft-gray text-xl text-maroon"
                  onClick={() => setGuideOpen(false)}
                >
                  ×
                </button>
              </div>
              <div className="my-5 grid gap-4 text-[10px] leading-5">
                <p>
                  <b>General:</b> Configure report handling, validation,
                  dispatch, and data sources.
                </p>
                <p>
                  <b>Notifications:</b> Choose which operational alerts admins
                  receive.
                </p>
                <p>
                  <b>Users and security:</b> Limit access and protect
                  administrator sessions.
                </p>
                <p>
                  <b>Saving:</b> The Save Changes button enables only after a
                  setting changes and all required fields are complete.
                </p>
              </div>
              <div className="flex justify-end">
                <Button onClick={() => setGuideOpen(false)}>Got it</Button>
              </div>
            </div>
          </Card>
        </div>
      )}
    </>
  );
}
