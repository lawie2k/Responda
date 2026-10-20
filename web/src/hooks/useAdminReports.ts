import { useCallback, useEffect, useState } from "react";
import {
  getAdminReport,
  getAdminReports,
  type AdminReportDetail,
  type AdminReportList,
  type AdminReportsQuery,
} from "../api/respondaApi";

type ReportListState =
  | { status: "loading"; data: AdminReportList | null; error: null }
  | { status: "ready"; data: AdminReportList; error: null }
  | { status: "error"; data: AdminReportList | null; error: string };

export function useAdminReports(
  query: AdminReportsQuery = {},
  refreshIntervalMs = 0,
) {
  const queryKey = JSON.stringify(query);
  const [requestVersion, setRequestVersion] = useState(0);
  const [state, setState] = useState<ReportListState & { queryKey: string }>({
    queryKey,
    status: "loading",
    data: null,
    error: null,
  });

  useEffect(() => {
    const stableQuery = JSON.parse(queryKey) as AdminReportsQuery;
    let controller: AbortController | null = null;
    let timer: number | undefined;
    let disposed = false;

    const load = async () => {
      if (
        disposed ||
        controller ||
        (refreshIntervalMs > 0 && document.visibilityState === "hidden")
      ) {
        return;
      }
      window.clearTimeout(timer);
      const request = new AbortController();
      controller = request;
      try {
        const data = await getAdminReports(stableQuery, request.signal);
        if (!disposed && !request.signal.aborted) {
          setState({ queryKey, status: "ready", data, error: null });
        }
      } catch (error: unknown) {
        if (!disposed && !request.signal.aborted) {
          setState((current) => ({
            queryKey,
            status: "error",
            data: current.queryKey === queryKey ? current.data : null,
            error:
              error instanceof Error
                ? error.message
                : "The report queue could not be loaded.",
          }));
        }
      } finally {
        controller = null;
        if (
          !disposed &&
          refreshIntervalMs > 0 &&
          document.visibilityState !== "hidden"
        ) {
          timer = window.setTimeout(() => void load(), refreshIntervalMs);
        }
      }
    };
    const refreshWhenVisible = () => {
      window.clearTimeout(timer);
      if (document.visibilityState !== "hidden") void load();
    };

    void load();
    if (refreshIntervalMs > 0) {
      document.addEventListener("visibilitychange", refreshWhenVisible);
      window.addEventListener("focus", refreshWhenVisible);
      window.addEventListener("online", refreshWhenVisible);
    }
    return () => {
      disposed = true;
      window.clearTimeout(timer);
      controller?.abort();
      document.removeEventListener("visibilitychange", refreshWhenVisible);
      window.removeEventListener("focus", refreshWhenVisible);
      window.removeEventListener("online", refreshWhenVisible);
    };
  }, [queryKey, requestVersion, refreshIntervalMs]);

  const refetch = useCallback(() => setRequestVersion((value) => value + 1), []);
  if (state.queryKey !== queryKey) {
    return { status: "loading", data: null, error: null, refetch } as const;
  }
  return { ...state, refetch };
}

type LoadedReportDetailState =
  | { reportId: string; status: "ready"; data: AdminReportDetail; error: null }
  | { reportId: string; status: "error"; data: null; error: string };

export function useAdminReportDetail(reportId: string | null) {
  const [requestVersion, setRequestVersion] = useState(0);
  const [state, setState] = useState<LoadedReportDetailState | null>(null);

  useEffect(() => {
    if (!reportId) return;
    const controller = new AbortController();
    getAdminReport(reportId, controller.signal)
      .then((data) =>
        setState({ reportId, status: "ready", data, error: null }),
      )
      .catch((error: unknown) => {
        if (error instanceof DOMException && error.name === "AbortError") return;
        setState({
          reportId,
          status: "error",
          data: null,
          error:
            error instanceof Error
              ? error.message
              : "The report details could not be loaded.",
        });
      });
    return () => controller.abort();
  }, [reportId, requestVersion]);

  const refetch = useCallback(() => setRequestVersion((value) => value + 1), []);

  if (!reportId) {
    return { status: "idle", data: null, error: null, refetch } as const;
  }
  if (state?.reportId !== reportId) {
    return { status: "loading", data: null, error: null, refetch } as const;
  }
  return { ...state, refetch };
}
