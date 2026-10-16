import type { AdminReportListItem } from "../api/respondaApi";
import { getBarangayForPosition } from "./barangayBoundaries";

export type Report = {
  id: string;
  reference: string;
  incident: string;
  location: string;
  position: [number, number] | null;
  barangay: string | null;
  priority: "CRITICAL" | "HIGH" | "MEDIUM" | "LOW";
  status: string;
  time: string;
  receivedAt: string;
  description: string;
  source: AdminReportListItem["source"];
  verificationStatus: AdminReportListItem["verification_status"];
  incidentStatus: NonNullable<AdminReportListItem["incident"]>["status"] | undefined;
  incidentTypeId: string;
};

const formatStatus = (report: AdminReportListItem) => {
  if (report.status === "closed" || report.incident?.status === "closed") {
    return "CLOSED";
  }
  if (report.incident?.status === "dispatched") return "DISPATCHED";
  if (report.incident?.status === "responding") return "RESPONDING";
  if (report.incident?.status === "resolved") return "RESOLVED";
  if (report.verification_status === "pending") return "VERIFYING";
  if (report.verification_status === "verified") return "VALIDATED";
  if (report.verification_status === "unverified") return "UNVERIFIED";
  if (report.verification_status === "invalid") return "INVALID";
  return report.status.replaceAll("_", " ").toUpperCase();
};

export const toReport = (report: AdminReportListItem): Report => {
  const position: [number, number] | null =
    report.location?.latitude != null && report.location.longitude != null
      ? [report.location.latitude, report.location.longitude]
      : null;
  const coordinateLabel = position
    ? `${position[0].toFixed(5)}, ${position[1].toFixed(5)}`
    : "Location not provided";
  return {
    id: report.report_id,
    reference: `RSP-${report.report_id.slice(0, 8).toUpperCase()}`,
    incident: report.incident_type.name,
    location: report.location?.landmark || coordinateLabel,
    position,
    barangay: getBarangayForPosition(position),
    priority: report.effective_priority.toUpperCase() as Report["priority"],
    status: formatStatus(report),
    time: new Intl.DateTimeFormat("en-PH", {
      hour: "numeric",
      minute: "2-digit",
    }).format(new Date(report.received_at)),
    receivedAt: report.received_at,
    description: report.description_original,
    source: report.source,
    verificationStatus: report.verification_status,
    incidentStatus: report.incident?.status,
    incidentTypeId: report.incident_type.incident_type_id,
  };
};

export const tone = (value: string) =>
  value === "CRITICAL"
    ? "red"
    : value === "HIGH"
      ? "orange"
      : value === "MEDIUM"
        ? "amber"
        : value === "LOW"
          ? "green"
        : value === "DISPATCHED"
          ? "green"
          : value === "VALIDATED"
            ? "blue"
            : "amber";
