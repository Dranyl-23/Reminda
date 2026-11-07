"use client";

import React, { useState, useRef, useEffect } from "react";
import { ChevronDown, Check } from "lucide-react";

export interface DropdownOption {
  value: string;
  label: string;
  icon?: React.ComponentType<{ className?: string }>;
  colorClass?: string;
}

interface CustomDropdownProps {
  value: string;
  onChange: (val: string) => void;
  options: (string | DropdownOption)[];
  placeholder?: string;
  className?: string;
  buttonClassName?: string;
  compact?: boolean;
}

export function CustomDropdown({
  value,
  onChange,
  options,
  placeholder = "Select option...",
  className = "",
  buttonClassName = "",
  compact = false,
}: CustomDropdownProps) {
  const [isOpen, setIsOpen] = useState(false);
  const dropdownRef = useRef<HTMLDivElement>(null);

  const normalizedOptions: DropdownOption[] = options.map((opt) => {
    if (typeof opt === "string") {
      return { value: opt, label: opt };
    }
    return opt;
  });

  const selectedOption = normalizedOptions.find((opt) => opt.value === value) || {
    value,
    label: value || placeholder,
  };

  useEffect(() => {
    const handleClickOutside = (event: MouseEvent) => {
      if (dropdownRef.current && !dropdownRef.current.contains(event.target as Node)) {
        setIsOpen(false);
      }
    };
    document.addEventListener("mousedown", handleClickOutside);
    return () => document.removeEventListener("mousedown", handleClickOutside);
  }, []);

  return (
    <div ref={dropdownRef} className={`relative select-none text-xs ${className}`}>
      {/* Trigger Button */}
      <button
        type="button"
        onClick={() => setIsOpen(!isOpen)}
        className={`w-full text-left flex items-center justify-between transition-all font-medium focus:outline-none cursor-pointer ${
          compact
            ? "px-2.5 py-1.5 rounded-lg text-[11px] bg-white dark:bg-zinc-900 border border-zinc-200 dark:border-zinc-800 text-zinc-900 dark:text-zinc-100 hover:bg-zinc-50 dark:hover:bg-zinc-800/80"
            : "px-3 py-2 rounded-lg bg-white dark:bg-zinc-900 border border-zinc-200 dark:border-zinc-800 text-zinc-900 dark:text-zinc-100 hover:border-zinc-300 dark:hover:border-zinc-700"
        } ${
          isOpen
            ? "border-zinc-900 dark:border-zinc-400 ring-2 ring-zinc-900/10 dark:ring-zinc-100/10 shadow-2xs"
            : ""
        } ${buttonClassName}`}
      >
        <span className="truncate flex items-center gap-1.5">
          {selectedOption.icon && (
            <selectedOption.icon className="w-3.5 h-3.5 shrink-0 text-zinc-400 dark:text-zinc-500" />
          )}
          {selectedOption.label}
        </span>
        <ChevronDown
          className={`w-3.5 h-3.5 text-zinc-400 transition-transform duration-200 shrink-0 ml-2 ${
            isOpen ? "rotate-180 text-zinc-900 dark:text-zinc-100" : ""
          }`}
        />
      </button>

      {/* Popover Menu */}
      {isOpen && (
        <div className="absolute z-[999] left-0 right-0 mt-1.5 p-1 rounded-xl bg-white dark:bg-[#18181B] border border-zinc-200 dark:border-zinc-800 shadow-xl max-h-60 overflow-y-auto space-y-0.5 animate-in fade-in zoom-in-95 min-w-[150px]">
          {normalizedOptions.map((opt) => {
            const isSelected = opt.value === value;
            return (
              <button
                key={opt.value}
                type="button"
                onClick={() => {
                  onChange(opt.value);
                  setIsOpen(false);
                }}
                className={`w-full px-2.5 py-1.5 rounded-lg text-left flex items-center justify-between text-xs transition-colors cursor-pointer ${
                  isSelected
                    ? "bg-zinc-100 dark:bg-zinc-800 text-zinc-900 dark:text-zinc-100 font-semibold"
                    : "text-zinc-600 dark:text-zinc-300 hover:bg-zinc-50 dark:hover:bg-zinc-800/60 hover:text-zinc-900 dark:hover:text-zinc-100 font-medium"
                }`}
              >
                <div className="flex items-center gap-2 truncate">
                  {opt.icon && (
                    <opt.icon className="w-3.5 h-3.5 shrink-0 text-zinc-400 dark:text-zinc-500" />
                  )}
                  <span className="truncate">{opt.label}</span>
                </div>

                {isSelected && (
                  <Check className="w-3.5 h-3.5 text-zinc-900 dark:text-zinc-100 shrink-0 ml-2" />
                )}
              </button>
            );
          })}
        </div>
      )}
    </div>
  );
}
