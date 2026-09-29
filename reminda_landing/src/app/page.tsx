import { MarketingConfigProvider } from "@/context/MarketingConfigContext";
import { Navbar } from "@/components/Navbar";
import { HeroSection } from "@/components/HeroSection";
import { FeaturesBento } from "@/components/FeaturesBento";
import { LogosStrip } from "@/components/LogosStrip";
import { InteractiveTimetable } from "@/components/InteractiveTimetable";
import { HowItWorks } from "@/components/HowItWorks";
import { DownloadHub } from "@/components/DownloadHub";
import { FaqSection } from "@/components/FaqSection";
import { Footer } from "@/components/Footer";
import { defaultMarketingConfig } from "@/lib/marketingDefaults";

export default function Home() {
  return (
    <MarketingConfigProvider>
      <div className="min-h-screen bg-white text-slate-900 selection:bg-black selection:text-white">
        <Navbar />
        <HeroSection />
        <FeaturesBento features={defaultMarketingConfig.features} />
        <LogosStrip />
        <InteractiveTimetable />
        <HowItWorks />
        <DownloadHub />
        <FaqSection />
        <Footer
          copyrightText={defaultMarketingConfig.footer.copyrightText}
          githubUrl={defaultMarketingConfig.footer.githubUrl}
          primaryButtonUrl={defaultMarketingConfig.hero.primaryButtonUrl}
          versionBadge={defaultMarketingConfig.hero.versionBadge}
        />
      </div>
    </MarketingConfigProvider>
  );
}
