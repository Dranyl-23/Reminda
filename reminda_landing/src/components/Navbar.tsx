"use client";

import { useState, useRef, useEffect } from "react";
import { Download, Menu, X, ArrowRight, ChevronDown } from "lucide-react";
import { useMarketingConfig } from "@/context/MarketingConfigContext";
import { WindowsIcon, AndroidIcon } from "@/components/icons";

export function Navbar() {
  const [mobileMenuOpen, setMobileMenuOpen] = useState(false);
  const [downloadOpen, setDownloadOpen] = useState(false);
  const dropdownRef = useRef<HTMLDivElement>(null);
  const { config } = useMarketingConfig();
  const { announcement, hero, downloadHub } = config;

  // Close dropdown on click outside or escape key
  useEffect(() => {
    function handleClickOutside(event: MouseEvent) {
      if (dropdownRef.current && !dropdownRef.current.contains(event.target as Node)) {
        setDownloadOpen(false);
      }
    }
    function handleKeyDown(event: KeyboardEvent) {
      if (event.key === "Escape") {
        setDownloadOpen(false);
      }
    }
    document.addEventListener("mousedown", handleClickOutside);
    document.addEventListener("keydown", handleKeyDown);
    return () => {
      document.removeEventListener("mousedown", handleClickOutside);
      document.removeEventListener("keydown", handleKeyDown);
    };
  }, []);

  return (
    <>
      {/* Dynamic Top Announcement Banner (Controlled from Admin Portal) */}
      {announcement.enabled && (
        <div className="bg-slate-900 text-white text-xs py-2.5 px-4 font-medium transition-all">
          <div className="max-w-6xl mx-auto flex items-center justify-between gap-3">
            <div className="flex items-center gap-2 flex-wrap">
              <span className="px-2 py-0.5 rounded-full bg-blue-600 text-white font-bold text-[10px] uppercase tracking-wider">
                {announcement.badge}
              </span>
              <span>{announcement.text}</span>
            </div>

            {announcement.linkUrl && (
              <a
                href={announcement.linkUrl}
                target="_blank"
                rel="noopener noreferrer"
                className="hidden sm:inline-flex items-center gap-1 text-blue-400 hover:text-white transition-colors shrink-0 font-semibold underline underline-offset-2"
              >
                <span>{announcement.linkText}</span>
                <ArrowRight className="w-3 h-3" />
              </a>
            )}
          </div>
        </div>
      )}

      {/* Astroship Main Header */}
      <div className="max-w-6xl mx-auto px-5">
        <header className="flex flex-col lg:flex-row justify-between items-center my-5">
          
          {/* Brand */}
          <div className="flex w-full lg:w-auto items-center justify-between">
            <a href="#" className="flex items-center gap-2.5 text-lg group">
              <img
                src="/icon.png"
                alt="Reminda Logo"
                className="w-8 h-8 rounded-lg object-contain shadow-xs group-hover:scale-105 transition-transform"
              />
              <div className="flex items-center">
                <span className="font-bold text-slate-800 text-xl tracking-tight">Reminda</span>
                <span className="text-slate-500 text-xl">.app</span>
              </div>
            </a>

            <div className="block lg:hidden">
              <button
                onClick={() => setMobileMenuOpen(!mobileMenuOpen)}
                id="astronav-menu"
                aria-label="Toggle Menu"
                className="text-slate-800 p-1"
              >
                {mobileMenuOpen ? <X className="w-5 h-5" /> : <Menu className="w-5 h-5" />}
              </button>
            </div>
          </div>

          {/* Navigation links */}
          <nav
            className={`${
              mobileMenuOpen ? "flex flex-col" : "hidden"
            } w-full lg:w-auto mt-2 lg:flex lg:mt-0`}
          >
            <ul className="flex flex-col lg:flex-row lg:gap-3 text-sm">
              <li>
                <a
                  href="#features"
                  onClick={() => setMobileMenuOpen(false)}
                  className="flex lg:px-3 py-2 items-center text-gray-600 hover:text-gray-900"
                >
                  Features
                </a>
              </li>
              <li>
                <a
                  href="#preview"
                  onClick={() => setMobileMenuOpen(false)}
                  className="flex lg:px-3 py-2 items-center text-gray-600 hover:text-gray-900"
                >
                  Interactive Timetable
                </a>
              </li>
              <li>
                <a
                  href="#how-it-works"
                  onClick={() => setMobileMenuOpen(false)}
                  className="flex lg:px-3 py-2 items-center text-gray-600 hover:text-gray-900"
                >
                  How It Works
                </a>
              </li>
              <li>
                <a
                  href="#faq"
                  onClick={() => setMobileMenuOpen(false)}
                  className="flex lg:px-3 py-2 items-center text-gray-600 hover:text-gray-900"
                >
                  FAQ
                </a>
              </li>
              <li>
                <a
                  href="#download"
                  onClick={() => setMobileMenuOpen(false)}
                  className="flex lg:px-3 py-2 items-center text-gray-600 hover:text-gray-900"
                >
                  <span>Release</span>
                  <span className="ml-1 px-2 py-0.5 text-[10px] animate-pulse font-semibold uppercase text-white bg-indigo-600 rounded-full">
                    {hero.versionBadge}
                  </span>
                </a>
              </li>
            </ul>

            {/* Mobile Drawer Platform CTAs */}
            <div className="lg:hidden flex flex-col gap-2 mt-4 pt-3 border-t border-slate-100">
              <span className="text-[11px] font-bold uppercase tracking-wider text-slate-400">
                Download Reminda
              </span>
              <a
                href={downloadHub.universalApkUrl || "https://github.com/Dranyl-23/Reminda/releases/latest/download/app-arm64-v8a-release.apk"}
                target="_blank"
                rel="noopener noreferrer"
                onClick={() => setMobileMenuOpen(false)}
                className="rounded-sm text-center transition focus-visible:ring-2 ring-offset-2 ring-gray-200 w-full px-4 py-2.5 bg-black text-white hover:bg-gray-800 border-2 border-transparent text-sm font-medium flex items-center justify-center gap-2"
              >
                <AndroidIcon className="w-4 h-4 text-emerald-400" />
                <span>Download Android APK</span>
              </a>

              <a
                href={downloadHub.windowsUrl || "https://github.com/Dranyl-23/Reminda/releases/latest/download/reminda-windows-x64.zip"}
                target="_blank"
                rel="noopener noreferrer"
                onClick={() => setMobileMenuOpen(false)}
                className="rounded-sm text-center transition focus-visible:ring-2 ring-offset-2 ring-gray-200 w-full px-4 py-2 bg-slate-50 text-slate-800 hover:bg-slate-100 border border-slate-200 text-xs font-medium flex items-center justify-center gap-2"
              >
                <WindowsIcon className="w-3.5 h-3.5 text-blue-600" />
                <span>Download for Windows PC (x64)</span>
              </a>
            </div>
          </nav>

          {/* Desktop Right CTA: Dropdown for PC or Mobile */}
          <div className="hidden lg:relative lg:flex items-center gap-4 text-sm" ref={dropdownRef}>
            <button
              onClick={() => setDownloadOpen((prev) => !prev)}
              className="rounded-sm text-center transition focus-visible:ring-2 ring-offset-2 ring-gray-200 px-4 py-2 bg-black text-white hover:bg-gray-800 border-2 border-transparent font-medium flex items-center gap-1.5 cursor-pointer whitespace-nowrap"
              aria-expanded={downloadOpen}
            >
              <Download className="w-4 h-4" />
              <span>Download</span>
              <ChevronDown className={`w-3.5 h-3.5 transition-transform duration-200 ${downloadOpen ? "rotate-180" : ""}`} />
            </button>

            {downloadOpen && (
              <div className="absolute right-0 top-full mt-2 w-72 bg-white rounded-xl shadow-xl border border-slate-200 p-2 z-50 animate-fade-in">
                <div className="px-3 py-1.5 text-[10px] font-bold uppercase tracking-wider text-slate-400">
                  Select Platform
                </div>

                {/* Windows Option */}
                <a
                  href={downloadHub.windowsUrl || "https://github.com/Dranyl-23/Reminda/releases/latest/download/reminda-windows-x64.zip"}
                  target="_blank"
                  rel="noopener noreferrer"
                  onClick={() => setDownloadOpen(false)}
                  className="flex items-start gap-3 p-2.5 rounded-lg hover:bg-slate-50 transition-colors group"
                >
                  <div className="p-2 rounded-md bg-blue-50 text-blue-600 group-hover:bg-blue-600 group-hover:text-white transition-colors shrink-0">
                    <WindowsIcon className="w-4 h-4" />
                  </div>
                  <div className="flex-1 min-w-0">
                    <div className="flex items-center justify-between">
                      <span className="font-semibold text-slate-800 text-xs group-hover:text-blue-600 transition-colors">
                        Windows Desktop
                      </span>
                      <span className="text-[10px] font-mono px-1.5 py-0.5 rounded bg-slate-100 text-slate-600">
                        {downloadHub.windowsSize || "~18 MB"}
                      </span>
                    </div>
                    <p className="text-[11px] text-slate-500 mt-0.5">Windows 10 / 11 (64-bit)</p>
                  </div>
                </a>

                {/* Android Option */}
                <a
                  href={downloadHub.universalApkUrl || "https://github.com/Dranyl-23/Reminda/releases/latest/download/app-arm64-v8a-release.apk"}
                  target="_blank"
                  rel="noopener noreferrer"
                  onClick={() => setDownloadOpen(false)}
                  className="flex items-start gap-3 p-2.5 rounded-lg hover:bg-slate-50 transition-colors group"
                >
                  <div className="p-2 rounded-md bg-emerald-50 text-emerald-600 group-hover:bg-emerald-600 group-hover:text-white transition-colors shrink-0">
                    <AndroidIcon className="w-4 h-4" />
                  </div>
                  <div className="flex-1 min-w-0">
                    <div className="flex items-center justify-between">
                      <span className="font-semibold text-slate-800 text-xs group-hover:text-emerald-600 transition-colors">
                        Android Mobile
                      </span>
                      <span className="text-[10px] font-mono px-1.5 py-0.5 rounded bg-slate-100 text-slate-600">
                        {downloadHub.universalApkSize || "~58 MB"}
                      </span>
                    </div>
                    <p className="text-[11px] text-slate-500 mt-0.5">APK &bull; Android 8.0 to 15</p>
                  </div>
                </a>

                {/* Footer link to Hub */}
                <div className="border-t border-slate-100 mt-1 pt-1.5 px-2">
                  <a
                    href="#download"
                    onClick={() => setDownloadOpen(false)}
                    className="text-[11px] font-medium text-slate-500 hover:text-slate-800 flex items-center justify-between py-1"
                  >
                    <span>View all packages &amp; QR code</span>
                    <ArrowRight className="w-3 h-3" />
                  </a>
                </div>
              </div>
            )}
          </div>

        </header>
      </div>
    </>
  );
}
