import { getBarangayForPosition } from "./barangayBoundaries";

export type Report = {
  id: string;
  incident: string;
  location: string;
  position: [number, number] | null;
  barangay: string | null;
  priority: string;
  status: string;
  time: string;
};

const reportSeeds: Omit<Report, "barangay">[] = [
  {
    id: "RSP-00872",
    incident: "Road Accident",
    location: "Kingking Highway",
    position: [7.1428, 125.8882],
    priority: "CRITICAL",
    status: "VERIFYING",
    time: "1:41 PM",
  },
  {
    id: "RSP-00871",
    incident: "Flash Flood",
    location: "Magnaga Riverside",
    position: [7.19521, 125.956137],
    priority: "HIGH",
    status: "DISPATCHED",
    time: "1:36 PM",
  },
  {
    id: "RSP-00870",
    incident: "Medical",
    location: "Matiao Public Market",
    position: [7.103213, 125.924505],
    priority: "MODERATE",
    status: "VALIDATED",
    time: "1:31 PM",
  },
  {
    id: "RSP-00869",
    incident: "Landslide",
    location: "Bongabong Slope",
    position: [7.234498, 125.946031],
    priority: "HIGH",
    status: "VERIFYING",
    time: "1:25 PM",
  },
  {
    id: "RSP-00868",
    incident: "Fire",
    location: "Kingking Junction",
    position: [7.1365, 125.8912],
    priority: "CRITICAL",
    status: "DISPATCHED",
    time: "1:19 PM",
  },
  {
    id: "RSP-00867",
    incident: "Fallen Tree",
    location: "Pantukan Highway",
    position: [7.12682, 125.89714],
    priority: "MODERATE",
    status: "VALIDATED",
    time: "1:04 PM",
  },
];

export const reports: Report[] = reportSeeds.map((report) => ({
  ...report,
  barangay: getBarangayForPosition(report.position),
}));

export const tone = (value: string) =>
  value === "CRITICAL"
    ? "red"
    : value === "HIGH"
      ? "orange"
      : value === "MODERATE"
        ? "amber"
        : value === "DISPATCHED"
          ? "green"
          : value === "VALIDATED"
            ? "blue"
            : "amber";
