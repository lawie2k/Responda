import { type FormEvent, useEffect, useState } from "react";
import {
  createAdminResponseUnit,
  transitionAdminAssignment,
  updateAdminResponseUnit,
  type AdminAssignmentListItem,
  type AssignmentTransitionStatus,
  type AdminResponseUnitListItem,
  type AdminUser,
  type ResponseUnitStatus,
} from "../api/respondaApi";
import { Icon } from "../components/Icon";
import { isAdministratorRole } from "../config/roles";
import {
  Badge,
  Button,
  Card,
  PageTitle,
  SectionHead,
  SelectField,
} from "../components/ui";
import { useActiveAdminAssignments } from "../hooks/useAdminAssignments";
import { useAdminResponseUnits } from "../hooks/useAdminResponseUnits";

const PAGE_SIZE = 20;
const editorInputClasses =
  "h-10 w-full rounded-[7px] border border-border bg-white px-3 text-[10px] outline-0 placeholder:text-muted focus:border-maroon";

const statusMeta: Record<
  ResponseUnitStatus,
  { label: string; tone: string; detail: string }
> = {
  available: { label: "AVAILABLE", tone: "green", detail: "Ready" },
  assigned: { label: "ASSIGNED", tone: "blue", detail: "Assigned" },
  responding: { label: "RESPONDING", tone: "maroon", detail: "Responding" },
  offline: { label: "OFFLINE", tone: "amber", detail: "Unavailable" },
};

const assignmentStatusMeta: Record<
  AdminAssignmentListItem["status"],
  { label: string; tone: string }
> = {
  assigned: { label: "ASSIGNED", tone: "blue" },
  acknowledged: { label: "ACKNOWLEDGED", tone: "blue" },
  responding: { label: "RESPONDING", tone: "maroon" },
  completed: { label: "COMPLETED", tone: "green" },
  cancelled: { label: "CANCELLED", tone: "amber" },
};

function unitReference(unitId: string) {
  return `UNIT-${unitId.slice(0, 8).toUpperCase()}`;
}

function formatTimestamp(value: string | null) {
  if (!value) return "Not recorded";
  const date = new Date(value);
  if (Number.isNaN(date.getTime())) return "Not recorded";
  return new Intl.DateTimeFormat("en-PH", {
    dateStyle: "medium",
    timeStyle: "short",
  }).format(date);
}

function locationLabel(unit: AdminResponseUnitListItem) {
  if (unit.current_latitude === null || unit.current_longitude === null) {
    return "No location reported";
  }
  return `${unit.current_latitude.toFixed(5)}, ${unit.current_longitude.toFixed(5)}`;
}

function UnitCard({
  unit,
  onSelect,
}: {
  unit: AdminResponseUnitListItem;
  onSelect: () => void;
}) {
  const meta = statusMeta[unit.status];
  return (
    <Card className="flex min-h-[230px] flex-col">
      <div className="flex items-center justify-between gap-3">
        <span className="grid size-11 shrink-0 place-items-center rounded-[10px] bg-[#f3efed] text-maroon">
          <Icon name="users" />
        </span>
        <Badge tone={meta.tone}>{meta.label}</Badge>
      </div>
      <h3 className="mb-1 mt-3 text-sm">{unit.name}</h3>
      <p className="m-0 text-[9px] text-muted">{unit.unit_type}</p>
      <div className="mt-4 grid gap-2 border-t border-border pt-3 text-[9px]">
        <div className="flex items-center justify-between gap-3">
          <span className="text-muted">Contact</span>
          <b className="truncate">{unit.contact}</b>
        </div>
        <div className="flex items-start justify-between gap-3">
          <span className="shrink-0 text-muted">Last location</span>
          <b className="text-right">{locationLabel(unit)}</b>
        </div>
      </div>
      <div className="mt-auto pt-4">
        <Button variant="secondary" onClick={onSelect}>
          View unit
        </Button>
      </div>
    </Card>
  );
}

