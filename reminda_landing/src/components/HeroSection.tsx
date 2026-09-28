"use client";

import { useState } from "react";
import { 
  QrCode, 
  Check 
} from "lucide-react";
import { useMarketingConfig } from "@/context/MarketingConfigContext";

function CloudDownloadIcon({ className = "w-5 h-5 text-white" }: { className?: string }) {
  return (
    <svg width="1em" height="1em" className={className} viewBox="0 0 24 24" fill="currentColor">
      <path d="M18.944 11.112C18.507 7.67 15.56 5 12 5C9.244 5 6.85 6.61 5.757 9.149C3.609 9.792 2 11.82 2 14c0 2.657 2.089 4.815 4.708 4.971V19H17.99v-.003L18 19c2.206 0 4-1.794 4-4a4.008 4.008 0 0 0-3.056-3.888zM8 12h3V9h2v3h3l-4 5l-4-5z" />
    </svg>
  );
}

function GithubIcon({ className = "w-4 h-4 text-black" }: { className?: string }) {
  return (
    <svg width="1em" height="1em" className={className} viewBox="0 0 24 24" fill="currentColor">
      <path
        fillRule="evenodd"
        clipRule="evenodd"
        d="M12.026 2c-5.509 0-9.974 4.465-9.974 9.974c0 4.406 2.857 8.145 6.821 9.465c.499.09.679-.217.679-.481c0-.237-.008-.865-.011-1.696c-2.775.602-3.361-1.338-3.361-1.338c-.452-1.152-1.107-1.459-1.107-1.459c-.905-.619.069-.605.069-.605c1.002.07 1.527 1.028 1.527 1.028c.89 1.524 2.336 1.084 2.902.829c.091-.645.351-1.085.635-1.334c-2.214-.251-4.542-1.107-4.542-4.93c0-1.087.389-1.979 1.024-2.675c-.101-.253-.446-1.268.099-2.64c0 0 .837-.269 2.742 1.021a9.582 9.582 0 0 1 2.496-.336a9.554 9.554 0 0 1 2.496.336c1.906-1.291 2.742-1.021 2.742-1.021c.545 1.372.203 2.387.099 2.64c.64.696 1.024 1.587 1.024 2.675c0 3.833-2.33 4.675-4.552 4.922c.355.308.675.916.675 1.846c0 1.334-.012 2.41-.012 2.737c0 .267.178.577.687.479C19.146 20.115 22 16.379 22 11.974C22 6.465 17.535 2 12.026 2z"
      />
    </svg>
  );
}

export function HeroSection() {
  const [showQrModal, setShowQrModal] = useState(false);
  const { config } = useMarketingConfig();
  const { hero } = config;

  return (
    <div className="max-w-6xl mx-auto px-5">
      <main className="grid lg:grid-cols-2 place-items-center pt-12 pb-8 md:pt-14 md:pb-20 gap-8 lg:gap-12">
        
        {/* Right Column: User's Official High-Res Reminda Multi-Mockup */}
        <div className="py-4 md:order-1 w-full flex justify-center items-center">
          <img
            src="/Reminda.png"
            alt="Reminda - Stay Organized, Live Better"
            className="w-full h-auto max-w-lg lg:max-w-xl xl:max-w-2xl object-contain drop-shadow-xl rounded-2xl transition-transform duration-300 hover:scale-[1.02]"
            loading="eager"
          />
        </div>

        {/* Left Column: Astroship-Exact Typography & Dynamic Content */}
        <div>
          <h1 className="text-5xl lg:text-6xl xl:text-7xl font-bold lg:tracking-tight xl:tracking-tighter text-slate-900 leading-[1.08]">
            {hero.title}
          </h1>

          <p className="text-lg mt-4 text-slate-600 max-w-xl leading-relaxed">
            {hero.subtitle}
          </p>

          {/* Astroship Dual CTA Buttons */}
          <div className="mt-6 flex flex-col sm:flex-row gap-3">
            <a
              href={hero.primaryButtonUrl}
              target="_blank"
              rel="noopener noreferrer"
              className="rounded-sm text-center transition focus-visible:ring-2 ring-offset-2 ring-gray-200 px-5 py-2.5 bg-black text-white hover:bg-gray-800 border-2 border-transparent flex gap-1 items-center justify-center font-medium text-sm"
            >
              <CloudDownloadIcon className="text-white w-5 h-5 mr-1" />
              <span>{hero.primaryButtonText}</span>
            </a>

            <a
              href={hero.secondaryButtonUrl}
              target="_blank"
              rel="noopener noreferrer"
              className="rounded-sm text-center transition focus-visible:ring-2 ring-offset-2 ring-gray-200 px-5 py-2.5 bg-white border-2 border-black hover:bg-gray-100 text-black flex gap-1 items-center justify-center font-medium text-sm"
            >
              <GithubIcon className="text-black w-4 h-4 mr-1" />
              <span>{hero.secondaryButtonText}</span>
            </a>

            {hero.enableQrModal && (
              <button
                onClick={() => setShowQrModal(true)}
                className="rounded-sm text-center transition px-4 py-2.5 bg-slate-50 border border-slate-200 hover:bg-slate-100 text-slate-700 flex gap-1.5 items-center justify-center text-sm font-medium cursor-pointer"
              >
                <QrCode className="w-4 h-4 text-slate-600" />
                <span>Scan QR</span>
              </button>
            )}
          </div>

          {/* Key Checklist Badges */}
          <div className="mt-8 flex items-center gap-6 text-xs text-slate-500 font-medium flex-wrap">
            <span className="flex items-center gap-1.5">
              <Check className="w-4 h-4 text-blue-600 stroke-[3]" />
              Zero-Blur PDF Stream OCR
            </span>
            <span className="flex items-center gap-1.5">
              <Check className="w-4 h-4 text-blue-600 stroke-[3]" />
              Home Screen Widget
            </span>
            <span className="flex items-center gap-1.5">
              <Check className="w-4 h-4 text-blue-600 stroke-[3]" />
              100% Offline Alarms
            </span>
          </div>
        </div>

      </main>

      {/* QR Modal */}
      {showQrModal && (
        <div className="fixed inset-0 z-50 flex items-center justify-center p-4 bg-black/60 backdrop-blur-xs">
          <div className="bg-white p-8 rounded-2xl max-w-sm w-full text-center relative border border-slate-200 shadow-2xl">
            <button
              onClick={() => setShowQrModal(false)}
              className="absolute top-4 right-4 text-slate-400 hover:text-slate-800 p-1 font-bold cursor-pointer"
            >
              &times;
            </button>
            <h3 className="text-lg font-bold text-slate-900 mb-1">Scan to Install Reminda</h3>
            <p className="text-xs text-slate-500 mb-6">Point your phone camera to download the APK directly.</p>
            
            <div className="p-3 rounded-xl bg-slate-50 border border-slate-200 mx-auto w-48 h-48 flex items-center justify-center">
              <img
                src={`https://api.qrserver.com/v1/create-qr-code/?size=170x170&data=${encodeURIComponent(
                  config.downloadHub.arm64ApkUrl || "https://github.com/Dranyl-23/Reminda/releases/latest/download/app-arm64-v8a-release.apk"
                )}`}
                alt="Reminda APK Download QR Code"
                className="w-40 h-40"
              />
            </div>

            <p className="text-[11px] text-slate-500 mt-4 font-mono font-medium">
              Release {hero.versionBadge} &bull; Android 8.0+
            </p>
          </div>
        </div>
      )}
    </div>
  );
}
