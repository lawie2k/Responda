import { useCallback, useEffect, useState } from "react";
import {
  getAdminAssignments,
  getAdminIncidents,
  type AdminAssignmentList,
  type AdminAssignmentListItem,
} from "../api/respondaApi";

type AssignmentState =
  | {
      queryKey: string;
      status: "ready";
      data: AdminAssignmentList;
      error: null;
    }
  | {
      queryKey: string;
      status: "error";
      data: null;
      error: string;
    };

export function useAdminAssignments(
  incidentId: string | null,
  enabled = true,
) {
  const queryKey = incidentId ?? "";
  const [requestVersion, setRequestVersion] = useState(0);
  const [state, setState] = useState<AssignmentState | null>(null);

  useEffect(() => {
    if (!enabled || !incidentId) return;
    const controller = new AbortController();
    getAdminAssignments(incidentId, { pageSize: 100 }, controller.signal)
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
              : "The response assignments could not be loaded.",
        });
      });
    return () => controller.abort();
  }, [enabled, incidentId, queryKey, requestVersion]);

  const refetch = useCallback(() => setRequestVersion((value) => value + 1), []);
  if (!enabled || !incidentId) {
    return { status: "idle", data: null, error: null, refetch } as const;
  }
  if (state?.queryKey !== queryKey) {
    return { status: "loading", data: null, error: null, refetch } as const;
  }
  return { ...state, refetch };
}

type ActiveAssignmentState =
  | { status: "ready"; data: AdminAssignmentListItem[]; error: null }
  | { status: "error"; data: null; error: string };

export function useActiveAdminAssignments() {
  const [requestVersion, setRequestVersion] = useState(0);
  const [state, setState] = useState<ActiveAssignmentState | null>(null);

  useEffect(() => {
    const controller = new AbortController();
    const load = async () => {
      const incidents = await getAdminIncidents(
        {
          pageSize: 100,
          statuses: ["open", "dispatched", "responding"],
        },
        controller.signal,
      );
      const lists = await Promise.all(
        incidents.items.map((incident) =>
          getAdminAssignments(
            incident.incident_id,
            { pageSize: 100 },
            controller.signal,
          ),
        ),
      );
      if (controller.signal.aborted) return;
      setState({
        status: "ready",
        data: lists
          .flatMap((list) => list.items)
          .filter((assignment) =>
            ["assigned", "acknowledged", "responding"].includes(
              assignment.status,
            ),
          ),
        error: null,
      });
    };

    load().catch((error: unknown) => {
      if (error instanceof DOMException && error.name === "AbortError") return;
      setState({
        status: "error",
        data: null,
        error:
          error instanceof Error
            ? error.message
            : "Active assignments could not be loaded.",
      });
    });
    return () => controller.abort();
  }, [requestVersion]);

  const refetch = useCallback(() => setRequestVersion((value) => value + 1), []);
  if (!state) {
    return { status: "loading", data: null, error: null, refetch } as const;
  }
  return { ...state, refetch };
}
