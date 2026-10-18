import { useCallback, useEffect, useState } from "react";
import {
  getHistory,
  getHistoryDetail,
  type HistoryFilters,
  type HistoryDetailQuery,
} from "../api/adminHistory";

function useHistoryResource<T>(
  key: string | null,
  load: (key: string, signal: AbortSignal) => Promise<T>,
) {
  const [version, setVersion] = useState(0);
  const requestKey = `${key}:${version}`;
  const [state, setState] = useState<{
    key: string;
    data: T | null;
    error: string | null;
  } | null>(null);

  useEffect(() => {
    if (key === null) return;
    const controller = new AbortController();
    load(key, controller.signal)
      .then((data) => {
        if (!controller.signal.aborted) setState({ key: requestKey, data, error: null });
      })
      .catch((error: unknown) => {
        if (controller.signal.aborted) return;
        setState({
          key: requestKey,
          data: null,
          error: error instanceof Error ? error.message : "Historical records could not be loaded.",
        });
      });
    return () => controller.abort();
  }, [key, load, requestKey]);

  const refetch = useCallback(() => setVersion((value) => value + 1), []);
  if (key === null) return { status: "idle", data: null, error: null, refetch } as const;
  if (state?.key !== requestKey) {
    return { status: "loading", data: null, error: null, refetch } as const;
  }
  if (state.error || !state.data) {
    return { status: "error", data: null, error: state.error, refetch } as const;
  }
  return { status: "ready", data: state.data, error: null, refetch } as const;
}

const loadList = (key: string, signal: AbortSignal) =>
  getHistory(JSON.parse(key), signal);
const loadDetail = (key: string, signal: AbortSignal) => {
  const { id, query } = JSON.parse(key) as { id: string; query: HistoryDetailQuery };
  return getHistoryDetail(id, query, signal);
};

export function useAdminHistory(query: HistoryFilters & { page: number }) {
  return useHistoryResource(JSON.stringify(query), loadList);
}

export function useAdminHistoryDetail(id: string | null, query: HistoryDetailQuery) {
  return useHistoryResource(id ? JSON.stringify({ id, query }) : null, loadDetail);
}
