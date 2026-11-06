import { NextResponse } from "next/server";

const FALLBACK_APK_URL =
  "https://github.com/Dranyl-23/Reminda/releases/download/v1.0.0%2B16/app-arm64-v8a-release.apk";

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
          const apkAsset = release.assets?.find((a: any) =>
            a.name?.endsWith(".apk")
          );
          if (apkAsset?.browser_download_url) {
            return NextResponse.redirect(apkAsset.browser_download_url, 302);
          }
        }
      }
    }
  } catch (error) {
    console.error("Failed to query latest Android APK release:", error);
  }

  return NextResponse.redirect(FALLBACK_APK_URL, 302);
}
