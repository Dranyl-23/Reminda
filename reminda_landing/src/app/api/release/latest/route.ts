import { NextResponse } from "next/server";

export async function GET() {
  try {
    const res = await fetch("https://api.github.com/repos/Dranyl-23/Reminda/releases", {
      headers: {
        Accept: "application/vnd.github.v3+json",
        "User-Agent": "Reminda-Landing-Page",
      },
      next: { revalidate: 300 }, // Cache on server for 5 minutes
    });

    if (res.ok) {
      const releases = await res.json();
      if (Array.isArray(releases) && releases.length > 0) {
        const latestRelease =
          releases.find((r: any) => !r.draft && !r.prerelease) || releases[0];

        let apkUrl: string | null = null;
        let windowsUrl: string | null = null;
        let apkSize: string | null = null;
        let windowsSize: string | null = null;

        for (const release of releases) {
          if (release.draft) continue;
          if (!apkUrl) {
            const apk = release.assets?.find((a: any) =>
              a.name?.endsWith(".apk")
            );
            if (apk) {
              apkUrl = apk.browser_download_url;
              apkSize = apk.size
                ? `~${Math.round(apk.size / (1024 * 1024))} MB`
                : null;
            }
          }
          if (!windowsUrl) {
            const win = release.assets?.find(
              (a: any) => a.name?.endsWith(".exe") || a.name?.endsWith(".zip")
            );
            if (win) {
              windowsUrl = win.browser_download_url;
              windowsSize = win.size
                ? `~${Math.round(win.size / (1024 * 1024))} MB`
                : null;
            }
          }
        }

        return NextResponse.json({
          tagName: latestRelease.tag_name,
          name: latestRelease.name || latestRelease.tag_name,
          publishedAt: latestRelease.published_at,
          htmlUrl: latestRelease.html_url,
          apkUrl: apkUrl || "/api/download/android",
          apkSize,
          windowsUrl: windowsUrl || "/api/download/windows",
          windowsSize,
        });
      }
    }
  } catch (error) {
    console.error("Failed to query latest release:", error);
  }

  return NextResponse.json({
    tagName: "v1.0.0+17",
    name: "Reminda v1.0.0+17",
    htmlUrl: "https://github.com/Dranyl-23/Reminda/releases",
    apkUrl: "/api/download/android",
    apkSize: "~68 MB",
    windowsUrl: "/api/download/windows",
    windowsSize: "~39 MB",
  });
}
