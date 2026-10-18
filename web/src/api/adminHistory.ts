import {
  apiBaseUrl,
  RespondaApiError,
  toApiError,
  type AdminIncidentType,
  type AssignmentStatus,
  type ReportPriority,
  type ReportSource,
  type ReportVerificationStatus,
} from "./respondaApi";

export type HistoryFilters = {
  search?: string;
  status?: "resolved" | "closed" | "";
  priority?: ReportPriority | "";
  incidentTypeId?: string;
  dateFrom?: string;
  dateTo?: string;
  sort?: "newest" | "oldest";
};

export type HistoryPage<T> = {
  items: T[];
  total: number;
  page: number;
  page_size: number;
  total_pages: number;
};

export type HistoricalIncident = {
  incident_id: string;
  reference: string;
  incident_type_id: string;
  incident_type_name: string;
  summary: string;
  priority: ReportPriority;
  status: "resolved" | "closed";
  location: string | null;
  report_count: number;
  team_count: number;
  first_team: string | null;
  completed_assignments: number;
  opened_at: string;
  resolved_at: string | null;
  closed_at: string | null;
  recorded_at: string;
};

export type HistoryList = HistoryPage<HistoricalIncident> & {
  counts: { resolved: number; closed: number };
};

export type HistoricalReport = {
  report_id: string;
  reference: string;
  description: string;
  source: ReportSource;
  verification_status: ReportVerificationStatus;
  location: string | null;
  received_at: string;
};

export type HistoricalAssignment = {
  assignment_id: string;
  unit_name: string;
  unit_type: string;
  status: AssignmentStatus;
  assigned_at: string;
  acknowledged_at: string | null;
  responding_at: string | null;
  completed_at: string | null;
  cancelled_at: string | null;
};

export type HistoricalEvent = {
  event_id: string;
  report_reference: string;
  event_type: string;
  created_at: string;
};

export type HistoryDetail = {
  incident: HistoricalIncident;
  reports: HistoryPage<HistoricalReport>;
  assignments: HistoryPage<HistoricalAssignment>;
  events: HistoryPage<HistoricalEvent>;
};

export type HistoryDetailQuery = {
  reportPage?: number;
  assignmentPage?: number;
  eventPage?: number;
};

function historyParameters(filters: HistoryFilters) {
  const parameters = new URLSearchParams();
  if (filters.search?.trim()) parameters.set("search", filters.search.trim());
  if (filters.status) parameters.set("status", filters.status);
  if (filters.priority) parameters.set("priority", filters.priority);
  if (filters.incidentTypeId) parameters.set("incident_type_id", filters.incidentTypeId);
  if (filters.dateFrom) parameters.set("date_from", filters.dateFrom);
  if (filters.dateTo) parameters.set("date_to", filters.dateTo);
  if (filters.sort) parameters.set("sort", filters.sort);
  return parameters;
}

async function historyFetch(path: string, signal?: AbortSignal) {
  const response = await fetch(`${apiBaseUrl}/api/v1/admin/history${path}`, {
    credentials: "include",
    cache: "no-store",
    headers: { Accept: path.startsWith("/export") ? "text/csv" : "application/json" },
    signal,
  });
  if (!response.ok) {
    throw await toApiError(response, "Historical records could not be loaded.");
  }
  return response;
}

export async function getHistory(
  filters: HistoryFilters & { page?: number },
  signal?: AbortSignal,
): Promise<HistoryList> {
  const parameters = historyParameters(filters);
  parameters.set("page", String(filters.page ?? 1));
  parameters.set("page_size", "10");
  const response = await historyFetch(`?${parameters}`, signal);
  const data: unknown = await response.json();
  if (!isPage(data, isIncident) || !isObject(data.counts) ||
      !isCount(data.counts.resolved) || !isCount(data.counts.closed)) {
    throw new RespondaApiError("The backend returned an invalid historical record list.");
  }
  return data as HistoryList;
}

