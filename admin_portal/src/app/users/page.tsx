"use client";

import { createPortal } from "react-dom";

import { useEffect, useState } from "react";
import { 
  collection, 
  onSnapshot, 
  query, 
  getDocs,
  doc,
  deleteDoc 
} from "firebase/firestore";
import { db, auth } from "@/lib/firebase";
import { UserAccount, UserProfileDoc, UserScheduleDoc } from "@/lib/types";
import { Header } from "@/components/Header";
import { ConfirmModal } from "@/components/ConfirmModal";
import { SkeletonTable, LoadingSpinner } from "@/components/Skeleton";
import { 
  Users,
  Clock,
  MapPin, 
  Search, 
  Layers, 
  X, 
  Mail, 
  ChevronRight, 
  CheckCircle2, 
  CalendarCheck,
  Trash2,
  Monitor,
  Smartphone,
  Globe
} from "lucide-react";

export const getUserDisplayName = (u: { displayName?: string; name?: string; email?: string } | null | undefined): string => {
  if (!u) return "User";
  const raw = (u.displayName || (u as any).name || "").trim();
  if (raw && raw.toLowerCase() !== "user" && raw.toLowerCase() !== "reminda user") {
    return raw;
  }
  if (u.email && u.email.includes("@")) {
    const handle = u.email.split("@")[0];
    const parts = handle
      .replace(/[._\-+0-9]+/g, " ")
      .trim()
      .split(/\s+/)
      .filter(Boolean);
    if (parts.length > 0) {
      return parts.map((p) => p.charAt(0).toUpperCase() + p.slice(1).toLowerCase()).join(" ");
    }
    return handle.charAt(0).toUpperCase() + handle.slice(1);
  }
  return raw || "Reminda User";
};

export const getPlatformMeta = (platformRaw?: string) => {
  const p = (platformRaw || "").toLowerCase();
  const isDesktop = p.includes("window") || p.includes("mac") || p.includes("linux") || p.includes("pc") || p.includes("desktop");
  const isWeb = p.includes("web");

  if (isDesktop) {
    const osName = p.includes("mac") ? "macOS" : p.includes("linux") ? "Linux" : "Windows";
    return {
      type: "desktop" as const,
      label: "Desktop PC",
      os: osName,
      badgeText: `Desktop (${osName})`,
      fullLabel: `${osName} Desktop App`,
      badgeStyle: "bg-blue-50 text-blue-700 border-blue-200/80 dark:bg-blue-950/60 dark:text-blue-300 dark:border-blue-800/80",
      icon: Monitor,
    };
  }

  if (isWeb) {
    return {
      type: "web" as const,
      label: "Web App",
      os: "Browser",
      badgeText: "Web Browser",
      fullLabel: "Web Browser Client",
      badgeStyle: "bg-amber-50 text-amber-700 border-amber-200/80 dark:bg-amber-950/60 dark:text-amber-300 dark:border-amber-800/80",
      icon: Globe,
    };
  }

  const osName = p.includes("ios") ? "iOS" : "Android";
  return {
    type: "mobile" as const,
    label: "Mobile App",
    os: osName,
    badgeText: `Mobile (${osName})`,
    fullLabel: `${osName} Mobile App`,
    badgeStyle: "bg-emerald-50 text-emerald-700 border-emerald-200/80 dark:bg-emerald-950/60 dark:text-emerald-300 dark:border-emerald-800/80",
    icon: Smartphone,
  };
};

