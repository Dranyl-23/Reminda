"use client";

import { useState } from "react";
import { Clock, MapPin, User, Bell, CheckCircle2, Layers } from "lucide-react";

interface ScheduleItem {
  id: string;
  code: string;
  title: string;
  startTime: string;
  endTime: string;
  room: string;
  instructor: string;
  category: "Major" | "Lab" | "GenEd";
  borderColor: string;
  bgColor: string;
  tagColor: string;
}

const mockScheduleData: Record<number, ScheduleItem[]> = {
  1: [ // Monday
    {
      id: "1",
      code: "IT 311",
      title: "Web Systems and Technologies",
      startTime: "08:30 AM",
      endTime: "10:30 AM",
      room: "CS Lab 2",
      instructor: "Prof. Del Rosario",
      category: "Major",
      borderColor: "border-blue-500",
      bgColor: "bg-blue-50/60 hover:bg-blue-50",
      tagColor: "bg-blue-100 text-blue-800",
    },
    {
      id: "2",
      code: "IT 312",
      title: "Data Structures & Algorithms",
      startTime: "01:00 PM",
      endTime: "03:00 PM",
      room: "Room 304",
      instructor: "Engr. Mendoza",
      category: "Major",
      borderColor: "border-indigo-500",
      bgColor: "bg-indigo-50/60 hover:bg-indigo-50",
      tagColor: "bg-indigo-100 text-indigo-800",
    }
  ],
  2: [ // Tuesday
    {
      id: "3",
      code: "GE 104",
      title: "Purposive Communication",
      startTime: "09:00 AM",
      endTime: "10:30 AM",
      room: "Hall B",
      instructor: "Dr. Santos",
      category: "GenEd",
      borderColor: "border-emerald-500",
      bgColor: "bg-emerald-50/60 hover:bg-emerald-50",
      tagColor: "bg-emerald-100 text-emerald-800",
    },
    {
      id: "4",
      code: "IT 313",
      title: "Database Management Systems",
      startTime: "02:00 PM",
      endTime: "04:30 PM",
      room: "CLB 3",
      instructor: "Prof. Villanueva",
      category: "Lab",
      borderColor: "border-purple-500",
      bgColor: "bg-purple-50/60 hover:bg-purple-50",
      tagColor: "bg-purple-100 text-purple-800",
    }
  ],
  3: [ // Wednesday
    {
      id: "5",
      code: "IT 311",
      title: "Web Systems (Hands-on Lab)",
      startTime: "08:30 AM",
      endTime: "11:30 AM",
      room: "Mac Lab 1",
      instructor: "Prof. Del Rosario",
      category: "Lab",
      borderColor: "border-blue-500",
      bgColor: "bg-blue-50/60 hover:bg-blue-50",
      tagColor: "bg-blue-100 text-blue-800",
    },
    {
      id: "6",
      code: "PE 103",
      title: "Physical Education (Team Sports)",
      startTime: "03:00 PM",
      endTime: "05:00 PM",
      room: "Gymnasium",
      instructor: "Coach Ramirez",
      category: "GenEd",
      borderColor: "border-amber-500",
      bgColor: "bg-amber-50/60 hover:bg-amber-50",
      tagColor: "bg-amber-100 text-amber-800",
    }
  ],
  4: [ // Thursday (Matches CJC screenshot)
    {
      id: "7",
      code: "IAS 320",
      title: "Information Assurance & Security (Lecture)",
      startTime: "04:30 PM",
      endTime: "06:30 PM",
      room: "CLB 4",
      instructor: "Dr. Alcantara",
      category: "Major",
      borderColor: "border-indigo-600",
      bgColor: "bg-indigo-50/80 hover:bg-indigo-50",
      tagColor: "bg-indigo-100 text-indigo-800",
    },
    {
      id: "8",
      code: "IAS 320-L",
      title: "Information Assurance & Security (Laboratory)",
      startTime: "06:30 PM",
      endTime: "09:00 PM",
      room: "CLB 4",
      instructor: "Dr. Alcantara",
      category: "Lab",
      borderColor: "border-blue-600",
      bgColor: "bg-blue-50/80 hover:bg-blue-50",
      tagColor: "bg-blue-100 text-blue-800",
    }
  ],
  5: [ // Friday
    {
      id: "9",
      code: "IT 314",
      title: "Software Engineering 1",
      startTime: "10:00 AM",
      endTime: "12:00 PM",
      room: "Room 208",
      instructor: "Engr. Tan",
      category: "Major",
      borderColor: "border-sky-500",
      bgColor: "bg-sky-50/60 hover:bg-sky-50",
      tagColor: "bg-sky-100 text-sky-800",
    },
    {
      id: "10",
      code: "NSTP 2",
      title: "Civic Welfare Training Service",
      startTime: "01:30 PM",
      endTime: "04:30 PM",
      room: "Auditorium",
      instructor: "Ms. Fernandez",
      category: "GenEd",
      borderColor: "border-teal-500",
      bgColor: "bg-teal-50/60 hover:bg-teal-50",
      tagColor: "bg-teal-100 text-teal-800",
    }
  ]
};

const dayNames = [
  { day: 1, name: "Monday" },
  { day: 2, name: "Tuesday" },
  { day: 3, name: "Wednesday" },
  { day: 4, name: "Thursday" },
  { day: 5, name: "Friday" },
];

