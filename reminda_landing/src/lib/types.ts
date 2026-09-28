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
