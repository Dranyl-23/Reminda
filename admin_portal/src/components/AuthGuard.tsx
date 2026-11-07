"use client";

import { useState } from "react";
import { useAuth } from "@/context/AuthContext";
import {
  ShieldCheck,
  HelpCircle,
  Lock,
  ArrowRight,
  Users,
  MessageSquare,
  ShieldAlert,
  LogOut,
  BarChart3,
  ExternalLink,
} from "lucide-react";

export function AuthGuard({ children }: { children: React.ReactNode }) {
  const { user, isAdmin, loading, error, loginWithGoogle, logout } = useAuth();
  const [isSigningIn, setIsSigningIn] = useState(false);
  const [showHelpModal, setShowHelpModal] = useState(false);

  const handleGoogleLogin = async () => {
    try {
      setIsSigningIn(true);
      await loginWithGoogle();
    } finally {
      setIsSigningIn(false);
    }
  };

  if (loading) {
    return (
      <div className="min-h-screen w-full bg-[#FAFAFA] dark:bg-[#09090B] flex flex-col items-center justify-center space-y-4">
        <div className="w-12 h-12 rounded-xl bg-zinc-900 dark:bg-zinc-100 flex items-center justify-center p-2 shadow-sm animate-pulse">
          <img
            src="/images/Reminda - NoBG.png"
            alt="Reminda Logo"
            className="w-full h-full object-contain"
          />
        </div>
        <p className="text-xs font-semibold text-zinc-500 dark:text-zinc-400 tracking-wide">
          Initializing Reminda Studio...
        </p>
      </div>
    );
  }

  // Not logged in -> Reminda Landing Page + Studio Admin Monochrome Login Portal
  if (!user) {
    return (
      <div className="min-h-screen w-full bg-[#FAFAFA] dark:bg-[#09090B] text-zinc-900 dark:text-zinc-100 flex flex-col justify-between selection:bg-zinc-900 selection:text-white relative overflow-hidden font-sans">
        {/* Subtle Architectural Grid Background */}
        <div
          className="absolute inset-0 pointer-events-none opacity-[0.35] dark:opacity-[0.12]"
          style={{
            backgroundImage:
              "radial-gradient(#a1a1aa 1px, transparent 1px)",
            backgroundSize: "24px 24px",
          }}
        />

        {/* 1. TOP NAVBAR */}
        <header className="max-w-7xl w-full mx-auto px-6 sm:px-10 pt-6 sm:pt-8 flex items-center justify-between z-10">
          <div className="flex items-center gap-3">
            <div className="w-9 h-9 rounded-lg bg-zinc-900 dark:bg-zinc-100 flex items-center justify-center shrink-0 p-1.5 shadow-2xs">
              <img
                src="/images/Reminda - NoBG.png"
                alt="Reminda Logo"
                className="w-full h-full object-contain"
              />
            </div>
            <div>
              <span className="font-bold text-base text-zinc-900 dark:text-zinc-100 tracking-tight leading-none block">
                Reminda Studio
              </span>
              <span className="font-medium text-[11px] text-zinc-500 dark:text-zinc-400 tracking-tight leading-none block mt-1">
                Executive Admin Console
              </span>
            </div>
          </div>

          <div className="flex items-center gap-3 sm:gap-5">
            <a
              href="https://getreminda.vercel.app"
              target="_blank"
              rel="noopener noreferrer"
              className="hidden sm:inline-flex items-center gap-1.5 text-xs font-medium text-zinc-600 dark:text-zinc-400 hover:text-zinc-900 dark:hover:text-zinc-100 transition-colors"
            >
              <span>getreminda.vercel.app</span>
              <ExternalLink className="w-3.5 h-3.5" />
            </a>

            <div className="flex items-center gap-1.5 px-3 py-1 rounded-full bg-white dark:bg-zinc-900 border border-zinc-200 dark:border-zinc-800 text-zinc-700 dark:text-zinc-300 text-xs font-medium shadow-2xs">
              <ShieldCheck className="w-3.5 h-3.5 text-zinc-900 dark:text-zinc-100" />
              <span>Admin Access Only</span>
            </div>

            <button
              onClick={() => setShowHelpModal(true)}
              className="flex items-center gap-1.5 text-xs font-medium text-zinc-600 dark:text-zinc-400 hover:text-zinc-900 dark:hover:text-zinc-100 transition-colors cursor-pointer"
            >
              <HelpCircle className="w-4 h-4 text-zinc-400" />
              <span className="hidden sm:inline">Help</span>
            </button>
          </div>
        </header>

        {/* 2. HERO MAIN CONTAINER */}
        <main className="max-w-7xl w-full mx-auto px-6 sm:px-10 py-8 my-auto grid grid-cols-1 lg:grid-cols-12 gap-10 lg:gap-12 items-center z-10">
          {/* Left Column: Auth Card */}
          <div className="lg:col-span-5 space-y-6 max-w-md mx-auto lg:mx-0 text-left">
            <div className="inline-flex items-center gap-2 px-3 py-1 rounded-full bg-white dark:bg-zinc-900 border border-zinc-200 dark:border-zinc-800 text-zinc-700 dark:text-zinc-300 text-xs font-medium shadow-2xs">
              <span className="w-1.5 h-1.5 rounded-full bg-emerald-500" />
              <span>Reminda Cloud · v1.0.0+17</span>
            </div>

            <div className="space-y-2">
              <h1 className="text-3xl sm:text-4xl font-bold text-zinc-900 dark:text-zinc-100 tracking-tight leading-[1.15]">
                Executive Command & Telemetry Portal
              </h1>
              <p className="text-sm text-zinc-500 dark:text-zinc-400 leading-relaxed">
                Manage student schedules, AI OCR dataset training, verified school directories, and live release channels from one unified workspace.
              </p>
            </div>

            {/* Error Banner */}
            {error && (
              <div className="p-3.5 rounded-xl bg-rose-50 dark:bg-rose-950/40 border border-rose-200 dark:border-rose-800 text-rose-700 dark:text-rose-300 text-xs font-medium flex items-start gap-2.5">
                <ShieldAlert className="w-4 h-4 shrink-0 mt-0.5 text-rose-600 dark:text-rose-400" />
                <span className="leading-snug">{error}</span>
              </div>
            )}

            {/* Sign in Card */}
            <div className="p-5 rounded-xl bg-white dark:bg-[#121215] border border-zinc-200/90 dark:border-zinc-800 shadow-xs space-y-4">
              <button
                onClick={handleGoogleLogin}
                disabled={isSigningIn}
                className="w-full h-11 px-5 rounded-lg bg-zinc-900 hover:bg-zinc-800 dark:bg-zinc-100 dark:hover:bg-white text-white dark:text-zinc-900 font-semibold text-xs shadow-xs transition-all flex items-center justify-between group cursor-pointer disabled:opacity-75"
              >
                <div className="flex items-center gap-3">
                  <div className="w-6 h-6 rounded-md bg-white flex items-center justify-center shrink-0">
                    <svg className="w-3.5 h-3.5" viewBox="0 0 24 24">
                      <path
                        fill="#4285F4"
                        d="M22.56 12.25c0-.78-.07-1.53-.2-2.25H12v4.26h5.92c-.26 1.37-1.04 2.53-2.21 3.31v2.77h3.57c2.08-1.92 3.28-4.74 3.28-8.09z"
                      />
                      <path
                        fill="#34A853"
                        d="M12 23c2.97 0 5.46-.98 7.28-2.66l-3.57-2.77c-.98.66-2.23 1.06-3.71 1.06-2.86 0-5.29-1.93-6.16-4.53H2.18v2.84C3.99 20.53 7.7 23 12 23z"
                      />
                      <path
                        fill="#FBBC05"
                        d="M5.84 14.09c-.22-.66-.35-1.36-.35-2.09s.13-1.43.35-2.09V7.06H2.18C1.43 8.55 1 10.22 1 12s.43 3.45 1.18 4.94l2.85-2.22.81-.63z"
                      />
                      <path
                        fill="#EA4335"
                        d="M12 5.38c1.62 0 3.06.56 4.21 1.64l3.15-3.15C17.45 2.09 14.97 1 12 1 7.7 1 3.99 3.47 2.18 7.06l3.66 2.84c.87-2.6 3.3-4.52 6.16-4.52z"
                      />
                    </svg>
                  </div>
                  <span className="text-xs font-semibold">
                    {isSigningIn ? "Authorizing Google Session..." : "Continue with Google"}
                  </span>
                </div>
                <ArrowRight className="w-4 h-4 opacity-70 group-hover:translate-x-0.5 transition-transform" />
              </button>

              <div className="pt-3 border-t border-zinc-100 dark:border-zinc-800/80 flex items-center gap-3">
                <div className="w-8 h-8 rounded-lg bg-zinc-100 dark:bg-zinc-800 flex items-center justify-center text-zinc-700 dark:text-zinc-300 shrink-0">
                  <Lock className="w-3.5 h-3.5" />
                </div>
                <div className="text-left">
                  <p className="text-xs font-semibold text-zinc-900 dark:text-zinc-100">
                    Authorized Administrator Whitelist
                  </p>
                  <p className="text-[11px] text-zinc-500 dark:text-zinc-400">
                    Protected by Firebase Auth & Firestore RBAC rules.
                  </p>
                </div>
              </div>
            </div>
          </div>

          {/* Right Column: Dashboard Preview Card */}
          <div className="lg:col-span-7 relative flex items-center justify-center">
            <div className="relative w-full max-w-[720px] rounded-xl bg-white dark:bg-[#121215] p-2 border border-zinc-200/90 dark:border-zinc-800 shadow-xl">
              <img
                src="/images/Dashboard.png"
                alt="Reminda Executive Dashboard Preview"
                className="w-full h-auto object-contain rounded-lg"
              />
            </div>
          </div>
        </main>

        {/* 3. BOTTOM 4-COLUMN FEATURE STRIP */}
        <footer className="max-w-7xl w-full mx-auto px-6 sm:px-10 pb-8 z-10 space-y-5">
          <div className="py-4 px-6 rounded-xl bg-white dark:bg-[#121215] border border-zinc-200/80 dark:border-zinc-800/80 shadow-2xs grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-5 items-center">
            <div className="flex items-center gap-3.5">
              <div className="w-9 h-9 rounded-lg bg-zinc-100 dark:bg-zinc-800 text-zinc-900 dark:text-zinc-100 flex items-center justify-center shrink-0">
                <ShieldCheck className="w-4 h-4" />
              </div>
              <div>
                <h4 className="font-semibold text-xs text-zinc-900 dark:text-zinc-100">
                  Zero-Trust Access
                </h4>
                <p className="text-[11px] text-zinc-500 dark:text-zinc-400">
                  Verified Google OAuth 2.0 session.
                </p>
              </div>
            </div>

            <div className="flex items-center gap-3.5">
              <div className="w-9 h-9 rounded-lg bg-zinc-100 dark:bg-zinc-800 text-zinc-900 dark:text-zinc-100 flex items-center justify-center shrink-0">
                <Users className="w-4 h-4" />
              </div>
              <div>
                <h4 className="font-semibold text-xs text-zinc-900 dark:text-zinc-100">
                  User & School Directory
                </h4>
                <p className="text-[11px] text-zinc-500 dark:text-zinc-400">
                  576+ schools & active student sync.
                </p>
              </div>
            </div>

            <div className="flex items-center gap-3.5">
              <div className="w-9 h-9 rounded-lg bg-zinc-100 dark:bg-zinc-800 text-zinc-900 dark:text-zinc-100 flex items-center justify-center shrink-0">
                <MessageSquare className="w-4 h-4" />
              </div>
              <div>
                <h4 className="font-semibold text-xs text-zinc-900 dark:text-zinc-100">
                  Customer Feedback
                </h4>
                <p className="text-[11px] text-zinc-500 dark:text-zinc-400">
                  Direct email dispatch & review triage.
                </p>
              </div>
            </div>

            <div className="flex items-center gap-3.5">
              <div className="w-9 h-9 rounded-lg bg-zinc-100 dark:bg-zinc-800 text-zinc-900 dark:text-zinc-100 flex items-center justify-center shrink-0">
                <BarChart3 className="w-4 h-4" />
              </div>
              <div>
                <h4 className="font-semibold text-xs text-zinc-900 dark:text-zinc-100">
                  AI Dataset Lab
                </h4>
                <p className="text-[11px] text-zinc-500 dark:text-zinc-400">
                  Ground-truth OCR fine-tuning studio.
                </p>
              </div>
            </div>
          </div>

          <div className="text-center text-xs text-zinc-400 dark:text-zinc-500">
            © 2026 <strong className="text-zinc-700 dark:text-zinc-300 font-semibold">Reminda Studio</strong>. All rights reserved.
          </div>
        </footer>

        {/* Help Dialog */}
        {showHelpModal && (
          <div className="fixed inset-0 z-50 bg-black/60 backdrop-blur-xs flex items-center justify-center p-4">
            <div className="w-full max-w-sm bg-white dark:bg-[#121215] rounded-xl p-6 shadow-2xl border border-zinc-200 dark:border-zinc-800 space-y-4">
              <div className="flex items-center gap-2 text-zinc-900 dark:text-zinc-100">
                <HelpCircle className="w-4 h-4" />
                <h3 className="font-semibold text-sm">Need Help Signing In?</h3>
              </div>
              <p className="text-xs text-zinc-500 dark:text-zinc-400 leading-relaxed">
                Access to Reminda Studio is restricted to whitelisted administrator Google accounts. Ensure you sign in with your approved administrator email.
              </p>
              <button
                onClick={() => setShowHelpModal(false)}
                className="w-full h-9 rounded-lg bg-zinc-900 dark:bg-zinc-100 text-white dark:text-zinc-900 text-xs font-semibold cursor-pointer"
              >
                Close
              </button>
            </div>
          </div>
        )}
      </div>
    );
  }

  // Logged in but not authorized as admin
  if (!isAdmin) {
    return (
      <div className="min-h-screen w-full bg-[#FAFAFA] dark:bg-[#09090B] flex items-center justify-center p-6 font-sans">
        <div className="w-full max-w-md bg-white dark:bg-[#121215] rounded-xl border border-zinc-200 dark:border-zinc-800 p-8 shadow-xl text-center space-y-5">
          <div className="w-12 h-12 rounded-xl bg-rose-50 dark:bg-rose-950/50 text-rose-600 dark:text-rose-400 flex items-center justify-center mx-auto border border-rose-200 dark:border-rose-800/60">
            <ShieldAlert className="w-6 h-6" />
          </div>
          <div>
            <h3 className="text-base font-bold text-zinc-900 dark:text-zinc-100">
              Access Restricted
            </h3>
            <p className="text-xs text-zinc-500 dark:text-zinc-400 mt-1.5 leading-relaxed">
              You are signed in as{" "}
              <span className="font-semibold text-zinc-900 dark:text-zinc-100">
                {user.email}
              </span>
              , which does not have administrator privileges.
            </p>
          </div>
          <button
            onClick={logout}
            className="w-full h-10 rounded-lg bg-zinc-900 dark:bg-zinc-100 hover:bg-zinc-800 dark:hover:bg-white text-white dark:text-zinc-900 text-xs font-semibold flex items-center justify-center gap-2 shadow-xs transition-all cursor-pointer"
          >
            <LogOut className="w-4 h-4" />
            Switch or Sign Out
          </button>
        </div>
      </div>
    );
  }

  // Authenticated as Admin
  return <>{children}</>;
}
