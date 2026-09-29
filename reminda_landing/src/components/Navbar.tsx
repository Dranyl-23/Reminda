"use client";

import { useState } from "react";
import { Download, Menu, X, ArrowRight, Megaphone } from "lucide-react";
import { useMarketingConfig } from "@/context/MarketingConfigContext";

export function Navbar() {
  const [mobileMenuOpen, setMobileMenuOpen] = useState(false);
  const { config } = useMarketingConfig();
  const { announcement, hero } = config;

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
                  href={hero.primaryButtonUrl}
                  target="_blank"
                  rel="noopener noreferrer"
                  className="flex lg:px-3 py-2 items-center text-gray-600 hover:text-gray-900"
                >
                  <span>Release</span>
                  <span className="ml-1 px-2 py-0.5 text-[10px] animate-pulse font-semibold uppercase text-white bg-indigo-600 rounded-full">
                    {hero.versionBadge}
                  </span>
                </a>
              </li>
            </ul>

            <div className="lg:hidden flex items-center mt-3">
              <a
                href={hero.primaryButtonUrl}
                target="_blank"
                rel="noopener noreferrer"
                className="rounded-sm text-center transition focus-visible:ring-2 ring-offset-2 ring-gray-200 w-full px-4 py-2 bg-black text-white hover:bg-gray-800 border-2 border-transparent text-sm font-medium"
              >
                {hero.primaryButtonText}
              </a>
            </div>
          </nav>

          {/* Right CTA */}
          <div className="hidden lg:flex items-center gap-4 text-sm">
            <a
              href={hero.primaryButtonUrl}
              target="_blank"
              rel="noopener noreferrer"
              className="rounded-sm text-center transition focus-visible:ring-2 ring-offset-2 ring-gray-200 px-4 py-2 bg-black text-white hover:bg-gray-800 border-2 border-transparent font-medium"
            >
              Download APK
            </a>
          </div>

        </header>
      </div>
    </>
  );
}
