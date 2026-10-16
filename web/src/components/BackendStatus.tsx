import { apiBaseUrl } from "../api/respondaApi";
import { useBackendHealth } from "../hooks/useBackendHealth";

const statusStyle = {
  checking: "bg-soft-gray text-muted",
  connected: "bg-green-soft text-status-green",
  unavailable: "bg-red-soft text-priority-red",
};

const statusLabel = {
  checking: "Checking backend",
  connected: "Backend connected",
  unavailable: "Backend unavailable",
};

export function BackendStatus() {
  const { connection, refresh } = useBackendHealth();
  const version = connection.health?.api_version;

  return (
    <button
      type="button"
      aria-live="polite"
      className={`inline-flex h-9 shrink-0 items-center gap-2 rounded-[6px] border border-current/10 px-3 text-[9px] font-semibold transition-colors ${statusStyle[connection.status]} max-[850px]:size-9 max-[850px]:justify-center max-[850px]:px-0`}
      onClick={refresh}
      title={`${statusLabel[connection.status]} · ${apiBaseUrl}${version ? ` · API v${version}` : ""}`}
    >
      <span
        className={`size-2 rounded-full bg-current ${connection.status === "checking" ? "animate-pulse" : ""}`}
      />
      <span className="max-[850px]:hidden">{statusLabel[connection.status]}</span>
    </button>
  );
}
