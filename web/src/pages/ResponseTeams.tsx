import { useMemo, useState } from "react";
import { Icon } from "../components/Icon";
import {
  Badge,
  Button,
  Card,
  Metric,
  PageTitle,
  SectionHead,
  SelectField,
} from "../components/ui";

type TeamStatus = "AVAILABLE" | "ON ROUTE" | "ON SITE" | "DEPLOYED";

type Team = {
  id: string;
  name: string;
  status: TeamStatus;
  specialty: string;
  leader: string;
  assignment: string;
  tone: string;
  eta: string;
  needsAttention?: boolean;
};

const initialTeams: Team[] = [
  {
    id: "TEAM-001",
    name: "Rescue Alpha",
    status: "ON ROUTE",
    specialty: "Search & rescue",
    leader: "R. Villanueva",
    assignment: "Road Accident • Kingking Highway",
    tone: "maroon",
    eta: "4 min",
  },
  {
    id: "TEAM-002",
    name: "Medical 1",
    status: "AVAILABLE",
    specialty: "Emergency medical",
    leader: "D. Flores",
    assignment: "Available",
    tone: "green",
    eta: "0 min",
  },
  {
    id: "TEAM-003",
    name: "Flood Unit",
    status: "ON SITE",
    specialty: "Flood response",
    leader: "J. Ramos",
    assignment: "Flash Flood • Magnaga Riverside",
    tone: "blue",
    eta: "On site",
  },
  {
    id: "TEAM-004",
    name: "Rescue Bravo",
    status: "DEPLOYED",
    specialty: "Road clearing",
    leader: "A. Mercado",
    assignment: "Landslide • Bongabong Slope",
    tone: "orange",
    eta: "12 min",
    needsAttention: true,
  },
  {
    id: "TEAM-005",
    name: "Logistics 2",
    status: "AVAILABLE",
    specialty: "Transport & supplies",
    leader: "M. Santos",
    assignment: "Available",
    tone: "green",
    eta: "8 min",
  },
  {
    id: "TEAM-006",
    name: "Medical 2",
    status: "DEPLOYED",
    specialty: "Emergency medical",
    leader: "C. Reyes",
    assignment: "Medical • Matiao Public Market",
    tone: "blue",
    eta: "6 min",
  },
];

const teamToneClasses: Record<string, string> = {
  maroon: "bg-blush text-maroon",
  red: "bg-red-soft text-priority-red",
  orange: "bg-orange-soft text-priority-orange",
  amber: "bg-amber-soft text-priority-amber",
  green: "bg-green-soft text-status-green",
  blue: "bg-blue-soft text-status-blue",
};

