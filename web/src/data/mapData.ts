import { getBarangayForPosition } from "./barangayBoundaries";

export type MapPoint = {
  id: string;
  name: string;
  location: string;
  position: [number, number];
  barangay: string | null;
  priority: "Critical" | "High" | "Moderate";
  hoursAgo: number;
};

export type MapFocus = {
  label: string;
  position: [number, number];
  zoom: number;
};

const incidentSeeds: Omit<MapPoint, "barangay">[] = [
  {
    id: "RSP-00872",
    name: "Road accident",
    location: "Kingking Highway",
    position: [7.1428, 125.8882],
    priority: "Critical",
    hoursAgo: 1,
  },
  {
    id: "RSP-00871",
    name: "Flash flood",
    location: "Magnaga Riverside",
    position: [7.19521, 125.956137],
    priority: "High",
    hoursAgo: 5,
  },
  {
    id: "RSP-00870",
    name: "Medical emergency",
    location: "Bongabong Slope",
    position: [7.234498, 125.946031],
    priority: "Moderate",
    hoursAgo: 18,
  },
  {
    id: "RSP-00869",
    name: "Landslide",
    location: "Matiao Hillside",
    position: [7.103213, 125.924505],
    priority: "Critical",
    hoursAgo: 32,
  },
];

export const incidents: MapPoint[] = incidentSeeds.map((incident) => ({
  ...incident,
  barangay: getBarangayForPosition(incident.position),
}));