export async function getHistoryDetail(
  id: string,
  query: HistoryDetailQuery,
  signal?: AbortSignal,
): Promise<HistoryDetail> {
  const parameters = new URLSearchParams({
    report_page: String(query.reportPage ?? 1),
    assignment_page: String(query.assignmentPage ?? 1),
    event_page: String(query.eventPage ?? 1),
    page_size: "10",
  });
  const response = await historyFetch(`/${encodeURIComponent(id)}?${parameters}`, signal);
  const data: unknown = await response.json();
  if (!isObject(data) || !isIncident(data.incident) ||
      !isPage(data.reports, isReport) || !isPage(data.assignments, isAssignment) ||
      !isPage(data.events, isEvent)) {
    throw new RespondaApiError("The backend returned invalid historical incident details.");
  }
  return data as HistoryDetail;
}

export async function getHistoryTypes(signal?: AbortSignal): Promise<AdminIncidentType[]> {
  const response = await historyFetch("/incident-types", signal);
  const data: unknown = await response.json();
  if (!isObject(data) || !Array.isArray(data.items) || !data.items.every((item) =>
    isObject(item) && typeof item.incident_type_id === "string" &&
    typeof item.code === "string" && typeof item.name === "string")) {
    throw new RespondaApiError("The historical incident types could not be loaded.");
  }
  return data.items as AdminIncidentType[];
}

export async function exportHistory(filters: HistoryFilters, signal?: AbortSignal): Promise<Blob> {
  const response = await historyFetch(`/export?${historyParameters(filters)}`, signal);
  if (!response.headers.get("content-type")?.startsWith("text/csv")) {
    throw new RespondaApiError("The backend returned an invalid CSV export.");
  }
  return response.blob();
}

function isObject(value: unknown): value is Record<string, unknown> {
  return typeof value === "object" && value !== null;
}
const isCount = (value: unknown): value is number =>
  typeof value === "number" && Number.isInteger(value) && value >= 0;
const isDate = (value: unknown): value is string =>
  typeof value === "string" && Number.isFinite(Date.parse(value));
const isNullableDate = (value: unknown) => value === null || isDate(value);
const isNullableString = (value: unknown) => value === null || typeof value === "string";

function isPage<T>(value: unknown, guard: (item: unknown) => item is T):
  value is HistoryPage<T> & Record<string, unknown> {
  return isObject(value) && Array.isArray(value.items) && value.items.every(guard) &&
    isCount(value.total) && isCount(value.total_pages) &&
    isCount(value.page) && value.page >= 1 &&
    isCount(value.page_size) && value.page_size >= 1 && value.page_size <= 100;
}

function isIncident(value: unknown): value is HistoricalIncident {
  return isObject(value) &&
    [value.incident_id, value.reference, value.incident_type_id, value.incident_type_name,
      value.summary].every((item) => typeof item === "string") &&
    ["critical", "high", "medium", "low"].includes(String(value.priority)) &&
    ["resolved", "closed"].includes(String(value.status)) &&
    isNullableString(value.location) && isNullableString(value.first_team) &&
    isCount(value.report_count) && isCount(value.team_count) && isCount(value.completed_assignments) &&
    isDate(value.opened_at) && isDate(value.recorded_at) &&
    isNullableDate(value.resolved_at) && isNullableDate(value.closed_at);
}

function isReport(value: unknown): value is HistoricalReport {
  return isObject(value) && typeof value.report_id === "string" &&
    typeof value.reference === "string" && typeof value.description === "string" &&
    ["app_api", "app_sms", "manual"].includes(String(value.source)) &&
    ["pending", "verified", "unverified", "invalid"].includes(String(value.verification_status)) &&
    isNullableString(value.location) && isDate(value.received_at);
}

function isAssignment(value: unknown): value is HistoricalAssignment {
  return isObject(value) && typeof value.assignment_id === "string" &&
    typeof value.unit_name === "string" && typeof value.unit_type === "string" &&
    ["assigned", "acknowledged", "responding", "completed", "cancelled"].includes(String(value.status)) &&
    isDate(value.assigned_at) && isNullableDate(value.acknowledged_at) &&
    isNullableDate(value.responding_at) && isNullableDate(value.completed_at) &&
    isNullableDate(value.cancelled_at);
}

function isEvent(value: unknown): value is HistoricalEvent {
  return isObject(value) && typeof value.event_id === "string" &&
    typeof value.report_reference === "string" && typeof value.event_type === "string" &&
    isDate(value.created_at);
}
