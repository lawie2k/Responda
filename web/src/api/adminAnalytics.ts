import { apiBaseUrl, RespondaApiError, toApiError, type AdminIncidentType } from "./respondaApi";

export type AnalyticsFilters = { dateFrom: string; dateTo: string; incidentTypeId?: string };
export type AnalyticsCount = { key: string; label: string; count: number };
export type AnalyticsData = {
  date_from: string; date_to: string; timezone: string; generated_at: string;
  summary: {
    reports: number; verified_reports: number; incidents: number;
    critical_incidents: number; completed_incidents: number;
    average_dispatch_minutes: number | null; dispatch_samples: number;
  };
  daily: { date: string; reports: number; verified_reports: number; incidents: number }[];
  incident_types: { incident_type_id: string; name: string; reports: number; incidents: number }[];
  sources: AnalyticsCount[]; priorities: AnalyticsCount[]; statuses: AnalyticsCount[];
};

function parameters(filters: AnalyticsFilters) {
  const query = new URLSearchParams({ date_from: filters.dateFrom, date_to: filters.dateTo });
  if (filters.incidentTypeId) query.set("incident_type_id", filters.incidentTypeId);
  return query;
}

async function analyticsFetch(path: string, signal?: AbortSignal) {
  const response = await fetch(`${apiBaseUrl}/api/v1/admin/analytics${path}`, {
    credentials: "include", cache: "no-store", signal,
    headers: { Accept: path.startsWith("/export") ? "text/csv" : "application/json" },
  });
  if (!response.ok) throw await toApiError(response, "Analytics could not be loaded.");
  return response;
}

const object = (value: unknown): value is Record<string, unknown> =>
  typeof value === "object" && value !== null;
const count = (value: unknown): value is number =>
  typeof value === "number" && Number.isSafeInteger(value) && value >= 0;
const date = (value: unknown): value is string =>
  typeof value === "string" && /^\d{4}-\d{2}-\d{2}$/.test(value) && Number.isFinite(Date.parse(value));
const counts = (value: unknown) => Array.isArray(value) && value.every((row: unknown) =>
  object(row) && typeof row.key === "string" && typeof row.label === "string" && count(row.count));

export async function getAnalytics(filters: AnalyticsFilters, signal: AbortSignal): Promise<AnalyticsData> {
  const response = await analyticsFetch(`?${parameters(filters)}`, signal);
  const data: unknown = await response.json();
  if (!object(data) || !date(data.date_from) || !date(data.date_to) ||
      data.timezone !== "Asia/Manila" || typeof data.generated_at !== "string" ||
      !Number.isFinite(Date.parse(data.generated_at)) || !object(data.summary) ||
      !["reports", "verified_reports", "incidents", "critical_incidents", "completed_incidents", "dispatch_samples"]
        .every((key) => count((data.summary as Record<string, unknown>)[key])) ||
      !(data.summary.average_dispatch_minutes === null ||
        (typeof data.summary.average_dispatch_minutes === "number" &&
         Number.isFinite(data.summary.average_dispatch_minutes) && data.summary.average_dispatch_minutes >= 0)) ||
      !Array.isArray(data.daily) || !data.daily.every((row: unknown) => object(row) && date(row.date) &&
        count(row.reports) && count(row.verified_reports) && count(row.incidents)) ||
      !Array.isArray(data.incident_types) || !data.incident_types.every((row: unknown) => object(row) &&
        typeof row.incident_type_id === "string" && typeof row.name === "string" &&
        count(row.reports) && count(row.incidents)) ||
      !counts(data.sources) || !counts(data.priorities) || !counts(data.statuses)) {
    throw new RespondaApiError("The analytics response was invalid.", 502);
  }
  return data as AnalyticsData;
}

export async function getAnalyticsTypes(signal: AbortSignal): Promise<AdminIncidentType[]> {
  const response = await analyticsFetch("/incident-types", signal);
  const data: unknown = await response.json();
  if (!object(data) || !Array.isArray(data.items) || !data.items.every((row: unknown) =>
    object(row) && typeof row.incident_type_id === "string" &&
    typeof row.name === "string" && typeof row.code === "string")) {
    throw new RespondaApiError("The incident types response was invalid.", 502);
  }
  return data.items as AdminIncidentType[];
}

export async function exportAnalytics(filters: AnalyticsFilters, signal: AbortSignal) {
  const response = await analyticsFetch(`/export?${parameters(filters)}`, signal);
  return response.blob();
}
