import { useCallback, useEffect, useState } from "react";
import {
  getBackendHealth,
  type BackendHealth,
} from "../api/respondaApi";

export type BackendConnection =
  | { status: "checking"; health: null }
  | { status: "connected"; health: BackendHealth }
  | { status: "unavailable"; health: null };

export function useBackendHealth() {
  const [connection, setConnection] = useState<BackendConnection>({
    status: "checking",
    health: null,
  });

  const refresh = useCallback(async () => {
    setConnection({ status: "checking", health: null });
    try {
      const health = await getBackendHealth();
      setConnection(toConnection(health));
    } catch {
      setConnection({ status: "unavailable", health: null });
    }
  }, []);

  useEffect(() => {
    const controller = new AbortController();
    getBackendHealth(controller.signal)
      .then((health) => setConnection(toConnection(health)))
      .catch((error: unknown) => {
        const requestWasAborted =
          error instanceof DOMException && error.name === "AbortError";
        if (!requestWasAborted) {
          setConnection({ status: "unavailable", health: null });
        }
      });
    return () => controller.abort();
  }, []);

  return {
    connection,
    refresh,
  };
}

function toConnection(health: BackendHealth): BackendConnection {
  return health.status === "ok" && health.database === "ok"
    ? { status: "connected", health }
    : { status: "unavailable", health: null };
}
