import { NextRequest, NextResponse } from "next/server";
import { FieldValue } from "firebase-admin/firestore";
import { adminAuth, adminDb, isAdminToken } from "@/lib/firebaseAdmin";

const EXTRACTION_SYSTEM_PROMPT = `You are an expert schedule extraction AI. Analyze the provided schedule image or document text (which could be a university class timetable, certificate of registration / matriculation / enrollment form, study load, work shift roster, hospital/security duty roster, or handwritten schedule).

Extract EVERY schedule event/shift without skipping any rows, subjects, lectures, or laboratory sessions. Output ONLY a valid JSON array matching this exact schema:
[
  {
    "title": "string (subject code, course name, job role, or duty description e.g. ITIAS2, IT SAM, Cashier Duty)",
    "category": "string (one of: 'class', 'work', 'duty', 'custom')",
    "daysOfWeek": [1, 3, 5],
    "startTime": "string (24-hour format HH:mm e.g. 07:00, 08:30, 13:00, 17:00, 22:00)",
    "endTime": "string (24-hour format HH:mm e.g. 09:00, 10:00, 15:30, 19:00, 06:00)",
    "spansNextDay": false,
    "location": "string or null (room number, venue, lab e.g. CLB 4, LAN LAB, Room 302)",
    "notes": "string or null (course description, professor/instructor name)"
  }
]

Critical Extraction Rules:
1. Extract ALL entries on the document. Do NOT truncate or omit any course, lecture, laboratory session, or day.
2. Separate Lecture and Lab entries into distinct items if they have different times/days.
3. Resolve day abbreviations: M/Mon->[1], T/Tu/Tue->[2], W/Wed->[3], TH/Thu/H/R->[4], F/Fri->[5], S/Sat->[6], SU/Sun->[7], TTH->[2,4], MWF->[1,3,5].
4. Convert all 12-hour AM/PM times into 24-hour HH:mm format.
5. Output ONLY the raw JSON array.`;

const DAILY_SCAN_LIMIT = 30;

// Request size caps to protect the paid AI providers from oversized payloads.
const MAX_EXTRACTED_TEXT_CHARS = 200_000;
const MAX_BASE64_CHARS = 8_000_000; // ~6 MB binary

// Model names are configurable because providers retire models regularly.
// Override these in the deployment environment without a code change.
const GROQ_TEXT_MODEL =
  process.env.GROQ_TEXT_MODEL || "llama-3.3-70b-versatile";
const GROQ_VISION_MODEL =
  process.env.GROQ_VISION_MODEL || "meta-llama/llama-4-scout-17b-16e-instruct";
const GEMINI_MODEL = process.env.GEMINI_MODEL || "gemini-2.5-flash";

function extractJsonArray(raw: string): unknown[] {
  const cleaned = raw
    .replace(/```json/gi, "")
    .replace(/```/g, "")
    .trim();
  const start = cleaned.indexOf("[");
  const end = cleaned.lastIndexOf("]");
  if (start === -1 || end === -1 || end <= start) {
    throw new Error("AI response did not contain a valid JSON array.");
  }
  return JSON.parse(cleaned.slice(start, end + 1));
}

/**
 * Usage lives in a server-only collection (`ai_usage/{uid}`). Firestore rules
 * deny all client access to it, so users cannot reset their own quota (the old
 * `users/{uid}.aiScanUsage` field was writable by its owner). The reservation is
 * transactional, so concurrent requests cannot race past the limit.
 */
async function reserveScan(uid: string, todayIso: string): Promise<boolean> {
  const ref = adminDb.collection("ai_usage").doc(uid);
  return adminDb.runTransaction(async (tx) => {
    const snap = await tx.get(ref);
    const data = snap.data() as { date?: string; count?: number } | undefined;
    const current = data && data.date === todayIso ? Number(data.count || 0) : 0;
    if (current >= DAILY_SCAN_LIMIT) return false;
    tx.set(ref, { date: todayIso, count: current + 1 }, { merge: true });
    return true;
  });
}

