"use client";

import React, { createContext, useContext, useEffect, useState } from "react";
import { doc, onSnapshot } from "firebase/firestore";
import { db } from "@/lib/firebase";
import { MarketingSiteConfig } from "@/lib/types";
import { defaultMarketingConfig } from "@/lib/marketingDefaults";

interface MarketingConfigContextType {
  config: MarketingSiteConfig;
  isLive: boolean;
}

const MarketingConfigContext = createContext<MarketingConfigContextType>({
  config: defaultMarketingConfig,
  isLive: false,
});

export function MarketingConfigProvider({ children }: { children: React.ReactNode }) {
  const [config, setConfig] = useState<MarketingSiteConfig>(defaultMarketingConfig);
  const [isLive, setIsLive] = useState(false);

  useEffect(() => {
    try {
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
            setIsLive(true);
          }
        },
        (error) => {
          console.warn("Marketing config real-time listener notice:", error.message);
          // Fallback seamlessly to defaultMarketingConfig
        }
      );

      return () => unsub();
    } catch (e: any) {
      console.warn("Failed to attach Firestore listener, using default config:", e.message);
    }
  }, []);

  return (
    <MarketingConfigContext.Provider value={{ config, isLive }}>
      {children}
    </MarketingConfigContext.Provider>
  );
}

export function useMarketingConfig() {
  return useContext(MarketingConfigContext);
}
