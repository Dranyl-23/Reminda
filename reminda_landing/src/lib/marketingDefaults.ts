import { MarketingSiteConfig } from "./types";

export const defaultMarketingConfig: MarketingSiteConfig = {
  announcement: {
    enabled: false,
    badge: "NEW RELEASE",
    text: "🎉 Reminda v1.0.0+14 is now live with enhanced Android 15 Home Screen Widgets!",
    linkText: "Download Now",
    linkUrl: "https://github.com/Dranyl-23/Reminda/releases/latest",
  },
  hero: {
    versionBadge: "v1.0.0+14",
    title: "Class schedules done the smart way",
    subtitle: "Reminda is an intelligent college timetable app. Built with zero-blur PDF OCR, Android home screen widgets, and offline-first alarms. You can quickly master your entire academic semester with this companion.",
    primaryButtonText: "Download for Free",
    primaryButtonUrl: "https://github.com/Dranyl-23/Reminda/releases/latest",
    secondaryButtonText: "GitHub Repo",
    secondaryButtonUrl: "https://github.com/Dranyl-23/Reminda",
    enableQrModal: true,
  },
  features: [
    {
      id: "feat-1",
      title: "Direct PDF & COR Stream Importer",
      description: "Upload your official Certificate of Registration (COR) or study load directly as a PDF. By reading raw text streams, Reminda extracts subjects, room assignments, and schedules with near-100% accuracy.",
      icon: "FileText",
    },
    {
      id: "feat-2",
      title: "Native Android Home Screen Widget",
      description: "Keep track of your current in-session lecture or next upcoming room right from your phone's desktop. Updates automatically in the background without draining your battery.",
      icon: "Smartphone",
    },
    {
      id: "feat-3",
      title: "Schedule Conflict & Overlap Guard",
      description: "Automatically detects overlapping class periods or conflicting laboratory blocks as you add, edit, or import schedules, keeping your weekly routine conflict-free.",
      icon: "ShieldAlert",
    },
    {
      id: "feat-4",
      title: "Holiday / Skip-Next Class Mode",
      description: "Suspended classes due to campus holidays, intramurals, or weather signals? Mute individual upcoming sessions with one tap without disabling your recurring alarms.",
      icon: "Sun",
    },
    {
      id: "feat-5",
      title: "6-Digit Class Block Sharing",
      description: "Share your entire semester schedule with classmates and blockmates in seconds using a generated 6-digit sync code or export a high-resolution PNG timetable wallpaper.",
      icon: "Share2",
    },
    {
      id: "feat-6",
      title: "100% Offline-First Cloud Sync",
      description: "Engineered for spotty campus Wi-Fi. All schedules and alarms are cached locally with instant zero-lag reads, and automatically sync to Cloud Firestore when reconnecting.",
      icon: "WifiOff",
    },
  ],
  downloadHub: {
    tag: "Production Release • v1.0.0+14",
    title: "Never miss another class.",
    subtitle: "Download Reminda for Android today and turn your registration slip into an intelligent, alarm-synced schedule on your smartphone.",
    universalApkUrl: "https://github.com/Dranyl-23/Reminda/releases/latest/download/app-arm64-v8a-release.apk",
    universalApkSize: "~58 MB",
    arm64ApkUrl: "https://github.com/Dranyl-23/Reminda/releases/latest/download/app-arm64-v8a-release.apk",
    arm64ApkSize: "~45 MB",
    sideloadNote: "When installing the APK file, Android might display an \"Install unknown apps\" prompt. Simply tap Allow from this source to proceed. Reminda is open-source and free of tracking.",
  },
  faqs: [
    {
      q: "Is Reminda free to use?",
      a: "Yes! Reminda is 100% free, privacy-first, and completely ad-free. There are no paid tiers or subscription paywalls.",
    },
    {
      q: "Which colleges and universities are supported?",
      a: "Reminda works for students anywhere in the world. It includes pre-configured profile options for Philippine institutions (such as Cor Jesu College, UIC, Ateneo, UP, and others), plus a custom option to set up any school or department.",
    },
    {
      q: "Do alarms and schedules work without internet connection?",
      a: "Absolutely. Reminda is engineered with an offline-first architecture using local Hive databases. Your alarms and widgets are scheduled directly with native Android AlarmManagers and will ring reliably even in Airplane Mode or without Wi-Fi.",
    },
    {
      q: "How does the Zero-Blur PDF / COR scanner work?",
      a: "When you upload your official Certificate of Registration (COR) PDF file, Reminda extracts the raw digital text streams directly from the document without converting it to compressed images. This eliminates camera blur, glare, and typos.",
    },
    {
      q: "How does the Android Home Screen Widget update?",
      a: "Reminda features a native Android AppWidgetProvider that updates automatically when shifts start or end. It displays your current in-session class or next upcoming room at a glance.",
    },
    {
      q: "What is Holiday / Skip-Next Class Mode?",
      a: "If a class is suspended for a holiday, teacher absence, or university event, you can tap 'Skip Next' to mute just that single session. Your recurring weekly alarm remains active for the following week without manual re-enabling.",
    },
  ],
  footer: {
    copyrightText: `Copyright © ${new Date().getFullYear()} Reminda. All rights reserved.`,
    githubUrl: "https://github.com/Dranyl-23/Reminda",
  },
};