export function ResponseTeams() {
  const [teams, setTeams] = useState(initialTeams);
  const [statusFilter, setStatusFilter] = useState("");
  const [selectedTeamId, setSelectedTeamId] = useState<string | null>(null);
  const [addTeamOpen, setAddTeamOpen] = useState(false);
  const [activity, setActivity] = useState([
    ["1:42 PM", "Rescue Alpha", "Departed for Kingking Highway"],
    ["1:38 PM", "Flood Unit", "Arrived at Magnaga riverside"],
    ["1:31 PM", "Medical 1", "Returned to available status"],
  ]);
  const [draftTeam, setDraftTeam] = useState({
    name: "",
    specialty: "",
    leader: "",
    status: "AVAILABLE" as TeamStatus,
  });

  const availableTeams = teams.filter((team) => team.status === "AVAILABLE");
  const deployedTeams = teams.filter((team) => team.status !== "AVAILABLE");
  const visibleTeams = useMemo(
    () =>
      teams.filter((team) => {
        if (!statusFilter) return true;
        if (statusFilter === "DEPLOYED") return team.status !== "AVAILABLE";
        return team.status === statusFilter;
      }),
    [statusFilter, teams],
  );
  const selectedTeam = teams.find((team) => team.id === selectedTeamId);
  const canAddTeam = Boolean(
    draftTeam.name.trim() &&
    draftTeam.specialty.trim() &&
    draftTeam.leader.trim(),
  );
  const addTeam = () => {
    if (!canAddTeam) return;
    const newTeam: Team = {
      id: `TEAM-${String(teams.length + 1).padStart(3, "0")}`,
      name: draftTeam.name.trim(),
      specialty: draftTeam.specialty.trim(),
      leader: draftTeam.leader.trim(),
      status: draftTeam.status,
      assignment:
        draftTeam.status === "AVAILABLE" ? "Available" : "Awaiting details",
      tone: draftTeam.status === "AVAILABLE" ? "green" : "blue",
      eta: draftTeam.status === "AVAILABLE" ? "Ready" : "Active",
    };
    setTeams((current) => [...current, newTeam]);
    setActivity((current) => [
      ["Now", newTeam.name, "Added to the response-team roster"],
      ...current,
    ]);
    setDraftTeam({
      name: "",
      specialty: "",
      leader: "",
      status: "AVAILABLE",
    });
    setAddTeamOpen(false);
  };

  return (
    <>
      <PageTitle
        title="Response Teams"
        subtitle="Manage the team roster, readiness, and current incident assignments."
        action="Add team"
        onAction={() => setAddTeamOpen(true)}
      />

      <div className="grid grid-cols-4 gap-4 max-[1180px]:grid-cols-2 max-[650px]:grid-cols-1">
        <Metric
          icon="users"
          title="Total teams"
          value={String(teams.length)}
          sub="MDRRMO operational units"
          tone="maroon"
        />
        <Metric
          icon="truck"
          title="Deployed"
          value={String(deployedTeams.length)}
          sub="Across active incidents"
          tone="blue"
        />
        <Metric
          icon="verify"
          title="Available"
          value={String(availableTeams.length)}
          sub="Ready for assignment"
          tone="green"
        />
        <Metric
          icon="alert"
          title="Needs attention"
          value={String(teams.filter((team) => team.needsAttention).length)}
          sub="Vehicle maintenance due"
          tone="amber"
        />
      </div>

      <div className="grid grid-cols-[minmax(0,2fr)_minmax(360px,1fr)] gap-4 max-[1180px]:grid-cols-1">
        <div>
          <div className="mb-3 flex h-10 items-center justify-between gap-3 [&_h3]:m-0 [&_h3]:text-sm [&_p]:my-0.5 [&_p]:text-[9px] [&_p]:text-muted">
            <div>
              <h3>Operational units</h3>
              <p>{visibleTeams.length} teams match the current status</p>
            </div>
            <SelectField
              label="All statuses"
              value={statusFilter}
              options={["AVAILABLE", "DEPLOYED", "ON ROUTE", "ON SITE"]}
              onChange={setStatusFilter}
            />
          </div>

          <div className="mb-3 grid grid-cols-2 gap-3 max-[650px]:grid-cols-1">
            {visibleTeams.map((team) => (
              <Card
                className="[&>div:first-child]:flex [&>div:first-child]:items-center [&>div:first-child]:justify-between [&_h3]:mt-[10px] [&_h3]:mb-[3px] [&_h3]:text-sm [&>p]:text-[9px] [&>p]:text-muted [&>div:not(:first-child)]:my-[7px] [&>div:not(:first-child)]:flex [&>div:not(:first-child)]:justify-between [&>div:not(:first-child)]:text-[9px] [&>div_span]:text-muted [&_.button]:mt-[10px] [&_.button]:w-full"
                key={team.id}
              >
                <div>
                  <span
                    className={`grid size-11 shrink-0 place-items-center rounded-[14px] ${teamToneClasses[team.tone]}`}
                  >
                    <Icon name="users" />
                  </span>
                  <Badge tone={team.tone}>{team.status}</Badge>
                </div>
                <h3>{team.name}</h3>
                <p>{team.specialty}</p>
                <div>
                  <span>Team leader</span>
                  <b>{team.leader}</b>
                </div>
                <div>
                  <span>Current assignment</span>
                  <b>{team.assignment}</b>
                </div>
                <Button
                  variant="secondary"
                  onClick={() => setSelectedTeamId(team.id)}
                >
                  View team
                </Button>
              </Card>
            ))}
            {!visibleTeams.length && (
              <Card className="col-span-full grid min-h-40 place-items-center text-[10px] text-muted">
                No teams match this status.
              </Card>
            )}
          </div>

          <Card className="p-4">
            <SectionHead
              title="Recent team activity"
              subtitle="Latest status changes"
            />
            {activity.slice(0, 5).map((entry, index) => (
              <div
                className="grid min-h-7 grid-cols-[45px_100px_1fr] items-center gap-2 border-b border-[#f0f0f1] text-[9px] last:border-0 [&_span]:text-muted [&_p]:text-muted"
                key={`${entry[0]}-${entry[1]}-${index}`}
              >
                <span>{entry[0]}</span>
                <b>{entry[1]}</b>
                <p>{entry[2]}</p>
              </div>
            ))}
          </Card>
        </div>

        <div className="side-stack flex flex-col gap-3 max-[1180px]:grid max-[1180px]:grid-cols-2 max-[900px]:grid-cols-1">
          <Card className="p-4">
            <SectionHead
              title="Current assignments"
              subtitle={`${deployedTeams.length} teams assigned to active incidents`}
            />
            {deployedTeams.map((team) => (
              <button
                className="mt-2.5 grid min-h-[92px] w-full gap-2 rounded-[14px] border border-transparent bg-soft-gray p-3 text-left transition-colors hover:border-maroon hover:bg-blush"
                key={team.id}
                onClick={() => setSelectedTeamId(team.id)}
              >
                <div className="flex min-w-0 items-center gap-2.5">
                  <span className="grid size-9 shrink-0 place-items-center rounded-[11px] bg-white text-maroon">
                    <Icon name="truck" />
                  </span>
                  <div className="grid min-w-0 flex-1 gap-0.5">
                    <b className="truncate text-[10px]">{team.name}</b>
                    <small className="truncate text-[8px] text-muted">
                      {team.specialty}
                    </small>
                  </div>
                  <Badge tone={team.tone}>{team.status}</Badge>
                </div>
                <span className="flex items-start gap-1.5 border-t border-border pt-2 text-[9px] leading-[1.45] text-muted">
                  <Icon name="pin" size={13} />
                  <strong className="font-semibold text-[#1c1c1e]">
                    {team.assignment}
                  </strong>
                </span>
              </button>
            ))}
          </Card>

          <Card>
            <SectionHead
              title="Available now"
              subtitle="Units ready for a future assignment"
            />
            {availableTeams.map((team) => (
              <button
                className="mt-2 flex h-[58px] w-full items-center gap-2 rounded-xl border border-transparent bg-green-soft p-[9px] text-left transition-colors hover:border-status-green [&>span]:grid [&>span]:size-8 [&>span]:place-items-center [&>span]:rounded-[10px] [&>span]:bg-white [&>span]:text-status-green [&>div]:grid [&>div]:flex-1 [&>div]:gap-[3px] [&_small]:text-[9px] [&_small]:text-muted [&>strong]:text-[9px] [&>strong]:text-status-green"
                key={team.id}
                onClick={() => setSelectedTeamId(team.id)}
              >
                <span>
                  <Icon name="users" />
                </span>
                <div>
                  <b>{team.name}</b>
                  <small>{team.specialty}</small>
                </div>
                <strong>{team.eta}</strong>
              </button>
            ))}
            {!availableTeams.length && (
              <p className="text-[9px] text-muted">
                No response team is currently available.
              </p>
            )}
          </Card>
        </div>
      </div>

      {selectedTeam && (
        <div
          className="fixed inset-0 z-[110] grid place-items-center bg-[#23090f7a] p-5 backdrop-blur"
          onMouseDown={() => setSelectedTeamId(null)}
        >
          <Card className="max-h-[calc(100vh-40px)] w-[min(620px,100%)] overflow-y-auto p-7 max-[650px]:p-5">
            <div onMouseDown={(event) => event.stopPropagation()}>
              <div className="flex items-start gap-4">
                <span
                  className={`grid size-14 shrink-0 place-items-center rounded-[17px] ${teamToneClasses[selectedTeam.tone]}`}
                >
                  <Icon name="users" size={25} />
                </span>
                <div className="flex-1">
                  <span className="text-[9px] font-bold tracking-[.04em] text-muted">
                    {selectedTeam.id}
                  </span>
                  <h2 className="my-1.5 text-xl">{selectedTeam.name}</h2>
                  <Badge tone={selectedTeam.tone}>{selectedTeam.status}</Badge>
                </div>
                <button
                  className="mt-2 grid size-10 shrink-0 place-items-center rounded-xl border-0 bg-soft-gray text-xl text-maroon"
                  onClick={() => setSelectedTeamId(null)}
                >
                  ×
                </button>
              </div>
              <div className="my-6 h-px w-full bg-border" />
              <div className="flex flex-col gap-5 px-1 py-1">
                {[
                  ["Specialty", selectedTeam.specialty],
                  ["Team leader", selectedTeam.leader],
                  ["Current assignment", selectedTeam.assignment],
                  ["Estimated availability", selectedTeam.eta],
                ].map(([label, value]) => (
                  <div className="flex flex-col gap-1.5" key={label}>
                    <span className="text-[9px] font-bold tracking-[.04em] text-muted">
                      {label.toUpperCase()}
                    </span>
                    <b className="text-[13px] leading-[1.5]">{value}</b>
                  </div>
                ))}
              </div>
              <div className="mt-7 flex justify-end gap-2 border-t border-border pt-5 max-[650px]:flex-col-reverse max-[650px]:[&_.button]:w-full">
                <Button
                  variant="secondary"
                  onClick={() => setSelectedTeamId(null)}
                >
                  Close
                </Button>
              </div>
            </div>
          </Card>
        </div>
      )}

      {addTeamOpen && (
        <div
          className="fixed inset-0 z-[110] grid place-items-center bg-[#23090f7a] p-5 backdrop-blur"
          onMouseDown={() => setAddTeamOpen(false)}
        >
          <Card className="w-[min(500px,100%)] p-5">
            <div
              className="grid gap-3"
              onMouseDown={(event) => event.stopPropagation()}
            >
              <div>
                <h2 className="m-0 text-lg">Add response team</h2>
                <p className="mt-1 text-[9px] text-muted">
                  Add a new operational unit to the team roster.
                </p>
              </div>
              {[
                ["Team name", "name", "Example: Rescue Charlie"],
                ["Specialty", "specialty", "Example: Search and rescue"],
                ["Team leader", "leader", "Full name or call sign"],
              ].map(([label, key, placeholder]) => (
                <label
                  className="grid gap-1 text-[9px] font-semibold"
                  key={key}
                >
                  {label}
                  <input
                    className="h-10 rounded-[10px] border border-border px-3 text-[11px] outline-0 focus:border-maroon"
                    value={draftTeam[key as "name" | "specialty" | "leader"]}
                    onChange={(event) =>
                      setDraftTeam((current) => ({
                        ...current,
                        [key]: event.target.value,
                      }))
                    }
                    placeholder={placeholder}
                  />
                </label>
              ))}
              <label className="grid gap-1 text-[9px] font-semibold">
                Initial status
                <select
                  className="h-10 rounded-[10px] border border-border px-3 text-[11px] outline-0 focus:border-maroon"
                  value={draftTeam.status}
                  onChange={(event) =>
                    setDraftTeam((current) => ({
                      ...current,
                      status: event.target.value as TeamStatus,
                    }))
                  }
                >
                  <option value="AVAILABLE">Available</option>
                  <option value="DEPLOYED">Deployed</option>
                </select>
              </label>
              {!canAddTeam && (
                <span className="text-[8px] text-muted">
                  Complete the team name, specialty, and leader.
                </span>
              )}
              <div className="flex justify-end gap-2">
                <Button
                  variant="secondary"
                  onClick={() => setAddTeamOpen(false)}
                >
                  Cancel
                </Button>
                <Button icon="plus" disabled={!canAddTeam} onClick={addTeam}>
                  Add team
                </Button>
              </div>
            </div>
          </Card>
        </div>
      )}
    </>
  );
}
