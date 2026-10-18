export type MapPoint = {
  id: string;
  name: string;
  location: string;
  position: [number, number];
  barangay: string | null;
  priority: "Critical" | "High" | "Moderate" | "Low";
  hoursAgo: number;
  status?: string;
  source?: string;
  receivedAt?: string;
  assignedTeams?: string[];
  assignmentState?: "loading" | "ready" | "error";
};

export type MapFocus = {
  label: string;
  position: [number, number];
  zoom: number;
};