/** Gives back a reserved scan when the AI call produced nothing usable. */
async function releaseScan(uid: string, todayIso: string): Promise<void> {
  try {
    const ref = adminDb.collection("ai_usage").doc(uid);
    await adminDb.runTransaction(async (tx) => {
      const snap = await tx.get(ref);
      const data = snap.data() as { date?: string; count?: number } | undefined;
      if (data && data.date === todayIso && Number(data.count || 0) > 0) {
        tx.set(ref, { count: FieldValue.increment(-1) }, { merge: true });
      }
    });
  } catch (err) {
    console.warn("/api/ai/parse failed to release scan quota:", err);
  }
}

async function callGroqText(groqKey: string, extractedText: string) {
  const res = await fetch("https://api.groq.com/openai/v1/chat/completions", {
    method: "POST",
    headers: {
      Authorization: `Bearer ${groqKey}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({
      model: GROQ_TEXT_MODEL,
      messages: [
        { role: "system", content: EXTRACTION_SYSTEM_PROMPT },
        {
          role: "user",
          content: `Extract all schedule entries from this digital PDF / COR text:\n\n${extractedText}`,
        },
      ],
      temperature: 0.1,
      max_tokens: 4096,
    }),
  });
  if (!res.ok) {
    console.warn(
      `/api/ai/parse Groq text model ${GROQ_TEXT_MODEL} returned HTTP ${res.status}`,
      (await res.text()).slice(0, 300)
    );
    return null;
  }
  const data = await res.json();
  return (data.choices?.[0]?.message?.content as string) || null;
}

async function callGroqVision(
  groqKey: string,
  base64Data: string,
  mimeType: string
) {
  const normalizedMime = mimeType.includes("png") ? "image/png" : "image/jpeg";
  const res = await fetch("https://api.groq.com/openai/v1/chat/completions", {
    method: "POST",
    headers: {
      Authorization: `Bearer ${groqKey}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({
      model: GROQ_VISION_MODEL,
      messages: [
        {
          role: "user",
          content: [
            { type: "text", text: EXTRACTION_SYSTEM_PROMPT },
            {
              type: "image_url",
              image_url: { url: `data:${normalizedMime};base64,${base64Data}` },
            },
          ],
        },
      ],
      temperature: 0.1,
      max_tokens: 4096,
    }),
  });
  if (!res.ok) {
    console.warn(
      `/api/ai/parse Groq vision model ${GROQ_VISION_MODEL} returned HTTP ${res.status}`,
      (await res.text()).slice(0, 300)
    );
    return null;
  }
  const data = await res.json();
  return (data.choices?.[0]?.message?.content as string) || null;
}

async function callGemini(
  geminiKey: string,
  extractedText: string,
  base64Data: string,
  mimeType: string
) {
  const parts: Record<string, unknown>[] = [
    {
      text: extractedText
        ? `${EXTRACTION_SYSTEM_PROMPT}\n\nDIGITAL PDF / COR TEXT:\n${extractedText}`
        : EXTRACTION_SYSTEM_PROMPT,
    },
  ];

  if (!extractedText && base64Data) {
    parts.push({
      inline_data: {
        mime_type: mimeType.includes("pdf")
          ? "application/pdf"
          : mimeType.includes("png")
          ? "image/png"
          : "image/jpeg",
        data: base64Data,
      },
    });
  }

  // Key goes in a header rather than the URL so it never lands in access logs.
  const res = await fetch(
    `https://generativelanguage.googleapis.com/v1beta/models/${GEMINI_MODEL}:generateContent`,
    {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "x-goog-api-key": geminiKey,
      },
      body: JSON.stringify({
        contents: [{ parts }],
        generationConfig: {
          temperature: 0.1,
          responseMimeType: "application/json",
        },
      }),
    }
  );
  if (!res.ok) {
    console.warn(
      `/api/ai/parse Gemini model ${GEMINI_MODEL} returned HTTP ${res.status}`,
      (await res.text()).slice(0, 300)
    );
    return null;
  }
  const data = await res.json();
  return (data.candidates?.[0]?.content?.parts?.[0]?.text as string) || null;
}

