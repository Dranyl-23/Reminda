import type { Metadata } from "next";
import { Inter } from "next/font/google";
import "./globals.css";
import { Sidebar } from "@/components/Sidebar";
import { AuthProvider } from "@/context/AuthContext";
import { ThemeProvider } from "@/context/ThemeContext";
import { AuthGuard } from "@/components/AuthGuard";

const inter = Inter({ subsets: ["latin"], variable: "--font-inter" });

export const metadata: Metadata = {
  title: "Reminda Studio — Executive Analytics & Admin Console",
  description: "Minimalist executive dashboard for Reminda",
  icons: {
    icon: [
      { url: "/icon.png", type: "image/png" },
      { url: "/favicon.ico" },
    ],
    shortcut: "/icon.png",
    apple: "/apple-icon.png",
  },
};

export default function RootLayout({
  children,
}: Readonly<{
  children: React.ReactNode;
}>) {
  return (
    <html lang="en">
      <head>
        <link rel="icon" href="/icon.png" sizes="any" />
        <link rel="apple-touch-icon" href="/apple-icon.png" />
      </head>
      <body
        className={`${inter.className} bg-[#FAFAFA] dark:bg-[#09090B] text-zinc-900 dark:text-zinc-100 antialiased min-h-screen selection:bg-zinc-900 selection:text-white dark:selection:bg-zinc-100 dark:selection:text-zinc-950 transition-colors duration-200`}
      >
        <ThemeProvider>
          <AuthProvider>
            <AuthGuard>
              <div className="flex min-h-screen bg-[#FAFAFA] dark:bg-[#09090B]">
                <Sidebar />
                <div className="flex-1 flex flex-col min-h-screen overflow-x-hidden bg-white dark:bg-[#09090B]">
                  {children}
                </div>
              </div>
            </AuthGuard>
          </AuthProvider>
        </ThemeProvider>
      </body>
    </html>
  );
}
