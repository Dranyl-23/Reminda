import { getApps, initializeApp, cert, getApp, App } from "firebase-admin/app";
import { getAuth, Auth } from "firebase-admin/auth";
import { getFirestore, Firestore } from "firebase-admin/firestore";

function getServiceAccount() {
  const serviceAccountEnv = process.env.FIREBASE_SERVICE_ACCOUNT_KEY;

  if (serviceAccountEnv) {
    try {
      if (serviceAccountEnv.trim().startsWith("{")) {
        return JSON.parse(serviceAccountEnv);
      }
    } catch (e) {
      console.warn("Failed to parse FIREBASE_SERVICE_ACCOUNT_KEY JSON string:", e);
    }
  }

  // Fallback to separate env variables
  const projectId = process.env.FIREBASE_PROJECT_ID || process.env.NEXT_PUBLIC_FIREBASE_PROJECT_ID || "schedly-b4b8d";
  const clientEmail = process.env.FIREBASE_CLIENT_EMAIL;
  let privateKey = process.env.FIREBASE_PRIVATE_KEY;

  if (clientEmail && privateKey) {
    if (privateKey.includes("\\n")) {
      privateKey = privateKey.replace(/\\n/g, "\n");
    }
    return {
      projectId,
      clientEmail,
      privateKey,
    };
  }

  return null;
}

let app: App;

if (!getApps().length) {
  const serviceAccount = getServiceAccount();

  if (serviceAccount) {
    app = initializeApp({
      credential: cert(serviceAccount),
      projectId: serviceAccount.project_id || serviceAccount.projectId || "schedly-b4b8d",
    });
  } else {
    app = initializeApp({
      projectId: process.env.NEXT_PUBLIC_FIREBASE_PROJECT_ID || "schedly-b4b8d",
    });
  }
} else {
  app = getApp();
}

export const adminAuth: Auth = getAuth(app);
export const adminDb: Firestore = getFirestore(app);

export const AUTHORIZED_ADMIN_EMAILS = [
  "alfielynard23@gmail.com",
  "alfielynardrosalita@gmail.com",
  "dranyl23@gmail.com"
];

export async function verifyAdminRequest(req: Request): Promise<{ authorized: boolean; email?: string; error?: string; status?: number }> {
  const authHeader = req.headers.get("authorization");
  if (!authHeader || !authHeader.startsWith("Bearer ")) {
    return { authorized: false, error: "Unauthorized: Missing Authorization header.", status: 401 };
  }

  const token = authHeader.split("Bearer ")[1]?.trim();
  if (!token) {
    return { authorized: false, error: "Unauthorized: Missing Bearer token.", status: 401 };
  }

  try {
    const decoded = await adminAuth.verifyIdToken(token);
    const email = decoded.email?.toLowerCase();
    const isAdmin = decoded.admin === true || (Boolean(email) && AUTHORIZED_ADMIN_EMAILS.includes(email!));

    if (!isAdmin) {
      return { authorized: false, error: "Forbidden: Account lacks administrator privileges.", status: 403 };
    }

    return { authorized: true, email };
  } catch (err: any) {
    return { authorized: false, error: `Authentication failed: ${err.message}`, status: 401 };
  }
}

export default app;