export async function POST(req: NextRequest) {
  let uid = "";
  let todayIso = "";
  let reserved = false;

  try {
    const authHeader = req.headers.get("authorization") || "";
    if (!authHeader.startsWith("Bearer ")) {
      return NextResponse.json(
        { error: "Missing Authorization Bearer token." },
        { status: 401 }
      );
    }

    // 1. Authenticate (a bad / expired token is a 401, not a 500).
    let decodedToken;
    try {
      decodedToken = await adminAuth.verifyIdToken(authHeader.slice(7).trim());
    } catch {
      return NextResponse.json(
        { error: "Invalid or expired authentication token." },
        { status: 401 }
      );
    }
    uid = decodedToken.uid;
    const isAdmin = isAdminToken(decodedToken);

    // 2. Validate the payload BEFORE spending any quota.
    let body: Record<string, unknown>;
    try {
      body = await req.json();
    } catch {
      return NextResponse.json(
        { error: "Request body must be valid JSON." },
        { status: 400 }
      );
    }

    const extractedText =
      typeof body.extractedText === "string" ? body.extractedText.trim() : "";
    const base64Data =
      typeof body.base64Data === "string" ? body.base64Data.trim() : "";
    const mimeType =
      typeof body.mimeType === "string" ? body.mimeType : "image/jpeg";

    if (!extractedText && !base64Data) {
      return NextResponse.json(
        { error: "Either extractedText or base64Data is required." },
        { status: 400 }
      );
    }
    if (
      extractedText.length > MAX_EXTRACTED_TEXT_CHARS ||
      base64Data.length > MAX_BASE64_CHARS
    ) {
      return NextResponse.json(
        { error: "Payload too large." },
        { status: 413 }
      );
    }

    // 3. Reserve one scan from the per-user daily quota (admins are exempt).
    todayIso = new Date().toISOString().slice(0, 10);
    if (!isAdmin) {
      const allowed = await reserveScan(uid, todayIso);
      if (!allowed) {
        return NextResponse.json(
          {
            error: `Daily cloud AI scan limit (${DAILY_SCAN_LIMIT}/day) reached. Offline scanner remains available.`,
          },
          { status: 429 }
        );
      }
      reserved = true;
    }

    const groqKey = process.env.GROQ_API_KEY || "";
    const geminiKey = process.env.GEMINI_API_KEY || "";

    let rawAiOutput: string | null = null;

    // 4a. Try Groq first (Text model for PDF/COR text, Vision model for images)
    if (groqKey) {
      try {
        if (extractedText.length >= 20) {
          rawAiOutput = await callGroqText(groqKey, extractedText);
        } else if (base64Data && !mimeType.includes("pdf")) {
          rawAiOutput = await callGroqVision(groqKey, base64Data, mimeType);
        }
      } catch (err) {
        console.warn("/api/ai/parse Groq tier failed, cascading to Gemini:", err);
      }
    }

    // 4b. Fallback to Google Gemini (Supports Text, Images, and Native PDFs)
    if (!rawAiOutput && geminiKey) {
      try {
        rawAiOutput = await callGemini(
          geminiKey,
          extractedText,
          base64Data,
          mimeType
        );
      } catch (err) {
        console.warn("/api/ai/parse Gemini tier failed:", err);
      }
    }

    if (!rawAiOutput) {
      if (reserved) await releaseScan(uid, todayIso);
      return NextResponse.json(
        {
          error:
            "No server AI engine (GROQ_API_KEY / GEMINI_API_KEY) succeeded.",
        },
        { status: 503 }
      );
    }

    let schedules: unknown[];
    try {
      schedules = extractJsonArray(rawAiOutput);
    } catch (err) {
      console.warn("/api/ai/parse could not parse AI output:", err);
      if (reserved) await releaseScan(uid, todayIso);
      return NextResponse.json(
        { error: "AI returned an unreadable schedule. Please try again." },
        { status: 502 }
      );
    }

    return NextResponse.json({
      success: true,
      schedules,
      rawJson: JSON.stringify(schedules),
    });
  } catch (error) {
    // Don't leak internal error details to clients; log them server-side.
    console.error("/api/ai/parse unexpected error:", error);
    if (reserved) await releaseScan(uid, todayIso);
    return NextResponse.json(
      { error: "Failed to parse schedule." },
      { status: 500 }
    );
  }
}
