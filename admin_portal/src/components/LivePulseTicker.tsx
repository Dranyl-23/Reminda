"use client";

import { useState, useMemo, useSyncExternalStore } from "react";
import Link from "next/link";
import {
  UserAccount,
  UserFeedback,
  AiTrainingSample,
  Announcement,
} from "@/lib/types";
import {
  Activity,
  UserCheck,
  MessageSquare,
  BrainCircuit,
  Megaphone,
  Clock,
  ArrowUpRight,
} from "lucide-react";
import { getUserDisplayName, getPlatformMeta } from "@/app/users/page";

export type PulseEventType = "user" | "feedback" | "ai_sample" | "announcement";

export interface PulseEvent {
  id: string;
  type: PulseEventType;
  title: string;
  subtitle: string;
  timestamp: number;
  badge: string;
  targetUrl: string;
  avatarUrl?: string | null;
}

interface LivePulseTickerProps {
  users: UserAccount[];
  feedbacks: UserFeedback[];
  aiSamples: AiTrainingSample[];
  announcements?: Announcement[];
  userPhotos?: Record<string, string>;
}

let currentClockSnapshot = typeof Date !== "undefined" ? Date.now() : 0;
const clockListeners = new Set<() => void>();

if (typeof window !== "undefined") {
  setInterval(() => {
    currentClockSnapshot = Date.now();
    clockListeners.forEach((l) => l());
  }, 30000);
}

function subscribeClock(callback: () => void) {
  clockListeners.add(callback);
  return () => {
    clockListeners.delete(callback);
  };
}

function getClockSnapshot(): number {
  return currentClockSnapshot;
}

function getServerSnapshot(): number {
  return 0;
}

function extractMillis(ts: any, iso?: string): number {
  if (!ts && !iso) return 0;
  try {
    if (typeof ts?.toMillis === "function") return ts.toMillis();
    if (ts?.seconds) return ts.seconds * 1000;
    if (iso) {
      const parsed = new Date(iso).getTime();
      if (!isNaN(parsed)) return parsed;
    }
    if (typeof ts === "string" || typeof ts === "number") {
      const parsed = new Date(ts).getTime();
      if (!isNaN(parsed)) return parsed;
    }
  } catch (_) {}
  return 0;
}

function formatRelativeTime(timestampMs: number, nowMs: number): string {
  if (!timestampMs || timestampMs === 0) return "Recent";
  if (!nowMs || nowMs === 0) return "Recently";
  const diff = Math.max(0, nowMs - timestampMs);
  const secs = Math.floor(diff / 1000);
  if (secs < 45) return "Just now";
  const mins = Math.floor(secs / 60);
  if (mins < 60) return `${mins}m ago`;
  const hours = Math.floor(mins / 60);
  if (hours < 24) return `${hours}h ago`;
  const days = Math.floor(hours / 24);
  if (days === 1) return "Yesterday";
  return `${days}d ago`;
}