export default function UsersPage() {
  const [users, setUsers] = useState<UserAccount[]>([]);
  const [searchQuery, setSearchQuery] = useState("");
  const [inspectingUser, setInspectingUser] = useState<UserAccount | null>(null);
  useEffect(() => {
    if (inspectingUser) document.body.style.overflow = "hidden";
    else document.body.style.overflow = "";
    return () => { document.body.style.overflow = ""; };
  }, [inspectingUser]);
  const [toastMessage, setToastMessage] = useState<string | null>(null);
  
  // Custom Confirmation Modal State
  const [deleteTarget, setDeleteTarget] = useState<{ id: string; name?: string; displayName?: string; email?: string } | null>(null);

  // Inspector Data State
  const [userProfiles, setUserProfiles] = useState<UserProfileDoc[]>([]);
  const [userSchedules, setUserSchedules] = useState<UserScheduleDoc[]>([]);
  const [isLoadingInspector, setIsLoadingInspector] = useState(false);
  const [isLoading, setIsLoading] = useState(true);
  const [currentPage, setCurrentPage] = useState(1);
  const itemsPerPage = 10;
  const [platformFilter, setPlatformFilter] = useState<"all" | "desktop" | "mobile">("all");

  const desktopCount = users.filter((u) => getPlatformMeta(u.platform).type === "desktop").length;
  const mobileCount = users.filter((u) => getPlatformMeta(u.platform).type === "mobile").length;

  useEffect(() => {
    const q = query(collection(db, "users"));
    const unsub = onSnapshot(q, (snap) => {
      const list: UserAccount[] = [];
      snap.forEach((doc) => {
        list.push({ id: doc.id, ...doc.data() } as UserAccount);
      });
      setUsers(list);
      setIsLoading(false);
    }, (err: any) => {
      console.warn("Users snapshot notice:", err.message);
    });

    return () => unsub();
  }, []);

  const showToast = (msg: string) => {
    setToastMessage(msg);
    setTimeout(() => setToastMessage(null), 3500);
  };

  const handleConfirmDelete = async () => {
    if (!deleteTarget) return;
    try {
      const idToken = await auth.currentUser?.getIdToken();
      const res = await fetch("/api/users/delete", {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          ...(idToken ? { Authorization: `Bearer ${idToken}` } : {}),
        },
        body: JSON.stringify({ uid: deleteTarget.id }),
      });
      const result = await res.json();

      if (!res.ok && !result.success) {
        // Fallback to client-side Firestore deletion if API returned error
        await deleteDoc(doc(db, "users", deleteTarget.id));
      }

      if (inspectingUser && inspectingUser.id === deleteTarget.id) {
        setInspectingUser(null);
      }
      showToast(`User "${deleteTarget.displayName || (deleteTarget as any).name || deleteTarget.email || deleteTarget.id}" permanently deleted.`);
    } catch (err: any) {
      // Fallback
      try {
        await deleteDoc(doc(db, "users", deleteTarget.id));
        showToast(`User "${deleteTarget.displayName || (deleteTarget as any).name || deleteTarget.email || deleteTarget.id}" deleted.`);
      } catch (fallbackErr: any) {
        showToast("Delete failed: " + fallbackErr.message);
      }
    } finally {
      setDeleteTarget(null);
    }
  };

  // Fetch Schedules & Custom Profiles for selected user
  const openInspector = async (user: UserAccount) => {
    setInspectingUser(user);
    setIsLoadingInspector(true);
    setUserProfiles([]);
    setUserSchedules([]);

    try {
      // 1. Fetch Profiles
      const profilesSnap = await getDocs(collection(db, "users", user.id, "profiles"));
      const profs: any[] = [];
      profilesSnap.forEach((d) => profs.push({ id: d.id, ...d.data() }));
      setUserProfiles(profs);

      // 2. Fetch Schedules
      const schedulesSnap = await getDocs(collection(db, "users", user.id, "schedules"));
      const scheds: any[] = [];
      schedulesSnap.forEach((d) => scheds.push({ id: d.id, ...d.data() }));
      setUserSchedules(scheds);
    } catch (err: any) {
      console.error("Inspector error:", err);
    } finally {
      setIsLoadingInspector(false);
    }
  };

  const dayNames = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"];

  const filtered = users.filter((u) => {
    const meta = getPlatformMeta(u.platform);
    if (platformFilter === "desktop" && meta.type !== "desktop") return false;
    if (platformFilter === "mobile" && meta.type !== "mobile") return false;

    const q = searchQuery.toLowerCase().trim();
    if (!q) return true;
    const name = getUserDisplayName(u).toLowerCase();
    const rawName = (u.displayName || (u as any).name || "").toLowerCase();
    const email = (u.email || "").toLowerCase();
    const id = (u.id || "").toLowerCase();
    const platform = (u.platform || "").toLowerCase();
    const fullClient = meta.fullLabel.toLowerCase();

    return (
      name.includes(q) ||
      rawName.includes(q) ||
      email.includes(q) ||
      id.includes(q) ||
      platform.includes(q) ||
      fullClient.includes(q)
    );
  });

  return (
    <>
      <Header title="Customers & User Accounts" />
      <main className="flex-1 px-8 pb-12 space-y-6 max-w-[1600px] w-full">
        {/* Toast */}
        {toastMessage && (
          <div className="fixed bottom-6 right-6 z-50 px-4 py-3 rounded-2xl bg-slate-900 text-white text-xs font-bold shadow-xl flex items-center gap-2.5 animate-bounce">
            <CheckCircle2 className="w-4 h-4 text-emerald-400" />
            <span>{toastMessage}</span>
          </div>
        )}

        {/* Custom Confirmation Modal */}
        <ConfirmModal
          isOpen={!!deleteTarget}
          title="Delete User Account?"
          message={`Are you sure you want to permanently delete the account for "${getUserDisplayName(deleteTarget)}"? This action will remove all their cloud-synced schedule records.`}
          confirmText="Yes, Delete Record"
          cancelText="Keep Account"
          onConfirm={handleConfirmDelete}
          onCancel={() => setDeleteTarget(null)}
        />

        {/* Top Information Bar */}
        <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-4">
          <div>
            <p className="text-xs text-slate-500 dark:text-slate-400 font-semibold">
              Live Registered Reminda Accounts ({users.length} Active). Click any user to inspect their live schedule profiles & classes for customer support troubleshooting.
            </p>
          </div>

          <div className="flex items-center gap-2">
            <span className="inline-flex items-center gap-1.5 px-3 py-1.5 rounded-2xl bg-blue-50 dark:bg-blue-950/40 border border-blue-200/80 dark:border-blue-800/80 text-xs font-bold text-blue-700 dark:text-blue-300 shadow-2xs">
              <Monitor className="w-3.5 h-3.5 text-blue-600 dark:text-blue-400" />
              <span>Desktop: {desktopCount}</span>
            </span>

            <span className="inline-flex items-center gap-1.5 px-3 py-1.5 rounded-2xl bg-emerald-50 dark:bg-emerald-950/40 border border-emerald-200/80 dark:border-emerald-800/80 text-xs font-bold text-emerald-700 dark:text-emerald-300 shadow-2xs">
              <Smartphone className="w-3.5 h-3.5 text-emerald-600 dark:text-emerald-400" />
              <span>Mobile: {mobileCount}</span>
            </span>

            <div className="px-3.5 py-1.5 rounded-2xl bg-white dark:bg-[#1C1D2B] border border-slate-200 dark:border-[#282A3D] text-xs font-bold text-slate-700 dark:text-slate-300 shadow-2xs">
              Total: {users.length}
            </div>
          </div>
        </div>

        {/* Search & Platform Filter Bar */}
        <div className="flex flex-col md:flex-row md:items-center justify-between gap-3 p-4 rounded-3xl bg-white dark:bg-[#1C1D2B] border border-slate-200 dark:border-[#282A3D]/70 shadow-xs">
          <div className="flex items-center gap-1 p-1 bg-slate-100 dark:bg-[#25273A]/80 rounded-2xl shrink-0 overflow-x-auto">
            <button
              onClick={() => setPlatformFilter("all")}
              className={`px-3 py-1.5 rounded-xl font-bold text-xs transition-all ${
                platformFilter === "all"
                  ? "bg-white dark:bg-[#1C1D2B] text-slate-900 dark:text-white shadow-xs"
                  : "text-slate-500 hover:text-slate-800 dark:text-slate-400"
              }`}
            >
              All Clients ({users.length})
            </button>

            <button
              onClick={() => setPlatformFilter("desktop")}
              className={`flex items-center gap-1.5 px-3 py-1.5 rounded-xl font-bold text-xs transition-all ${
                platformFilter === "desktop"
                  ? "bg-blue-600 text-white shadow-xs"
                  : "text-slate-500 hover:text-slate-800 dark:text-slate-400"
              }`}
            >
              <Monitor className="w-3.5 h-3.5" />
              <span>Desktop / PC ({desktopCount})</span>
            </button>

            <button
              onClick={() => setPlatformFilter("mobile")}
              className={`flex items-center gap-1.5 px-3 py-1.5 rounded-xl font-bold text-xs transition-all ${
                platformFilter === "mobile"
                  ? "bg-emerald-600 text-white shadow-xs"
                  : "text-slate-500 hover:text-slate-800 dark:text-slate-400"
              }`}
            >
              <Smartphone className="w-3.5 h-3.5" />
              <span>Mobile ({mobileCount})</span>
            </button>
          </div>

          <div className="relative w-full md:max-w-md">
            <Search className="w-4 h-4 text-slate-400 absolute left-3.5 top-1/2 -translate-y-1/2" />
            <input
              type="text"
              placeholder="Search by name, email, platform, or UID..."
              value={searchQuery}
              onChange={(e) => setSearchQuery(e.target.value)}
              className="w-full pl-10 pr-4 py-2 rounded-2xl bg-slate-50 dark:bg-[#25273A]/60 border border-slate-200 dark:border-[#282A3D]/70 text-slate-900 dark:text-white text-xs placeholder-slate-400 focus:outline-none focus:border-blue-500"
            />
          </div>
        </div>

        {/* Users Table */}
        {isLoading ? (
          <SkeletonTable rows={5} />
        ) : filtered.length === 0 ? (
          <div className="py-20 text-center rounded-3xl bg-white dark:bg-[#1C1D2B] border border-slate-200 dark:border-[#282A3D] text-slate-400 text-xs space-y-2">
            <Users className="w-10 h-10 mx-auto text-slate-300" />
            <p className="font-bold text-sm text-slate-800 dark:text-slate-200">No registered users yet</p>
            <p className="text-slate-400">Users who open Reminda or log in on Android/iOS will automatically appear here in real time.</p>
          </div>
        ) : (
          <div className="rounded-3xl bg-white dark:bg-[#1C1D2B] border border-slate-200 dark:border-[#282A3D]/70 shadow-xs overflow-hidden">
            <div className="overflow-x-auto">
              <table className="w-full text-left text-xs">
                <thead>
                  <tr className="bg-slate-50 dark:bg-[#25273A]/60/80 border-b border-slate-200 dark:border-[#282A3D]/70 text-[11px] font-bold text-slate-500 dark:text-slate-400 uppercase tracking-wider">
                    <th className="py-3.5 px-6">Customer / User</th>
                    <th className="py-3.5 px-6">Email Address</th>
                    <th className="py-3.5 px-6">Platform & Client</th>
                    <th className="py-3.5 px-6">Firebase User ID</th>
                    <th className="py-3.5 px-6 text-right">Actions</th>
                  </tr>
                </thead>
                <tbody className="divide-y divide-slate-100 dark:divide-[#282A3D] font-medium text-slate-700 dark:text-slate-300">
                  {filtered.map((u) => {
                    const userDisplayName = getUserDisplayName(u);
                    const meta = getPlatformMeta(u.platform);
                    const Icon = meta.icon;
                    return (
                      <tr
                        key={u.id}
                        onClick={() => openInspector(u)}
                        className="hover:bg-blue-50/40 cursor-pointer transition-colors"
                      >
                        <td className="py-4 px-6">
                          <div className="flex items-center gap-3">
                            {u.photoUrl ? (
                              <img
                                src={u.photoUrl}
                                alt={userDisplayName}
                                className="w-9 h-9 rounded-full object-cover border border-slate-200 dark:border-[#282A3D] shadow-xs shrink-0"
                                referrerPolicy="no-referrer"
                              />
                            ) : (
                              <div className="w-9 h-9 rounded-full bg-linear-to-tr from-blue-600 to-indigo-600 text-white flex items-center justify-center font-black text-xs shadow-xs shrink-0">
                                {(userDisplayName || u.email || "U")[0].toUpperCase()}
                              </div>
                            )}
                            <div>
                              <p className="font-extrabold text-slate-900 dark:text-white text-xs">{userDisplayName}</p>
                              <p className="text-[10px] text-slate-400 dark:text-slate-300 font-mono">UID: {u.id.slice(0, 10)}...</p>
                            </div>
                          </div>
                        </td>

                        <td className="py-4 px-6 text-slate-600 dark:text-slate-400 font-mono text-xs">
                          {u.email || "Anonymous Account"}
                        </td>

                        <td className="py-4 px-6 text-xs">
                          <div className="flex flex-col gap-1 items-start">
                            <span className={`inline-flex items-center gap-1.5 px-2.5 py-1 rounded-xl font-bold text-[11px] border shadow-2xs ${meta.badgeStyle}`}>
                              <Icon className="w-3.5 h-3.5 shrink-0" />
                              <span>{meta.badgeText}</span>
                            </span>
                            <span className="font-mono text-[10px] text-slate-400 dark:text-slate-300 pl-1 font-semibold">
                              {u.appVersion || "v1.0.0"}
                            </span>
                          </div>
                        </td>

                        <td className="py-4 px-6 font-mono text-slate-400 text-[11px]">
                          {u.id}
                        </td>

                        <td className="py-4 px-6 text-right">
                          <div className="flex items-center justify-end gap-2">
                            <span className="px-3 py-1.5 rounded-xl bg-blue-50 hover:bg-blue-100 text-blue-700 font-bold text-[11px] inline-flex items-center gap-1 transition-colors">
                              <span>Inspect</span>
                              <ChevronRight className="w-3.5 h-3.5" />
                            </span>

                            <button
                              onClick={(e) => {
                                e.stopPropagation();
                                setDeleteTarget({ id: u.id, name: userDisplayName });
                              }}
                              className="p-1.5 rounded-xl text-slate-400 hover:text-red-600 hover:bg-red-50 transition-colors"
                              title="Delete User Record"
                            >
                              <Trash2 className="w-4 h-4" />
                            </button>
                          </div>
                        </td>
                      </tr>
                    );
                  })}
                </tbody>
              </table>
            </div>
          </div>
        )}

        {/* User Schedule Inspector Drawer / Modal */}
        {inspectingUser && typeof document !== "undefined" && createPortal(
          <div className="fixed inset-0 z-9999 bg-black/70 backdrop-blur-sm flex items-center justify-center p-4 overflow-y-auto animate-in fade-in duration-150">
            <div className="w-full max-w-3xl bg-white dark:bg-[#1C1D2B] rounded-3xl p-6 shadow-2xl border border-slate-200 dark:border-[#282A3D] space-y-5 animate-in fade-in zoom-in-95 max-h-[90vh] overflow-y-auto">
              {/* Header */}
              <div className="flex items-start justify-between pb-4 border-b border-slate-100 dark:border-[#282A3D]">
                <div className="flex items-center gap-3">
                  {inspectingUser.photoUrl ? (
                    <img
                      src={inspectingUser.photoUrl}
                      alt={getUserDisplayName(inspectingUser)}
                      className="w-12 h-12 rounded-2xl object-cover border border-slate-200 dark:border-[#282A3D] shadow-md shadow-blue-500/20 shrink-0"
                      referrerPolicy="no-referrer"
                    />
                  ) : (
                    <div className="w-12 h-12 rounded-2xl bg-linear-to-tr from-blue-600 to-indigo-600 text-white flex items-center justify-center font-black text-sm shadow-md shadow-blue-500/20 shrink-0">
                      {(getUserDisplayName(inspectingUser) || inspectingUser.email || "U")[0].toUpperCase()}
                    </div>
                  )}
                  <div>
                    <h3 className="font-extrabold text-base text-slate-900 dark:text-white">
                      {getUserDisplayName(inspectingUser)}
                    </h3>
                    <p className="text-xs text-slate-400 dark:text-slate-300 font-mono flex items-center gap-1.5">
                      <Mail className="w-3.5 h-3.5" />
                      {inspectingUser.email}
                    </p>
                    {(() => {
                      const meta = getPlatformMeta(inspectingUser.platform);
                      const Icon = meta.icon;
                      return (
                        <div className="flex items-center gap-2 mt-1.5">
                          <span className={`inline-flex items-center gap-1.5 px-2.5 py-0.5 rounded-lg text-[10px] font-bold border ${meta.badgeStyle}`}>
                            <Icon className="w-3.5 h-3.5" />
                            <span>{meta.fullLabel}</span>
                          </span>
                        </div>
                      );
                    })()}
                  </div>
                </div>

                <button
                  onClick={() => setInspectingUser(null)}
                  className="p-2 rounded-xl hover:bg-slate-100 dark:bg-[#25273A] text-slate-400 transition-colors"
                >
                  <X className="w-5 h-5" />
                </button>
              </div>

              {/* Statistics summary */}
              <div className="grid grid-cols-2 sm:grid-cols-4 gap-3 text-xs">
                <div className="p-3.5 rounded-2xl bg-blue-50/60 dark:bg-blue-950/40 border border-blue-100/80 dark:border-blue-900/60">
                  <p className="font-bold text-blue-700 dark:text-blue-300 text-[10px] uppercase tracking-wider">Schedule Profiles</p>
                  <p className="text-lg font-black text-slate-900 dark:text-white mt-0.5">{userProfiles.length}</p>
                </div>
                <div className="p-3.5 rounded-2xl bg-emerald-50/60 dark:bg-emerald-950/40 border border-emerald-100/80 dark:border-emerald-900/60">
                  <p className="font-bold text-emerald-700 dark:text-emerald-300 text-[10px] uppercase tracking-wider">Total Active Classes</p>
                  <p className="text-lg font-black text-slate-900 dark:text-white mt-0.5">{userSchedules.length}</p>
                </div>
                <div className="p-3.5 rounded-2xl bg-indigo-50/60 dark:bg-indigo-950/40 border border-indigo-100/80 dark:border-indigo-900/60">
                  <p className="font-bold text-indigo-700 dark:text-indigo-300 text-[10px] uppercase tracking-wider">Device & Client</p>
                  {(() => {
                    const meta = getPlatformMeta(inspectingUser.platform);
                    const Icon = meta.icon;
                    return (
                      <div className="flex items-center gap-1.5 mt-1 font-black text-slate-900 dark:text-white text-xs">
                        <Icon className="w-4 h-4 text-indigo-600 dark:text-indigo-400 shrink-0" />
                        <span className="truncate">{meta.badgeText}</span>
                      </div>
                    );
                  })()}
                </div>
                <div className="p-3.5 rounded-2xl bg-purple-50/60 dark:bg-purple-950/40 border border-purple-100/80 dark:border-purple-900/60">
                  <p className="font-bold text-purple-700 dark:text-purple-300 text-[10px] uppercase tracking-wider">App Version</p>
                  <p className="text-lg font-black text-slate-900 dark:text-white mt-0.5 font-mono">{inspectingUser.appVersion || "v1.0.0+15"}</p>
                </div>
              </div>

              {isLoadingInspector ? (
                <LoadingSpinner label="Fetching user schedules & profiles from cloud..." className="py-8" />
              ) : (
                <>
              {/* Profiles Section */}
              <div className="space-y-2">
                <h4 className="font-extrabold text-xs text-slate-900 dark:text-white flex items-center gap-1.5">
                  <Layers className="w-4 h-4 text-blue-600" />
                  <span>Custom Schedule Profiles ({userProfiles.length})</span>
                </h4>

                {userProfiles.length === 0 ? (
                  <p className="text-xs text-slate-400 p-4 rounded-2xl bg-slate-50 dark:bg-[#25273A]/60 border border-slate-100 dark:border-[#282A3D]">
                    No custom profiles synced in cloud for this user.
                  </p>
                ) : (
                  <div className="grid grid-cols-1 sm:grid-cols-2 gap-3 text-xs">
                    {userProfiles.map((p) => (
                      <div key={p.id} className="p-3.5 rounded-2xl bg-slate-50 dark:bg-[#25273A]/60 border border-slate-200 dark:border-[#282A3D]/70 space-y-1">
                        <div className="flex items-center justify-between">
                          <p className="font-extrabold text-slate-900 dark:text-white">{p.name || "Default Profile"}</p>
                          {(p.isCurrent || p.isActive) && (
                            <span className="px-2 py-0.5 rounded-md bg-emerald-100 text-emerald-800 font-bold text-[9px]">
                              Active Profile
                            </span>
                          )}
                        </div>
                        <p className="text-[11px] text-slate-500 dark:text-slate-400">
                          {p.institutionName || p.type || "Standard"} • <span className="font-semibold text-slate-700 dark:text-slate-300">{p.role || p.category || "Schedule"}</span>
                        </p>
                      </div>
                    ))}
                  </div>
                )}
              </div>

              {/* Timetables / Classes Section */}
              <div className="space-y-2">
                <h4 className="font-extrabold text-xs text-slate-900 dark:text-white flex items-center gap-1.5">
                  <CalendarCheck className="w-4 h-4 text-indigo-600" />
                  <span>Timetable Classes & Duty Shifts ({userSchedules.length})</span>
                </h4>

                {userSchedules.length === 0 ? (
                  <p className="text-xs text-slate-400 p-4 rounded-2xl bg-slate-50 dark:bg-[#25273A]/60 border border-slate-100 dark:border-[#282A3D]">
                    No schedules or classes currently in Firestore.
                  </p>
                ) : (
                  <div className="space-y-2 max-h-60 overflow-y-auto pr-1">
                    {userSchedules.map((s) => (
                      <div
                        key={s.id}
                        className="p-3 rounded-2xl bg-white border border-slate-200 dark:border-[#282A3D] text-xs flex items-center justify-between hover:border-blue-300 transition-colors"
                      >
                        <div>
                          <p className="font-extrabold text-slate-900 dark:text-white">{s.title}</p>
                          <p className="text-[11px] text-slate-500 dark:text-slate-400 flex items-center gap-2 mt-0.5">
                            <span className="flex items-center gap-1"><Clock className="w-3.5 h-3.5 text-slate-400" /> {s.startTime} - {s.endTime}</span>
                            <span>•</span>
                            <span className="flex items-center gap-1"><MapPin className="w-3.5 h-3.5 text-slate-400" /> {s.location || "Online / TBA"}</span>
                          </p>
                        </div>

                        <div className="flex items-center gap-1">
                          {s.daysOfWeek?.map((d) => (
                            <span
                              key={d}
                              className="w-5 h-5 rounded-md bg-blue-50 text-blue-700 font-black text-[9px] flex items-center justify-center"
                            >
                              {dayNames[d] ? dayNames[d][0] : d}
                            </span>
                          ))}
                        </div>
                      </div>
                    ))}
                  </div>
                )}
              </div>

              </>
              )}

              {/* Footer */}
              <div className="flex items-center justify-between pt-3 border-t border-slate-100 dark:border-[#282A3D] text-xs">
                <div className="flex items-center gap-2">
                  <button
                    onClick={() => setDeleteTarget({ id: inspectingUser.id, name: inspectingUser.displayName || inspectingUser.email })}
                    className="px-3 py-1.5 rounded-xl bg-red-50 hover:bg-red-100 text-red-600 font-bold text-xs flex items-center gap-1.5 transition-colors"
                  >
                    <Trash2 className="w-3.5 h-3.5" />
                    <span>Delete User Record</span>
                  </button>
                  <span className="text-[10px] text-slate-400 dark:text-slate-300 font-mono">User ID: {inspectingUser.id}</span>
                </div>
                <a
                  href={`mailto:${inspectingUser.email}?subject=Reminda Support Assistance`}
                  className="px-4 py-2 rounded-xl bg-slate-900 hover:bg-slate-800 text-white font-bold text-xs flex items-center gap-1.5"
                >
                  <Mail className="w-3.5 h-3.5" />
                  <span>Email User</span>
                </a>
              </div>
            </div>
          </div>,
          document.body
        )}
      </main>
    </>
  );
}
