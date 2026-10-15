export type ValidationStatus = "PENDING" | "VALIDATED" | "REJECTED";
export type ValidationPriority = "Critical" | "High" | "Moderate";

export type ValidationReport = {
  id: string;
  incident: string;
  location: string;
  reason: string;
  reasonTone: string;
  priority: ValidationPriority;
  minutesAgo: number;
  reporter: string;
  contact: string;
  people: string;
  confidence: number;
  language: string;
  position: [number, number];
  barangay: string | null;
  status: ValidationStatus;
};

const validationReportSeeds: Omit<ValidationReport, "barangay">[] = [
  {
    id: "RSP-00872",
    incident: "Road Accident",
    location: "Kingking Highway",
    reason: "Priority conflict",
    reasonTone: "red",
    priority: "Critical",
    minutesAgo: 4,
    reporter: "Juan Dela Cruz",
    contact: "0917 123 4567",
    people: "1 injured • 2 affected",
    confidence: 94,
    language: "Mixed Bisaya / English",
    position: [7.1428, 125.8882],
    status: "PENDING",
  },
  {
    id: "RSP-00869",
    incident: "Landslide",
    location: "Bongabong Slope",
    reason: "Location accuracy",
    reasonTone: "orange",
    priority: "High",
    minutesAgo: 15,
    reporter: "Marites Cabral",
    contact: "0928 440 7812",
    people: "3 households nearby",
    confidence: 87,
    language: "Bisaya",
    position: [7.234498, 125.946031],
    status: "PENDING",
  },
  {
    id: "RSP-00865",
    incident: "Flood",
    location: "Magnaga Riverside",
    reason: "Possible duplicate",
    reasonTone: "amber",
    priority: "Moderate",
    minutesAgo: 18,
    reporter: "Carlo Mendoza",
    contact: "0919 662 3004",
    people: "Water rising near 4 homes",
    confidence: 91,
    language: "English",
    position: [7.19521, 125.956137],
    status: "PENDING",
  },
  {
    id: "RSP-00863",
    incident: "Medical",
    location: "Matiao Public Market",
    reason: "Contact details review",
    reasonTone: "blue",
    priority: "High",
    minutesAgo: 21,
    reporter: "Leah Ramos",
    contact: "0966 102 8891",
    people: "1 person experiencing chest pain",
    confidence: 89,
    language: "Mixed Bisaya / English",
    position: [7.103213, 125.924505],
    status: "PENDING",
  },
  {
    id: "RSP-00860",
    incident: "Fire",
    location: "Kingking Junction",
    reason: "Classification check",
    reasonTone: "maroon",
    priority: "Critical",
    minutesAgo: 24,
    reporter: "Noel Pascual",
    contact: "0908 774 2106",
    people: "Smoke visible from one structure",
    confidence: 82,
    language: "Bisaya",
    position: [7.1365, 125.8912],
    status: "PENDING",
  },
];

export const initialValidationReports: ValidationReport[] =
  validationReportSeeds.map((report) => ({
    ...report,
    barangay: getBarangayForPosition(report.position),
  }));
import { getBarangayForPosition } from "./barangayBoundaries";