export function LivePulseTicker({
  users,
  feedbacks,
  aiSamples,
  announcements = [],
  userPhotos = {},
}: LivePulseTickerProps) {
  const [selectedFilter, setSelectedFilter] = useState<"all" | PulseEventType>("all");
  const now = useSyncExternalStore(subscribeClock, getClockSnapshot, getServerSnapshot);

  const events = useMemo<PulseEvent[]>(() => {
    const list: PulseEvent[] = [];

    users.forEach((u) => {
      const ts = extractMillis(u.lastSyncAt || u.lastActive || u.createdAt || u.updatedAt);
      const name = getUserDisplayName(u);
      const isGuest = (u as any).isGuest;
      const meta = getPlatformMeta(u.platform);

      list.push({
        id: `user-${u.id}`,
        type: "user",
        title: `${name} ${isGuest ? "(Guest)" : "synced account"}`,
        subtitle: `Active on ${meta.fullLabel} · App ${u.appVersion || "v1.0.0+17"}`,
        timestamp: ts,
        badge: isGuest ? "Guest Sync" : meta.badgeText,
        targetUrl: "/users",
        avatarUrl:
          u.photoUrl ||
          userPhotos[u.id] ||
          (u.email ? userPhotos[u.email.toLowerCase().trim()] : null),
      });
    });

    feedbacks.forEach((f) => {
      const ts = extractMillis(f.timestamp, f.createdAtIso);
      const rating = f.rating || 5;
      const snippet = f.message || f.comment || "Submitted helpful feedback.";
      const shortSnippet = snippet.length > 65 ? `${snippet.substring(0, 62)}...` : snippet;

      list.push({
        id: `feedback-${f.id}`,
        type: "feedback",
        title: `${f.userName || "User"} submitted ${rating}★ review`,
        subtitle: `"${shortSnippet}" · ${f.category || "General"}`,
        timestamp: ts,
        badge: `${rating}★ Review`,
        targetUrl: "/feedbacks",
        avatarUrl:
          f.userPhotoUrl ||
          f.photoUrl ||
          userPhotos[f.userId] ||
          (f.contactEmail ? userPhotos[f.contactEmail.toLowerCase().trim()] : null),
      });
    });

    aiSamples.forEach((s) => {
      const ts = extractMillis(s.timestamp, s.createdAtIso);
      const count = s.entriesCount || s.verifiedEntries?.length || 1;
      const org = s.institutionName ? `from ${s.institutionName}` : "from timetable scan";

      list.push({
        id: `ai-${s.id}`,
        type: "ai_sample",
        title: `Ground-truth OCR sample ingested`,
        subtitle: `${count} classes extracted ${org} (${s.engineSource || "ML Kit"})`,
        timestamp: ts,
        badge: `${count} Classes`,
        targetUrl: "/dataset",
      });
    });

    announcements.forEach((a) => {
      const ts = extractMillis((a as any).timestamp, (a as any).createdAt);
      list.push({
        id: `announcement-${a.id}`,
        type: "announcement",
        title: `Broadcast: "${a.title || "Announcement"}"`,
        subtitle: a.isActive ? "Live in mobile app home banner" : "Archived broadcast notice",
        timestamp: ts,
        badge: a.type.toUpperCase(),
        targetUrl: "/announcements",
      });
    });

    list.sort((a, b) => b.timestamp - a.timestamp);
    return list;
  }, [users, feedbacks, aiSamples, announcements, userPhotos]);

  const filteredEvents = useMemo(() => {
    if (selectedFilter === "all") return events.slice(0, 12);
    return events.filter((e) => e.type === selectedFilter).slice(0, 12);
  }, [events, selectedFilter]);

  const counts = useMemo(() => {
    return {
      all: events.length,
      user: events.filter((e) => e.type === "user").length,
      feedback: events.filter((e) => e.type === "feedback").length,
      ai_sample: events.filter((e) => e.type === "ai_sample").length,
    };
  }, [events]);

  const getEventIcon = (type: PulseEventType) => {
    switch (type) {
      case "user":
        return <UserCheck className="w-4 h-4 text-zinc-700 dark:text-zinc-300" />;
      case "feedback":
        return <MessageSquare className="w-4 h-4 text-zinc-700 dark:text-zinc-300" />;
      case "ai_sample":
        return <BrainCircuit className="w-4 h-4 text-zinc-700 dark:text-zinc-300" />;
      case "announcement":
        return <Megaphone className="w-4 h-4 text-zinc-700 dark:text-zinc-300" />;
    }
  };

  return (
    <div className="rounded-xl bg-white dark:bg-[#121215] border border-zinc-200/80 dark:border-zinc-800 shadow-2xs overflow-hidden">
      {/* Header */}
      <div className="p-5 flex flex-col sm:flex-row sm:items-center justify-between gap-3 border-b border-zinc-200/80 dark:border-zinc-800">
        <div className="flex items-center gap-3">
          <div className="p-2 rounded-lg bg-zinc-100 dark:bg-zinc-900 text-zinc-800 dark:text-zinc-200">
            <Activity className="w-4 h-4" />
          </div>
          <div>
            <div className="flex items-center gap-2">
              <h3 className="font-bold text-sm text-zinc-900 dark:text-zinc-100">
                Real-Time System Activity Log
              </h3>
              <span className="inline-flex items-center gap-1.5 px-2 py-0.5 rounded-md text-[10px] font-semibold bg-zinc-100 dark:bg-zinc-800 text-zinc-700 dark:text-zinc-300 border border-zinc-200/80 dark:border-zinc-700">
                <span className="w-1.5 h-1.5 rounded-full bg-emerald-500 animate-ping" />
                Firestore Live
              </span>
            </div>
            <p className="text-xs text-zinc-500 dark:text-zinc-400">
              Chronological stream of account syncs, AI OCR extractions, and user reviews
            </p>
          </div>
        </div>

        {/* Studio Admin Segmented Filter Tabs */}
        <div className="inline-flex items-center p-0.5 rounded-lg bg-zinc-100 dark:bg-zinc-900 border border-zinc-200/80 dark:border-zinc-800 flex-wrap">
          {[
            { id: "all", label: `All (${counts.all})` },
            { id: "user", label: `Users (${counts.user})` },
            { id: "ai_sample", label: `AI OCR (${counts.ai_sample})` },
            { id: "feedback", label: `Reviews (${counts.feedback})` },
          ].map((tab) => (
            <button
              key={tab.id}
              type="button"
              onClick={() => setSelectedFilter(tab.id as any)}
              className={`px-2.5 py-1 rounded-md text-xs font-semibold transition-all cursor-pointer ${
                selectedFilter === tab.id
                  ? "bg-white dark:bg-zinc-800 text-zinc-900 dark:text-zinc-100 shadow-2xs"
                  : "text-zinc-500 hover:text-zinc-900 dark:hover:text-zinc-200"
              }`}
            >
              {tab.label}
            </button>
          ))}
        </div>
      </div>

      {/* Table / Stream Rows */}
      {filteredEvents.length === 0 ? (
        <div className="py-12 text-center text-zinc-400 text-xs">
          No live activity events recorded in this filter.
        </div>
      ) : (
        <div className="divide-y divide-zinc-100 dark:divide-zinc-800/80 max-h-96 overflow-y-auto">
          {filteredEvents.map((evt) => (
            <Link
              key={evt.id}
              href={evt.targetUrl}
              className="group flex items-center justify-between gap-4 px-5 py-3 hover:bg-zinc-50/80 dark:hover:bg-zinc-900/50 transition-colors"
            >
              <div className="flex items-center gap-3 min-w-0">
                {evt.avatarUrl ? (
                  <img
                    src={evt.avatarUrl}
                    alt="User"
                    className="w-8 h-8 rounded-lg object-cover border border-zinc-200 dark:border-zinc-700 shrink-0"
                    onError={(e) => {
                      (e.currentTarget as HTMLElement).style.display = "none";
                    }}
                  />
                ) : (
                  <div className="w-8 h-8 rounded-lg bg-zinc-100 dark:bg-zinc-900 border border-zinc-200/70 dark:border-zinc-800 flex items-center justify-center shrink-0">
                    {getEventIcon(evt.type)}
                  </div>
                )}

                <div className="min-w-0">
                  <p className="text-xs font-semibold text-zinc-900 dark:text-zinc-100 truncate group-hover:underline">
                    {evt.title}
                  </p>
                  <p className="text-[11px] text-zinc-500 dark:text-zinc-400 truncate mt-0.5">
                    {evt.subtitle}
                  </p>
                </div>
              </div>

              <div className="flex items-center gap-3 shrink-0">
                <span className="px-2 py-0.5 rounded-md text-[10px] font-semibold bg-zinc-100 dark:bg-zinc-800 text-zinc-700 dark:text-zinc-300 border border-zinc-200/80 dark:border-zinc-700">
                  {evt.badge}
                </span>
                <span className="text-[11px] text-zinc-400 font-mono w-16 text-right flex items-center justify-end gap-1">
                  <Clock className="w-3 h-3 shrink-0" />
                  {formatRelativeTime(evt.timestamp, now)}
                </span>
                <ArrowUpRight className="w-3.5 h-3.5 text-zinc-400 group-hover:text-zinc-900 dark:group-hover:text-zinc-100 transition-colors" />
              </div>
            </Link>
          ))}
        </div>
      )}
    </div>
  );
}
