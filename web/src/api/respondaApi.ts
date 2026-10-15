const defaultApiBaseUrl = `${window.location.protocol}//${window.location.hostname}:8000`;

export const apiBaseUrl = (
  import.meta.env.VITE_RESPONDA_API_BASE_URL || defaultApiBaseUrl
).replace(/\/+$/, "");

export type BackendHealth = {
  status: "ok" | "degraded";
  service: string;
  environment: string;
  api_version: string;
  database: "ok" | "unavailable";
};

export type AdminUser = {
  user_id: string;
  full_name: string;
  email: string;
  role: "admin" | "dispatcher" | "verifier" | "viewer";
};

export type AdminSession = {
  user: AdminUser;
  expires_at: string;
};

export type ReportPriority = "critical" | "high" | "medium" | "low";
export type ReportSource = "app_api" | "app_sms" | "manual";
export type ReportVerificationStatus =
  | "pending"
  | "verified"
  | "unverified"
  | "invalid";
export type ReportWorkflowStatus =
  | "new"
  | "under_review"
  | "linked"
  | "closed";
export type IncidentStatus =
  | "open"
  | "dispatched"
  | "responding"
  | "resolved"
  | "closed";

export type AdminReportListItem = {
  report_id: string;
  client_report_id: string | null;
  incident_type: {
    incident_type_id: string;
    code: string;
    name: string;
  };
  incident: {
    incident_id: string;
    priority: ReportPriority;
    status: IncidentStatus;
    summary: string;
  } | null;
  source: ReportSource;
  description_original: string;
  original_language: string | null;
  people_need_help: boolean;
  immediate_danger: boolean;
  suggested_priority: ReportPriority | null;
  final_priority: ReportPriority | null;
  effective_priority: ReportPriority;
  verification_status: ReportVerificationStatus;
  status: ReportWorkflowStatus;
  location: {
    latitude: number;
    longitude: number;
    accuracy_meters: number | null;
    landmark: string | null;
    source: "gps" | "manual";
    captured_at: string;
  } | null;
  received_at: string;
  updated_at: string;
  closed_at: string | null;
};

export type AdminReportList = {
  items: AdminReportListItem[];
  total: number;
  page: number;
  page_size: number;
  total_pages: number;
};

export type AdminReportDetail = AdminReportListItem & {
  reporter: {
    user_id: string;
    full_name: string;
    phone_number: string | null;
    email: string | null;
  };
  attachments: Array<{
    attachment_id: string;
    media_type: "image" | "video";
    content_type: string;
    size_bytes: number;
    created_at: string;
  }>;
  translations: Array<{
    translation_id: string;
    source_language: string;
    target_language: string;
    translated_text: string;
    model_name: string;
    model_version: string;
    confidence: number | null;
    created_at: string;
  }>;
  priority_assessments: Array<{
    assessment_id: string;
    suggested_priority: ReportPriority;
    confidence: number;
    model_name: string;
    model_version: string;
    explanation: string | null;
    created_at: string;
  }>;
  reviews: Array<{
    review_id: string;
    reviewed_by_staff_id: string;
    priority_conflict: boolean;
    location_accurate: boolean | null;
    possible_duplicate: boolean;
    callback_needed: boolean;
    decision: string;
    notes: string | null;
    reviewed_at: string;
  }>;
};

export type AdminReportsQuery = {
  page?: number;
  pageSize?: number;
  search?: string;
  reportStatuses?: ReportWorkflowStatus[];
  verificationStatuses?: ReportVerificationStatus[];
  priorities?: ReportPriority[];
  sources?: ReportSource[];
  incidentStatuses?: IncidentStatus[];
  incidentTypeId?: string;
  sort?: "newest" | "oldest";
};

export type AdminReportReviewPayload = {
  expected_updated_at: string;
  decision: "verified" | "unverified" | "invalid";
  final_priority?: ReportPriority;
  location_accurate?: boolean;
  possible_duplicate: boolean;
  callback_needed: boolean;
  notes: string;
};

export type AdminReportReviewResult = {
  report_id: string;
  decision: "verified" | "unverified" | "invalid";
  verification_status: ReportVerificationStatus;
  report_status: ReportWorkflowStatus;
  final_priority: ReportPriority | null;
  reviewed_at: string;
};

export type AdminIncidentListItem = {
  incident_id: string;
  incident_type_id: string;
  incident_type_name: string;
  summary: string;
  priority: ReportPriority;
  status: IncidentStatus;
  opened_at: string;
  updated_at: string;
};

export type AdminIncidentList = {
  items: AdminIncidentListItem[];
  total: number;
  page: number;
  page_size: number;
  total_pages: number;
};

export type AdminIncidentsQuery = {
  page?: number;
  pageSize?: number;
  search?: string;
  statuses?: IncidentStatus[];
  incidentTypeId?: string;
};

