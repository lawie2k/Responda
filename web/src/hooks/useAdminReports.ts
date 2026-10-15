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

export function useAdminReports(query: AdminReportsQuery = {}) {
  const queryKey = JSON.stringify(query);
  const [requestVersion, setRequestVersion] = useState(0);
  const [state, setState] = useState<ReportListState>({
    status: "loading",
    data: null,
    error: null,
  });

  useEffect(() => {
    const controller = new AbortController();
    const stableQuery = JSON.parse(queryKey) as AdminReportsQuery;
    getAdminReports(stableQuery, controller.signal)
      .then((data) => setState({ status: "ready", data, error: null }))
      .catch((error: unknown) => {
        if (error instanceof DOMException && error.name === "AbortError") return;
        setState((current) => ({
          status: "error",
          data: current.data,
          error:
            error instanceof Error
              ? error.message
              : "The report queue could not be loaded.",
        }));
      });
    return () => controller.abort();
  }, [queryKey, requestVersion]);

  const refetch = useCallback(() => setRequestVersion((value) => value + 1), []);
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
