"use client";

import { useState, useEffect } from "react";
import { useRouter, usePathname } from "next/navigation";
import {
  Calendar,
  Sun,
  Moon,
  RefreshCw,
  PanelLeft,
  Search,
  ExternalLink,
  BarChart3,
  Globe,
  School,
  Megaphone,
  Sliders,
  Database,
  MessageSquare,
  Users,
  ArrowRight,
  X,
} from "lucide-react";
import { format } from "date-fns";
import { useAuth } from "@/context/AuthContext";
import { useTheme } from "@/context/ThemeContext";

const COMMAND_ROUTES = [
  { href: "/", label: "Analytics Dashboard", group: "Dashboards", icon: BarChart3 },
  { href: "/users", label: "Customers & User Accounts", group: "Dashboards", icon: Users },
  { href: "/feedbacks", label: "Messages & User Reviews", group: "Dashboards", icon: MessageSquare },
  { href: "/website", label: "Marketing Website CMS", group: "Platform & Content", icon: Globe },
  { href: "/institutions", label: "Institutions & Schools Directory", group: "Platform & Content", icon: School },
  { href: "/announcements", label: "Broadcast Notices & Banners", group: "Platform & Content", icon: Megaphone },
  { href: "/dataset", label: "AI Training Dataset & Annotation Lab", group: "AI & Operations", icon: Database },
  { href: "/config", label: "Remote App Config & Feature Flags", group: "AI & Operations", icon: Sliders },
];

