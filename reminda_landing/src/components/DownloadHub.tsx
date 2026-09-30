"use client";

import { useState } from "react";
import { Download, QrCode, ShieldCheck, Cpu } from "lucide-react";
import { useMarketingConfig } from "@/context/MarketingConfigContext";
import { WindowsIcon, AndroidIcon } from "@/components/icons";

export function DownloadHub() {
  const [showQr, setShowQr] = useState(false);
  const { config } = useMarketingConfig();
  const { downloadHub } = config;

  const windowsDownloadUrl = downloadHub.windowsUrl || "https://github.com/Dranyl-23/Reminda/releases/latest/download/reminda-windows-x64.zip";
  const universalApkUrl = downloadHub.universalApkUrl || "https://github.com/Dranyl-23/Reminda/releases/latest/download/app-arm64-v8a-release.apk";

  return (
    <div id="download" className="max-w-6xl mx-auto px-5 py-12">
      
      {/* Astroship Signature Jet-Black CTA Box */}
      <div className="bg-black p-8 md:px-16 md:py-20 mt-10 mx-auto max-w-5xl rounded-lg flex flex-col items-center text-center">
        <span className="text-xs font-mono uppercase tracking-widest text-indigo-400 font-bold mb-2">
          {downloadHub.tag}
        </span>
        <h2 className="text-white text-4xl md:text-6xl tracking-tight font-bold">
          {downloadHub.title}
        </h2>
        <p className="text-slate-400 mt-4 text-lg md:text-xl max-w-2xl leading-relaxed">
          {downloadHub.subtitle}
        </p>

        {/* Dual Platform Action Buttons */}
        <div className="flex flex-col sm:flex-row gap-3 mt-8 items-center justify-center w-full max-w-lg">
          <a
            href={windowsDownloadUrl}
            target="_blank"
            rel="noopener noreferrer"
            className="rounded-sm text-center transition focus-visible:ring-2 ring-offset-2 ring-gray-200 px-5 py-3 bg-white text-black hover:bg-gray-100 border-2 border-transparent font-semibold text-sm flex items-center justify-center gap-2 w-full sm:w-auto shadow-sm"
          >
            <WindowsIcon className="w-4 h-4 text-blue-600" />
            <span>Download for Windows (x64)</span>
          </a>

          <a
            href={universalApkUrl}
            target="_blank"
            rel="noopener noreferrer"
            className="rounded-sm text-center transition focus-visible:ring-2 ring-offset-2 ring-gray-200 px-5 py-3 bg-slate-900 border border-slate-700 hover:border-slate-500 text-white font-semibold text-sm flex items-center justify-center gap-2 w-full sm:w-auto"
          >
            <AndroidIcon className="w-4 h-4 text-emerald-400" />
            <span>Download Android APK</span>
          </a>

          <button
            onClick={() => setShowQr(!showQr)}
            className="rounded-sm text-center transition px-4 py-3 border border-slate-800 hover:border-slate-600 text-slate-300 hover:text-white font-medium text-sm flex items-center justify-center gap-2 cursor-pointer w-full sm:w-auto"
          >
            <QrCode className="w-4 h-4 text-slate-400" />
            <span>{showQr ? "Hide QR" : "Scan QR"}</span>
          </button>
        </div>

        {/* Embedded QR toggle for direct mobile install */}
        {showQr && (
          <div className="mt-8 p-5 rounded-2xl bg-white text-slate-900 inline-block text-center shadow-2xl animate-fade-in border border-slate-100">
            <img
              src={`https://api.qrserver.com/v1/create-qr-code/?size=160x160&data=${encodeURIComponent(
                universalApkUrl
              )}`}
              alt="Download QR Code"
              className="w-36 h-36 mx-auto"
            />
            <p className="text-[11px] text-slate-600 font-semibold mt-3">
              Scan with your phone camera
            </p>
            <p className="text-[10px] text-slate-400 font-mono mt-0.5">
              Direct Android APK installation &bull; Android 8.0+
            </p>
          </div>
        )}
      </div>

      {/* 3 Package Cards: Windows PC + Universal APK + arm64 APK */}
      <div className="grid grid-cols-1 md:grid-cols-3 gap-6 mt-16 max-w-5xl mx-auto">
        
        {/* Card 1: Windows Desktop */}
        <div className="p-6 rounded-xl border border-slate-200 bg-white shadow-xs flex flex-col justify-between">
          <div>
            <div className="flex items-center justify-between mb-3">
              <div className="flex items-center gap-2">
                <WindowsIcon className="w-4 h-4 text-blue-600" />
                <span className="font-bold text-slate-900 text-base">Windows PC</span>
              </div>
              <span className="text-[10px] font-bold px-2 py-0.5 rounded bg-blue-100 text-blue-800">
                Desktop x64
              </span>
            </div>
            <p className="text-xs text-slate-600 leading-relaxed mb-5">
              Native 64-bit Windows client. Designed for laptops and workstations with full timetable overview, quick keyboard navigation, and Firestore cloud sync.
            </p>
          </div>
          <a
            href={windowsDownloadUrl}
            target="_blank"
            rel="noopener noreferrer"
            className="inline-flex items-center gap-1.5 text-xs font-semibold text-slate-900 hover:text-blue-600 transition-colors pt-2 border-t border-slate-100"
          >
            <Download className="w-3.5 h-3.5" />
            <span>Download Windows ({downloadHub.windowsSize || "~18 MB"}) &rarr;</span>
          </a>
        </div>

        {/* Card 2: Universal Android APK */}
        <div className="p-6 rounded-xl border border-slate-200 bg-white shadow-xs flex flex-col justify-between">
          <div>
            <div className="flex items-center justify-between mb-3">
              <div className="flex items-center gap-2">
                <AndroidIcon className="w-4 h-4 text-emerald-600" />
                <span className="font-bold text-slate-900 text-base">Universal APK</span>
              </div>
              <span className="text-[10px] font-bold px-2 py-0.5 rounded bg-emerald-100 text-emerald-800">
                All Android Phones
              </span>
            </div>
            <p className="text-xs text-slate-600 leading-relaxed mb-5">
              Works across all Android smartphones (Android 8.0 Oreo up to Android 15). Compatible with Samsung, Xiaomi, Realme, Oppo, Vivo, and Google Pixel.
            </p>
          </div>
          <a
            href={universalApkUrl}
            target="_blank"
            rel="noopener noreferrer"
            className="inline-flex items-center gap-1.5 text-xs font-semibold text-slate-900 hover:text-blue-600 transition-colors pt-2 border-t border-slate-100"
          >
            <Download className="w-3.5 h-3.5" />
            <span>Download Universal ({downloadHub.universalApkSize}) &rarr;</span>
          </a>
        </div>

        {/* Card 3: arm64 Split APK */}
        <div className="p-6 rounded-xl border border-slate-200 bg-white shadow-xs flex flex-col justify-between">
          <div>
            <div className="flex items-center justify-between mb-3">
              <div className="flex items-center gap-2">
                <Cpu className="w-4 h-4 text-slate-700" />
                <span className="font-bold text-slate-900 text-base">arm64 Split APK</span>
              </div>
              <span className="text-[10px] font-mono font-bold px-2 py-0.5 rounded bg-slate-100 text-slate-700">
                {downloadHub.arm64ApkSize}
              </span>
            </div>
            <p className="text-xs text-slate-600 leading-relaxed mb-5">
              Optimized compact package size for modern 64-bit Android processors. Rapid download engineered for students on mobile data connections.
            </p>
          </div>
          <a
            href={downloadHub.arm64ApkUrl}
            target="_blank"
            rel="noopener noreferrer"
            className="inline-flex items-center gap-1.5 text-xs font-semibold text-slate-900 hover:text-blue-600 transition-colors pt-2 border-t border-slate-100"
          >
            <Cpu className="w-3.5 h-3.5" />
            <span>Download arm64 ({downloadHub.arm64ApkSize}) &rarr;</span>
          </a>
        </div>

      </div>

      {/* Sideload Guide Alert */}
      <div className="mt-8 max-w-5xl mx-auto p-4 rounded-xl bg-slate-50 border border-slate-200 text-xs text-slate-600 flex items-start gap-3">
        <ShieldCheck className="w-4 h-4 text-emerald-600 shrink-0 mt-0.5" />
        <span>
          <strong>Installation note:</strong> On Android, tap <em>Allow from this source</em> if prompted during install. On Windows, unzip and launch <em>Reminda.exe</em>. Reminda is open-source, private, and 100% ad-free.
        </span>
      </div>

    </div>
  );
}
