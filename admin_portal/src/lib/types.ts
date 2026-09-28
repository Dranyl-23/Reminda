export interface UserFeedback {
  id: string;
  rating: number;
  category: string;
  message?: string;
  comment?: string;
  contactEmail: string;
  userName: string;
  userId: string;
  userPhotoUrl?: string;
  photoUrl?: string;
  appVersion: string;
  platform: string;
  createdAtIso?: string;
  timestamp?: any;
  status?: "pending" | "in-progress" | "resolved" | "reviewed";
}

export interface VerifiedScheduleEntry {
  title: string;
  daysOfWeek: number[];
  startTime: string;
  endTime: string;
  location: string;
  category: string;
  notes?: string;
}

export interface AiTrainingSample {
  id: string;
  entriesCount: number;
  institutionName: string;
  role: string;
  engineSource: string;
  appVersion: string;
  platform: string;
  rawOcrText?: string;
  verifiedEntries: VerifiedScheduleEntry[];
  qualityStatus?: "clean" | "unreviewed" | "flagged";
  notes?: string;
  createdAtIso?: string;
  timestamp?: any;
}

export interface UserAccount {
  id: string;
  displayName: string;
  email: string;
  photoUrl?: string;
  createdAt?: any;
  lastSyncAt?: any;
  lastActive?: any;
  updatedAt?: any;
  schedulesCount?: number;
  appVersion?: string;
  platform?: string;
}

export interface UserProfileDoc {
  id: string;
  name: string;
  role?: string;
  type?: string;
  institutionName?: string;
  category?: string;
  isCurrent?: boolean;
  isActive?: boolean;
  academicYear?: string;
  semester?: string;
  colorHex?: string;
  updatedAt?: any;
}

export interface UserScheduleDoc {
  id: string;
  title: string;
  profileId: string;
  daysOfWeek: number[];
  startTime: string;
  endTime: string;
  location?: string;
  category?: string;
  colorHex?: string;
  notes?: string;
  reminders?: number[];
  alarmLeadMinutes?: number;
  isActive?: boolean;
  updatedAt?: any;
}

export interface Institution {
  id: string;
  name: string;
  shortName: string;
  category: string;
  regionCode: string;
  city: string;
  themeColor: string;
  logoUrl?: string;
  emblemInitials?: string;
  isOfficial?: boolean;
  createdAt?: any;
}

export interface Announcement {
  id: string;
  title: string;
  message: string;
  type: "info" | "warning" | "urgent" | "promo";
  isActive: boolean;
  actionLabel?: string;
  actionUrl?: string;
  createdAt?: any;
  updatedAt?: any;
}

export interface SystemAppConfig {
  geminiOnlineFallbackEnabled: boolean;
  minRequiredAppVersion: string;
  latestAppVersion: string;
  forceUpdateEnabled: boolean;
  updateStoreUrl: string;
  maintenanceMode: boolean;
  maintenanceMessage: string;
  updatedAt?: any;
}

export interface MarketingSiteConfig {
  announcement: {
    enabled: boolean;
    badge: string;
    text: string;
    linkText: string;
    linkUrl: string;
  };
  hero: {
    versionBadge: string;
    title: string;
    subtitle: string;
    primaryButtonText: string;
    primaryButtonUrl: string;
    secondaryButtonText: string;
    secondaryButtonUrl: string;
    enableQrModal: boolean;
  };
  features: Array<{
    id: string;
    title: string;
    description: string;
    icon: string;
  }>;
  downloadHub: {
    tag: string;
    title: string;
    subtitle: string;
    universalApkUrl: string;
    universalApkSize: string;
    arm64ApkUrl: string;
    arm64ApkSize: string;
    sideloadNote: string;
  };
  faqs: Array<{
    q: string;
    a: string;
  }>;
  footer: {
    copyrightText: string;
    githubUrl: string;
  };
  updatedAt?: any;
}

