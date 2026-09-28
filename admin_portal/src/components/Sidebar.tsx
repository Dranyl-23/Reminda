"use client";

import { useState } from "react";
import Link from "next/link";
import { usePathname } from "next/navigation";
import { 
  LayoutGrid, 
  MessageSquare, 
  Database, 
  Users, 
  School,
  Megaphone,
  Sliders,
  LogOut,
  Globe
} from "lucide-react";
import { useAuth } from "@/context/AuthContext";
import { ConfirmModal } from "@/components/ConfirmModal";

export function Sidebar() {
  const pathname = usePathname();
  const { logout } = useAuth();
  const [isLogoutModalOpen, setIsLogoutModalOpen] = useState(false);

  const mainNav = [
    { href: "/", label: "Analytics", icon: LayoutGrid },
    { href: "/website", label: "Marketing Website", icon: Globe },
    { href: "/institutions", label: "Institutions & Schools", icon: School },
    { href: "/announcements", label: "Broadcast Notices", icon: Megaphone },
    { href: "/config", label: "App Config & Flags", icon: Sliders },
    { href: "/dataset", label: "AI Dataset Lab", icon: Database },
    { href: "/feedbacks", label: "Messages & Reviews", icon: MessageSquare },
    { href: "/users", label: "Customers & Users", icon: Users },
  ];

  return (
    <>
      {/* Custom Clean Logout Confirmation Modal */}
      <ConfirmModal
        isOpen={isLogoutModalOpen}
        title="Sign Out of Reminda?"
        message="Are you sure you want to sign out of your administrator executive session?"
        confirmText="Yes, Sign Out"
        cancelText="Stay Signed In"
        onConfirm={async () => {
          setIsLogoutModalOpen(false);
          await logout();
        }}
        onCancel={() => setIsLogoutModalOpen(false)}
      />

      <aside className="w-64 bg-white dark:bg-[#14151F] border-r border-slate-200/80 dark:border-[#202231] flex flex-col justify-between shrink-0 select-none min-h-screen p-5 z-20 sticky top-0 h-screen transition-colors duration-300">
        <div>
          {/* Brand Header */}
          <div className="flex items-center gap-3 px-2 py-3 mb-6">
            <div className="w-10 h-10 flex items-center justify-center">
              <img
                src="/images/Reminda - NoBG.png"
                alt="Reminda Logo"
                className="w-full h-full object-contain drop-shadow-sm"
              />
            </div>
            <div>
              <h1 className="font-extrabold text-lg text-slate-900 dark:text-white tracking-tight flex items-center gap-1.5">
                Reminda
              </h1>
              <p className="text-[11px] text-slate-500 dark:text-[#9499B0] font-semibold">Executive Portal</p>
            </div>
          </div>

          {/* Navigation Items */}
          <nav className="space-y-1.5">
            {mainNav.map((item) => {
              const Icon = item.icon;
              const isActive = pathname === item.href;
              return (
                <Link
                  key={item.href}
                  href={item.href}
                  className={`flex items-center gap-3.5 px-4 py-3 rounded-2xl text-sm font-bold transition-all duration-200 ${
                    isActive
                      ? "bg-blue-50 text-blue-600 dark:bg-white dark:text-slate-950 shadow-md shadow-black/10"
                      : "text-slate-700 dark:text-[#9499B0] hover:text-slate-900 dark:hover:text-white hover:bg-slate-50 dark:hover:bg-[#1C1D2B]"
                  }`}
                >
                  <Icon className={`w-5 h-5 ${
                    isActive 
                      ? "text-blue-600 dark:text-slate-950" 
                      : "text-slate-600 dark:text-[#9499B0]"
                  }`} />
                  {item.label}
                </Link>
              );
            })}
          </nav>

          {/* Divider */}
          <div className="my-6 border-t border-slate-100 dark:border-[#202231]" />

          {/* Secondary Links */}
          <div className="space-y-1">
            <button
              onClick={() => setIsLogoutModalOpen(true)}
              className="w-full flex items-center gap-3.5 px-4 py-2.5 rounded-2xl text-sm font-semibold text-slate-700 dark:text-[#9499B0] hover:text-red-600 dark:hover:text-rose-400 hover:bg-red-50/50 dark:hover:bg-[#1C1D2B] transition-colors text-left cursor-pointer"
            >
              <LogOut className="w-5 h-5 text-slate-600 dark:text-[#9499B0]" />
              Sign Out
            </button>
          </div>
        </div>

        {/* 3D Mascot Contact Support Card */}
        <div className="relative mt-8 p-4 rounded-3xl bg-linear-to-b from-blue-50/80 to-indigo-50/50 dark:from-[#1C1D2B] dark:to-[#1C1D2B]/80 border border-blue-100/60 dark:border-[#282A3D] overflow-hidden shadow-sm">
          <div className="relative z-10 flex flex-col items-start pr-12">
            <p className="text-[12px] font-bold text-slate-800 dark:text-slate-200 leading-snug">Need help?</p>
            <p className="text-[10px] text-slate-500 dark:text-[#9499B0] mb-3">Feel free to contact</p>
            <a
              href="mailto:alfielynard23@gmail.com"
              className="px-3.5 py-1.5 rounded-xl bg-blue-600 hover:bg-blue-700 text-white font-extrabold text-[11px] shadow-sm shadow-blue-600/20 transition-colors"
            >
              Get support
            </a>
          </div>
          <div className="absolute -right-2 -bottom-2 w-20 h-28 pointer-events-none opacity-95">
            <img
              src="/images/Friendly 3D Hoodie Mascot with Smartphone.png"
              alt="Mascot"
              className="w-full h-full object-contain"
            />
          </div>
        </div>
      </aside>
    </>
  );
}