export type AdminIncidentLinkResult = {
  incident_id: string;
  linked_report_id: string;
  incident_type_id: string;
  priority: ReportPriority;
  incident_status: IncidentStatus;
  summary: string;
  report_status: ReportWorkflowStatus;
  operation: "created" | "linked";
  linked_at: string;
};

export class RespondaApiError extends Error {
  readonly status?: number;

  constructor(message: string, status?: number) {
    super(message);
    this.name = "RespondaApiError";
    this.status = status;
  }
}

export async function getBackendHealth(
  signal?: AbortSignal,
): Promise<BackendHealth> {
  const response = await fetch(`${apiBaseUrl}/api/v1/shared/health`, {
    method: "GET",
    headers: { Accept: "application/json" },
    cache: "no-store",
    signal,
  });

  if (!response.ok) {
    throw new RespondaApiError(
      "The Responda backend health check failed.",
      response.status,
    );
  }

  const payload: unknown = await response.json();
  if (!isBackendHealth(payload)) {
    throw new RespondaApiError(
      "The Responda backend returned an invalid health response.",
    );
  }
  return payload;
}

export async function loginAdmin(
  email: string,
  password: string,
): Promise<AdminSession> {
  const response = await fetch(`${apiBaseUrl}/api/v1/admin/auth/login`, {
    method: "POST",
    credentials: "include",
    cache: "no-store",
    headers: {
      Accept: "application/json",
      "Content-Type": "application/json",
    },
    body: JSON.stringify({ email, password }),
  });

  return parseAdminSessionResponse(response);
}

export async function getAdminSession(
  signal?: AbortSignal,
): Promise<AdminSession> {
  const response = await fetch(`${apiBaseUrl}/api/v1/admin/auth/me`, {
    method: "GET",
    credentials: "include",
    cache: "no-store",
    headers: { Accept: "application/json" },
    signal,
  });

  return parseAdminSessionResponse(response);
}

export async function logoutAdmin(): Promise<void> {
  const response = await fetch(`${apiBaseUrl}/api/v1/admin/auth/logout`, {
    method: "POST",
    credentials: "include",
    cache: "no-store",
    headers: { Accept: "application/json" },
  });

  if (!response.ok) {
    throw await toApiError(response, "The session could not be ended.");
  }
}

export async function getAdminReports(
  query: AdminReportsQuery = {},
  signal?: AbortSignal,
): Promise<AdminReportList> {
  const parameters = new URLSearchParams();
  if (query.page !== undefined) parameters.set("page", String(query.page));
  if (query.pageSize !== undefined) {
    parameters.set("page_size", String(query.pageSize));
  }
  if (query.search?.trim()) parameters.set("search", query.search.trim());
  query.reportStatuses?.forEach((value) =>
    parameters.append("report_status", value),
  );
  query.verificationStatuses?.forEach((value) =>
    parameters.append("verification_status", value),
  );
  query.priorities?.forEach((value) => parameters.append("priority", value));
  query.sources?.forEach((value) => parameters.append("source", value));
  query.incidentStatuses?.forEach((value) =>
    parameters.append("incident_status", value),
  );
  if (query.incidentTypeId) {
    parameters.set("incident_type_id", query.incidentTypeId);
  }
  if (query.sort) parameters.set("sort", query.sort);

  const queryString = parameters.toString();
  const response = await fetch(
    `${apiBaseUrl}/api/v1/admin/reports${queryString ? `?${queryString}` : ""}`,
    {
      method: "GET",
      credentials: "include",
      cache: "no-store",
      headers: { Accept: "application/json" },
      signal,
    },
  );

  if (!response.ok) {
    throw await toApiError(response, "The report queue could not be loaded.");
  }
  const payload: unknown = await response.json();
  if (!isAdminReportList(payload)) {
    throw new RespondaApiError(
      "The Responda backend returned an invalid report list.",
    );
  }
  return payload;
}

export async function getAdminReport(
  reportId: string,
  signal?: AbortSignal,
): Promise<AdminReportDetail> {
  const response = await fetch(
    `${apiBaseUrl}/api/v1/admin/reports/${encodeURIComponent(reportId)}`,
    {
      method: "GET",
      credentials: "include",
      cache: "no-store",
      headers: { Accept: "application/json" },
      signal,
    },
  );

  if (!response.ok) {
    throw await toApiError(response, "The report details could not be loaded.");
  }
  const payload: unknown = await response.json();
  if (!isAdminReportDetail(payload)) {
    throw new RespondaApiError(
      "The Responda backend returned invalid report details.",
    );
  }
  return payload;
}

