import { Smartphone, Database, FileText, Cpu, Sparkles } from "lucide-react";

export function LogosStrip() {
  const technologies = [
    { name: "Zero-Blur PDF", icon: FileText },
    { name: "Gemini 2.5 Flash", icon: Sparkles },
    { name: "Android 8–15", icon: Smartphone },
    { name: "Cloud Firestore", icon: Database },
    { name: "Hive Offline DB", icon: Cpu },
  ];

  return (
    <div className="mt-20 max-w-6xl mx-auto px-5">
      <h2 className="text-center text-slate-500 text-sm font-semibold tracking-wider uppercase">
        Works seamlessly with academic portals &amp; modern Android
      </h2>

      <div className="flex gap-8 md:gap-14 items-center justify-center mt-8 flex-wrap">
        {technologies.map((tech, i) => {
          const Icon = tech.icon;
          return (
            <div
              key={i}
              className="flex items-center gap-2 text-slate-400 hover:text-slate-800 transition-colors select-none"
            >
              <Icon className="w-5 h-5 text-slate-500" />
              <span className="font-semibold text-sm text-slate-700">{tech.name}</span>
            </div>
          );
        })}
      </div>
    </div>
  );
}
