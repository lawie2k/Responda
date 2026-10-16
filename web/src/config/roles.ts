import type { AdminUser } from "../api/respondaApi";
import type { Page } from "../types";

export function isAdministratorRole(role: string): role is AdminUser["role"] {
  return role === "admin" || role === "operations_admin";
}

export function administratorRoleLabel(role: AdminUser["role"]): string {
  return role === "admin" ? "Super Admin" : "Administrator";
}

export function canAccessDashboardPage(
  role: AdminUser["role"],
  page: Page,
): boolean {
  return role === "admin" || page !== "Settings";
}