export async function reviewAdminReport(
  reportId: string,
  payload: AdminReportReviewPayload,
): Promise<AdminReportReviewResult> {
  const response = await fetch(
    `${apiBaseUrl}/api/v1/admin/reports/${encodeURIComponent(reportId)}/reviews`,
    {
      method: "POST",
      credentials: "include",
      cache: "no-store",
      headers: {
        Accept: "application/json",
        "Content-Type": "application/json",
      },
      body: JSON.stringify(payload),
    },
  );

  if (!response.ok) {
    throw await toApiError(response, "The report review could not be saved.");
  }
  const result: unknown = await response.json();
  if (!isAdminReportReviewResult(result)) {
    throw new RespondaApiError(
      "The Responda backend returned an invalid review result.",
    );
  }
  return result;
}

export async function getAdminIncidents(
  query: AdminIncidentsQuery = {},
  signal?: AbortSignal,
): Promise<AdminIncidentList> {
  const parameters = new URLSearchParams();
  if (query.page !== undefined) parameters.set("page", String(query.page));
  if (query.pageSize !== undefined) {
    parameters.set("page_size", String(query.pageSize));
  }
  if (query.search?.trim()) parameters.set("search", query.search.trim());
  query.statuses?.forEach((value) =>
    parameters.append("incident_status", value),
  );
  if (query.incidentTypeId) {
    parameters.set("incident_type_id", query.incidentTypeId);
  }

  const queryString = parameters.toString();
  const response = await fetch(
    `${apiBaseUrl}/api/v1/admin/incidents${queryString ? `?${queryString}` : ""}`,
    {
      method: "GET",
      credentials: "include",
      cache: "no-store",
      headers: { Accept: "application/json" },
      signal,
    },
  );
  if (!response.ok) {
    throw await toApiError(response, "The incident list could not be loaded.");
  }
  const result: unknown = await response.json();
  if (!isAdminIncidentList(result)) {
    throw new RespondaApiError(
      "The Responda backend returned an invalid incident list.",
    );
  }
  return result;
}

export async function createAdminIncident(payload: {
  report_id: string;
  expected_report_updated_at: string;
  summary: string;
}): Promise<AdminIncidentLinkResult> {
  return submitIncidentOperation(
    `${apiBaseUrl}/api/v1/admin/incidents`,
    payload,
    "The incident could not be created.",
  );
}

export async function linkAdminReportToIncident(
  incidentId: string,
  payload: {
    report_id: string;
    expected_report_updated_at: string;
  },
): Promise<AdminIncidentLinkResult> {
  return submitIncidentOperation(
    `${apiBaseUrl}/api/v1/admin/incidents/${encodeURIComponent(incidentId)}/reports`,
    payload,
    "The report could not be linked to the incident.",
  );
}

async function submitIncidentOperation(
  url: string,
  payload: object,
  fallbackMessage: string,
): Promise<AdminIncidentLinkResult> {
  const response = await fetch(url, {
    method: "POST",
    credentials: "include",
    cache: "no-store",
    headers: {
      Accept: "application/json",
      "Content-Type": "application/json",
    },
    body: JSON.stringify(payload),
  });
  if (!response.ok) {
    throw await toApiError(response, fallbackMessage);
  }
  const result: unknown = await response.json();
  if (!isAdminIncidentLinkResult(result)) {
    throw new RespondaApiError(
      "The Responda backend returned an invalid incident result.",
    );
  }
  return result;
}

export async function clearSessionScopedCache(): Promise<void> {
  try {
    sessionStorage.clear();
  } catch {
    // Storage can be unavailable in hardened browser modes; auth must still continue.
  }

  if (!("caches" in window)) return;
  try {
    const cacheNames = await window.caches.keys();
    await Promise.all(
      cacheNames
        .filter((name) => name.startsWith("responda-"))
        .map((name) => window.caches.delete(name)),
    );
  } catch {
    // A cache cleanup failure must not strand a valid session on the login page.
  }
}

async function parseAdminSessionResponse(
  response: Response,
): Promise<AdminSession> {
  if (!response.ok) {
    throw await toApiError(response, "The staff session request failed.");
  }

  const payload: unknown = await response.json();
  if (!isAdminSession(payload)) {
    throw new RespondaApiError(
      "The Responda backend returned an invalid session response.",
    );
  }
  return payload;
}

async function toApiError(
  response: Response,
  fallbackMessage: string,
): Promise<RespondaApiError> {
  try {
    const payload: unknown = await response.json();
    if (typeof payload === "object" && payload !== null) {
      const error = (payload as Record<string, unknown>).error;
      if (typeof error === "object" && error !== null) {
        const message = (error as Record<string, unknown>).message;
        if (typeof message === "string") {
          return new RespondaApiError(message, response.status);
        }
      }
    }
  } catch {
    // Fall through to the stable client-side message.
  }
  return new RespondaApiError(fallbackMessage, response.status);
}