export function InteractiveTimetable() {
  const [selectedDay, setSelectedDay] = useState(4); // Default Thursday
  const [activeItem, setActiveItem] = useState<ScheduleItem | null>(mockScheduleData[4][0]);

  const items = mockScheduleData[selectedDay] || [];

  return (
    <div id="preview" className="max-w-6xl mx-auto px-5 py-16">
      
      {/* Astroship Section Heading */}
      <div className="mb-10 text-center md:text-left">
        <h2 className="text-3xl lg:text-4xl font-bold lg:tracking-tight text-slate-900">
          Interactive Timetable Preview
        </h2>
        <p className="text-base text-slate-600 mt-2">
          Click across the days below to see how Reminda displays courses, class hours, and room assignments.
        </p>
      </div>

      {/* Main Container */}
      <div className="bg-white rounded-2xl border border-slate-200 shadow-sm p-6 sm:p-8">
        
        {/* Days Pill Row */}
        <div className="flex items-center justify-between pb-6 border-b border-slate-100 flex-wrap gap-3">
          <div className="flex items-center gap-2">
            {dayNames.map((d) => {
              const isSelected = selectedDay === d.day;
              return (
                <button
                  key={d.day}
                  onClick={() => {
                    setSelectedDay(d.day);
                    const dayClasses = mockScheduleData[d.day] || [];
                    setActiveItem(dayClasses[0] || null);
                  }}
                  className={`px-4 py-2 rounded-sm text-xs font-semibold transition-all ${
                    isSelected
                      ? "bg-black text-white"
                      : "bg-slate-100 hover:bg-slate-200 text-slate-700"
                  }`}
                >
                  {d.name}
                </button>
              );
            })}
          </div>

          <span className="text-xs font-medium text-slate-500 font-mono">
            {items.length} classes scheduled
          </span>
        </div>

        {/* 2-Column Schedule Grid */}
        <div className="grid grid-cols-1 lg:grid-cols-12 gap-8 pt-6 items-start">
          
          {/* Left Column: Cards */}
          <div className="lg:col-span-7 space-y-3">
            {items.map((item) => {
              const isSelected = activeItem?.id === item.id;
              return (
                <div
                  key={item.id}
                  onClick={() => setActiveItem(item)}
                  className={`p-4 rounded-xl transition-all cursor-pointer border ${item.borderColor} ${item.bgColor} ${
                    isSelected ? "ring-2 ring-slate-900/10 shadow-sm" : ""
                  }`}
                >
                  <div className="flex items-start justify-between gap-3">
                    <div>
                      <div className="flex items-center gap-2 mb-1">
                        <span className="text-[11px] font-mono font-bold text-slate-900">
                          {item.code}
                        </span>
                        <span className={`text-[10px] font-semibold px-2 py-0.5 rounded-full ${item.tagColor}`}>
                          {item.category}
                        </span>
                      </div>
                      <h4 className="font-bold text-sm text-slate-900">{item.title}</h4>
                    </div>

                    <div className="text-right shrink-0">
                      <span className="text-xs font-mono font-bold text-slate-800 block">
                        {item.startTime}
                      </span>
                      <span className="text-[11px] text-slate-500 font-mono">
                        to {item.endTime}
                      </span>
                    </div>
                  </div>

                  <div className="flex items-center gap-4 mt-3 pt-2 border-t border-slate-200/50 text-xs text-slate-600">
                    <span className="flex items-center gap-1 font-medium">
                      <MapPin className="w-3.5 h-3.5 text-slate-500" />
                      {item.room}
                    </span>
                    <span className="flex items-center gap-1 font-medium">
                      <User className="w-3.5 h-3.5 text-slate-500" />
                      {item.instructor}
                    </span>
                  </div>
                </div>
              );
            })}
          </div>

          {/* Right Column: Class Inspector */}
          <div className="lg:col-span-5 bg-slate-50 rounded-xl p-5 border border-slate-200">
            {activeItem ? (
              <div className="space-y-4">
                <div className="flex items-center justify-between pb-3 border-b border-slate-200">
                  <span className="font-mono font-bold text-xs text-slate-800">
                    Course Details ({activeItem.code})
                  </span>
                  <span className="text-xs text-emerald-600 font-semibold flex items-center gap-1">
                    <CheckCircle2 className="w-3.5 h-3.5" />
                    Alarm Set
                  </span>
                </div>

                <div>
                  <h3 className="font-bold text-base text-slate-900">{activeItem.title}</h3>
                  <p className="text-xs text-slate-600 mt-0.5">Faculty: {activeItem.instructor}</p>
                </div>

                <div className="space-y-2.5 text-xs text-slate-700 bg-white p-3.5 rounded-lg border border-slate-200">
                  <div className="flex justify-between">
                    <span className="text-slate-500 flex items-center gap-1.5">
                      <Clock className="w-3.5 h-3.5" /> Time
                    </span>
                    <span className="font-mono font-bold">{activeItem.startTime} – {activeItem.endTime}</span>
                  </div>
                  <div className="flex justify-between">
                    <span className="text-slate-500 flex items-center gap-1.5">
                      <MapPin className="w-3.5 h-3.5" /> Room
                    </span>
                    <span className="font-semibold">{activeItem.room}</span>
                  </div>
                  <div className="flex justify-between">
                    <span className="text-slate-500 flex items-center gap-1.5">
                      <Bell className="w-3.5 h-3.5" /> Alarm Lead
                    </span>
                    <span className="font-semibold text-blue-600">15 minutes before</span>
                  </div>
                </div>

                <div className="text-[11px] text-slate-500 flex items-start gap-2 bg-blue-50/60 p-3 rounded-lg border border-blue-100">
                  <Layers className="w-4 h-4 text-blue-600 shrink-0 mt-0.5" />
                  <span>
                    Syncs automatically with your <strong>Android Home Screen Widget</strong> without requiring internet.
                  </span>
                </div>
              </div>
            ) : null}
          </div>

        </div>

      </div>
    </div>
  );
}
