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
