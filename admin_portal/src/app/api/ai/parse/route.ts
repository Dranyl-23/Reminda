import { NextRequest, NextResponse } from "next/server";
import { adminAuth, adminDb, AUTHORIZED_ADMIN_EMAILS } from "@/lib/firebaseAdmin";

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

export async function POST(req: NextRequest) {
  try {
    const authHeader = req.headers.get("authorization") || "";
    if (!authHeader.startsWith("Bearer ")) {
      return NextResponse.json(
        { error: "Missing Authorization Bearer token." },
        { status: 401 }
      );
    }

    const idToken = authHeader.slice(7).trim();
    const decodedToken = await adminAuth.verifyIdToken(idToken);
    const uid = decodedToken.uid;
    const email = (decodedToken.email || "").toLowerCase();
    const isAdmin =
      decodedToken.admin === true || AUTHORIZED_ADMIN_EMAILS.includes(email);

    // Per-user daily scan limit enforcement in Firestore
    const todayIso = new Date().toISOString().slice(0, 10);
    const userRef = adminDb.collection("users").doc(uid);

    if (!isAdmin) {
      const userSnap = await userRef.get();
      const usage = userSnap.data()?.aiScanUsage as
        | { date?: string; count?: number }
        | undefined;

      const currentCount =
        usage && usage.date === todayIso ? Number(usage.count || 0) : 0;

      if (currentCount >= DAILY_SCAN_LIMIT) {
        return NextResponse.json(
          {
            error: `Daily cloud AI scan limit (${DAILY_SCAN_LIMIT}/day) reached. Offline scanner remains available.`,
          },
          { status: 429 }
        );
      }

      await userRef.set(
        {
          aiScanUsage: {
            date: todayIso,
            count: currentCount + 1,
          },
        },
        { merge: true }
      );
    }

    const body = await req.json();
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

    const groqKey = process.env.GROQ_API_KEY || "";
    const geminiKey = process.env.GEMINI_API_KEY || "";

    let rawAiOutput: string | null = null;

    // 1. Try Groq first (Text model for PDF/COR text, Vision model for images)
    if (groqKey) {
      try {
        if (extractedText.length >= 20) {
          const groqRes = await fetch(
            "https://api.groq.com/openai/v1/chat/completions",
            {
              method: "POST",
              headers: {
                Authorization: `Bearer ${groqKey}`,
                "Content-Type": "application/json",
              },
              body: JSON.stringify({
                model: "llama-3.3-70b-versatile",
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
            }
          );

          if (groqRes.ok) {
            const data = await groqRes.json();
            rawAiOutput = data.choices?.[0]?.message?.content || null;
          }
        } else if (base64Data && !mimeType.includes("pdf")) {
          const normalizedMime = mimeType.includes("png")
            ? "image/png"
            : "image/jpeg";
          const groqRes = await fetch(
            "https://api.groq.com/openai/v1/chat/completions",
            {
              method: "POST",
              headers: {
                Authorization: `Bearer ${groqKey}`,
                "Content-Type": "application/json",
              },
              body: JSON.stringify({
                model: "llama-3.2-11b-vision-preview",
                messages: [
                  {
                    role: "user",
                    content: [
                      { type: "text", text: EXTRACTION_SYSTEM_PROMPT },
                      {
                        type: "image_url",
                        image_url: {
                          url: `data:${normalizedMime};base64,${base64Data}`,
                        },
                      },
                    ],
                  },
                ],
                temperature: 0.1,
                max_tokens: 4096,
              }),
            }
          );

          if (groqRes.ok) {
            const data = await groqRes.json();
            rawAiOutput = data.choices?.[0]?.message?.content || null;
          }
        }
      } catch (err) {
        console.warn("/api/ai/parse Groq tier failed, cascading to Gemini:", err);
      }
    }

    // 2. Fallback to Google Gemini 1.5/2.0 Flash (Supports Text, Images, and Native PDFs)
    if (!rawAiOutput && geminiKey) {
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

      const geminiRes = await fetch(
        `https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent?key=${geminiKey}`,
        {
          method: "POST",
          headers: { "Content-Type": "application/json" },
          body: JSON.stringify({
            contents: [{ parts }],
            generationConfig: {
              temperature: 0.1,
              responseMimeType: "application/json",
            },
          }),
        }
      );

      if (geminiRes.ok) {
        const data = await geminiRes.json();
        rawAiOutput =
          data.candidates?.[0]?.content?.parts?.[0]?.text || null;
      }
    }

    if (!rawAiOutput) {
      return NextResponse.json(
        {
          error:
            "No server AI engine (GROQ_API_KEY / GEMINI_API_KEY) succeeded.",
        },
        { status: 503 }
      );
    }

    const schedules = extractJsonArray(rawAiOutput);
    return NextResponse.json({
      success: true,
      schedules,
      rawJson: JSON.stringify(schedules),
    });
  } catch (error) {
    const message =
      error instanceof Error ? error.message : "Failed to parse schedule.";
    return NextResponse.json({ error: message }, { status: 500 });
  }
}
