import { UploadCloud, Cpu, BellRing } from "lucide-react";

const steps = [
  {
    step: "01",
    title: "Upload or Snap Your Schedule",
    description: "Import your official PDF Certificate of Registration (COR) directly from your student portal downloads, or snap a clear photo of your printed schedule.",
    icon: UploadCloud,
  },
  {
    step: "02",
    title: "AI Extracts & Verifies Courses",
    description: "Reminda's zero-blur text stream parser instantly identifies subject codes, room numbers, class days, and starting/ending hours.",
    icon: Cpu,
  },
  {
    step: "03",
    title: "Alarms & Widgets Activate",
    description: "Your classes appear on your Weekly Timetable, alarms are queued to fire reliably with your custom ringtones, and your Android Home Widget stays updated.",
    icon: BellRing,
  },
];

export function HowItWorks() {
  return (
    <div id="how-it-works" className="max-w-6xl mx-auto px-5 py-20 border-t border-slate-100">
      
      {/* Astroship Section Heading */}
      <div className="mb-14">
        <h2 className="text-4xl lg:text-5xl font-bold lg:tracking-tight text-slate-900">
          How it works in 3 simple steps
        </h2>
        <p className="text-lg mt-3 text-slate-600 max-w-xl">
          Automate your entire semester setup in under 30 seconds with zero manual typing.
        </p>
      </div>

      {/* 3 Step Columns */}
      <div className="grid sm:grid-cols-2 md:grid-cols-3 gap-12 sm:gap-16">
        {steps.map((st, i) => {
          const Icon = st.icon;
          return (
            <div key={i} className="flex gap-4 items-start">
              <div className="mt-1 bg-black rounded-full p-2.5 w-10 h-10 shrink-0 flex items-center justify-center text-white font-mono font-bold text-xs">
                {st.step}
              </div>
              <div>
                <h3 className="font-semibold text-lg text-slate-900">
                  {st.title}
                </h3>
                <p className="text-slate-500 mt-2 text-sm leading-relaxed">
                  {st.description}
                </p>
              </div>
            </div>
          );
        })}
      </div>

    </div>
  );
}
