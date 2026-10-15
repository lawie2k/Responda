import { useCallback, useEffect, useState } from "react";
import {
  getAdminIncidents,
  type AdminIncidentList,
  type AdminIncidentsQuery,
} from "../api/respondaApi";

type LoadedIncidentState =
  | {
      queryKey: string;
      status: "ready";
      data: AdminIncidentList;
      error: null;
    }
  | {
      queryKey: string;
      status: "error";
      data: null;
      error: string;
    };

export function useAdminIncidents(
  query: AdminIncidentsQuery = {},
  enabled = true,
) {
  const queryKey = JSON.stringify(query);
  const [requestVersion, setRequestVersion] = useState(0);
  const [state, setState] = useState<LoadedIncidentState | null>(null);

  useEffect(() => {
    if (!enabled) return;
    const controller = new AbortController();
    const stableQuery = JSON.parse(queryKey) as AdminIncidentsQuery;
    getAdminIncidents(stableQuery, controller.signal)
      .then((data) =>
        setState({ queryKey, status: "ready", data, error: null }),
      )
      .catch((error: unknown) => {
        if (error instanceof DOMException && error.name === "AbortError") return;
        setState({
          queryKey,
          status: "error",
          data: null,
          error:
            error instanceof Error
              ? error.message
              : "The incident list could not be loaded.",
        });
      });
    return () => controller.abort();
  }, [enabled, queryKey, requestVersion]);

  const refetch = useCallback(() => setRequestVersion((value) => value + 1), []);
  if (!enabled) {
    return { status: "idle", data: null, error: null, refetch } as const;
  }
  if (state?.queryKey !== queryKey) {
    return { status: "loading", data: null, error: null, refetch } as const;
  }
  return { ...state, refetch };
}
