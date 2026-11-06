import { NextRequest, NextResponse } from "next/server";
import { adminAuth, adminDb, AUTHORIZED_ADMIN_EMAILS, verifyAdminRequest } from "@/lib/firebaseAdmin";
import clientPromise from "@/lib/mongodb";

export async function POST(req: NextRequest) {
  try {
    const authResult = await verifyAdminRequest(req);
    if (!authResult.authorized) {
      return NextResponse.json(
        { success: false, error: authResult.error },
        { status: authResult.status || 401 }
      );
    }

    const body = await req.json();
    const { uid } = body;

    if (!uid || typeof uid !== "string") {
      return NextResponse.json(
        { success: false, error: "Missing or invalid 'uid' parameter." },
        { status: 400 }
      );
    }

    if (uid === authResult.uid) {
      return NextResponse.json(
        { success: false, error: "Cannot delete your own administrator account." },
        { status: 403 }
      );
    }

    // Check if target user is an authorized administrator before deleting
    try {
      const targetUser = await adminAuth.getUser(uid);
      const targetEmail = (targetUser.email || "").toLowerCase();
      if (
        AUTHORIZED_ADMIN_EMAILS.includes(targetEmail) ||
        targetUser.customClaims?.admin === true ||
        targetUser.customClaims?.role === "admin"
      ) {
        return NextResponse.json(
          { success: false, error: "Cannot delete an administrator account via this endpoint." },
          { status: 403 }
        );
      }
    } catch (lookupErr: any) {
      if (lookupErr.code !== "auth/user-not-found") {
        console.error("Firebase Auth getUser check error:", lookupErr);
      }
    }

    let authDeleted = false;
    let authError: string | null = null;

    // 1. Delete from Firebase Authentication
    try {
      await adminAuth.deleteUser(uid);
      authDeleted = true;
    } catch (err: any) {
      if (err.code === "auth/user-not-found") {
        authDeleted = true; // Already deleted or never existed in Auth
      } else {
        console.error("Firebase Auth deleteUser error:", err);
        authError = err.message || "Failed to delete from Firebase Authentication.";
      }
    }

    // 2. Recursively delete Firestore user document, all subcollections, and quota doc
    try {
      const userDocRef = adminDb.collection("users").doc(uid);
      await adminDb.recursiveDelete(userDocRef);
      await adminDb.collection("ai_usage").doc(uid).delete().catch(() => {});
    } catch (err: any) {
      console.error("Firestore user deletion error:", err);
      return NextResponse.json(
        {
          success: false,
          authDeleted,
          authError,
          error: err.message || "Failed to delete Firestore user records.",
        },
        { status: 500 }
      );
    }

    // 3. Delete from MongoDB Atlas (if configured)
    try {
      const client = await clientPromise;
      if (client) {
        const db = client.db("reminda_warehouse");
        await db.collection("users").deleteOne({ $or: [{ id: uid }, { uid: uid }, { _id: uid as any }] });
        await db.collection("schedules").deleteMany({ userId: uid });
        await db.collection("profiles").deleteMany({ userId: uid });
      }
    } catch (mongoErr) {
      // Non-blocking MongoDB sync
    }

    return NextResponse.json({
      success: true,
      authDeleted,
      authError,
      message: authDeleted
        ? `User ${uid} permanently deleted from Firebase Auth and Database.`
        : `User ${uid} database records deleted (Auth note: ${authError})`,
    });
  } catch (error: any) {
    console.error("API /api/users/delete error:", error);
    return NextResponse.json(
      { success: false, error: error.message || "Internal server error" },
      { status: 500 }
    );
  }
}
