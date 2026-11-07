"use client";

import { useState, useRef, useEffect } from "react";
import Link from "next/link";
import { usePathname, useRouter } from "next/navigation";
import {
  BarChart3,
  MessageSquare,
  Database,
  Users,
  School,
  Megaphone,
  Sliders,
  LogOut,
  Globe,
  PlusCircle,
  Inbox,
  ChevronsUpDown,
  ExternalLink,
  Sparkles,
} from "lucide-react";
import { useAuth } from "@/context/AuthContext";
import { useTheme } from "@/context/ThemeContext";
import { ConfirmModal } from "@/components/ConfirmModal";

export function Sidebar() {
  const pathname = usePathname();
  const router = useRouter();
  const { user, logout } = useAuth();
  const { sidebarCollapsed } = useTheme();
  const [isLogoutModalOpen, setIsLogoutModalOpen] = useState(false);
  const [quickMenuOpen, setQuickMenuOpen] = useState(false);
  const quickMenuRef = useRef<HTMLDivElement>(null);

  useEffect(() => {
    function handleOutside(e: MouseEvent) {
      if (quickMenuRef.current && !quickMenuRef.current.contains(e.target as Node)) {
        setQuickMenuOpen(false);
      }
    }
    document.addEventListener("mousedown", handleOutside);
    return () => document.removeEventListener("mousedown", handleOutside);
  }, []);

  const navGroups = [
    {
      label: "Dashboards",
      items: [
        { href: "/", label: "Analytics", icon: BarChart3 },
        { href: "/users", label: "Customers & Users", icon: Users },
        { href: "/feedbacks", label: "Messages & Reviews", icon: MessageSquare, badge: "Live" },
      ],
    },
    {
      label: "Platform & Content",
      items: [
        { href: "/website", label: "Marketing Website", icon: Globe },
        { href: "/institutions", label: "Institutions & Schools", icon: School },
        { href: "/announcements", label: "Broadcast Notices", icon: Megaphone },
      ],
    },
    {
      label: "AI & Operations",
      items: [
        { href: "/dataset", label: "AI Dataset Lab", icon: Database },
        { href: "/config", label: "App Config & Flags", icon: Sliders },
      ],
    },
  ];

  return (
    <>
      <ConfirmModal
        isOpen={isLogoutModalOpen}
        title="Sign Out of Reminda Studio?"
        message="Are you sure you want to end your administrator session?"
        confirmText="Sign Out"
        cancelText="Cancel"
        onConfirm={async () => {
          setIsLogoutModalOpen(false);
          await logout();
        }}
        onCancel={() => setIsLogoutModalOpen(false)}
      />

      <aside
        className={`${
          sidebarCollapsed ? "w-[68px]" : "w-64"
        } bg-[#FAFAFA] dark:bg-[#09090B] border-r border-zinc-200/80 dark:border-zinc-800/80 flex flex-col justify-between shrink-0 select-none min-h-screen z-30 sticky top-0 h-screen transition-all duration-200 ease-in-out`}
      >
        {/* Top Section */}
        <div className="p-3 space-y-3 overflow-y-auto flex-1">
          {/* Studio Admin Brand Switcher Header */}
          <Link
            href="/"
            className={`flex items-center ${
              sidebarCollapsed ? "justify-center px-0" : "justify-between px-2.5"
            } py-2 rounded-lg hover:bg-zinc-100 dark:hover:bg-zinc-900 transition-colors group`}
          >
            <div className="flex items-center gap-2.5 min-w-0">
              <div className="w-8 h-8 rounded-lg bg-zinc-900 dark:bg-zinc-100 flex items-center justify-center shrink-0 shadow-2xs p-1">
                <img
                  src="/images/Reminda - NoBG.png"
                  alt="Reminda"
                  className="w-full h-full object-contain"
                />
              </div>
              {!sidebarCollapsed && (
                <div className="min-w-0">
                  <div className="flex items-center gap-1.5">
                    <span className="font-bold text-sm text-zinc-900 dark:text-zinc-100 tracking-tight truncate">
                      Reminda Studio
                    </span>
                  </div>
                  <p className="text-[11px] text-zinc-500 dark:text-zinc-400 font-medium truncate">
                    Executive Console · v1.0.0+17
                  </p>
                </div>
              )}
            </div>
            {!sidebarCollapsed && (
              <ChevronsUpDown className="w-4 h-4 text-zinc-400 group-hover:text-zinc-600 dark:group-hover:text-zinc-300 shrink-0" />
            )}
          </Link>

          {/* Studio Admin Quick Create + Inbox Action Row */}
          <div className="relative" ref={quickMenuRef}>
            <div className={`flex items-center gap-1.5 ${sidebarCollapsed ? "flex-col" : ""}`}>
              <button
                type="button"
                onClick={() => setQuickMenuOpen((prev) => !prev)}
                title="Quick Create"
                className={`${
                  sidebarCollapsed ? "w-10 h-9 justify-center px-0" : "flex-1 px-3 py-2 justify-start"
                } rounded-lg bg-zinc-900 hover:bg-zinc-800 text-white dark:bg-zinc-100 dark:hover:bg-zinc-200 dark:text-zinc-950 text-xs font-semibold flex items-center gap-2 shadow-2xs transition-all cursor-pointer`}
              >
                <PlusCircle className="w-4 h-4 shrink-0" />
                {!sidebarCollapsed && <span>Quick Create</span>}
              </button>

              <Link
                href="/feedbacks"
                title="Customer Inbox & Reviews"
                className="w-9 h-9 rounded-lg border border-zinc-200 dark:border-zinc-800 bg-white dark:bg-zinc-900 hover:bg-zinc-100 dark:hover:bg-zinc-800 text-zinc-700 dark:text-zinc-300 flex items-center justify-center shrink-0 shadow-2xs transition-colors"
              >
                <Inbox className="w-4 h-4" />
              </Link>
            </div>

            {/* Quick Create Popover Menu */}
            {quickMenuOpen && (
              <div className="absolute left-0 right-0 mt-1.5 p-1.5 rounded-xl bg-white dark:bg-zinc-900 border border-zinc-200 dark:border-zinc-800 shadow-xl z-50 space-y-0.5 min-w-[200px]">
                <p className="px-2.5 py-1 text-[10px] font-semibold uppercase tracking-wider text-zinc-400">
                  Quick Actions
                </p>
                <button
                  type="button"
                  onClick={() => {
                    setQuickMenuOpen(false);
                    router.push("/announcements");
                  }}
                  className="w-full px-2.5 py-2 rounded-lg text-xs font-medium text-zinc-700 dark:text-zinc-200 hover:bg-zinc-100 dark:hover:bg-zinc-800 flex items-center gap-2.5 text-left cursor-pointer"
                >
                  <Megaphone className="w-3.5 h-3.5 text-zinc-500" />
                  <span>New Broadcast Notice</span>
                </button>
                <button
                  type="button"
                  onClick={() => {
                    setQuickMenuOpen(false);
                    router.push("/institutions");
                  }}
                  className="w-full px-2.5 py-2 rounded-lg text-xs font-medium text-zinc-700 dark:text-zinc-200 hover:bg-zinc-100 dark:hover:bg-zinc-800 flex items-center gap-2.5 text-left cursor-pointer"
                >
                  <School className="w-3.5 h-3.5 text-zinc-500" />
                  <span>Add School / Institution</span>
                </button>
                <button
                  type="button"
                  onClick={() => {
                    setQuickMenuOpen(false);
                    router.push("/dataset");
                  }}
                  className="w-full px-2.5 py-2 rounded-lg text-xs font-medium text-zinc-700 dark:text-zinc-200 hover:bg-zinc-100 dark:hover:bg-zinc-800 flex items-center gap-2.5 text-left cursor-pointer"
                >
                  <Sparkles className="w-3.5 h-3.5 text-zinc-500" />
                  <span>Review AI OCR Dataset</span>
                </button>
                <a
                  href="https://getreminda.vercel.app"
                  target="_blank"
                  rel="noopener noreferrer"
                  onClick={() => setQuickMenuOpen(false)}
                  className="w-full px-2.5 py-2 rounded-lg text-xs font-medium text-zinc-700 dark:text-zinc-200 hover:bg-zinc-100 dark:hover:bg-zinc-800 flex items-center justify-between text-left"
                >
                  <span className="flex items-center gap-2.5">
                    <Globe className="w-3.5 h-3.5 text-zinc-500" />
                    <span>Open Landing Website</span>
                  </span>
                  <ExternalLink className="w-3 h-3 text-zinc-400" />
                </a>
              </div>
            )}
          </div>

          {/* Grouped Navigation Sections */}
          <div className="space-y-4 pt-1">
            {navGroups.map((group) => (
              <div key={group.label} className="space-y-1">
                {!sidebarCollapsed && (
                  <p className="px-2.5 text-[11px] font-medium text-zinc-400 dark:text-zinc-500 tracking-tight">
                    {group.label}
                  </p>
                )}
                <nav className="space-y-0.5">
                  {group.items.map((item) => {
                    const Icon = item.icon;
                    const isActive = pathname === item.href;
                    return (
                      <Link
                        key={item.href}
                        href={item.href}
                        title={sidebarCollapsed ? item.label : undefined}
                        className={`flex items-center ${
                          sidebarCollapsed ? "justify-center px-0 py-2.5" : "justify-between px-2.5 py-2"
                        } rounded-lg text-[13px] font-medium transition-all duration-150 ${
                          isActive
                            ? "bg-zinc-900 text-white dark:bg-zinc-100 dark:text-zinc-950 font-semibold shadow-2xs"
                            : "text-zinc-600 dark:text-zinc-400 hover:text-zinc-950 dark:hover:text-zinc-100 hover:bg-zinc-200/60 dark:hover:bg-zinc-900"
                        }`}
                      >
                        <div className="flex items-center gap-2.5 min-w-0">
                          <Icon
                            className={`w-4 h-4 shrink-0 ${
                              isActive
                                ? "text-white dark:text-zinc-950"
                                : "text-zinc-500 dark:text-zinc-400"
                            }`}
                          />
                          {!sidebarCollapsed && <span className="truncate">{item.label}</span>}
                        </div>

                        {!sidebarCollapsed && item.badge && (
                          <span
                            className={`px-1.5 py-0.5 rounded-md text-[10px] font-semibold leading-none ${
                              isActive
                                ? "bg-white/20 text-white dark:bg-zinc-900/15 dark:text-zinc-900"
                                : "bg-zinc-200/80 dark:bg-zinc-800 text-zinc-600 dark:text-zinc-300"
                            }`}
                          >
                            {item.badge}
                          </span>
                        )}
                      </Link>
                    );
                  })}
                </nav>
              </div>
            ))}
          </div>
        </div>

        {/* Bottom Studio Admin User Account Footer */}
        <div className="p-3 border-t border-zinc-200/80 dark:border-zinc-800/80 space-y-2">
          <div
            className={`flex items-center ${
              sidebarCollapsed ? "justify-center" : "justify-between"
            } p-2 rounded-lg bg-white dark:bg-zinc-900 border border-zinc-200/70 dark:border-zinc-800/80 shadow-2xs`}
          >
            <div className="flex items-center gap-2.5 min-w-0">
              {user?.photoURL ? (
                <img
                  src={user.photoURL}
                  alt="Avatar"
                  referrerPolicy="no-referrer"
                  className="w-8 h-8 rounded-lg object-cover shrink-0 border border-zinc-200 dark:border-zinc-700"
                />
              ) : (
                <div className="w-8 h-8 rounded-lg bg-zinc-900 dark:bg-zinc-100 text-white dark:text-zinc-950 flex items-center justify-center font-bold text-xs shrink-0">
                  {(user?.displayName || "A")[0].toUpperCase()}
                </div>
              )}
              {!sidebarCollapsed && (
                <div className="min-w-0">
                  <p className="text-xs font-semibold text-zinc-900 dark:text-zinc-100 truncate leading-tight">
                    {user?.displayName || "Alfie Polacas"}
                  </p>
                  <p className="text-[10px] text-zinc-500 dark:text-zinc-400 truncate font-mono leading-tight mt-0.5">
                    {user?.email || "alfielynard23@gmail.com"}
                  </p>
                </div>
              )}
            </div>

            {!sidebarCollapsed && (
              <button
                type="button"
                onClick={() => setIsLogoutModalOpen(true)}
                title="Sign Out"
                className="p-1.5 rounded-md text-zinc-400 hover:text-rose-600 dark:hover:text-rose-400 hover:bg-zinc-100 dark:hover:bg-zinc-800 transition-colors cursor-pointer shrink-0"
              >
                <LogOut className="w-4 h-4" />
              </button>
            )}
          </div>
        </div>
      </aside>
    </>
  );
}
