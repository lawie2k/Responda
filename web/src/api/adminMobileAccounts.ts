import { apiBaseUrl, RespondaApiError, toApiError } from "./respondaApi";

export type MobileAccount = {
  user_id: string;
  full_name: string;
  masked_phone: string;
  barangay: string | null;
  is_active: boolean;
  created_at: string;
  updated_at: string;
  phone_verified_at: string;
  privacy_notice_accepted_at: string;
  last_sign_in_at: string | null;
  reports_submitted: number;
};
export type MobileAccountQuery = { page: number; search: string; active: string };
export type MobileAccountList = {
  items: MobileAccount[];
  total: number; page: number; page_size: number; total_pages: number;
  counts: { total: number; active: number; suspended: number };
};
export type AccountReason = "suspected_misuse" | "account_security" | "review_completed";
const object = (value: unknown): value is Record<string, unknown> => typeof value === "object" && value !== null;
const count = (value: unknown) => typeof value === "number" && Number.isSafeInteger(value) && value >= 0;
const date = (value: unknown) => typeof value === "string" && Number.isFinite(Date.parse(value));

function isAccount(value: unknown): value is MobileAccount {
  return object(value) && typeof value.user_id === "string" && typeof value.full_name === "string" &&
    typeof value.masked_phone === "string" && (value.barangay === null || typeof value.barangay === "string") &&
    typeof value.is_active === "boolean" && count(value.reports_submitted) &&
    ["created_at", "updated_at", "phone_verified_at", "privacy_notice_accepted_at"].every(key => date(value[key])) &&
    (value.last_sign_in_at === null || date(value.last_sign_in_at));
}
async function request(path: string, signal: AbortSignal, method = "GET", body?: object): Promise<unknown> {
  const response = await fetch(`${apiBaseUrl}/api/v1/admin/mobile-accounts${path}`, {
    method, credentials: "include", cache: "no-store", signal,
    headers: { Accept: "application/json", ...(body ? { "Content-Type": "application/json" } : {}) },
    ...(body ? { body: JSON.stringify(body) } : {}),
  });
  if (!response.ok) throw await toApiError(response, "Mobile account operation failed.");
  return response.json();
}
export async function getMobileAccounts(query: MobileAccountQuery, signal: AbortSignal): Promise<MobileAccountList> {
  const params = new URLSearchParams({ page: String(query.page), page_size: "10" });
  if (query.search.trim()) params.set("search", query.search.trim());
  if (query.active) params.set("active", query.active);
  const data = await request(`?${params}`, signal);
  if (!object(data) || !Array.isArray(data.items) || !data.items.every(isAccount) ||
    !["total", "page", "page_size", "total_pages"].every(key => count(data[key])) ||
    !object(data.counts) || !["total", "active", "suspended"].every(key => count((data.counts as Record<string, unknown>)[key]))) {
    throw new RespondaApiError("Invalid mobile account response.");
  }
  return data as MobileAccountList;
}
export async function changeMobileAccountStatus(account: MobileAccount, isActive: boolean,
  reason: AccountReason, signal: AbortSignal): Promise<MobileAccount> {
  const data = await request(`/${encodeURIComponent(account.user_id)}/status`, signal, "PATCH", {
    expected_updated_at: account.updated_at, is_active: isActive, reason,
  });
  if (!isAccount(data)) throw new RespondaApiError("Invalid mobile account response.");
  return data;
}
