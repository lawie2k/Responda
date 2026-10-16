import type { IconName, Page } from "../types";

export const pageInfo: Record<Page, [string, string]> = {
  Overview: ["Operations Dashboard", "Tuesday, 1 September 2026  •  1:45 PM"],
  "Live Reports": [
    "Live Reports",
    "Incoming app and manually encoded emergency reports",
  ],
  "Incident Map": [
    "Incident Map",
    "Live operational map and active incident locations",
  ],
  "Report Validation": [
    "Report Validation",
    "Review incident details and system suggestions before dispatch",
  ],
  "Mobile Accounts": [
    "Mobile Accounts",
    "Monitor phone-verified users and optional account details",
  ],
  "Response Teams": [
    "Response Teams",
    "Team availability, assignments, and deployment status",
  ],
  Analytics: [
    "Analytics",
    "Emergency trends, response performance, and operational outcomes",
  ],
  "Historical Records": [
    "Historical Records",
    "Search, review, and export completed incident records",
  ],
  Settings: [
    "Settings",
    "System preferences, access, alerts, and data controls",
  ],
};
export const groups: { label: string; items: [Page, IconName, number?][] }[] = [
  {
    label: "OPERATIONS",
    items: [
      ["Overview", "dashboard"],
      ["Live Reports", "reports"],
      ["Incident Map", "map"],
      ["Report Validation", "verify"],
      ["Response Teams", "users"],
    ],
  },
  {
    label: "USER MANAGEMENT",
    items: [["Mobile Accounts", "phone"]],
  },
  {
    label: "INSIGHTS & RECORDS",
    items: [
      ["Analytics", "chart"],
      ["Historical Records", "records"],
      ["Settings", "settings"],
    ],
  },
];
