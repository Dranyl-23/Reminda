import type { Metadata } from "next";
import "./globals.css";

export const metadata: Metadata = {
  title: "Reminda — Smart Academic Timetable & AI Schedule Scanner",
  description: "Never miss a class again. Reminda is an intelligent timetable app for students with direct PDF/COR zero-blur scanner, native Android Home Screen widgets, and smart schedule conflict detection.",
  keywords: [
    "Reminda",
    "Schedly",
    "Schedule Scanner",
    "Certificate of Registration parser",
    "COR scanner",
    "College schedule app",
    "Android timetable widget",
    "Class schedule reminder",
    "Cor Jesu College"
  ],
  authors: [{ name: "Reminda Team" }],
  openGraph: {
    title: "Reminda — Smart Academic Timetable & AI Schedule Scanner",
    description: "Import your Certificate of Registration (COR) PDF with zero blur, track upcoming classes on your phone home screen, and stay ahead.",
    type: "website",
    locale: "en_US",
    siteName: "Reminda",
  },
  icons: {
    icon: "/favicon.ico",
  },
};

export default function RootLayout({
  children,
}: Readonly<{
  children: React.ReactNode;
}>) {
  return (
    <html lang="en" className="scroll-smooth">
      <body className="bg-white text-slate-900 antialiased selection:bg-black selection:text-white">
        {children}
      </body>
    </html>
  );
}
