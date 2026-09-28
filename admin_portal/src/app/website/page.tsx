"use client";

import { useEffect, useState } from "react";
import { doc, onSnapshot, setDoc, serverTimestamp } from "firebase/firestore";
import { db } from "@/lib/firebase";
import { MarketingSiteConfig } from "@/lib/types";
import { defaultMarketingConfig } from "@/lib/marketingDefaults";
import { Header } from "@/components/Header";
import { 
  Globe, 
  Sparkles, 
  Download, 
  Megaphone, 
  HelpCircle, 
  Save, 
  RefreshCw, 
  ExternalLink, 
  CheckCircle2, 
  Plus, 
  Trash2, 
  Layers,
  ArrowUpRight,
  ShieldCheck,
  Check
} from "lucide-react";

export default function WebsiteCMSPage() {
  const [config, setConfig] = useState<MarketingSiteConfig>(defaultMarketingConfig);
  const [isLoading, setIsLoading] = useState(true);
  const [isSaving, setIsSaving] = useState(false);
  const [toastMessage, setToastMessage] = useState<string | null>(null);
  const [activeTab, setActiveTab] = useState<"hero" | "banner" | "downloads" | "features" | "faqs">("hero");

  useEffect(() => {
    const docRef = doc(db, "system_config", "marketing_site");
    const unsub = onSnapshot(
      docRef,
      (snap) => {
        if (snap.exists()) {
          const data = snap.data();
          setConfig({
            announcement: { ...defaultMarketingConfig.announcement, ...(data.announcement || {}) },
            hero: { ...defaultMarketingConfig.hero, ...(data.hero || {}) },
            features: data.features && data.features.length > 0 ? data.features : defaultMarketingConfig.features,
            downloadHub: { ...defaultMarketingConfig.downloadHub, ...(data.downloadHub || {}) },
            faqs: data.faqs && data.faqs.length > 0 ? data.faqs : defaultMarketingConfig.faqs,
            footer: { ...defaultMarketingConfig.footer, ...(data.footer || {}) },
          });
        }
        setIsLoading(false);
      },
      (err: any) => {
        console.warn("Marketing config listener warning:", err.message);
        setIsLoading(false);
      }
    );

    return () => unsub();
  }, []);

  const showToast = (msg: string) => {
    setToastMessage(msg);
    setTimeout(() => setToastMessage(null), 3500);
  };

  const handleSave = async (e?: React.FormEvent) => {
    if (e) e.preventDefault();
    try {
      setIsSaving(true);
      const docRef = doc(db, "system_config", "marketing_site");
      await setDoc(docRef, {
        ...config,
        updatedAt: serverTimestamp(),
      }, { merge: true });
      showToast("Marketing website content published successfully!");
    } catch (err: any) {
      console.error("Save marketing config error:", err);
      showToast("Failed to save: " + err.message);
    } finally {
      setIsSaving(false);
    }
  };

  const handleResetToDefaults = () => {
    if (window.confirm("Are you sure you want to restore default marketing website content?")) {
      setConfig(defaultMarketingConfig);
      showToast("Defaults restored. Click 'Publish Changes' to apply live.");
    }
  };

  // FAQ Handlers
  const handleAddFaq = () => {
    setConfig({
      ...config,
      faqs: [
        ...config.faqs,
        { q: "New Question", a: "Answer explanation goes here..." }
      ]
    });
  };

  const handleUpdateFaq = (index: number, field: "q" | "a", value: string) => {
    const updated = [...config.faqs];
    updated[index][field] = value;
    setConfig({ ...config, faqs: updated });
  };

  const handleDeleteFaq = (index: number) => {
    const updated = config.faqs.filter((_, i) => i !== index);
    setConfig({ ...config, faqs: updated });
  };

  return (
    <>
      <Header title="Marketing Website CMS" />
      <main className="flex-1 px-8 pb-12 space-y-6 max-w-[1400px] w-full">
        
        {/* Toast */}
        {toastMessage && (
          <div className="fixed bottom-6 right-6 z-50 px-4 py-3 rounded-2xl bg-slate-900 text-white text-xs font-bold shadow-xl flex items-center gap-2.5 animate-bounce">
            <CheckCircle2 className="w-4 h-4 text-emerald-400" />
            <span>{toastMessage}</span>
          </div>
        )}

        {/* Top Control Bar */}
        <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-4">
          <div>
            <p className="text-xs text-slate-500 dark:text-slate-400 font-semibold">
              Live Headless CMS. Any updates saved here propagate in real-time to the public Reminda marketing landing page.
            </p>
          </div>

          <div className="flex items-center gap-3">
            <a
              href="http://localhost:3005"
              target="_blank"
              rel="noopener noreferrer"
              className="px-4 py-2 rounded-2xl border border-slate-200 dark:border-[#202231] hover:bg-slate-50 dark:hover:bg-[#1C1D2B] text-slate-700 dark:text-slate-300 font-bold text-xs transition-colors flex items-center gap-1.5"
            >
              <span>View Live Website</span>
              <ArrowUpRight className="w-3.5 h-3.5" />
            </a>

            <button
              type="button"
              onClick={handleResetToDefaults}
              className="px-4 py-2 rounded-2xl border border-slate-200 dark:border-[#202231] hover:bg-slate-50 dark:hover:bg-[#1C1D2B] text-slate-600 dark:text-slate-400 font-bold text-xs transition-colors flex items-center gap-1.5"
            >
              <RefreshCw className="w-3.5 h-3.5" />
              <span>Defaults</span>
            </button>

            <button
              onClick={() => handleSave()}
              disabled={isSaving || isLoading}
              className="px-5 py-2.5 rounded-2xl bg-blue-600 hover:bg-blue-700 text-white font-bold text-xs shadow-xs transition-colors flex items-center gap-2 disabled:opacity-50"
            >
              {isSaving ? (
                <>
                  <RefreshCw className="w-3.5 h-3.5 animate-spin" />
                  <span>Publishing...</span>
                </>
              ) : (
                <>
                  <Save className="w-3.5 h-3.5" />
                  <span>Publish to Live Site</span>
                </>
              )}
            </button>
          </div>
        </div>

        {/* CMS Tab Navigation */}
        <div className="flex items-center gap-2 border-b border-slate-200/80 dark:border-[#202231] pb-3 overflow-x-auto text-xs font-bold">
          <button
            onClick={() => setActiveTab("hero")}
            className={`px-4 py-2 rounded-xl transition-colors flex items-center gap-2 shrink-0 ${
              activeTab === "hero"
                ? "bg-blue-600 text-white shadow-xs"
                : "text-slate-600 dark:text-slate-400 hover:bg-slate-100 dark:hover:bg-[#1C1D2B]"
            }`}
          >
            <Sparkles className="w-3.5 h-3.5" />
            <span>Hero &amp; Releases</span>
          </button>

          <button
            onClick={() => setActiveTab("banner")}
            className={`px-4 py-2 rounded-xl transition-colors flex items-center gap-2 shrink-0 ${
              activeTab === "banner"
                ? "bg-blue-600 text-white shadow-xs"
                : "text-slate-600 dark:text-slate-400 hover:bg-slate-100 dark:hover:bg-[#1C1D2B]"
            }`}
          >
            <Megaphone className="w-3.5 h-3.5" />
            <span>Notice Banner</span>
            {config.announcement.enabled && (
              <span className="w-2 h-2 rounded-full bg-emerald-400 animate-pulse" />
            )}
          </button>

          <button
            onClick={() => setActiveTab("downloads")}
            className={`px-4 py-2 rounded-xl transition-colors flex items-center gap-2 shrink-0 ${
              activeTab === "downloads"
                ? "bg-blue-600 text-white shadow-xs"
                : "text-slate-600 dark:text-slate-400 hover:bg-slate-100 dark:hover:bg-[#1C1D2B]"
            }`}
          >
            <Download className="w-3.5 h-3.5" />
            <span>Download Hub</span>
          </button>

          <button
            onClick={() => setActiveTab("features")}
            className={`px-4 py-2 rounded-xl transition-colors flex items-center gap-2 shrink-0 ${
              activeTab === "features"
                ? "bg-blue-600 text-white shadow-xs"
                : "text-slate-600 dark:text-slate-400 hover:bg-slate-100 dark:hover:bg-[#1C1D2B]"
            }`}
          >
            <Layers className="w-3.5 h-3.5" />
            <span>Feature Cards (6)</span>
          </button>

          <button
            onClick={() => setActiveTab("faqs")}
            className={`px-4 py-2 rounded-xl transition-colors flex items-center gap-2 shrink-0 ${
              activeTab === "faqs"
                ? "bg-blue-600 text-white shadow-xs"
                : "text-slate-600 dark:text-slate-400 hover:bg-slate-100 dark:hover:bg-[#1C1D2B]"
            }`}
          >
            <HelpCircle className="w-3.5 h-3.5" />
            <span>FAQ Manager ({config.faqs.length})</span>
          </button>
        </div>

        {/* Tab 1: Hero & Releases */}
        {activeTab === "hero" && (
          <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
            <div className="bg-white dark:bg-[#14151F] border border-slate-200/80 dark:border-[#202231] rounded-2xl p-6 space-y-4">
              <h3 className="text-sm font-bold text-slate-900 dark:text-white flex items-center gap-2">
                <Sparkles className="w-4 h-4 text-blue-600" />
                <span>Hero Headline &amp; Tagline</span>
              </h3>

              <div>
                <label className="block text-xs font-semibold text-slate-600 dark:text-slate-400 mb-1.5">
                  Version Release Pill
                </label>
                <input
                  type="text"
                  value={config.hero.versionBadge}
                  onChange={(e) => setConfig({ ...config, hero: { ...config.hero, versionBadge: e.target.value } })}
                  placeholder="v1.0.0+14"
                  className="w-full px-3.5 py-2.5 rounded-xl border border-slate-200 dark:border-[#202231] bg-slate-50/50 dark:bg-[#1C1D2B] text-xs font-bold text-slate-900 dark:text-white focus:outline-hidden focus:ring-2 focus:ring-blue-600"
                />
              </div>

              <div>
                <label className="block text-xs font-semibold text-slate-600 dark:text-slate-400 mb-1.5">
                  Hero Title (Headline)
                </label>
                <input
                  type="text"
                  value={config.hero.title}
                  onChange={(e) => setConfig({ ...config, hero: { ...config.hero, title: e.target.value } })}
                  placeholder="Class schedules done the smart way"
                  className="w-full px-3.5 py-2.5 rounded-xl border border-slate-200 dark:border-[#202231] bg-slate-50/50 dark:bg-[#1C1D2B] text-xs font-bold text-slate-900 dark:text-white focus:outline-hidden focus:ring-2 focus:ring-blue-600"
                />
              </div>

              <div>
                <label className="block text-xs font-semibold text-slate-600 dark:text-slate-400 mb-1.5">
                  Hero Subtitle / Description
                </label>
                <textarea
                  rows={4}
                  value={config.hero.subtitle}
                  onChange={(e) => setConfig({ ...config, hero: { ...config.hero, subtitle: e.target.value } })}
                  placeholder="Reminda is an intelligent college timetable app..."
                  className="w-full px-3.5 py-2.5 rounded-xl border border-slate-200 dark:border-[#202231] bg-slate-50/50 dark:bg-[#1C1D2B] text-xs text-slate-900 dark:text-white focus:outline-hidden focus:ring-2 focus:ring-blue-600 leading-relaxed"
                />
              </div>
            </div>

            <div className="bg-white dark:bg-[#14151F] border border-slate-200/80 dark:border-[#202231] rounded-2xl p-6 space-y-4">
              <h3 className="text-sm font-bold text-slate-900 dark:text-white flex items-center gap-2">
                <Download className="w-4 h-4 text-blue-600" />
                <span>Call to Action (CTA) Buttons</span>
              </h3>

              <div>
                <label className="block text-xs font-semibold text-slate-600 dark:text-slate-400 mb-1.5">
                  Primary Button Label
                </label>
                <input
                  type="text"
                  value={config.hero.primaryButtonText}
                  onChange={(e) => setConfig({ ...config, hero: { ...config.hero, primaryButtonText: e.target.value } })}
                  className="w-full px-3.5 py-2.5 rounded-xl border border-slate-200 dark:border-[#202231] bg-slate-50/50 dark:bg-[#1C1D2B] text-xs font-bold text-slate-900 dark:text-white focus:outline-hidden focus:ring-2 focus:ring-blue-600"
                />
              </div>

              <div>
                <label className="block text-xs font-semibold text-slate-600 dark:text-slate-400 mb-1.5">
                  Primary Button Download URL
                </label>
                <input
                  type="text"
                  value={config.hero.primaryButtonUrl}
                  onChange={(e) => setConfig({ ...config, hero: { ...config.hero, primaryButtonUrl: e.target.value } })}
                  placeholder="https://github.com/Dranyl-23/Reminda/releases/latest"
                  className="w-full px-3.5 py-2.5 rounded-xl border border-slate-200 dark:border-[#202231] bg-slate-50/50 dark:bg-[#1C1D2B] text-xs font-mono text-slate-900 dark:text-white focus:outline-hidden focus:ring-2 focus:ring-blue-600"
                />
              </div>

              <div>
                <label className="block text-xs font-semibold text-slate-600 dark:text-slate-400 mb-1.5">
                  Secondary Button Label
                </label>
                <input
                  type="text"
                  value={config.hero.secondaryButtonText}
                  onChange={(e) => setConfig({ ...config, hero: { ...config.hero, secondaryButtonText: e.target.value } })}
                  className="w-full px-3.5 py-2.5 rounded-xl border border-slate-200 dark:border-[#202231] bg-slate-50/50 dark:bg-[#1C1D2B] text-xs font-bold text-slate-900 dark:text-white focus:outline-hidden focus:ring-2 focus:ring-blue-600"
                />
              </div>

              <div>
                <label className="block text-xs font-semibold text-slate-600 dark:text-slate-400 mb-1.5">
                  Secondary Button Target URL
                </label>
                <input
                  type="text"
                  value={config.hero.secondaryButtonUrl}
                  onChange={(e) => setConfig({ ...config, hero: { ...config.hero, secondaryButtonUrl: e.target.value } })}
                  placeholder="https://github.com/Dranyl-23/Reminda"
                  className="w-full px-3.5 py-2.5 rounded-xl border border-slate-200 dark:border-[#202231] bg-slate-50/50 dark:bg-[#1C1D2B] text-xs font-mono text-slate-900 dark:text-white focus:outline-hidden focus:ring-2 focus:ring-blue-600"
                />
              </div>

              <div className="pt-2 flex items-center justify-between border-t border-slate-100 dark:border-[#202231]">
                <div>
                  <span className="text-xs font-bold text-slate-900 dark:text-white">Enable Scan QR Modal</span>
                  <p className="text-[11px] text-slate-500">Allow users to scan camera QR codes to install.</p>
                </div>
                <input
                  type="checkbox"
                  checked={config.hero.enableQrModal}
                  onChange={(e) => setConfig({ ...config, hero: { ...config.hero, enableQrModal: e.target.checked } })}
                  className="w-4 h-4 rounded text-blue-600 focus:ring-blue-500"
                />
              </div>
            </div>
          </div>
        )}

        {/* Tab 2: Notice Banner */}
        {activeTab === "banner" && (
          <div className="bg-white dark:bg-[#14151F] border border-slate-200/80 dark:border-[#202231] rounded-2xl p-6 space-y-5 max-w-3xl">
            <div className="flex items-center justify-between pb-4 border-b border-slate-100 dark:border-[#202231]">
              <div>
                <h3 className="text-sm font-bold text-slate-900 dark:text-white flex items-center gap-2">
                  <Megaphone className="w-4 h-4 text-blue-600" />
                  <span>Top Announcement Banner</span>
                </h3>
                <p className="text-xs text-slate-500 mt-0.5">
                  Display a top-level notice bar across the website for important updates or release announcements.
                </p>
              </div>

              <label className="relative inline-flex items-center cursor-pointer">
                <input
                  type="checkbox"
                  checked={config.announcement.enabled}
                  onChange={(e) => setConfig({ ...config, announcement: { ...config.announcement, enabled: e.target.checked } })}
                  className="sr-only peer"
                />
                <div className="w-11 h-6 bg-slate-200 peer-focus:outline-hidden rounded-full peer dark:bg-slate-700 peer-checked:after:translate-x-full peer-checked:after:border-white after:content-[''] after:absolute after:top-[2px] after:left-[2px] after:bg-white after:border-gray-300 after:border after:rounded-full after:h-5 after:w-5 after:transition-all peer-checked:bg-blue-600"></div>
              </label>
            </div>

            <div className="grid grid-cols-1 sm:grid-cols-2 gap-4">
              <div>
                <label className="block text-xs font-semibold text-slate-600 dark:text-slate-400 mb-1.5">
                  Badge Label
                </label>
                <input
                  type="text"
                  value={config.announcement.badge}
                  onChange={(e) => setConfig({ ...config, announcement: { ...config.announcement, badge: e.target.value } })}
                  placeholder="NEW RELEASE"
                  className="w-full px-3.5 py-2.5 rounded-xl border border-slate-200 dark:border-[#202231] bg-slate-50/50 dark:bg-[#1C1D2B] text-xs font-bold text-slate-900 dark:text-white focus:outline-hidden focus:ring-2 focus:ring-blue-600"
                />
              </div>

              <div>
                <label className="block text-xs font-semibold text-slate-600 dark:text-slate-400 mb-1.5">
                  Action Link Label
                </label>
                <input
                  type="text"
                  value={config.announcement.linkText}
                  onChange={(e) => setConfig({ ...config, announcement: { ...config.announcement, linkText: e.target.value } })}
                  placeholder="Download Now"
                  className="w-full px-3.5 py-2.5 rounded-xl border border-slate-200 dark:border-[#202231] bg-slate-50/50 dark:bg-[#1C1D2B] text-xs font-bold text-slate-900 dark:text-white focus:outline-hidden focus:ring-2 focus:ring-blue-600"
                />
              </div>
            </div>

            <div>
              <label className="block text-xs font-semibold text-slate-600 dark:text-slate-400 mb-1.5">
                Banner Message Text
              </label>
              <input
                type="text"
                value={config.announcement.text}
                onChange={(e) => setConfig({ ...config, announcement: { ...config.announcement, text: e.target.value } })}
                placeholder="🎉 Reminda v1.0.0+14 is now live!"
                className="w-full px-3.5 py-2.5 rounded-xl border border-slate-200 dark:border-[#202231] bg-slate-50/50 dark:bg-[#1C1D2B] text-xs text-slate-900 dark:text-white focus:outline-hidden focus:ring-2 focus:ring-blue-600"
              />
            </div>

            <div>
              <label className="block text-xs font-semibold text-slate-600 dark:text-slate-400 mb-1.5">
                Banner Click URL
              </label>
              <input
                type="text"
                value={config.announcement.linkUrl}
                onChange={(e) => setConfig({ ...config, announcement: { ...config.announcement, linkUrl: e.target.value } })}
                placeholder="https://github.com/Dranyl-23/Reminda/releases/latest"
                className="w-full px-3.5 py-2.5 rounded-xl border border-slate-200 dark:border-[#202231] bg-slate-50/50 dark:bg-[#1C1D2B] text-xs font-mono text-slate-900 dark:text-white focus:outline-hidden focus:ring-2 focus:ring-blue-600"
              />
            </div>
          </div>
        )}

        {/* Tab 3: Download Hub */}
        {activeTab === "downloads" && (
          <div className="bg-white dark:bg-[#14151F] border border-slate-200/80 dark:border-[#202231] rounded-2xl p-6 space-y-5 max-w-4xl">
            <h3 className="text-sm font-bold text-slate-900 dark:text-white flex items-center gap-2">
              <Download className="w-4 h-4 text-blue-600" />
              <span>Bottom Black CTA Card &amp; Package Distribution</span>
            </h3>

            <div className="grid grid-cols-1 sm:grid-cols-2 gap-4">
              <div>
                <label className="block text-xs font-semibold text-slate-600 dark:text-slate-400 mb-1.5">
                  Card Pill Tag
                </label>
                <input
                  type="text"
                  value={config.downloadHub.tag}
                  onChange={(e) => setConfig({ ...config, downloadHub: { ...config.downloadHub, tag: e.target.value } })}
                  className="w-full px-3.5 py-2.5 rounded-xl border border-slate-200 dark:border-[#202231] bg-slate-50/50 dark:bg-[#1C1D2B] text-xs font-bold text-slate-900 dark:text-white focus:outline-hidden focus:ring-2 focus:ring-blue-600"
                />
              </div>

              <div>
                <label className="block text-xs font-semibold text-slate-600 dark:text-slate-400 mb-1.5">
                  Heading Title
                </label>
                <input
                  type="text"
                  value={config.downloadHub.title}
                  onChange={(e) => setConfig({ ...config, downloadHub: { ...config.downloadHub, title: e.target.value } })}
                  className="w-full px-3.5 py-2.5 rounded-xl border border-slate-200 dark:border-[#202231] bg-slate-50/50 dark:bg-[#1C1D2B] text-xs font-bold text-slate-900 dark:text-white focus:outline-hidden focus:ring-2 focus:ring-blue-600"
                />
              </div>
            </div>

            <div>
              <label className="block text-xs font-semibold text-slate-600 dark:text-slate-400 mb-1.5">
                Card Description
              </label>
              <textarea
                rows={2}
                value={config.downloadHub.subtitle}
                onChange={(e) => setConfig({ ...config, downloadHub: { ...config.downloadHub, subtitle: e.target.value } })}
                className="w-full px-3.5 py-2.5 rounded-xl border border-slate-200 dark:border-[#202231] bg-slate-50/50 dark:bg-[#1C1D2B] text-xs text-slate-900 dark:text-white focus:outline-hidden focus:ring-2 focus:ring-blue-600"
              />
            </div>

            <div className="grid grid-cols-1 sm:grid-cols-2 gap-4 pt-3 border-t border-slate-100 dark:border-[#202231]">
              <div className="p-4 rounded-xl border border-slate-100 dark:border-[#202231] space-y-3">
                <span className="text-xs font-bold text-slate-900 dark:text-white">Universal Release APK</span>
                <input
                  type="text"
                  value={config.downloadHub.universalApkUrl}
                  onChange={(e) => setConfig({ ...config, downloadHub: { ...config.downloadHub, universalApkUrl: e.target.value } })}
                  placeholder="URL to Universal APK"
                  className="w-full px-3 py-2 rounded-lg border border-slate-200 dark:border-[#202231] bg-slate-50/50 dark:bg-[#1C1D2B] text-[11px] font-mono text-slate-900 dark:text-white focus:outline-hidden"
                />
                <input
                  type="text"
                  value={config.downloadHub.universalApkSize}
                  onChange={(e) => setConfig({ ...config, downloadHub: { ...config.downloadHub, universalApkSize: e.target.value } })}
                  placeholder="~58 MB"
                  className="w-24 px-2 py-1 rounded-md border border-slate-200 dark:border-[#202231] bg-slate-50/50 dark:bg-[#1C1D2B] text-[11px] font-mono text-slate-900 dark:text-white focus:outline-hidden"
                />
              </div>

              <div className="p-4 rounded-xl border border-slate-100 dark:border-[#202231] space-y-3">
                <span className="text-xs font-bold text-slate-900 dark:text-white">arm64-v8a Split APK</span>
                <input
                  type="text"
                  value={config.downloadHub.arm64ApkUrl}
                  onChange={(e) => setConfig({ ...config, downloadHub: { ...config.downloadHub, arm64ApkUrl: e.target.value } })}
                  placeholder="URL to arm64 APK"
                  className="w-full px-3 py-2 rounded-lg border border-slate-200 dark:border-[#202231] bg-slate-50/50 dark:bg-[#1C1D2B] text-[11px] font-mono text-slate-900 dark:text-white focus:outline-hidden"
                />
                <input
                  type="text"
                  value={config.downloadHub.arm64ApkSize}
                  onChange={(e) => setConfig({ ...config, downloadHub: { ...config.downloadHub, arm64ApkSize: e.target.value } })}
                  placeholder="~45 MB"
                  className="w-24 px-2 py-1 rounded-md border border-slate-200 dark:border-[#202231] bg-slate-50/50 dark:bg-[#1C1D2B] text-[11px] font-mono text-slate-900 dark:text-white focus:outline-hidden"
                />
              </div>
            </div>

            <div>
              <label className="block text-xs font-semibold text-slate-600 dark:text-slate-400 mb-1.5">
                Sideloading Help Alert
              </label>
              <textarea
                rows={2}
                value={config.downloadHub.sideloadNote}
                onChange={(e) => setConfig({ ...config, downloadHub: { ...config.downloadHub, sideloadNote: e.target.value } })}
                className="w-full px-3.5 py-2.5 rounded-xl border border-slate-200 dark:border-[#202231] bg-slate-50/50 dark:bg-[#1C1D2B] text-xs text-slate-900 dark:text-white focus:outline-hidden focus:ring-2 focus:ring-blue-600"
              />
            </div>
          </div>
        )}

        {/* Tab 4: Features */}
        {activeTab === "features" && (
          <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-5">
            {config.features.map((feat, idx) => (
              <div
                key={feat.id || idx}
                className="bg-white dark:bg-[#14151F] border border-slate-200/80 dark:border-[#202231] rounded-2xl p-5 space-y-3"
              >
                <div className="flex items-center justify-between">
                  <span className="text-[10px] font-mono font-bold px-2 py-0.5 rounded bg-slate-100 dark:bg-[#1C1D2B] text-slate-700 dark:text-slate-300">
                    Feature #{idx + 1}
                  </span>
                </div>

                <div>
                  <label className="block text-[11px] font-semibold text-slate-500 mb-1">Title</label>
                  <input
                    type="text"
                    value={feat.title}
                    onChange={(e) => {
                      const updated = [...config.features];
                      updated[idx].title = e.target.value;
                      setConfig({ ...config, features: updated });
                    }}
                    className="w-full px-3 py-2 rounded-xl border border-slate-200 dark:border-[#202231] bg-slate-50/50 dark:bg-[#1C1D2B] text-xs font-bold text-slate-900 dark:text-white focus:outline-hidden focus:ring-2 focus:ring-blue-600"
                  />
                </div>

                <div>
                  <label className="block text-[11px] font-semibold text-slate-500 mb-1">Description</label>
                  <textarea
                    rows={3}
                    value={feat.description}
                    onChange={(e) => {
                      const updated = [...config.features];
                      updated[idx].description = e.target.value;
                      setConfig({ ...config, features: updated });
                    }}
                    className="w-full px-3 py-2 rounded-xl border border-slate-200 dark:border-[#202231] bg-slate-50/50 dark:bg-[#1C1D2B] text-xs text-slate-900 dark:text-white focus:outline-hidden focus:ring-2 focus:ring-blue-600 leading-relaxed"
                  />
                </div>
              </div>
            ))}
          </div>
        )}

        {/* Tab 5: FAQs */}
        {activeTab === "faqs" && (
          <div className="bg-white dark:bg-[#14151F] border border-slate-200/80 dark:border-[#202231] rounded-2xl p-6 space-y-5">
            <div className="flex items-center justify-between pb-3 border-b border-slate-100 dark:border-[#202231]">
              <div>
                <h3 className="text-sm font-bold text-slate-900 dark:text-white flex items-center gap-2">
                  <HelpCircle className="w-4 h-4 text-blue-600" />
                  <span>Student Frequently Asked Questions</span>
                </h3>
                <p className="text-xs text-slate-500 mt-0.5">
                  Add, update, or remove question items displayed on the marketing website accordion.
                </p>
              </div>

              <button
                type="button"
                onClick={handleAddFaq}
                className="px-3.5 py-2 rounded-xl bg-blue-50 dark:bg-blue-900/30 text-blue-600 dark:text-blue-400 font-bold text-xs hover:bg-blue-100 transition-colors flex items-center gap-1.5"
              >
                <Plus className="w-3.5 h-3.5" />
                <span>Add Question</span>
              </button>
            </div>

            <div className="space-y-4">
              {config.faqs.map((faq, idx) => (
                <div
                  key={idx}
                  className="p-4 rounded-xl border border-slate-200/80 dark:border-[#202231] bg-slate-50/40 dark:bg-[#1C1D2B]/40 space-y-3 relative group"
                >
                  <div className="flex items-center justify-between gap-4">
                    <span className="text-xs font-mono font-bold text-blue-600">Q{idx + 1}</span>
                    <button
                      type="button"
                      onClick={() => handleDeleteFaq(idx)}
                      className="text-slate-400 hover:text-red-500 p-1 transition-colors"
                      title="Delete question"
                    >
                      <Trash2 className="w-4 h-4" />
                    </button>
                  </div>

                  <div>
                    <input
                      type="text"
                      value={faq.q}
                      onChange={(e) => handleUpdateFaq(idx, "q", e.target.value)}
                      placeholder="Question title"
                      className="w-full px-3 py-2 rounded-lg border border-slate-200 dark:border-[#202231] bg-white dark:bg-[#14151F] text-xs font-bold text-slate-900 dark:text-white focus:outline-hidden focus:ring-2 focus:ring-blue-600"
                    />
                  </div>

                  <div>
                    <textarea
                      rows={2}
                      value={faq.a}
                      onChange={(e) => handleUpdateFaq(idx, "a", e.target.value)}
                      placeholder="Answer details..."
                      className="w-full px-3 py-2 rounded-lg border border-slate-200 dark:border-[#202231] bg-white dark:bg-[#14151F] text-xs text-slate-700 dark:text-slate-300 focus:outline-hidden focus:ring-2 focus:ring-blue-600"
                    />
                  </div>
                </div>
              ))}
            </div>
          </div>
        )}

      </main>
    </>
  );
}
