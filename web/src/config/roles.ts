import type { AdminUser } from "../api/respondaApi";

export function isAdministratorRole(role: string): role is AdminUser["role"] {
  return role === "admin" || role === "operations_admin";
}

export function administratorRoleLabel(role: AdminUser["role"]): string {
  return role === "admin" ? "Super Admin" : "Administrator";
}

export function canAccessDashboardPage(
  role: AdminUser["role"],
): boolean {
  return isAdministratorRole(role);
}
