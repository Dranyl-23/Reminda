"use client";

import { useMarketingConfig } from "@/context/MarketingConfigContext";

interface FooterProps {
  copyrightText?: string;
  githubUrl?: string;
  primaryButtonUrl?: string;
  versionBadge?: string;
}

export function Footer(props: FooterProps) {
  const { config } = useMarketingConfig();
  const copyrightText = props.copyrightText || config.footer.copyrightText;
  const githubUrl = props.githubUrl || config.footer.githubUrl;
  const primaryButtonUrl = props.primaryButtonUrl || "/api/download/android";
  const versionBadge = props.versionBadge || config.hero.versionBadge;

  return (
    <footer className="my-20">
      <p className="text-center text-sm text-slate-500">
        {copyrightText}
      </p>
      <p className="text-center text-xs text-slate-400 mt-1">
        Open Source Student Project &bull;{" "}
        <a
          href={githubUrl}
          target="_blank"
          rel="noopener noreferrer"
          className="hover:underline text-slate-600 font-medium"
        >
          GitHub Repository
        </a>{" "}
        &bull;{" "}
        <a
          href={primaryButtonUrl}
          target="_blank"
          rel="noopener noreferrer"
          className="hover:underline text-slate-600 font-medium"
        >
          Release {versionBadge}
        </a>
      </p>
    </footer>
  );
}
