"use client";

import { useState } from "react";
import { Download, QrCode, ShieldCheck, Cpu } from "lucide-react";
import { useMarketingConfig } from "@/context/MarketingConfigContext";

export function DownloadHub() {
  const [showQr, setShowQr] = useState(false);
  const { config } = useMarketingConfig();
  const { downloadHub } = config;

  return (
    <div id="download" className="max-w-6xl mx-auto px-5 py-12">
      
      {/* Astroship Signature Jet-Black CTA Box */}
      <div className="bg-black p-8 md:px-20 md:py-20 mt-10 mx-auto max-w-5xl rounded-lg flex flex-col items-center text-center">
        <span className="text-xs font-mono uppercase tracking-widest text-indigo-400 font-bold mb-2">
          {downloadHub.tag}
        </span>
        <h2 className="text-white text-4xl md:text-6xl tracking-tight font-bold">
          {downloadHub.title}
        </h2>
        <p className="text-slate-400 mt-4 text-lg md:text-xl max-w-2xl leading-relaxed">
          {downloadHub.subtitle}
        </p>

        <div className="flex flex-col sm:flex-row gap-3 mt-6">
          <a
            href={downloadHub.universalApkUrl}
            target="_blank"
            rel="noopener noreferrer"
            className="rounded-sm text-center transition focus-visible:ring-2 ring-offset-2 ring-gray-200 px-6 py-3 bg-white text-black hover:bg-gray-100 border-2 border-transparent font-semibold text-sm flex items-center justify-center gap-2"
          >
            <Download className="w-4 h-4 text-black" />
            <span>Download APK ({config.hero.versionBadge})</span>
          </a>

          <button
            onClick={() => setShowQr(!showQr)}
            className="rounded-sm text-center transition px-5 py-3 border border-slate-700 hover:border-slate-500 text-white font-medium text-sm flex items-center justify-center gap-2 cursor-pointer"
          >
            <QrCode className="w-4 h-4 text-slate-300" />
            <span>{showQr ? "Hide QR Code" : "Scan QR Code"}</span>
          </button>
        </div>

        {/* Embedded QR toggle */}
        {showQr && (
          <div className="mt-8 p-4 rounded-xl bg-white text-slate-900 inline-block text-center shadow-xl animate-fade-in">
            <img
              src={`https://api.qrserver.com/v1/create-qr-code/?size=160x160&data=${encodeURIComponent(
                downloadHub.universalApkUrl
              )}`}
              alt="Download QR Code"
              className="w-36 h-36 mx-auto"
            />
            <p className="text-[10px] text-slate-500 font-mono mt-2 font-semibold">
              Point phone camera to install directly
            </p>
          </div>
        )}
      </div>

      {/* 2 Clean Package Cards */}
      <div className="grid grid-cols-1 md:grid-cols-2 gap-6 mt-16 max-w-5xl mx-auto">
        <div className="p-6 rounded-xl border border-slate-200 bg-white shadow-xs">
          <div className="flex items-center justify-between mb-3">
            <span className="font-bold text-slate-900 text-base">Universal Release APK</span>
            <span className="text-[10px] font-bold px-2 py-0.5 rounded bg-blue-100 text-blue-800">
              Recommended
            </span>
          </div>
          <p className="text-xs text-slate-600 leading-relaxed mb-5">
            Works across all Android smartphones (Android 8.0 Oreo up to Android 15). Compatible with Samsung, Xiaomi, Realme, Oppo, Vivo, and Google Pixel.
          </p>
          <a
            href={downloadHub.universalApkUrl}
            target="_blank"
            rel="noopener noreferrer"
            className="inline-flex items-center gap-1.5 text-xs font-semibold text-slate-900 hover:text-blue-600 transition-colors"
          >
            <Download className="w-3.5 h-3.5" />
            <span>Download Universal Package ({downloadHub.universalApkSize}) &rarr;</span>
          </a>
        </div>

        <div className="p-6 rounded-xl border border-slate-200 bg-white shadow-xs">
          <div className="flex items-center justify-between mb-3">
            <span className="font-bold text-slate-900 text-base">arm64-v8a Split APK</span>
            <span className="text-[10px] font-mono font-bold px-2 py-0.5 rounded bg-slate-100 text-slate-700">
              {downloadHub.arm64ApkSize}
            </span>
          </div>
          <p className="text-xs text-slate-600 leading-relaxed mb-5">
            Optimized file size for modern 64-bit Android processors. Fast download designed for students on mobile data connections.
          </p>
          <a
            href={downloadHub.arm64ApkUrl}
            target="_blank"
            rel="noopener noreferrer"
            className="inline-flex items-center gap-1.5 text-xs font-semibold text-slate-900 hover:text-blue-600 transition-colors"
          >
            <Cpu className="w-3.5 h-3.5" />
            <span>Download arm64 Package &rarr;</span>
          </a>
        </div>
      </div>

      {/* Sideload Guide Alert */}
      <div className="mt-8 max-w-5xl mx-auto p-4 rounded-xl bg-slate-50 border border-slate-200 text-xs text-slate-600 flex items-start gap-3">
        <ShieldCheck className="w-4 h-4 text-emerald-600 shrink-0 mt-0.5" />
        <span>
          <strong>Installation note:</strong> {downloadHub.sideloadNote}
        </span>
      </div>

    </div>
  );
}
