import { NextResponse } from "next/server";
import clientPromise from "@/lib/mongodb";
import { verifyAdminRequest } from "@/lib/firebaseAdmin";

export async function POST(req: Request) {
  try {
    const authResult = await verifyAdminRequest(req);
    if (!authResult.authorized) {
      return NextResponse.json({ error: authResult.error }, { status: authResult.status || 401 });
    }

    const body = await req.json();
    const { collectionName, documents } = body;

    if (!collectionName || !Array.isArray(documents)) {
      return NextResponse.json({ error: "Invalid payload format" }, { status: 400 });
    }

    if (documents.some((d: any) => !d || typeof d !== "object" || !d.id)) {
      return NextResponse.json({ error: "One or more documents are missing a valid 'id' property" }, { status: 400 });
    }

    const client = await clientPromise;
    const db = client.db("reminda_warehouse");
    const col = db.collection(collectionName);

    if (documents.length === 0) {
      return NextResponse.json({ success: true, count: 0 });
    }

    // Bulk upsert by id
    const operations = documents.map((doc: any) => ({
      updateOne: {
        filter: { id: doc.id },
        update: { $set: { ...doc, updatedAt: new Date() } },
        upsert: true
      }
    }));

    const result = await col.bulkWrite(operations);

    return NextResponse.json({
      success: true,
      upsertedCount: result.upsertedCount,
      modifiedCount: result.modifiedCount,
      matchedCount: result.matchedCount,
      totalProcessed: documents.length
    });
  } catch (err: any) {
    console.error("MongoDB Sync API Error:", err);
    return NextResponse.json({ error: err.message }, { status: 500 });
  }
}

export async function GET(req: Request) {
  try {
    const authResult = await verifyAdminRequest(req);
    if (!authResult.authorized) {
      return NextResponse.json({ error: authResult.error }, { status: authResult.status || 401 });
    }

    const client = await clientPromise;
    const db = client.db("reminda_warehouse");
    const collections = await db.listCollections().toArray();
    
    const counts: Record<string, number> = {};
    for (const c of collections) {
      counts[c.name] = await db.collection(c.name).countDocuments();
    }

    return NextResponse.json({
      status: "connected",
      database: "reminda_warehouse",
      collections: counts
    });
  } catch (err: any) {
    return NextResponse.json({ status: "error", error: err.message }, { status: 500 });
  }
}