export function ResponseTeams({
  role,
  onAssignmentsChanged,
}: {
  role: AdminUser["role"];
  onAssignmentsChanged: () => void;
}) {
  const canManageRoster = isAdministratorRole(role);
  const [statusFilter, setStatusFilter] = useState<ResponseUnitStatus | "">("");
  const [localSearch, setLocalSearch] = useState("");
  const [search, setSearch] = useState("");
  const [page, setPage] = useState(1);
  const [selectedUnitId, setSelectedUnitId] = useState<string | null>(null);
  const [editor, setEditor] = useState<{
    mode: "create" | "edit";
    unit: AdminResponseUnitListItem | null;
  } | null>(null);
  const [editorFields, setEditorFields] = useState({
    name: "",
    unitType: "",
    contact: "",
  });
  const [editorError, setEditorError] = useState("");
  const [savingUnit, setSavingUnit] = useState(false);
  const [feedback, setFeedback] = useState("");
  const [transitioning, setTransitioning] =
    useState<AssignmentTransitionStatus | null>(null);
  const [assignmentError, setAssignmentError] = useState("");
  const [confirmCancellation, setConfirmCancellation] = useState(false);

  useEffect(() => {
    const timeout = window.setTimeout(() => {
      setSearch(localSearch.trim());
      setPage(1);
    }, 250);
    return () => window.clearTimeout(timeout);
  }, [localSearch]);

  const roster = useAdminResponseUnits({
    page,
    pageSize: PAGE_SIZE,
    search: search || undefined,
    statuses: statusFilter ? [statusFilter] : undefined,
  });
  const activeAssignments = useActiveAdminAssignments();
  const data = roster.data;
  const counts = data?.counts ?? {
    total: 0,
    available: 0,
    assigned: 0,
    responding: 0,
    offline: 0,
  };
  const selectedUnit = data?.items.find(
    (unit) => unit.unit_id === selectedUnitId,
  );
  const selectedAssignment = activeAssignments.data?.find(
    (assignment) => assignment.unit.unit_id === selectedUnitId,
  );
  const inService =
    data?.items.filter(
      (unit) => unit.status === "assigned" || unit.status === "responding",
    ) ?? [];
  const available =
    data?.items.filter((unit) => unit.status === "available") ?? [];
  const hasFilters = Boolean(statusFilter || localSearch.trim());

  const resetFilters = () => {
    setLocalSearch("");
    setSearch("");
    setStatusFilter("");
    setPage(1);
  };

  const openUnit = (unitId: string) => {
    setSelectedUnitId(unitId);
    setAssignmentError("");
    setConfirmCancellation(false);
  };

  const closeUnit = () => {
    if (transitioning) return;
    setSelectedUnitId(null);
    setAssignmentError("");
    setConfirmCancellation(false);
  };

  const openCreateEditor = () => {
    setEditor({ mode: "create", unit: null });
    setEditorFields({ name: "", unitType: "", contact: "" });
    setEditorError("");
    setFeedback("");
  };

  const openEditEditor = (unit: AdminResponseUnitListItem) => {
    setSelectedUnitId(null);
    setEditor({ mode: "edit", unit });
    setEditorFields({
      name: unit.name,
      unitType: unit.unit_type,
      contact: unit.contact,
    });
    setEditorError("");
    setFeedback("");
  };

  const closeEditor = () => {
    if (savingUnit) return;
    setEditor(null);
    setEditorError("");
  };

  const submitUnit = async (event: FormEvent<HTMLFormElement>) => {
    event.preventDefault();
    if (!editor || savingUnit) return;
    const payload = {
      name: editorFields.name.trim(),
      unit_type: editorFields.unitType.trim(),
      contact: editorFields.contact.trim(),
    };
    if (!payload.name || !payload.unit_type || !payload.contact) {
      setEditorError("Name, unit type, and contact are required.");
      return;
    }

    setSavingUnit(true);
    setEditorError("");
    try {
      const saved =
        editor.mode === "create"
          ? await createAdminResponseUnit(payload)
          : await updateAdminResponseUnit(editor.unit!.unit_id, {
              ...payload,
              expected_updated_at: editor.unit!.updated_at,
            });
      setFeedback(
        editor.mode === "create"
          ? `${saved.name} was registered and is available for assignment.`
          : `${saved.name}'s roster details were updated.`,
      );
      setEditor(null);
      setPage(1);
      roster.refetch();
    } catch (error) {
      setEditorError(
        error instanceof Error
          ? error.message
          : "The response-unit details could not be saved.",
      );
    } finally {
      setSavingUnit(false);
    }
  };

  const transitionAssignment = async (
    assignment: AdminAssignmentListItem,
    status: AssignmentTransitionStatus,
  ) => {
    if (transitioning) return;
    setTransitioning(status);
    setAssignmentError("");
    try {
      const result = await transitionAdminAssignment(
        assignment.assignment_id,
        {
          expected_updated_at: assignment.updated_at,
          status,
        },
      );
      const action =
        status === "acknowledged"
          ? "acknowledged"
          : status === "responding"
            ? "marked as responding"
            : status === "completed"
              ? "completed"
              : "cancelled";
      setFeedback(`${result.assignment.unit.name}'s assignment was ${action}.`);
      setSelectedUnitId(null);
      setConfirmCancellation(false);
      roster.refetch();
      activeAssignments.refetch();
      onAssignmentsChanged();
    } catch (error) {
      setAssignmentError(
        error instanceof Error
          ? error.message
          : "The assignment status could not be updated.",
      );
    } finally {
      setTransitioning(null);
    }
  };

  return (
    <>
      <PageTitle
        title="Response Teams"
        subtitle="View the response-unit roster, readiness, contact details, and latest reported location."
        action={canManageRoster ? "Register unit" : undefined}
        onAction={openCreateEditor}
      />

      {feedback && (
        <div className="flex min-h-11 items-center justify-between border border-[#b9ddc7] border-l-[3px] border-l-status-green bg-white px-3 text-[10px] text-status-green">
          <b>{feedback}</b>
          <button
            aria-label="Dismiss roster message"
            className="border-0 bg-transparent text-base text-status-green"
            onClick={() => setFeedback("")}
          >
            ×
          </button>
        </div>
      )}

      <Card className="flex items-center gap-3 max-[760px]:flex-col max-[760px]:items-stretch">
        <label className="relative flex-1">
          <span className="sr-only">Search response units</span>
          <span className="absolute left-3 top-1/2 -translate-y-1/2 text-muted">
            <Icon name="search" size={15} />
          </span>
          <input
            className="h-[38px] w-full rounded-[10px] border border-border bg-white pl-9 pr-3 text-[10px] outline-0 placeholder:text-muted focus:border-maroon focus:shadow-[0_0_0_3px_rgba(122,31,43,.08)]"
            onChange={(event) => setLocalSearch(event.target.value)}
            placeholder="Search by unit name, type, or contact"
            value={localSearch}
          />
        </label>
        <SelectField
          label="All statuses"
          onChange={(value) => {
            setStatusFilter(value as ResponseUnitStatus | "");
            setPage(1);
          }}
          options={[
            { label: "Available", value: "available" },
            { label: "Assigned", value: "assigned" },
            { label: "Responding", value: "responding" },
            { label: "Offline", value: "offline" },
          ]}
          value={statusFilter}
        />
        <Button variant="secondary" onClick={roster.refetch}>
          Refresh roster
        </Button>
      </Card>

      <div className="grid grid-cols-[minmax(0,2.4fr)_minmax(320px,0.9fr)] items-stretch gap-4 max-[1050px]:grid-cols-1">
        <Card className="flex min-h-[650px] flex-col overflow-visible p-5 max-[1050px]:min-h-[480px] max-[650px]:min-h-[360px]">
          <SectionHead
            title="Operational units"
            subtitle={
              data
                ? `${data.total} unit${data.total === 1 ? "" : "s"} match the current view`
                : "Loading the live response-unit roster"
            }
          />

          {roster.status === "loading" && (
            <div className="grid min-h-64 flex-1 place-items-center text-[10px] text-muted">
              Loading response units…
            </div>
          )}

          {roster.status === "error" && (
            <div className="grid min-h-64 flex-1 place-items-center gap-3 text-center">
              <div>
                <b className="block text-sm">The roster could not be loaded</b>
                <p className="mt-1 text-[10px] text-muted">{roster.error}</p>
              </div>
              <Button variant="secondary" onClick={roster.refetch}>
                Try again
              </Button>
            </div>
          )}

          {roster.status === "ready" && !roster.data.items.length && (
            <div className="grid min-h-64 flex-1 place-items-center text-center">
              <div className="max-w-sm">
                <span className="mx-auto grid size-12 place-items-center rounded-[15px] bg-soft-gray text-maroon">
                  <Icon name="users" size={22} />
                </span>
                <b className="mt-3 block text-sm">
                  {hasFilters
                    ? "No units match these filters"
                    : "No response units have been registered"}
                </b>
                <p className="mt-1 text-[10px] leading-5 text-muted">
                  {hasFilters
                    ? "Clear the filters to return to the full roster."
                    : "Units will appear here after they are added to the database."}
                </p>
                {hasFilters && (
                  <div className="mt-3">
                    <Button variant="secondary" onClick={resetFilters}>
                      Clear filters
                    </Button>
                  </div>
                )}
              </div>
            </div>
          )}

          {roster.status === "ready" && roster.data.items.length > 0 && (
            <div className="grid grid-cols-2 gap-3 max-[650px]:grid-cols-1">
              {roster.data.items.map((unit) => (
                <UnitCard
                  key={unit.unit_id}
                  onSelect={() => openUnit(unit.unit_id)}
                  unit={unit}
                />
              ))}
            </div>
          )}

          {roster.status === "ready" && (
            <div className="mt-auto flex items-center justify-between border-t border-border pt-4 text-[9px] text-muted">
              <span>
                Page {roster.data.page} of {Math.max(roster.data.total_pages, 1)}
              </span>
              <div className="flex gap-2">
                <Button
                  disabled={roster.data.page <= 1}
                  variant="secondary"
                  onClick={() => setPage((current) => Math.max(1, current - 1))}
                >
                  Previous
                </Button>
                <Button
                  disabled={roster.data.page >= roster.data.total_pages}
                  variant="secondary"
                  onClick={() => setPage((current) => current + 1)}
                >
                  Next
                </Button>
              </div>
            </div>
          )}
        </Card>

        <aside className="flex min-h-[650px] min-w-0 flex-col gap-4 max-[1050px]:min-h-0">
          <Card className="overflow-hidden p-0">
            <div className="flex min-h-[158px] flex-col border-t-[3px] border-t-maroon px-5 py-4">
              <span className="text-[8px] font-bold tracking-[.11em] text-muted">
                TOTAL UNITS · ACTIVE RESPONSE ROSTER
              </span>
              <strong className="mt-3 block text-[38px] font-semibold leading-none tracking-[-.055em] text-[#211b1d]">
                {counts.total}
              </strong>
              <p className="mb-0 mt-1.5 text-[9px] text-muted">
                Registered units available to Pantukan MDRRMO
              </p>
              <div className="mt-auto border-t border-border pt-2.5 text-[7px] uppercase tracking-[.07em] text-muted">
                Live roster status from PostgreSQL
              </div>
            </div>
            <div className="grid grid-rows-3 border-t border-border max-[1050px]:grid-cols-3 max-[1050px]:grid-rows-none max-[650px]:grid-cols-1">
              {[
                {
                  label: "IN SERVICE",
                  value: counts.assigned + counts.responding,
                  detail: "Assigned or responding",
                },
                {
                  label: "AVAILABLE",
                  value: counts.available,
                  detail: "Ready for assignment",
                },
                {
                  label: "OFFLINE",
                  value: counts.offline,
                  detail: "Currently unavailable",
                },
              ].map((item, index) => (
                <div
                  className={`grid min-h-[72px] grid-cols-[minmax(0,1fr)_auto] items-center gap-3 px-4 py-3 max-[1050px]:min-h-[86px] max-[1050px]:grid-cols-1 max-[1050px]:items-start max-[650px]:min-h-0 max-[650px]:grid-cols-[minmax(0,1fr)_auto] max-[650px]:items-center ${index > 0 ? "border-t border-border max-[1050px]:border-l max-[1050px]:border-t-0 max-[650px]:border-l-0 max-[650px]:border-t" : ""}`}
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
                  <strong className="text-[20px] font-semibold leading-none tracking-[-.04em] text-[#211b1d]">
                    {item.value}
                  </strong>
                </div>
              ))}
            </div>
          </Card>

          <Card className="p-4">
            <SectionHead
              title="In service"
              subtitle={`${counts.assigned + counts.responding} assigned or responding`}
            />
            {inService.map((unit) => {
              const meta = statusMeta[unit.status];
              const assignment = activeAssignments.data?.find(
                (item) => item.unit.unit_id === unit.unit_id,
              );
              return (
                <button
                  className="mt-2.5 grid min-h-[82px] w-full gap-2 rounded-[14px] border border-transparent bg-soft-gray p-3 text-left transition-colors hover:border-maroon hover:bg-blush"
                  key={unit.unit_id}
                  onClick={() => openUnit(unit.unit_id)}
                >
                  <div className="flex min-w-0 items-center gap-2.5">
                    <span className="grid size-9 shrink-0 place-items-center rounded-[11px] bg-white text-maroon">
                      <Icon name="truck" />
                    </span>
                    <div className="grid min-w-0 flex-1 gap-0.5">
                      <b className="truncate text-[10px]">{unit.name}</b>
                      <small className="truncate text-[8px] text-muted">
                        {unit.unit_type}
                      </small>
                    </div>
                    <Badge tone={meta.tone}>{meta.label}</Badge>
                  </div>
                  <span className="border-t border-border pt-2 text-[8px] text-muted">
                    {assignment
                      ? `INC-${assignment.incident_id.slice(0, 8).toUpperCase()}`
                      : activeAssignments.status === "loading"
                        ? "Loading active assignment details…"
                        : "Assignment details unavailable"}
                  </span>
                </button>
              );
            })}
            {!inService.length && (
              <p className="text-[9px] leading-5 text-muted">
                No assigned or responding units appear on this page.
              </p>
            )}
          </Card>

          <Card className="flex flex-1 flex-col p-4">
            <SectionHead
              title="Available now"
              subtitle={`${counts.available} unit${counts.available === 1 ? "" : "s"} ready for assignment`}
            />
            {available.map((unit) => (
              <button
                className="mt-2 flex min-h-[58px] w-full items-center gap-2 rounded-xl border border-transparent bg-green-soft p-[9px] text-left transition-colors hover:border-status-green"
                key={unit.unit_id}
                onClick={() => openUnit(unit.unit_id)}
              >
                <span className="grid size-8 shrink-0 place-items-center rounded-[10px] bg-white text-status-green">
                  <Icon name="users" />
                </span>
                <div className="grid min-w-0 flex-1 gap-[3px]">
                  <b className="truncate text-[10px]">{unit.name}</b>
                  <small className="truncate text-[9px] text-muted">
                    {unit.unit_type}
                  </small>
                </div>
                <strong className="text-[9px] text-status-green">Ready</strong>
              </button>
            ))}
            {!available.length && (
              <p className="text-[9px] leading-5 text-muted">
                No available units appear on this page.
              </p>
            )}
          </Card>
        </aside>
      </div>

      {editor && (
        <div
          aria-modal="true"
          className="fixed inset-0 z-[120] grid place-items-center bg-[#23090f7a] p-5 backdrop-blur"
          onMouseDown={closeEditor}
          role="dialog"
        >
          <Card className="w-[min(560px,100%)] p-0">
            <form
              className="grid gap-0"
              onMouseDown={(event) => event.stopPropagation()}
              onSubmit={submitUnit}
            >
              <div className="flex items-start justify-between border-b border-border px-6 py-5 max-[650px]:px-5">
                <div>
                  <span className="text-[8px] font-bold tracking-[.12em] text-maroon">
                    RESPONSE-UNIT ROSTER
                  </span>
                  <h2 className="mb-0 mt-2 text-xl">
                    {editor.mode === "create"
                      ? "Register response unit"
                      : "Edit response unit"}
                  </h2>
                  <p className="mb-0 mt-1.5 text-[9px] text-muted">
                    {editor.mode === "create"
                      ? "Add a deployable unit to the Pantukan MDRRMO roster."
                      : "Update roster identity and contact information."}
                  </p>
                </div>
                <button
                  aria-label="Close response-unit editor"
                  className="grid size-9 place-items-center rounded-[7px] border border-border bg-white text-lg text-maroon"
                  disabled={savingUnit}
                  onClick={closeEditor}
                  type="button"
                >
                  ×
                </button>
              </div>

              <div className="grid gap-4 px-6 py-5 max-[650px]:px-5">
                <label className="grid gap-1.5 text-[9px] font-semibold text-[#3c3335]">
                  Unit name
                  <input
                    autoFocus
                    className={editorInputClasses}
                    maxLength={150}
                    onChange={(event) =>
                      setEditorFields((current) => ({
                        ...current,
                        name: event.target.value,
                      }))
                    }
                    placeholder="Example: Rescue Alpha"
                    required
                    value={editorFields.name}
                  />
                </label>
                <label className="grid gap-1.5 text-[9px] font-semibold text-[#3c3335]">
                  Unit type
                  <input
                    className={editorInputClasses}
                    maxLength={80}
                    onChange={(event) =>
                      setEditorFields((current) => ({
                        ...current,
                        unitType: event.target.value,
                      }))
                    }
                    placeholder="Example: Search and rescue"
                    required
                    value={editorFields.unitType}
                  />
                </label>
                <label className="grid gap-1.5 text-[9px] font-semibold text-[#3c3335]">
                  Contact channel
                  <input
                    className={editorInputClasses}
                    maxLength={100}
                    onChange={(event) =>
                      setEditorFields((current) => ({
                        ...current,
                        contact: event.target.value,
                      }))
                    }
                    placeholder="Radio call sign or dispatch contact"
                    required
                    value={editorFields.contact}
                  />
                </label>

                <div className="border-l-2 border-maroon bg-[#fbf7f7] px-3 py-2.5 text-[9px] leading-5 text-muted">
                  {editor.mode === "create"
                    ? "New units start as available. Assignment and operational-status changes use the separate dispatch workflow."
                    : "Editing these details does not change the unit's operational status or current assignment."}
                </div>

                {editorError && (
                  <div
                    className="border border-[#efc7c4] bg-white px-3 py-2.5 text-[9px] text-priority-red"
                    role="alert"
                  >
                    {editorError}
                  </div>
                )}
              </div>

              <div className="flex justify-end gap-2 border-t border-border px-6 py-4 max-[650px]:grid max-[650px]:grid-cols-2 max-[650px]:px-5">
                <button
                  className="button min-h-10 rounded-[7px] border border-[#d9d3d1] bg-white px-4 text-[11px] font-semibold text-[#352b2d] disabled:opacity-45"
                  disabled={savingUnit}
                  onClick={closeEditor}
                  type="button"
                >
                  Cancel
                </button>
                <Button disabled={savingUnit}>
                  {savingUnit
                    ? "Saving…"
                    : editor.mode === "create"
                      ? "Register unit"
                      : "Save changes"}
                </Button>
              </div>
            </form>
          </Card>
        </div>
      )}

      {selectedUnit && (
        <div
          aria-modal="true"
          className="fixed inset-0 z-[110] grid place-items-center bg-[#23090f7a] p-5 backdrop-blur"
          onMouseDown={closeUnit}
          role="dialog"
        >
          <Card className="max-h-[calc(100vh-40px)] w-[min(620px,100%)] overflow-y-auto p-7 max-[650px]:p-5">
            <div onMouseDown={(event) => event.stopPropagation()}>
              <div className="flex items-start gap-4">
                <span className="grid size-14 shrink-0 place-items-center rounded-[12px] bg-[#f3efed] text-maroon">
                  <Icon name="users" size={25} />
                </span>
                <div className="min-w-0 flex-1">
                  <span className="text-[9px] font-bold tracking-[.04em] text-muted">
                    {unitReference(selectedUnit.unit_id)}
                  </span>
                  <h2 className="my-1.5 truncate text-xl">{selectedUnit.name}</h2>
                  <Badge tone={statusMeta[selectedUnit.status].tone}>
                    {statusMeta[selectedUnit.status].label}
                  </Badge>
                </div>
                <button
                  aria-label="Close unit details"
                  className="mt-2 grid size-10 shrink-0 place-items-center rounded-xl border-0 bg-soft-gray text-xl text-maroon"
                  disabled={transitioning !== null}
                  onClick={closeUnit}
                >
                  ×
                </button>
              </div>
              <div className="my-6 h-px w-full bg-border" />
              <div className="grid grid-cols-2 gap-5 px-1 py-1 max-[650px]:grid-cols-1">
                {[
                  ["Unit type", selectedUnit.unit_type],
                  ["Contact", selectedUnit.contact],
                  ["Operational state", statusMeta[selectedUnit.status].detail],
                  ["Last location", locationLabel(selectedUnit)],
                  [
                    "Location updated",
                    formatTimestamp(selectedUnit.location_updated_at),
                  ],
                  ["Roster updated", formatTimestamp(selectedUnit.updated_at)],
                ].map(([label, value]) => (
                  <div className="flex flex-col gap-1.5" key={label}>
                    <span className="text-[9px] font-bold tracking-[.04em] text-muted">
                      {label.toUpperCase()}
                    </span>
                    <b className="break-words text-[13px] leading-[1.5]">{value}</b>
                  </div>
                ))}
              </div>
              {(selectedAssignment || activeAssignments.status !== "ready") && (
                <div className="mt-6 border-t border-border pt-5">
                  <span className="text-[8px] font-bold tracking-[.12em] text-maroon">
                    ACTIVE INCIDENT ASSIGNMENT
                  </span>
                  {activeAssignments.status === "loading" ? (
                    <p className="mb-0 mt-3 text-[9px] text-muted">
                      Loading assignment details…
                    </p>
                  ) : activeAssignments.status === "error" ? (
                    <div className="mt-3 grid gap-2 border border-[#efc7c4] bg-red-soft p-3 text-[9px] text-priority-red">
                      <span>{activeAssignments.error}</span>
                      <Button
                        variant="secondary"
                        onClick={activeAssignments.refetch}
                      >
                        Reload assignments
                      </Button>
                    </div>
                  ) : selectedAssignment ? (
                    <div className="mt-3 grid gap-4 rounded-[12px] bg-soft-gray p-4">
                      <div className="flex items-start justify-between gap-3">
                        <div>
                          <b className="block text-[11px]">
                            INC-{selectedAssignment.incident_id.slice(0, 8).toUpperCase()}
                          </b>
                          <span className="mt-1 block text-[9px] text-muted">
                            Assigned {formatTimestamp(selectedAssignment.assigned_at)}
                          </span>
                        </div>
                        <Badge tone={assignmentStatusMeta[selectedAssignment.status].tone}>
                          {assignmentStatusMeta[selectedAssignment.status].label}
                        </Badge>
                      </div>

                      {assignmentError && (
                        <div
                          className="border border-[#efc7c4] bg-white px-3 py-2.5 text-[9px] text-priority-red"
                          role="alert"
                        >
                          {assignmentError}
                        </div>
                      )}

                      <div className="flex flex-wrap gap-2">
                        {selectedAssignment.status === "assigned" && (
                          <Button
                            disabled={transitioning !== null}
                            onClick={() =>
                              void transitionAssignment(
                                selectedAssignment,
                                "acknowledged",
                              )
                            }
                          >
                            {transitioning === "acknowledged"
                              ? "Saving…"
                              : "Record acknowledgment"}
                          </Button>
                        )}
                        {selectedAssignment.status === "acknowledged" && (
                          <Button
                            disabled={transitioning !== null}
                            onClick={() =>
                              void transitionAssignment(
                                selectedAssignment,
                                "responding",
                              )
                            }
                          >
                            {transitioning === "responding"
                              ? "Saving…"
                              : "Mark responding"}
                          </Button>
                        )}
                        {selectedAssignment.status === "responding" && (
                          <Button
                            disabled={transitioning !== null}
                            onClick={() =>
                              void transitionAssignment(
                                selectedAssignment,
                                "completed",
                              )
                            }
                          >
                            {transitioning === "completed"
                              ? "Saving…"
                              : "Complete response"}
                          </Button>
                        )}
                        {!confirmCancellation ? (
                          <Button
                            variant="secondary"
                            disabled={transitioning !== null}
                            onClick={() => setConfirmCancellation(true)}
                          >
                            Cancel assignment
                          </Button>
                        ) : (
                          <div className="flex flex-wrap items-center gap-2 rounded-[9px] border border-[#efc7c4] bg-white p-2">
                            <span className="text-[9px] text-priority-red">
                              Release this unit from the incident?
                            </span>
                            <Button
                              disabled={transitioning !== null}
                              onClick={() =>
                                void transitionAssignment(
                                  selectedAssignment,
                                  "cancelled",
                                )
                              }
                            >
                              {transitioning === "cancelled"
                                ? "Cancelling…"
                                : "Confirm cancellation"}
                            </Button>
                            <Button
                              variant="secondary"
                              disabled={transitioning !== null}
                              onClick={() => setConfirmCancellation(false)}
                            >
                              Keep assignment
                            </Button>
                          </div>
                        )}
                      </div>
                      <p className="m-0 text-[8px] leading-4 text-muted">
                        Record updates received by radio or phone. Responders do not
                        access this dashboard.
                      </p>
                    </div>
                  ) : null}
                </div>
              )}
              <div className="mt-7 flex justify-end gap-2 border-t border-border pt-5 max-[650px]:grid max-[650px]:grid-cols-1 max-[650px]:[&_.button]:w-full">
                {canManageRoster && (
                  <Button
                    variant="secondary"
                    onClick={() => openEditEditor(selectedUnit)}
                  >
                    Edit unit
                  </Button>
                )}
                <Button
                  variant="secondary"
                  disabled={transitioning !== null}
                  onClick={closeUnit}
                >
                  Close
                </Button>
              </div>
            </div>
          </Card>
        </div>
      )}
    </>
  );
}
