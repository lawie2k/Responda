import { apiBaseUrl, toApiError, RespondaApiError } from "./respondaApi";

export type Staff = {
  user_id: string; full_name: string; email: string | null;
  role: "admin" | "operations_admin"; is_active: boolean; created_at: string; updated_at: string;
};
export type StaffList = { items: Staff[]; total: number; page: number; page_size: number; total_pages: number };
export type StaffQuery = { page: number; search: string; active: string };
export type StaffPolicy = {
  password_min_length: number; password_max_length: number; session_ttl_seconds: number;
  max_sessions_per_user: number; login_attempts: number; login_window_seconds: number;
  secure_cookies: boolean; timezone: string;
};
const object = (v: unknown): v is Record<string, unknown> => typeof v === "object" && v !== null;
const count = (v: unknown) => typeof v === "number" && Number.isSafeInteger(v) && v >= 0;
function isStaff(v: unknown): v is Staff {
  return object(v) && typeof v.user_id === "string" && typeof v.full_name === "string" &&
    (v.email === null || typeof v.email === "string") && ["admin", "operations_admin"].includes(String(v.role)) &&
    typeof v.is_active === "boolean" && typeof v.created_at === "string" &&
    typeof v.updated_at === "string" && Number.isFinite(Date.parse(v.updated_at));
}
async function request(path: string, signal?: AbortSignal, method = "GET", body?: unknown) {
  const response = await fetch(`${apiBaseUrl}/api/v1/admin/staff${path}`, {
    method, credentials: "include", cache: "no-store", signal,
    headers: { Accept: "application/json", ...(body ? { "Content-Type": "application/json" } : {}) },
    ...(body ? { body: JSON.stringify(body) } : {}),
  });
  if (!response.ok) throw await toApiError(response, "Staff account operation failed.");
  return response.json() as Promise<unknown>;
}
export async function getStaff(query: StaffQuery, signal: AbortSignal): Promise<StaffList> {
  const params = new URLSearchParams({ page: String(query.page), page_size: "10" });
  if (query.search.trim()) params.set("search", query.search.trim());
  if (query.active) params.set("active", query.active);
  const data = await request(`?${params}`, signal);
  if (!object(data) || !Array.isArray(data.items) || !data.items.every(isStaff) ||
    !["total", "page", "page_size", "total_pages"].every((key) => count(data[key]))) {
    throw new RespondaApiError("Invalid staff-list response.");
  }
  return data as StaffList;
}
export async function getStaffPolicy(signal: AbortSignal): Promise<StaffPolicy> {
  const data = await request("/policy", signal);
  if (!object(data) || typeof data.secure_cookies !== "boolean" || data.timezone !== "Asia/Manila" ||
    !["password_min_length", "password_max_length", "session_ttl_seconds", "max_sessions_per_user", "login_attempts", "login_window_seconds"]
      .every((key) => count(data[key]))) throw new RespondaApiError("Invalid staff-policy response.");
  return data as StaffPolicy;
}
export async function saveStaff(id: string | null, values: {
  full_name: string; email: string; password?: string; is_active?: boolean; expected_updated_at?: string;
}, signal: AbortSignal): Promise<Staff> {
  const data = await request(id ? `/${encodeURIComponent(id)}` : "", signal, id ? "PATCH" : "POST", values);
  if (!isStaff(data)) throw new RespondaApiError("Invalid staff-account response.");
  return data;
}
export async function revokeStaffSessions(user: Staff, signal: AbortSignal): Promise<Staff> {
  const data = await request(`/${encodeURIComponent(user.user_id)}/revoke-sessions`, signal, "POST", {
    expected_updated_at: user.updated_at,
  });
  if (!isStaff(data)) throw new RespondaApiError("Invalid staff-account response.");
  return data;
}
