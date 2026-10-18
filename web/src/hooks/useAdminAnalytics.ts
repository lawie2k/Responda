import { useCallback, useEffect, useState } from "react";
import { getAnalytics, type AnalyticsData, type AnalyticsFilters } from "../api/adminAnalytics";

export function useAdminAnalytics(filters: AnalyticsFilters) {
  const [version, setVersion] = useState(0);
  const queryKey = JSON.stringify(filters);
  const requestKey = `${queryKey}:${version}`;
  const [state, setState] = useState<{
    key: string; data: AnalyticsData | null; error: string | null;
  } | null>(null);
  useEffect(() => {
    const controller = new AbortController();
    getAnalytics(JSON.parse(queryKey), controller.signal)
      .then((data) => {
        if (!controller.signal.aborted) setState({ key: requestKey, data, error: null });
      })
      .catch((error: unknown) => {
        if (!controller.signal.aborted) setState({
          key: requestKey, data: null,
          error: error instanceof Error ? error.message : "Analytics could not be loaded.",
        });
      });
    return () => controller.abort();
  }, [queryKey, requestKey]);
  const refetch = useCallback(() => setVersion((value) => value + 1), []);
  if (state?.key !== requestKey) return { status: "loading", data: null, error: null, refetch } as const;
  if (!state.data) return { status: "error", data: null, error: state.error, refetch } as const;
  return { status: "ready", data: state.data, error: null, refetch } as const;
}
