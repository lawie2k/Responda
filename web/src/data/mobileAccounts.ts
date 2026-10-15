export type MobileAccountStatus = "ACTIVE" | "NEEDS_ATTENTION" | "SUSPENDED";

export type MobileAccount = {
  id: string;
  fullName: string;
  initials: string;
  phone: string;
  barangay: string;
  joined: string;
  phoneVerified: string;
  privacyAccepted: string;
  lastActive: string;
  reportsSubmitted: number;
  status: MobileAccountStatus;
  accent: string;
};

export const initialMobileAccounts: MobileAccount[] = [
  {
    id: "USR-00131",
    fullName: "Ana Mae Flores",
    initials: "AF",
    phone: "0917 482 1936",
    barangay: "Kingking",
    joined: "12 min ago",
    phoneVerified: "Today, 1:33 PM",
    privacyAccepted: "Today, 1:29 PM",
    lastActive: "2 min ago",
    reportsSubmitted: 1,
    status: "ACTIVE",
    accent: "rose",
  },
  {
    id: "USR-00130",
    fullName: "",
    initials: "09",
    phone: "0928 715 6042",
    barangay: "",
    joined: "28 min ago",
    phoneVerified: "Today, 1:17 PM",
    privacyAccepted: "Today, 1:14 PM",
    lastActive: "18 min ago",
    reportsSubmitted: 0,
    status: "ACTIVE",
    accent: "blue",
  },
  {
    id: "USR-00129",
    fullName: "Liza Manalo",
    initials: "LM",
    phone: "0966 304 8821",
    barangay: "Matiao",
    joined: "43 min ago",
    phoneVerified: "Today, 1:02 PM",
    privacyAccepted: "Today, 12:59 PM",
    lastActive: "31 min ago",
    reportsSubmitted: 2,
    status: "NEEDS_ATTENTION",
    accent: "amber",
  },
  {
    id: "USR-00128",
    fullName: "Joel Dizon",
    initials: "JD",
    phone: "0918 902 4450",
    barangay: "Magnaga",
    joined: "Yesterday",
    phoneVerified: "Yesterday, 4:28 PM",
    privacyAccepted: "Yesterday, 4:25 PM",
    lastActive: "Today, 11:20 AM",
    reportsSubmitted: 4,
    status: "ACTIVE",
    accent: "green",
  },
  {
    id: "USR-00127",
    fullName: "Mark Reyes",
    initials: "MR",
    phone: "0995 610 2284",
    barangay: "Bongabong",
    joined: "2 days ago",
    phoneVerified: "October 6, 9:14 AM",
    privacyAccepted: "October 6, 9:11 AM",
    lastActive: "Yesterday, 8:06 PM",
    reportsSubmitted: 3,
    status: "SUSPENDED",
    accent: "rose",
  },
];
