import { useCallback, useEffect, useState } from "react";
import { getStaff, type StaffList, type StaffQuery } from "../api/adminStaff";

export function useAdminStaff(query: StaffQuery) {
  const [version, setVersion] = useState(0);
  const key = JSON.stringify(query);
  const requestKey = `${key}:${version}`;
  const [state, setState] = useState<{ key: string; data: StaffList | null; error: string | null } | null>(null);
  useEffect(() => {
    const controller = new AbortController();
    getStaff(JSON.parse(key), controller.signal)
      .then((data) => { if (!controller.signal.aborted) setState({ key: requestKey, data, error: null }); })
      .catch((error: unknown) => { if (!controller.signal.aborted) setState({ key: requestKey, data: null,
        error: error instanceof Error ? error.message : "Staff accounts could not be loaded." }); });
    return () => controller.abort();
  }, [key, requestKey]);
  const refetch = useCallback(() => setVersion((value) => value + 1), []);
  if (state?.key !== requestKey) return { status: "loading", data: null, error: null, refetch } as const;
  if (!state.data) return { status: "error", data: null, error: state.error, refetch } as const;
  return { status: "ready", data: state.data, error: null, refetch } as const;
}