export function Header({
  title = "Analytics",
  onRefresh,
}: {
  title?: string;
  onRefresh?: () => void;
}) {
  const currentDateStr = `${format(new Date(), "MMM dd, yyyy")} · Today`;
  const { user } = useAuth();
  const { theme, toggleTheme, toggleSidebar } = useTheme();
  const router = useRouter();
  const pathname = usePathname();
  const [searchOpen, setSearchOpen] = useState(false);
  const [searchQuery, setSearchQuery] = useState("");

  useEffect(() => {
    function handleKeyDown(e: KeyboardEvent) {
      if ((e.metaKey || e.ctrlKey) && e.key.toLowerCase() === "k") {
        e.preventDefault();
        setSearchOpen((prev) => !prev);
      } else if (e.key === "Escape") {
        setSearchOpen(false);
      }
    }
    window.addEventListener("keydown", handleKeyDown);
    return () => window.removeEventListener("keydown", handleKeyDown);
  }, []);

  const filteredRoutes = COMMAND_ROUTES.filter(
    (r) =>
      r.label.toLowerCase().includes(searchQuery.toLowerCase()) ||
      r.group.toLowerCase().includes(searchQuery.toLowerCase())
  );

  const sectionCategory =
    pathname === "/" || pathname === "/users" || pathname === "/feedbacks"
      ? "Dashboards"
      : pathname === "/dataset" || pathname === "/config"
      ? "AI & Operations"
      : "Platform";

  return (
    <>
      {/* Studio Admin Top Sticky Command Navbar */}
      <header className="sticky top-0 z-20 h-14 px-6 bg-white/90 dark:bg-[#09090B]/90 backdrop-blur-md border-b border-zinc-200/80 dark:border-zinc-800/80 flex items-center justify-between gap-4">
        {/* Left: Sidebar Trigger + Divider + Breadcrumb */}
        <div className="flex items-center gap-3 min-w-0">
          <button
            type="button"
            onClick={toggleSidebar}
            title="Toggle Sidebar"
            className="p-1.5 rounded-lg text-zinc-500 hover:text-zinc-900 dark:text-zinc-400 dark:hover:text-zinc-100 hover:bg-zinc-100 dark:hover:bg-zinc-800 transition-colors cursor-pointer"
          >
            <PanelLeft className="w-4 h-4" />
          </button>

          <div className="h-4 w-px bg-zinc-200 dark:bg-zinc-800 shrink-0" />

          <div className="flex items-center gap-2 text-xs font-medium min-w-0">
            <span className="text-zinc-400 dark:text-zinc-500 hidden sm:inline">
              {sectionCategory}
            </span>
            <span className="text-zinc-300 dark:text-zinc-700 hidden sm:inline">/</span>
            <h1 className="text-sm font-semibold text-zinc-900 dark:text-zinc-100 truncate">
              {title}
            </h1>
          </div>
        </div>

        {/* Right: Studio Admin Command Search + Date + Theme + Profile */}
        <div className="flex items-center gap-2.5">
          {/* Search Command Trigger (⌘K) */}
          <button
            type="button"
            onClick={() => setSearchOpen(true)}
            className="hidden md:flex items-center justify-between gap-6 px-3 py-1.5 rounded-lg bg-zinc-100/80 dark:bg-zinc-900 hover:bg-zinc-200/70 dark:hover:bg-zinc-800 border border-zinc-200/80 dark:border-zinc-800 text-zinc-500 dark:text-zinc-400 text-xs transition-colors cursor-pointer"
          >
            <span className="flex items-center gap-2">
              <Search className="w-3.5 h-3.5 text-zinc-400" />
              <span>Search pages...</span>
            </span>
            <kbd className="px-1.5 py-0.5 text-[10px] font-mono font-semibold bg-white dark:bg-zinc-950 text-zinc-500 dark:text-zinc-400 rounded border border-zinc-200 dark:border-zinc-800 shadow-2xs">
              ⌘K
            </kbd>
          </button>

          {/* Date Pill */}
          <div className="hidden lg:flex items-center gap-2 px-3 py-1.5 rounded-lg bg-white dark:bg-zinc-900 border border-zinc-200/80 dark:border-zinc-800 text-zinc-600 dark:text-zinc-300 text-xs font-medium shadow-2xs">
            <Calendar className="w-3.5 h-3.5 text-zinc-400" />
            <span>{currentDateStr}</span>
          </div>

          {/* Live Website Quick Link */}
          <a
            href="https://getreminda.vercel.app"
            target="_blank"
            rel="noopener noreferrer"
            title="Open Reminda Landing Page"
            className="hidden sm:flex items-center gap-1.5 px-2.5 py-1.5 rounded-lg bg-white dark:bg-zinc-900 hover:bg-zinc-100 dark:hover:bg-zinc-800 border border-zinc-200/80 dark:border-zinc-800 text-zinc-700 dark:text-zinc-300 text-xs font-medium transition-colors shadow-2xs"
          >
            <span>Landing</span>
            <ExternalLink className="w-3 h-3 text-zinc-400" />
          </a>

          {onRefresh && (
            <button
              onClick={onRefresh}
              className="p-2 rounded-lg bg-white dark:bg-zinc-900 hover:bg-zinc-100 dark:hover:bg-zinc-800 border border-zinc-200/80 dark:border-zinc-800 text-zinc-600 dark:text-zinc-400 transition-colors shadow-2xs cursor-pointer"
              title="Refresh Data"
            >
              <RefreshCw className="w-3.5 h-3.5" />
            </button>
          )}

          {/* Studio Admin Theme Toggle Button */}
          <button
            type="button"
            onClick={toggleTheme}
            className="p-2 rounded-lg bg-white dark:bg-zinc-900 hover:bg-zinc-100 dark:hover:bg-zinc-800 border border-zinc-200/80 dark:border-zinc-800 text-zinc-700 dark:text-zinc-300 transition-colors shadow-2xs cursor-pointer"
            title={`Switch to ${theme === "light" ? "Dark" : "Light"} mode`}
          >
            {theme === "light" ? (
              <Moon className="w-3.5 h-3.5" />
            ) : (
              <Sun className="w-3.5 h-3.5" />
            )}
          </button>

          {/* Compact User Avatar */}
          <div className="flex items-center gap-2 pl-1">
            {user?.photoURL ? (
              <img
                src={user.photoURL}
                alt="Avatar"
                referrerPolicy="no-referrer"
                className="w-7 h-7 rounded-full object-cover border border-zinc-200 dark:border-zinc-700"
              />
            ) : (
              <div className="w-7 h-7 rounded-full bg-zinc-900 dark:bg-zinc-100 text-white dark:text-zinc-950 flex items-center justify-center font-bold text-xs">
                {(user?.displayName || "A")[0].toUpperCase()}
              </div>
            )}
          </div>
        </div>
      </header>

      {/* Studio Admin Inner Page Heading Banner */}
      {pathname !== "/" && pathname !== "/website" && title && (
        <div className="px-8 pt-6 pb-2 max-w-[1600px] w-full mx-auto">
          <h1 className="text-xl sm:text-2xl font-bold tracking-tight text-zinc-900 dark:text-zinc-100">
            {title}
          </h1>
        </div>
      )}

      {/* Studio Admin Command Palette Modal (⌘K) */}
      {searchOpen && (
        <div
          onClick={() => setSearchOpen(false)}
          className="fixed inset-0 z-50 bg-black/50 backdrop-blur-xs flex items-start justify-center pt-24 p-4 animate-in fade-in duration-150"
        >
          <div
            onClick={(e) => e.stopPropagation()}
            className="w-full max-w-lg rounded-xl bg-white dark:bg-zinc-900 border border-zinc-200 dark:border-zinc-800 shadow-2xl overflow-hidden"
          >
            <div className="flex items-center gap-3 px-4 py-3 border-b border-zinc-200 dark:border-zinc-800">
              <Search className="w-4 h-4 text-zinc-400 shrink-0" />
              <input
                type="text"
                autoFocus
                value={searchQuery}
                onChange={(e) => setSearchQuery(e.target.value)}
                placeholder="Type a command or search pages..."
                className="w-full bg-transparent text-sm text-zinc-900 dark:text-zinc-100 placeholder:text-zinc-400 focus:outline-none"
              />
              <button
                type="button"
                onClick={() => setSearchOpen(false)}
                className="p-1 rounded-md text-zinc-400 hover:text-zinc-600 dark:hover:text-zinc-200"
              >
                <X className="w-4 h-4" />
              </button>
            </div>

            <div className="max-h-80 overflow-y-auto p-2 space-y-1">
              {filteredRoutes.length === 0 ? (
                <p className="py-8 text-center text-xs text-zinc-400">
                  No matching pages found.
                </p>
              ) : (
                filteredRoutes.map((route) => {
                  const Icon = route.icon;
                  const active = pathname === route.href;
                  return (
                    <button
                      key={route.href}
                      type="button"
                      onClick={() => {
                        setSearchOpen(false);
                        setSearchQuery("");
                        router.push(route.href);
                      }}
                      className={`w-full px-3 py-2.5 rounded-lg text-left flex items-center justify-between text-xs font-medium transition-colors cursor-pointer ${
                        active
                          ? "bg-zinc-900 text-white dark:bg-zinc-100 dark:text-zinc-950"
                          : "text-zinc-700 dark:text-zinc-300 hover:bg-zinc-100 dark:hover:bg-zinc-800"
                      }`}
                    >
                      <div className="flex items-center gap-3">
                        <Icon className="w-4 h-4 shrink-0 opacity-75" />
                        <div>
                          <p className="font-semibold">{route.label}</p>
                          <p
                            className={`text-[10px] ${
                              active ? "opacity-75" : "text-zinc-400"
                            }`}
                          >
                            {route.group}
                          </p>
                        </div>
                      </div>
                      <ArrowRight className="w-3.5 h-3.5 opacity-60" />
                    </button>
                  );
                })
              )}
            </div>
          </div>
        </div>
      )}
    </>
  );
}
