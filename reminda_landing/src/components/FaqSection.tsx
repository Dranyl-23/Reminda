"use client";

import { useState } from "react";
import { ChevronDown } from "lucide-react";
import { useMarketingConfig } from "@/context/MarketingConfigContext";

export function FaqSection() {
  const [openIndex, setOpenIndex] = useState<number | null>(0);
  const { config } = useMarketingConfig();
  const faqs = config.faqs && config.faqs.length > 0 ? config.faqs : [];

  const toggle = (i: number) => {
    setOpenIndex(openIndex === i ? null : i);
  };

  return (
    <div id="faq" className="max-w-4xl mx-auto px-5 py-20 border-t border-slate-100">
      
      {/* Astroship Section Heading */}
      <div className="mb-12 text-center md:text-left">
        <h2 className="text-3xl lg:text-4xl font-bold lg:tracking-tight text-slate-900">
          Frequently Asked Questions
        </h2>
        <p className="text-base text-slate-600 mt-2">
          Everything you need to know about Reminda&apos;s offline alarms, scanners, and compatibility.
        </p>
      </div>

      {/* Clean Accordion */}
      <div className="space-y-3">
        {faqs.map((faq, i) => {
          const isOpen = openIndex === i;
          return (
            <div
              key={i}
              className="border border-slate-200 rounded-xl overflow-hidden bg-white"
            >
              <button
                onClick={() => toggle(i)}
                className="w-full p-5 text-left flex items-center justify-between gap-4 text-slate-900 hover:text-blue-600 transition-colors cursor-pointer"
              >
                <span className="font-semibold text-sm sm:text-base">{faq.q}</span>
                <ChevronDown
                  className={`w-4 h-4 text-slate-400 shrink-0 transition-transform duration-200 ${
                    isOpen ? "rotate-180 text-slate-900" : ""
                  }`}
                />
              </button>

              {isOpen && (
                <div className="px-5 pb-5 text-sm text-slate-600 leading-relaxed border-t border-slate-100 pt-3">
                  {faq.a}
                </div>
              )}
            </div>
          );
        })}
      </div>

    </div>
  );
}
