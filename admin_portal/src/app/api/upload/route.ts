import { NextRequest, NextResponse } from "next/server";
import { verifyAdminRequest } from "@/lib/firebaseAdmin";

export async function POST(req: NextRequest) {
  try {
    const authResult = await verifyAdminRequest(req);
    if (!authResult.authorized) {
      return NextResponse.json(
        { error: authResult.error || "Unauthorized" },
        { status: authResult.status || 401 }
      );
    }

    const body = await req.json();
    const rawBase64 =
      typeof body.base64Image === "string" ? body.base64Image.trim() : "";
    const name =
      typeof body.name === "string" && body.name.trim()
        ? body.name.trim().replace(/[^a-zA-Z0-9_-]/g, "_").slice(0, 40)
        : `institution_${Date.now()}`;

    if (!rawBase64) {
      return NextResponse.json(
        { error: "Missing base64Image payload." },
        { status: 400 }
      );
    }

    const imgbbApiKey =
      process.env.IMGBB_API_KEY || process.env.NEXT_PUBLIC_IMGBB_API_KEY || "";

    // If IMGBB_API_KEY is not configured in the environment yet, return fallback flag
    // so the client gracefully uses its compressed data URI without breaking local dev.
    if (!imgbbApiKey || imgbbApiKey.includes("your_")) {
      return NextResponse.json({
        success: false,
        fallback: true,
        url: rawBase64,
        message:
          "IMGBB_API_KEY not configured on server; using compressed inline image fallback.",
      });
    }

    // Strip `data:image/png;base64,` prefix if present
    const strippedBase64 = rawBase64.includes(",")
      ? rawBase64.split(",")[1]
      : rawBase64;

    const formData = new FormData();
    formData.append("key", imgbbApiKey);
    formData.append("image", strippedBase64);
    formData.append("name", name);

    const imgbbRes = await fetch("https://api.imgbb.com/1/upload", {
      method: "POST",
      body: formData,
    });

    if (!imgbbRes.ok) {
      const errText = await imgbbRes.text();
      return NextResponse.json(
        {
          success: false,
          fallback: true,
          url: rawBase64,
          error: `ImgBB CDN upload returned HTTP ${imgbbRes.status}: ${errText}`,
        },
        { status: 200 }
      );
    }

    const data = await imgbbRes.json();
    const cdnUrl =
      data?.data?.display_url || data?.data?.url || rawBase64;

    return NextResponse.json({
      success: true,
      fallback: false,
      url: cdnUrl,
    });
  } catch (error) {
    const message =
      error instanceof Error ? error.message : "Server image upload failed.";
    return NextResponse.json({ error: message }, { status: 500 });
  }
}
