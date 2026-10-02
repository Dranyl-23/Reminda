"use client";

import { useState, useMemo, useSyncExternalStore } from "react";
import Link from "next/link";
import { 
  UserAccount, 
  UserFeedback, 
  AiTrainingSample, 
  Announcement 
} from "@/lib/types";
import { 
  Activity, 
  UserCheck, 
  MessageSquare, 
  BrainCircuit, 
  Megaphone, 
  Clock, 
  ArrowUpRight, 
  Sparkles
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
  badgeColor: string;
  iconColor: string;
  bgColor: string;
  targetUrl: string;
  avatarUrl?: string | null;
  extraMeta?: string;
  rating?: number;
}

interface LivePulseTickerProps {
  users: UserAccount[];
  feedbacks: UserFeedback[];
  aiSamples: AiTrainingSample[];
  announcements?: Announcement[];
  userPhotos?: Record<string, string>;
}

// Shared stable clock store for 30s ticking to prevent infinite re-renders
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

// Pure helper to safely extract milliseconds
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

// Pure helper for human-readable relative time
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
  const [hoveredEventId, setHoveredEventId] = useState<string | null>(null);
  const now = useSyncExternalStore(subscribeClock, getClockSnapshot, getServerSnapshot);

  // Aggregate and sort all events into a unified chronological stream
  const events = useMemo<PulseEvent[]>(() => {
    const list: PulseEvent[] = [];

    // 1. User Events
    users.forEach((u) => {
      const ts = extractMillis(u.lastSyncAt || u.lastActive || u.createdAt || u.updatedAt);
      const name = getUserDisplayName(u);
      const isGuest = (u as any).isGuest;
      const meta = getPlatformMeta(u.platform);

      list.push({
        id: `user-${u.id}`,
        type: "user",
        title: `${name} ${isGuest ? "(Guest)" : "synced account"}`,
        subtitle: `Active on ${meta.fullLabel} • App ${u.appVersion || "v1.0.0+15"}`,
        timestamp: ts,
        badge: isGuest ? "Guest Sync" : meta.badgeText,
        badgeColor: meta.type === "desktop"
          ? "bg-blue-50 dark:bg-blue-950/60 text-blue-600 dark:text-blue-400 border-blue-200/50"
          : "bg-emerald-50 dark:bg-emerald-950/60 text-emerald-600 dark:text-emerald-400 border-emerald-200/50",
        iconColor: meta.type === "desktop" ? "text-blue-500" : "text-emerald-500",
        bgColor: meta.type === "desktop" ? "bg-blue-500/10" : "bg-emerald-500/10",
        targetUrl: "/users",
        avatarUrl: u.photoUrl || userPhotos[u.id] || (u.email ? userPhotos[u.email.toLowerCase().trim()] : null),
        extraMeta: meta.label,
      });
    });

    // 2. Feedback Events
    feedbacks.forEach((f) => {
      const ts = extractMillis(f.timestamp, f.createdAtIso);
      const rating = f.rating || 5;
      const snippet = f.message || f.comment || "Submitted helpful feedback.";
      const shortSnippet = snippet.length > 55 ? `${snippet.substring(0, 52)}...` : snippet;

      list.push({
        id: `feedback-${f.id}`,
        type: "feedback",
        title: `${f.userName || "User"} submitted ${rating}★ feedback`,
        subtitle: `"${shortSnippet}" • ${f.category || "General"}`,
        timestamp: ts,
        badge: `${rating}★ Rating`,
        badgeColor: rating >= 4 
          ? "bg-amber-50 dark:bg-amber-950/60 text-amber-600 dark:text-amber-400 border-amber-200/50"
          : "bg-rose-50 dark:bg-rose-950/60 text-rose-600 dark:text-rose-400 border-rose-200/50",
        iconColor: "text-amber-500",
        bgColor: "bg-amber-500/10",
        targetUrl: "/feedbacks",
        avatarUrl: f.userPhotoUrl || f.photoUrl || userPhotos[f.userId] || (f.contactEmail ? userPhotos[f.contactEmail.toLowerCase().trim()] : null),
        rating: rating,
        extraMeta: f.category,
      });
    });

    // 3. AI OCR Training Sample Events
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
        badge: `${count} Classes Extracted`,
        badgeColor: "bg-purple-50 dark:bg-purple-950/60 text-purple-600 dark:text-purple-400 border-purple-200/50",
        iconColor: "text-purple-500",
        bgColor: "bg-purple-500/10",
        targetUrl: "/dataset",
        extraMeta: s.engineSource,
      });
    });

    // 4. Announcement Events
    announcements.forEach((a) => {
      const ts = extractMillis((a as any).timestamp, (a as any).createdAt);
      list.push({
        id: `announcement-${a.id}`,
        type: "announcement",
        title: `Broadcast: "${a.title || "Announcement"}"`,
        subtitle: a.isActive ? "Live in mobile app home banner" : "Archived broadcast notice",
        timestamp: ts,
        badge: a.type.toUpperCase(),
        badgeColor: "bg-blue-50 dark:bg-blue-950/60 text-blue-600 dark:text-blue-400 border-blue-200/50",
        iconColor: "text-blue-500",
        bgColor: "bg-blue-500/10",
        targetUrl: "/announcements",
        extraMeta: a.isActive ? "Active" : "Archived",
      });
    });

    // Sort newest to oldest
    list.sort((a, b) => b.timestamp - a.timestamp);
    return list;
  }, [users, feedbacks, aiSamples, announcements, userPhotos]);

  const filteredEvents = useMemo(() => {
    if (selectedFilter === "all") return events.slice(0, 15);
    return events.filter((e) => e.type === selectedFilter).slice(0, 15);
  }, [events, selectedFilter]);

  // Counts for filter pills
  const counts = useMemo(() => {
    return {
      all: events.length,
      user: events.filter((e) => e.type === "user").length,
      feedback: events.filter((e) => e.type === "feedback").length,
      ai_sample: events.filter((e) => e.type === "ai_sample").length,
      announcement: events.filter((e) => e.type === "announcement").length,
    };
  }, [events]);

  const getEventIcon = (type: PulseEventType) => {
    switch (type) {
      case "user":
        return <UserCheck className="w-4 h-4 text-emerald-500" />;
      case "feedback":
        return <MessageSquare className="w-4 h-4 text-amber-500" />;
      case "ai_sample":
        return <BrainCircuit className="w-4 h-4 text-purple-500" />;
      case "announcement":
        return <Megaphone className="w-4 h-4 text-blue-500" />;
    }
  };

  return (
    <div className="p-6 rounded-3xl bg-white dark:bg-[#1C1D2B] border border-slate-200/70 dark:border-[#282A3D]/80 shadow-xs flex flex-col justify-between hover:shadow-lg transition-all duration-300">
      {/* Header */}
      <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-3 mb-4 pb-4 border-b border-slate-100 dark:border-[#282A3D]">
        <div className="flex items-center gap-2.5">
          <div className="p-2.5 rounded-2xl bg-indigo-50 dark:bg-indigo-950/60 text-indigo-600 dark:text-indigo-400">
            <Activity className="w-5 h-5" />
          </div>
          <div>
            <div className="flex items-center gap-2">
              <h3 className="font-black text-sm text-slate-900 dark:text-white">Live System Activity Pulse</h3>
              <span className="flex items-center gap-1.5 px-2.5 py-0.5 rounded-full text-[10px] font-extrabold bg-emerald-50 dark:bg-emerald-950/60 text-emerald-600 dark:text-emerald-400 border border-emerald-200/60">
                <span className="w-1.5 h-1.5 rounded-full bg-emerald-500 animate-ping"></span>
                Firestore WebSocket Live
              </span>
            </div>
            <p className="text-[11px] text-slate-500 dark:text-slate-400">
              Real-time incoming mobile sync events, OCR extractions, and user feedback
            </p>
          </div>
        </div>

        {/* Filter Pills */}
        <div className="flex items-center gap-1.5 flex-wrap">
          <button
            onClick={() => setSelectedFilter("all")}
            className={`px-3 py-1 rounded-xl text-xs font-bold transition-all ${
              selectedFilter === "all"
                ? "bg-slate-900 text-white dark:bg-white dark:text-slate-900 shadow-xs"
                : "bg-slate-100 dark:bg-[#25273A] text-slate-600 dark:text-slate-300 hover:bg-slate-200 dark:hover:bg-[#2F3146]"
            }`}
          >
            All ({counts.all})
          </button>
          <button
            onClick={() => setSelectedFilter("user")}
            className={`px-2.5 py-1 rounded-xl text-xs font-bold flex items-center gap-1.5 transition-all ${
              selectedFilter === "user"
                ? "bg-emerald-600 text-white shadow-xs"
                : "bg-slate-100 dark:bg-[#25273A] text-slate-600 dark:text-slate-300 hover:bg-slate-200 dark:hover:bg-[#2F3146]"
            }`}
          >
            <span className="w-1.5 h-1.5 rounded-full bg-emerald-500"></span>
            Users ({counts.user})
          </button>
          <button
            onClick={() => setSelectedFilter("feedback")}
            className={`px-2.5 py-1 rounded-xl text-xs font-bold flex items-center gap-1.5 transition-all ${
              selectedFilter === "feedback"
                ? "bg-amber-600 text-white shadow-xs"
                : "bg-slate-100 dark:bg-[#25273A] text-slate-600 dark:text-slate-300 hover:bg-slate-200 dark:hover:bg-[#2F3146]"
            }`}
          >
            <span className="w-1.5 h-1.5 rounded-full bg-amber-500"></span>
            Feedbacks ({counts.feedback})
          </button>
          <button
            onClick={() => setSelectedFilter("ai_sample")}
            className={`px-2.5 py-1 rounded-xl text-xs font-bold flex items-center gap-1.5 transition-all ${
              selectedFilter === "ai_sample"
                ? "bg-purple-600 text-white shadow-xs"
                : "bg-slate-100 dark:bg-[#25273A] text-slate-600 dark:text-slate-300 hover:bg-slate-200 dark:hover:bg-[#2F3146]"
            }`}
          >
            <span className="w-1.5 h-1.5 rounded-full bg-purple-500"></span>
            AI OCR ({counts.ai_sample})
          </button>
        </div>
      </div>

      {/* Live Event Stream List */}
      {filteredEvents.length === 0 ? (
        <div className="py-12 text-center text-slate-400 text-xs">
          No live activity events recorded in this filter.
        </div>
      ) : (
        <div className="space-y-2.5 max-h-96 overflow-y-auto pr-1">
          {filteredEvents.map((evt, idx) => {
            const isHovered = hoveredEventId === evt.id;
            return (
              <Link
                key={evt.id}
                href={evt.targetUrl}
                onMouseEnter={() => setHoveredEventId(evt.id)}
                onMouseLeave={() => setHoveredEventId(null)}
                className={`group flex items-center justify-between gap-3 p-3.5 rounded-2xl border transition-all duration-200 ${
                  isHovered
                    ? "bg-slate-50/90 dark:bg-[#25273A] border-indigo-200 dark:border-indigo-800 shadow-sm translate-x-1"
                    : "bg-white dark:bg-[#1C1D2B] border-slate-100 dark:border-[#282A3D]/70 hover:border-slate-300"
                }`}
              >
                {/* Left: Avatar / Icon + Details */}
                <div className="flex items-center gap-3 min-w-0">
                  <div className="relative shrink-0">
                    {evt.avatarUrl ? (
                      <img
                        src={evt.avatarUrl}
                        alt="User Avatar"
                        className="w-9 h-9 rounded-2xl object-cover ring-1 ring-slate-200 dark:ring-slate-700 shadow-xs"
                        onError={(e) => {
                          (e.currentTarget as HTMLElement).style.display = "none";
                        }}
                      />
                    ) : (
                      <div className={`w-9 h-9 rounded-2xl ${evt.bgColor} flex items-center justify-center font-black text-xs shrink-0 shadow-xs`}>
                        {getEventIcon(evt.type)}
                      </div>
                    )}
                    {/* Small Pulsing Indicator for top recent events */}
                    {idx === 0 && (
                      <span className="absolute -top-1 -right-1 flex h-3 w-3">
                        <span className="animate-ping absolute inline-flex h-full w-full rounded-full bg-emerald-400 opacity-75"></span>
                        <span className="relative inline-flex rounded-full h-3 w-3 bg-emerald-500 border-2 border-white dark:border-[#1C1D2B]"></span>
                      </span>
                    )}
                  </div>

                  <div className="min-w-0">
                    <div className="flex items-center gap-2">
                      <p className="text-xs font-bold text-slate-900 dark:text-white truncate group-hover:text-indigo-600 dark:group-hover:text-indigo-400 transition-colors">
                        {evt.title}
                      </p>
                    </div>
                    <p className="text-[11px] text-slate-500 dark:text-slate-400 truncate mt-0.5">
                      {evt.subtitle}
                    </p>
                  </div>
                </div>

                {/* Right: Badge & Relative Time */}
                <div className="text-right shrink-0 flex flex-col items-end gap-1">
                  <div className="flex items-center gap-1.5">
                    <span className={`px-2 py-0.5 rounded-lg text-[10px] font-extrabold border ${evt.badgeColor}`}>
                      {evt.badge}
                    </span>
                    <ArrowUpRight className="w-3.5 h-3.5 text-slate-400 opacity-0 group-hover:opacity-100 group-hover:translate-x-0.5 group-hover:-translate-y-0.5 transition-all" />
                  </div>
                  <span className="text-[10px] text-slate-400 dark:text-slate-500 font-semibold flex items-center gap-1">
                    <Clock className="w-3 h-3" />
                    {formatRelativeTime(evt.timestamp, now)}
                  </span>
                </div>
              </Link>
            );
          })}
        </div>
      )}

      {/* Footer Quick Insight */}
      <div className="mt-4 pt-3 border-t border-slate-100 dark:border-[#282A3D] flex items-center justify-between text-xs">
        <span className="text-[11px] text-slate-400 font-medium">
          Showing latest {filteredEvents.length} live incoming telemetry records
        </span>
        <span className="text-[11px] font-bold text-indigo-600 dark:text-indigo-400 flex items-center gap-1">
          <Sparkles className="w-3.5 h-3.5" />
          Auto-synchronized with mobile devices
        </span>
      </div>
    </div>
  );
}
