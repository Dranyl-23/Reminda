"use client";

import React, { createContext, useContext, useEffect, useState } from "react";
import { 
  User, 
  signInWithPopup, 
  signOut, 
  onAuthStateChanged 
} from "firebase/auth";
import { auth, googleProvider } from "@/lib/firebase";

interface AuthContextType {
  user: User | null;
  isAdmin: boolean;
  loading: boolean;
  error: string | null;
  loginWithGoogle: () => Promise<void>;
  logout: () => Promise<void>;
}

// User-friendly custom error messages for Google Authentication
function formatAuthError(err: any): string | null {
  if (!err) return null;
  const code = err.code || "";
  const msg = err.message || "";

  if (code === "auth/popup-closed-by-user" || msg.includes("popup-closed-by-user")) {
    return "Sign-in cancelled. Click the button below whenever you're ready to proceed.";
  }
  if (code === "auth/popup-blocked" || msg.includes("popup-blocked")) {
    return "Google login popup was blocked by your browser. Please allow popups for this site.";
  }
  if (code === "auth/network-request-failed" || msg.includes("network-request-failed")) {
    return "Network connection issue. Please check your internet and try again.";
  }
  if (code === "auth/cancelled-popup-request" || msg.includes("cancelled-popup-request")) {
    return null;
  }
  if (code === "auth/user-disabled" || msg.includes("user-disabled")) {
    return "This administrator account has been disabled. Please contact system support.";
  }
  if (msg.includes("Access denied")) {
    return msg;
  }
  return "Unable to complete Google sign-in. Please try again.";
}

// Authorized Admin Emails
const AUTHORIZED_ADMINS = [
  "alfielynard23@gmail.com",
  "alfielynardrosalita@gmail.com",
  "dranyl23@gmail.com"
];

const AuthContext = createContext<AuthContextType>({
  user: null,
  isAdmin: false,
  loading: true,
  error: null,
  loginWithGoogle: async () => {},
  logout: async () => {},
});

export function AuthProvider({ children }: { children: React.ReactNode }) {
  const [user, setUser] = useState<User | null>(null);
  const [isAdmin, setIsAdmin] = useState(false);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    const unsubscribe = onAuthStateChanged(auth, (currentUser) => {
      setUser(currentUser);
      if (currentUser && currentUser.email) {
        const isAuth =
          currentUser.emailVerified &&
          AUTHORIZED_ADMINS.includes(currentUser.email.toLowerCase());
        setIsAdmin(isAuth);
        if (!isAuth) {
          setError(`Access denied. ${currentUser.email} is not an authorized verified administrator.`);
        } else {
          setError(null);
        }
      } else {
        setIsAdmin(false);
        setError(null);
      }
      setLoading(false);
    });

    return () => unsubscribe();
  }, []);

  const loginWithGoogle = async () => {
    try {
      setError(null);
      setLoading(true);
      const result = await signInWithPopup(auth, googleProvider);
      const email = result.user.email?.toLowerCase();
      if (!email || !result.user.emailVerified || !AUTHORIZED_ADMINS.includes(email)) {
        setError(`Access denied. ${email || "Account"} is not an authorized verified administrator.`);
        await signOut(auth);
      }
    } catch (err: any) {
      console.error("Google sign in error:", err);
      const friendly = formatAuthError(err);
      if (friendly) setError(friendly);
    } finally {
      setLoading(false);
    }
  };

  const logout = async () => {
    try {
      await signOut(auth);
      setUser(null);
      setIsAdmin(false);
      setError(null);
    } catch (err: any) {
      console.error("Sign out error:", err);
    }
  };

  return (
    <AuthContext.Provider value={{ user, isAdmin, loading, error, loginWithGoogle, logout }}>
      {children}
    </AuthContext.Provider>
  );
}

export const useAuth = () => useContext(AuthContext);
