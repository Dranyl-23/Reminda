interface FooterProps {
  copyrightText: string;
  githubUrl: string;
  primaryButtonUrl: string;
  versionBadge: string;
}

export function Footer({ copyrightText, githubUrl, primaryButtonUrl, versionBadge }: FooterProps) {
  const footer = { copyrightText, githubUrl };
  const hero = { primaryButtonUrl, versionBadge };

  return (
    <footer className="my-20">
      <p className="text-center text-sm text-slate-500">
        {footer.copyrightText}
      </p>
      <p className="text-center text-xs text-slate-400 mt-1">
        Open Source Student Project &bull;{" "}
        <a
          href={footer.githubUrl}
          target="_blank"
          rel="noopener noreferrer"
          className="hover:underline text-slate-600 font-medium"
        >
          GitHub Repository
        </a>{" "}
        &bull;{" "}
        <a
          href={hero.primaryButtonUrl}
          target="_blank"
          rel="noopener noreferrer"
          className="hover:underline text-slate-600 font-medium"
        >
          Release {hero.versionBadge}
        </a>
      </p>
    </footer>
  );
}
