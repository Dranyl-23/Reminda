import { NextResponse } from "next/server";

const FALLBACK_WINDOWS_URL =
  "https://github.com/Dranyl-23/Reminda/releases/download/v1.0.0%2B2/Reminda-Setup.exe";

export async function GET() {
  try {
    const res = await fetch("https://api.github.com/repos/Dranyl-23/Reminda/releases", {
      headers: {
        Accept: "application/vnd.github.v3+json",
        "User-Agent": "Reminda-Landing-Page",
      },
      next: { revalidate: 300 }, // cache for 5 minutes
    });

    if (res.ok) {
      const releases = await res.json();
      if (Array.isArray(releases)) {
        for (const release of releases) {
          if (release.draft) continue;
          const windowsAsset = release.assets?.find(
            (a: any) => a.name?.endsWith(".exe") || a.name?.endsWith(".zip")
          );
          if (windowsAsset?.browser_download_url) {
            return NextResponse.redirect(windowsAsset.browser_download_url, 302);
          }
        }
      }
    }
  } catch (error) {
    console.error("Failed to query latest Windows release:", error);
  }

  return NextResponse.redirect(FALLBACK_WINDOWS_URL, 302);
}
