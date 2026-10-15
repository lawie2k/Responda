const defaultApiBaseUrl = "http://127.0.0.1:8000";

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
