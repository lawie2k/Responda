import { useCallback, useEffect, useState } from "react";
import {
  getAdminResponseUnits,
  type AdminResponseUnitList,
  type AdminResponseUnitsQuery,
} from "../api/respondaApi";

type ResponseUnitState =
  | {
      queryKey: string;
      status: "ready";
      data: AdminResponseUnitList;
      error: null;
    }
  | {
      queryKey: string;
      status: "error";
      data: null;
      error: string;
    };

export function useAdminResponseUnits(query: AdminResponseUnitsQuery = {}) {
  const queryKey = JSON.stringify(query);
  const [requestVersion, setRequestVersion] = useState(0);
  const [state, setState] = useState<ResponseUnitState | null>(null);

  useEffect(() => {
    const controller = new AbortController();
    const stableQuery = JSON.parse(queryKey) as AdminResponseUnitsQuery;
    getAdminResponseUnits(stableQuery, controller.signal)
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
              : "The response-unit roster could not be loaded.",
        });
      });
    return () => controller.abort();
  }, [queryKey, requestVersion]);

  const refetch = useCallback(() => setRequestVersion((value) => value + 1), []);
  if (state?.queryKey !== queryKey) {
    return { status: "loading", data: null, error: null, refetch } as const;
  }
  return { ...state, refetch };
}