function isBackendHealth(value: unknown): value is BackendHealth {
  if (typeof value !== "object" || value === null) return false;

  const health = value as Record<string, unknown>;
  return (
    (health.status === "ok" || health.status === "degraded") &&
    typeof health.service === "string" &&
    typeof health.environment === "string" &&
    typeof health.api_version === "string" &&
    (health.database === "ok" || health.database === "unavailable")
  );
}

function isAdminSession(value: unknown): value is AdminSession {
  if (typeof value !== "object" || value === null) return false;
  const session = value as Record<string, unknown>;
  if (typeof session.expires_at !== "string") return false;
  if (typeof session.user !== "object" || session.user === null) return false;

  const user = session.user as Record<string, unknown>;
  return (
    typeof user.user_id === "string" &&
    typeof user.full_name === "string" &&
    typeof user.email === "string" &&
    (user.role === "admin" ||
      user.role === "dispatcher" ||
      user.role === "verifier" ||
      user.role === "viewer")
  );
}

function isAdminReportList(value: unknown): value is AdminReportList {
  if (typeof value !== "object" || value === null) return false;
  const list = value as Record<string, unknown>;
  return (
    Array.isArray(list.items) &&
    list.items.every(isAdminReportListItem) &&
    typeof list.total === "number" &&
    typeof list.page === "number" &&
    typeof list.page_size === "number" &&
    typeof list.total_pages === "number"
  );
}

function isAdminReportListItem(value: unknown): value is AdminReportListItem {
  if (typeof value !== "object" || value === null) return false;
  const report = value as Record<string, unknown>;
  const incidentType = report.incident_type;
  return (
    typeof report.report_id === "string" &&
    typeof report.description_original === "string" &&
    typeof report.received_at === "string" &&
    typeof report.effective_priority === "string" &&
    typeof report.verification_status === "string" &&
    typeof report.status === "string" &&
    typeof report.people_need_help === "boolean" &&
    typeof report.immediate_danger === "boolean" &&
    typeof incidentType === "object" &&
    incidentType !== null &&
    typeof (incidentType as Record<string, unknown>).incident_type_id ===
      "string" &&
    typeof (incidentType as Record<string, unknown>).name === "string"
  );
}

function isAdminReportDetail(value: unknown): value is AdminReportDetail {
  if (!isAdminReportListItem(value)) return false;
  const detail = value as unknown as Record<string, unknown>;
  const reporter = detail.reporter;
  return (
    typeof reporter === "object" &&
    reporter !== null &&
    typeof (reporter as Record<string, unknown>).full_name === "string" &&
    Array.isArray(detail.attachments) &&
    Array.isArray(detail.translations) &&
    Array.isArray(detail.priority_assessments) &&
    Array.isArray(detail.reviews)
  );
}

function isAdminReportReviewResult(
  value: unknown,
): value is AdminReportReviewResult {
  if (typeof value !== "object" || value === null) return false;
  const result = value as Record<string, unknown>;
  return (
    typeof result.report_id === "string" &&
    (result.decision === "verified" ||
      result.decision === "unverified" ||
      result.decision === "invalid") &&
    typeof result.verification_status === "string" &&
    typeof result.report_status === "string" &&
    typeof result.reviewed_at === "string"
  );
}

function isAdminIncidentList(value: unknown): value is AdminIncidentList {
  if (typeof value !== "object" || value === null) return false;
  const list = value as Record<string, unknown>;
  return (
    Array.isArray(list.items) &&
    list.items.every(isAdminIncidentListItem) &&
    typeof list.total === "number" &&
    typeof list.page === "number" &&
    typeof list.page_size === "number" &&
    typeof list.total_pages === "number"
  );
}

function isAdminIncidentListItem(
  value: unknown,
): value is AdminIncidentListItem {
  if (typeof value !== "object" || value === null) return false;
  const incident = value as Record<string, unknown>;
  return (
    typeof incident.incident_id === "string" &&
    typeof incident.incident_type_id === "string" &&
    typeof incident.incident_type_name === "string" &&
    typeof incident.summary === "string" &&
    typeof incident.priority === "string" &&
    typeof incident.status === "string" &&
    typeof incident.opened_at === "string" &&
    typeof incident.updated_at === "string"
  );
}

function isAdminIncidentLinkResult(
  value: unknown,
): value is AdminIncidentLinkResult {
  if (typeof value !== "object" || value === null) return false;
  const result = value as Record<string, unknown>;
  return (
    typeof result.incident_id === "string" &&
    typeof result.linked_report_id === "string" &&
    typeof result.incident_type_id === "string" &&
    typeof result.priority === "string" &&
    typeof result.incident_status === "string" &&
    typeof result.summary === "string" &&
    typeof result.report_status === "string" &&
    (result.operation === "created" || result.operation === "linked") &&
    typeof result.linked_at === "string"
  );
}
