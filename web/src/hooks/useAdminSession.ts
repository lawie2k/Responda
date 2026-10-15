import { useCallback, useEffect, useState } from "react";
import {
  clearSessionScopedCache,
  getAdminSession,
  loginAdmin,
  logoutAdmin,
  RespondaApiError,
  type AdminSession,
} from "../api/respondaApi";

type AuthState =
  | { status: "checking"; session: null }
  | { status: "signed-out"; session: null }
  | { status: "signed-in"; session: AdminSession };

const historyKey = "responda-auth-history";
const dashboardPath = "/";
const loginPath = "/login";

export function useAdminSession() {
  const [state, setState] = useState<AuthState>({
    status: "checking",
    session: null,
  });

  const showLogin = useCallback(async () => {
    await clearSessionScopedCache();
    window.history.replaceState({ [historyKey]: "login" }, "", loginPath);
    setState({ status: "signed-out", session: null });
  }, []);

  useEffect(() => {
    const controller = new AbortController();
    getAdminSession(controller.signal)
      .then((session) => {
        window.history.replaceState(
          { [historyKey]: "dashboard-root" },
          "",
          dashboardPath,
        );
        setState({ status: "signed-in", session });
      })
      .catch((error: unknown) => {
        const requestWasAborted =
          error instanceof DOMException && error.name === "AbortError";
        if (!requestWasAborted) void showLogin();
      });

    return () => controller.abort();
  }, [showLogin]);

  useEffect(() => {
    if (state.status === "signed-out") {
      const keepLoginRoute = () => {
        if (window.location.pathname !== loginPath) {
          window.history.replaceState(
            { [historyKey]: "login" },
            "",
            loginPath,
          );
        }
      };
      window.addEventListener("popstate", keepLoginRoute);
      return () => window.removeEventListener("popstate", keepLoginRoute);
    }

    if (state.status !== "signed-in") return;

    const currentState = window.history.state as Record<string, unknown> | null;
    if (currentState?.[historyKey] !== "dashboard-guard") {
      window.history.replaceState(
        { [historyKey]: "dashboard-root" },
        "",
        dashboardPath,
      );
      window.history.pushState(
        { [historyKey]: "dashboard-guard" },
        "",
        dashboardPath,
      );
    }

    const keepDashboardRoute = () => {
      window.history.pushState(
        { [historyKey]: "dashboard-guard" },
        "",
        dashboardPath,
      );
    };
    window.addEventListener("popstate", keepDashboardRoute);
    return () => window.removeEventListener("popstate", keepDashboardRoute);
  }, [state.status]);

  useEffect(() => {
    if (state.status !== "signed-in") return;

    let validating = false;
    const validateSession = async () => {
      if (validating) return;
      validating = true;
      try {
        const session = await getAdminSession();
        setState({ status: "signed-in", session });
      } catch (error) {
        if (error instanceof RespondaApiError && error.status === 401) {
          await showLogin();
        }
      } finally {
        validating = false;
      }
    };
    const validateWhenVisible = () => {
      if (document.visibilityState === "visible") void validateSession();
    };
    const interval = window.setInterval(validateSession, 5 * 60 * 1000);
    window.addEventListener("focus", validateSession);
    document.addEventListener("visibilitychange", validateWhenVisible);

    return () => {
      window.clearInterval(interval);
      window.removeEventListener("focus", validateSession);
      document.removeEventListener("visibilitychange", validateWhenVisible);
    };
  }, [showLogin, state.status]);

  const login = useCallback(async (email: string, password: string) => {
    const session = await loginAdmin(email, password);
    await clearSessionScopedCache();
    window.history.replaceState(
      { [historyKey]: "dashboard-root" },
      "",
      dashboardPath,
    );
    setState({ status: "signed-in", session });
  }, []);

  const logout = useCallback(async () => {
    await logoutAdmin();
    await showLogin();
  }, [showLogin]);

  return { state, login, logout };
}
