"use client";

import { useEffect, useState, useRef } from "react";
import { createPortal } from "react-dom";
import { collection, onSnapshot, query, orderBy, doc, deleteDoc, updateDoc, writeBatch } from "firebase/firestore";
import { db, auth } from "@/lib/firebase";
import { AiTrainingSample } from "@/lib/types";
import { Header } from "@/components/Header";
import { ConfirmModal } from "@/components/ConfirmModal";
import { SkeletonCardGrid } from "@/components/Skeleton";
import { downloadJsonFile, downloadCsvFile, downloadJsonlFile } from "@/lib/exportUtils";
import { 
  Database, 
  Search, 
  Trash2, 
  CheckCircle2, 
  Download, 
  Sparkles, 
  Code,
  Edit3,
  X,
  CheckSquare,
  Square,
  Flag,
  Layers,
  CheckCheck
} from "lucide-react";

export default function DatasetLabPage() {
  const [samples, setSamples] = useState<AiTrainingSample[]>([]);
  const [selectedIds, setSelectedIds] = useState<Set<string>>(new Set());
  const [isBatchDeleting, setIsBatchDeleting] = useState(false);
  const [searchQuery, setSearchQuery] = useState("");
  const [selectedQuality, setSelectedQuality] = useState("all");
  const [toastMessage, setToastMessage] = useState<string | null>(null);
  const [deleteTarget, setDeleteTarget] = useState<{ id: string; name?: string } | null>(null);
  const [editingSample, setEditingSample] = useState<AiTrainingSample | null>(null);
  useEffect(() => {
    if (editingSample) document.body.style.overflow = "hidden";
    else document.body.style.overflow = "";
    return () => { document.body.style.overflow = ""; };
  }, [editingSample]);
  const [editQuality, setEditQuality] = useState<"clean" | "unreviewed" | "flagged">("clean");
  const [editOcrText, setEditOcrText] = useState("");
  const [isLoading, setIsLoading] = useState(true);
  const [currentPage, setCurrentPage] = useState(1);
  const itemsPerPage = 8;
  const hasInitialSyncedRef = useRef(false);

  useEffect(() => {
    // Index-free direct collection listener with robust client-side sort
    const colRef = collection(db, "ai_training_samples");
    const unsub = onSnapshot(colRef, (snap) => {
      const list: AiTrainingSample[] = [];
      snap.forEach((doc) => {
        list.push({ id: doc.id, ...doc.data() } as AiTrainingSample);
      });

      // Sort newest first
      list.sort((a, b) => {
        const tA = (a.timestamp as any)?.toMillis ? (a.timestamp as any).toMillis() : (a.createdAtIso ? new Date(a.createdAtIso).getTime() : 0);
        const tB = (b.timestamp as any)?.toMillis ? (b.timestamp as any).toMillis() : (b.createdAtIso ? new Date(b.createdAtIso).getTime() : 0);
        return tB - tA;
      });

      setSamples(list);
      setIsLoading(false);

      if (!hasInitialSyncedRef.current && list.length > 0) {
        hasInitialSyncedRef.current = true;
        auth.currentUser?.getIdToken().then((idToken) => {
          fetch("/api/mongodb/sync", {
            method: "POST",
            headers: {
              "Content-Type": "application/json",
              ...(idToken ? { Authorization: `Bearer ${idToken}` } : {}),
            },
            body: JSON.stringify({ collectionName: "ai_training_datasets", documents: list })
          }).catch(() => {});
        });
      }
    }, (err: any) => {
      console.warn("Dataset snapshot notice:", err.message);
      setIsLoading(false);
    });

    return () => unsub();
  }, []);

  const showToast = (msg: string) => {
    setToastMessage(msg);
    setTimeout(() => setToastMessage(null), 3500);
  };

  const handleConfirmDelete = async () => {
    if (!deleteTarget) return;
    try {
      await deleteDoc(doc(db, "ai_training_samples", deleteTarget.id));
      showToast("Training sample purged from dataset.");
    } catch (err: any) {
      showToast("Failed to delete sample: " + err.message);
    } finally {
      setDeleteTarget(null);
    }
  };

  const openEditModal = (sample: AiTrainingSample) => {
    setEditingSample(sample);
    setEditQuality(sample.qualityStatus || "unreviewed");
    setEditOcrText(sample.rawOcrText || "");
  };

  const handleSaveAnnotatedSample = async () => {
    if (!editingSample) return;
    try {
      await updateDoc(doc(db, "ai_training_samples", editingSample.id), {
        qualityStatus: editQuality,
        rawOcrText: editOcrText.trim(),
        annotatedAt: new Date().toISOString()
      });
      showToast("Sample annotation saved!");
      setEditingSample(null);
    } catch (err: any) {
      showToast("Failed to save annotation: " + err.message);
    }
  };

  const handleToggleSelect = (id: string) => {
    setSelectedIds((prev) => {
      const next = new Set(prev);
      if (next.has(id)) next.delete(id);
      else next.add(id);
      return next;
    });
  };

  const handleSelectAll = () => {
    if (selectedIds.size === paginatedSamples.length && paginatedSamples.length > 0) {
      setSelectedIds(new Set());
    } else {
      setSelectedIds(new Set(paginatedSamples.map((s) => s.id)));
    }
  };

  const handleDeselectAll = () => {
    setSelectedIds(new Set());
  };

  const handleBatchQuality = async (newQuality: "clean" | "flagged" | "unreviewed") => {
    if (selectedIds.size === 0) return;
    try {
      const batch = writeBatch(db);
      selectedIds.forEach((id) => {
        batch.update(doc(db, "ai_training_samples", id), {
          qualityStatus: newQuality,
          annotatedAt: new Date().toISOString()
        });
      });
      await batch.commit();
      showToast(`Updated ${selectedIds.size} samples to "${newQuality.toUpperCase()}".`);
      setSelectedIds(new Set());
    } catch (err: any) {
      showToast("Batch update failed: " + err.message);
    }
  };

  const handleBatchDelete = async () => {
    if (selectedIds.size === 0) return;
    try {
      const batch = writeBatch(db);
      selectedIds.forEach((id) => {
        batch.delete(doc(db, "ai_training_samples", id));
      });
      await batch.commit();
      showToast(`Purged ${selectedIds.size} training samples.`);
      setSelectedIds(new Set());
      setIsBatchDeleting(false);
    } catch (err: any) {
      showToast("Batch delete failed: " + err.message);
    }
  };

  const handleBatchExportJson = () => {
    const targets = samples.filter((s) => selectedIds.has(s.id));
    if (targets.length === 0) return;
    downloadJsonFile(`reminda_dataset_selected_${new Date().toISOString().slice(0, 10)}.json`, targets);
    showToast(`Exported ${targets.length} training samples as JSON.`);
  };

  const handleBatchExportCsv = () => {
    const targets = samples.filter((s) => selectedIds.has(s.id));
    if (targets.length === 0) return;
    const headers = ["ID", "Institution", "Role", "Quality Status", "Classes Count", "Platform", "Raw OCR Snippet", "Date"];
    const rows = targets.map((s) => [
      s.id,
      s.institutionName || "Unknown",
      s.role || "Student",
      s.qualityStatus || "unreviewed",
      s.verifiedEntries ? s.verifiedEntries.length : 0,
      s.platform || "Android",
      (s.rawOcrText || "").replace(/\n/g, " ").slice(0, 200),
      s.createdAtIso || ""
    ]);
    downloadCsvFile(`reminda_dataset_selected_${new Date().toISOString().slice(0, 10)}.csv`, headers, rows);
    showToast(`Exported ${targets.length} training samples as CSV.`);
  };

  const exportJSON = (cleanOnly: boolean = false) => {
    const dataToExport = cleanOnly 
      ? samples.filter((s) => s.qualityStatus === "clean")
      : samples;

    downloadJsonFile(`reminda_dataset_${cleanOnly ? "clean" : "full"}_${Date.now()}.json`, dataToExport);
    showToast(`Exported ${dataToExport.length} samples to JSON!`);
  };

  const exportCSV = () => {
    const cleanSamples = samples.filter((s) => s.qualityStatus === "clean");
    const headers = ["id", "institutionName", "role", "platform", "qualityStatus", "timestamp", "rawOcrText", "entriesCount"];
    const rows = cleanSamples.map((s) => [
      s.id,
      s.institutionName || "",
      s.role || "",
      s.platform || "",
      s.qualityStatus || "",
      (s.timestamp as any)?.seconds || "",
      (s.rawOcrText || "").replace(/\n/g, " "),
      s.verifiedEntries ? s.verifiedEntries.length : 0
    ]);
    downloadCsvFile(`reminda_dataset_clean_${Date.now()}.csv`, headers, rows);
    showToast(`Exported ${cleanSamples.length} clean samples to CSV!`);
  };

  const exportFineTuningJsonl = (selectedOnly: boolean = false) => {
    const SYSTEM_PROMPT =
      "You are an expert schedule extraction AI. Extract every schedule entry from the provided university study load, COR, or work roster text and return ONLY a JSON array matching the schema: [{title, category, daysOfWeek, startTime, endTime, spansNextDay, location, notes}].";

    const candidatePool = selectedOnly
      ? samples.filter((s) => selectedIds.has(s.id))
      : samples.some((s) => s.qualityStatus === "clean")
      ? samples.filter((s) => s.qualityStatus === "clean")
      : samples.filter((s) => s.qualityStatus !== "flagged");

    const validSamples = candidatePool.filter(
      (s) =>
        (s.rawOcrText || "").trim().length > 10 &&
        Array.isArray(s.verifiedEntries) &&
        s.verifiedEntries.length > 0
    );

    if (validSamples.length === 0) {
      showToast("No valid training samples with both OCR text and verified entries found.");
      return;
    }

    const jsonlLines = validSamples.map((s) => {
      const sanitizedEntries = (s.verifiedEntries || []).map((entry) => {
        const raw = entry as unknown as Record<string, unknown>;
        return {
          title: entry.title || "Untitled",
          category: entry.category || "class",
          daysOfWeek: Array.isArray(entry.daysOfWeek) ? entry.daysOfWeek : [],
          startTime: entry.startTime || "08:00",
          endTime: entry.endTime || "09:00",
          spansNextDay: Boolean(raw.spansNextDay),
          location: entry.location ?? null,
          notes: (raw.notes as string | undefined) ?? null,
        };
      });

      return {
        messages: [
          { role: "system", content: SYSTEM_PROMPT },
          { role: "user", content: (s.rawOcrText || "").trim() },
          { role: "assistant", content: JSON.stringify(sanitizedEntries) },
        ],
      };
    });

    downloadJsonlFile(
      `reminda_finetune_${selectedOnly ? "selected" : "groundtruth"}_${new Date().toISOString().slice(0, 10)}.jsonl`,
      jsonlLines
    );
    showToast(`Exported ${jsonlLines.length} ChatML .jsonl examples for LLM Fine-Tuning!`);
  };

  const filtered = samples.filter((s) => {
    const matchesSearch = 
      (s.institutionName || "").toLowerCase().includes(searchQuery.toLowerCase()) ||
      (s.role || "").toLowerCase().includes(searchQuery.toLowerCase()) ||
      (s.rawOcrText || "").toLowerCase().includes(searchQuery.toLowerCase());
    const matchesQuality = selectedQuality === "all" || (s.qualityStatus || "unreviewed") === selectedQuality;
    return matchesSearch && matchesQuality;
  });

  const totalPages = Math.ceil(filtered.length / itemsPerPage) || 1;
  const paginatedSamples = filtered.slice((currentPage - 1) * itemsPerPage, currentPage * itemsPerPage);

  const cleanCount = samples.filter((s) => s.qualityStatus === "clean").length;
  const flaggedCount = samples.filter((s) => s.qualityStatus === "flagged").length;
  const unreviewedCount = samples.filter((s) => !s.qualityStatus || s.qualityStatus === "unreviewed").length;

  return (
    <>
      <Header title="AI Training Dataset & Annotation Lab" />
      <main className="flex-1 px-8 pb-12 space-y-6 max-w-[1600px] w-full">
        {/* Custom Delete Confirmation Modal */}
        <ConfirmModal
          isOpen={!!deleteTarget}
          title="Purge Training Sample?"
          message={`Are you sure you want to purge this blurred / corrupted scan telemetry from "${deleteTarget?.name}"?`}
          confirmText="Yes, Purge Sample"
          cancelText="Cancel"
          onConfirm={handleConfirmDelete}
          onCancel={() => setDeleteTarget(null)}
        />

        {/* Batch Purge Confirmation Modal */}
        <ConfirmModal
          isOpen={isBatchDeleting}
          title="Purge Selected Training Samples?"
          message={`Are you sure you want to permanently purge ${selectedIds.size} training telemetry samples from the dataset? This action cannot be undone.`}
          confirmText={`Yes, Purge ${selectedIds.size} Samples`}
          cancelText="Cancel"
          onConfirm={handleBatchDelete}
          onCancel={() => setIsBatchDeleting(false)}
        />

        {/* Toast */}
        {toastMessage && (
          <div className="fixed bottom-6 right-6 z-50 px-4 py-3 rounded-2xl bg-slate-900 text-white text-xs font-bold shadow-xl flex items-center gap-2.5 animate-bounce">
            <CheckCircle2 className="w-4 h-4 text-emerald-400" />
            <span>{toastMessage}</span>
          </div>
        )}

        {/* Sticky Floating Batch Action Bar */}
        {selectedIds.size > 0 && (
          <div className="fixed bottom-6 left-1/2 -translate-x-1/2 z-50 px-5 py-3 rounded-2xl bg-slate-900/95 dark:bg-[#1E2030]/95 backdrop-blur-md text-white shadow-2xl border border-slate-700/80 flex items-center gap-3 animate-in fade-in slide-in-from-bottom-5">
            <div className="flex items-center gap-2 pr-3 border-r border-slate-700">
              <span className="w-2 h-2 rounded-full bg-blue-400 animate-ping"></span>
              <span className="text-xs font-bold whitespace-nowrap">{selectedIds.size} Selected</span>
            </div>

            <div className="flex items-center gap-1.5 flex-wrap">
              <button
                onClick={() => handleBatchQuality("clean")}
                className="px-3 py-1.5 rounded-xl bg-emerald-600 hover:bg-emerald-500 text-white text-xs font-bold flex items-center gap-1.5 transition-all shadow-xs"
              >
                <Sparkles className="w-3.5 h-3.5" />
                <span>Mark Ground Truth</span>
              </button>

              <button
                onClick={() => handleBatchQuality("flagged")}
                className="px-3 py-1.5 rounded-xl bg-amber-600 hover:bg-amber-500 text-white text-xs font-bold flex items-center gap-1.5 transition-all shadow-xs"
              >
                <Flag className="w-3.5 h-3.5" />
                <span>Flag Issues</span>
              </button>

              <button
                onClick={handleBatchExportCsv}
                className="px-3 py-1.5 rounded-xl bg-slate-800 hover:bg-slate-700 text-slate-200 text-xs font-bold flex items-center gap-1.5 transition-all border border-slate-700"
              >
                <Download className="w-3.5 h-3.5" />
                <span>CSV</span>
              </button>

              <button
                onClick={handleBatchExportJson}
                className="px-3 py-1.5 rounded-xl bg-slate-800 hover:bg-slate-700 text-slate-200 text-xs font-bold flex items-center gap-1.5 transition-all border border-slate-700"
              >
                <Download className="w-3.5 h-3.5" />
                <span>JSON</span>
              </button>

              <button
                onClick={() => exportFineTuningJsonl(true)}
                className="px-3 py-1.5 rounded-xl bg-indigo-600 hover:bg-indigo-500 text-white text-xs font-bold flex items-center gap-1.5 transition-all shadow-xs"
              >
                <Sparkles className="w-3.5 h-3.5" />
                <span>.JSONL</span>
              </button>

              <button
                onClick={() => setIsBatchDeleting(true)}
                className="px-3 py-1.5 rounded-xl bg-rose-600 hover:bg-rose-500 text-white text-xs font-bold flex items-center gap-1.5 transition-all shadow-xs"
              >
                <Trash2 className="w-3.5 h-3.5" />
                <span>Purge</span>
              </button>
            </div>

            <button
              onClick={handleDeselectAll}
              className="p-1.5 rounded-xl hover:bg-slate-800 text-slate-400 hover:text-white transition-colors ml-2"
              title="Clear selection"
            >
              <X className="w-4 h-4" />
            </button>
          </div>
        )}

        {/* Top Header Actions */}
        <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-4">
          <div>
            <p className="text-xs text-slate-500 dark:text-slate-400 font-semibold">
              Ground-Truth Dataset Manager. Review OCR telemetry, purge blurred photos, and annotate schedule boundaries before model fine-tuning.
            </p>
          </div>

          <div className="flex items-center gap-2.5 flex-wrap">
            <button
              onClick={() => exportFineTuningJsonl(false)}
              className="px-4 py-2.5 rounded-2xl bg-indigo-600 hover:bg-indigo-700 text-white font-bold text-xs shadow-xs transition-colors flex items-center gap-2"
            >
              <Sparkles className="w-4 h-4" />
              Export .jsonl (Fine-Tune)
            </button>
            <button
              onClick={() => exportJSON(true)}
              className="px-4 py-2.5 rounded-2xl bg-white dark:bg-[#1C1D2B] border border-slate-200 dark:border-[#282A3D]/80 text-slate-800 dark:text-slate-200 hover:bg-slate-50 dark:hover:bg-[#25273A]/60 font-bold text-xs shadow-xs transition-colors flex items-center gap-2"
            >
              <Code className="w-4 h-4 text-blue-600" />
              Export Clean JSON
            </button>
            <button
              onClick={exportCSV}
              className="px-4 py-2.5 rounded-2xl bg-blue-600 hover:bg-blue-700 text-white font-bold text-xs shadow-xs transition-colors flex items-center gap-2"
            >
              <Download className="w-4 h-4" />
              Export Clean CSV
            </button>
          </div>
        </div>

        {/* Metric Cards Bar */}
        <div className="grid grid-cols-1 sm:grid-cols-4 gap-4">
          <div className="p-5 rounded-3xl bg-white dark:bg-[#1C1D2B] border border-slate-200 dark:border-[#282A3D]/70 shadow-xs flex items-center justify-between">
            <div>
              <span className="text-xs font-bold text-slate-500 dark:text-slate-300 uppercase tracking-wider">Total Scans</span>
              <p className="text-2xl font-black text-slate-900 dark:text-white mt-1">{samples.length}</p>
            </div>
            <div className="p-3 rounded-2xl bg-blue-50 text-blue-600 font-bold">
              <Database className="w-5 h-5" />
            </div>
          </div>

          <div className="p-5 rounded-3xl bg-white dark:bg-[#1C1D2B] border border-slate-200 dark:border-[#282A3D]/70 shadow-xs flex items-center justify-between">
            <div>
              <span className="text-xs font-bold text-emerald-600 uppercase tracking-wider">Clean & High Quality</span>
              <p className="text-2xl font-black text-slate-900 dark:text-white mt-1">{cleanCount}</p>
            </div>
            <div className="p-3 rounded-2xl bg-emerald-50 text-emerald-600 font-bold">
              <Sparkles className="w-5 h-5" />
            </div>
          </div>

          <div className="p-5 rounded-3xl bg-white dark:bg-[#1C1D2B] border border-slate-200 dark:border-[#282A3D]/70 shadow-xs flex items-center justify-between">
            <div>
              <span className="text-xs font-bold text-slate-500 dark:text-slate-400 uppercase tracking-wider">Unreviewed</span>
              <p className="text-2xl font-black text-slate-900 dark:text-white mt-1">{unreviewedCount}</p>
            </div>
            <div className="p-3 rounded-2xl bg-slate-100 dark:bg-[#25273A] text-slate-600 dark:text-slate-400 font-bold">
              <Code className="w-5 h-5" />
            </div>
          </div>

          <div className="p-5 rounded-3xl bg-white dark:bg-[#1C1D2B] border border-slate-200 dark:border-[#282A3D]/70 shadow-xs flex items-center justify-between">
            <div>
              <span className="text-xs font-bold text-rose-500 uppercase tracking-wider">Flagged / Blurred</span>
              <p className="text-2xl font-black text-slate-900 dark:text-white mt-1">{flaggedCount}</p>
            </div>
            <div className="p-3 rounded-2xl bg-rose-50 text-rose-600 font-bold">
              <Trash2 className="w-5 h-5" />
            </div>
          </div>
        </div>

        {/* Filters & Search Toolbar */}
        <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-4">
          <div className="relative flex-1 max-w-md">
            <Search className="w-4 h-4 text-slate-400 absolute left-3.5 top-1/2 -translate-y-1/2" />
            <input
              type="text"
              placeholder="Search by school, user role, or extracted text..."
              value={searchQuery}
              onChange={(e) => setSearchQuery(e.target.value)}
              className="w-full pl-10 pr-4 py-2.5 rounded-2xl bg-white dark:bg-[#1C1D2B] border border-slate-200 dark:border-[#282A3D]/80 text-xs font-semibold text-slate-800 dark:text-slate-200 placeholder:text-slate-400 focus:outline-blue-600 shadow-xs"
            />
          </div>

          <div className="flex items-center gap-2 p-1.5 rounded-2xl bg-white dark:bg-[#1C1D2B] border border-slate-200 dark:border-[#282A3D]/70 shadow-xs">
            <button
              onClick={() => setSelectedQuality("all")}
              className={`px-4 py-2 rounded-xl text-xs font-bold transition-all ${
                selectedQuality === "all" ? "bg-slate-900 text-white shadow-xs" : "text-slate-600 hover:text-slate-900 dark:text-white"
              }`}
            >
              All ({samples.length})
            </button>
            <button
              onClick={() => setSelectedQuality("clean")}
              className={`px-4 py-2 rounded-xl text-xs font-bold transition-all ${
                selectedQuality === "clean" ? "bg-emerald-500 text-white shadow-xs" : "text-emerald-700 hover:bg-emerald-50"
              }`}
            >
              Clean ({cleanCount})
            </button>
            <button
              onClick={() => setSelectedQuality("unreviewed")}
              className={`px-4 py-2 rounded-xl text-xs font-bold transition-all ${
                selectedQuality === "unreviewed" ? "bg-slate-700 text-white shadow-xs" : "text-slate-600 dark:text-slate-400 hover:bg-slate-100 dark:bg-[#25273A]"
              }`}
            >
              Unreviewed ({unreviewedCount})
            </button>
            <button
              onClick={() => setSelectedQuality("flagged")}
              className={`px-4 py-2 rounded-xl text-xs font-bold transition-all ${
                selectedQuality === "flagged" ? "bg-rose-500 text-white shadow-xs" : "text-rose-700 hover:bg-rose-50"
              }`}
            >
              Flagged ({flaggedCount})
            </button>
          </div>
        </div>

        {/* Dataset Samples List */}
        {isLoading ? (
          <SkeletonCardGrid count={6} />
        ) : filtered.length === 0 ? (
          <div className="py-20 text-center rounded-3xl bg-white dark:bg-[#1C1D2B] border border-slate-200 dark:border-[#282A3D] text-slate-400 text-xs space-y-2">
            <Database className="w-10 h-10 mx-auto text-slate-300" />
            <p className="font-bold text-sm text-slate-800 dark:text-slate-200">No training samples found</p>
            <p className="text-slate-400">Telemetry will automatically appear here when mobile users scan schedules with MMA Spatial Parser.</p>
          </div>
        ) : (
          <div className="space-y-4">
            {/* Select All on Page Toolbar */}
            <div className="flex items-center justify-between px-2 py-1">
              <button
                onClick={handleSelectAll}
                className="flex items-center gap-2 text-xs font-bold text-slate-600 dark:text-slate-300 hover:text-blue-600 transition-colors"
              >
                {selectedIds.size === paginatedSamples.length && paginatedSamples.length > 0 ? (
                  <CheckSquare className="w-4 h-4 text-blue-600" />
                ) : (
                  <Square className="w-4 h-4 text-slate-400" />
                )}
                <span>Select All on Page ({paginatedSamples.length})</span>
              </button>

              {selectedIds.size > 0 && (
                <span className="text-xs font-extrabold text-blue-600 dark:text-blue-400">
                  {selectedIds.size} sample{selectedIds.size > 1 ? "s" : ""} selected
                </span>
              )}
            </div>

            <div className="space-y-4">
              {paginatedSamples.map((s) => {
                const isSelected = selectedIds.has(s.id);

                return (
                  <div
                    key={s.id}
                    onClick={() => handleToggleSelect(s.id)}
                    className={`p-6 rounded-3xl border transition-all space-y-4 cursor-pointer ${
                      isSelected
                        ? "bg-blue-50/40 dark:bg-[#20253B] border-blue-400/80 shadow-md ring-2 ring-blue-500/20"
                        : "bg-white dark:bg-[#1C1D2B] border-slate-200 dark:border-[#282A3D]/70 shadow-xs hover:shadow-md hover:border-slate-300"
                    }`}
                  >
                    <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-3 pb-3 border-b border-slate-100 dark:border-[#282A3D]">
                      <div className="flex items-center gap-3">
                        {/* Checkbox */}
                        <div className="shrink-0">
                          {isSelected ? (
                            <CheckSquare className="w-5 h-5 text-blue-600 fill-blue-50" />
                          ) : (
                            <Square className="w-5 h-5 text-slate-300 hover:text-slate-400" />
                          )}
                        </div>

                        <div className="w-10 h-10 rounded-2xl bg-blue-50 text-blue-600 flex items-center justify-center font-black text-xs shrink-0">
                          {s.role ? s.role.slice(0, 3).toUpperCase() : "AI"}
                        </div>
                        <div>
                          <h4 className="font-extrabold text-sm text-slate-900 dark:text-white">{s.institutionName || "Unknown Institution"}</h4>
                          <p className="text-[11px] text-slate-500 dark:text-slate-400 font-medium">
                            Role: {s.role} • Platform: {s.platform || "Android"} • App: {s.appVersion || "v1.0.0"}
                          </p>
                        </div>
                      </div>

                      <div 
                        onClick={(e) => e.stopPropagation()}
                        className="flex items-center gap-2"
                      >
                        <span className={`px-3 py-1 rounded-full text-xs font-bold ${
                          s.qualityStatus === "clean" 
                            ? "bg-emerald-50 text-emerald-600 border border-emerald-200/60" 
                            : s.qualityStatus === "flagged"
                            ? "bg-rose-50 text-rose-600 border border-rose-200/60"
                            : "bg-slate-100 dark:bg-[#25273A] text-slate-700 dark:text-slate-300"
                        }`}>
                          {(s.qualityStatus || "unreviewed").toUpperCase()}
                        </span>

                        <button
                          onClick={(e) => {
                            e.stopPropagation();
                            openEditModal(s);
                          }}
                          className="px-3 py-1.5 rounded-xl bg-slate-50 dark:bg-[#25273A]/60 hover:bg-slate-100 text-slate-700 dark:text-slate-300 font-bold text-xs flex items-center gap-1 transition-colors"
                        >
                          <Edit3 className="w-3.5 h-3.5 text-slate-500 dark:text-slate-300" />
                          <span>Annotate</span>
                        </button>

                        <button
                          onClick={(e) => {
                            e.stopPropagation();
                            setDeleteTarget({ id: s.id, name: s.institutionName || s.id });
                          }}
                          className="p-1.5 rounded-xl hover:bg-red-50 text-slate-400 hover:text-red-600 transition-colors"
                          title="Purge Sample"
                        >
                          <Trash2 className="w-4 h-4" />
                        </button>
                      </div>
                    </div>

                  <div className="grid grid-cols-1 lg:grid-cols-2 gap-4 text-xs">
                    <div className="space-y-1">
                      <span className="font-bold text-slate-400 uppercase tracking-wider text-[10px]">Raw OCR Stream</span>
                      <div className="p-3 rounded-2xl bg-slate-50 dark:bg-[#25273A]/60 border border-slate-200 dark:border-[#282A3D]/60 font-mono text-[11px] text-slate-700 dark:text-slate-300 max-h-40 overflow-y-auto whitespace-pre-wrap">
                        {s.rawOcrText || "No raw text available"}
                      </div>
                    </div>

                    <div className="space-y-1">
                      <div className="flex items-center justify-between">
                        <span className="font-bold text-slate-400 uppercase tracking-wider text-[10px]">Verified Schedule Blocks</span>
                        <span className="text-[10px] font-bold text-blue-600">{s.verifiedEntries?.length || 0} entries</span>
                      </div>
                      <div className="space-y-1.5 max-h-40 overflow-y-auto">
                        {s.verifiedEntries?.map((entry, idx) => (
                          <div key={idx} className="p-2 rounded-xl bg-white dark:bg-[#25273A] border border-blue-100/80 dark:border-[#282A3D] text-[11px] flex items-center justify-between">
                            <span className="font-bold text-slate-900 dark:text-white">{entry.title}</span>
                            <span className="text-slate-500 dark:text-slate-400 font-mono">{entry.startTime} - {entry.endTime} ({entry.location})</span>
                          </div>
                        ))}
                      </div>
                    </div>
                  </div>
                </div>
              );
            })}
          </div>

            {/* Pagination Controls */}
            {totalPages > 1 && (
              <div className="flex items-center justify-between px-6 py-4 bg-white dark:bg-[#1C1D2B] rounded-2xl border border-slate-200 dark:border-[#282A3D]/70 shadow-xs mt-6">
                <span className="text-xs font-semibold text-slate-500 dark:text-slate-400">
                  Showing {Math.min((currentPage - 1) * itemsPerPage + 1, filtered.length)} to {Math.min(currentPage * itemsPerPage, filtered.length)} of {filtered.length} telemetry samples
                </span>
                <div className="flex items-center gap-2">
                  <button
                    disabled={currentPage === 1}
                    onClick={() => setCurrentPage((p) => Math.max(p - 1, 1))}
                    className="px-3.5 py-1.5 rounded-xl border border-slate-200 dark:border-[#282A3D] text-xs font-bold text-slate-700 dark:text-slate-300 bg-white hover:bg-slate-50 dark:bg-[#25273A]/60 disabled:opacity-40 disabled:cursor-not-allowed transition-colors"
                  >
                    Previous
                  </button>
                  <span className="text-xs font-bold text-slate-800 dark:text-slate-200 px-2">
                    Page {currentPage} of {totalPages}
                  </span>
                  <button
                    disabled={currentPage === totalPages}
                    onClick={() => setCurrentPage((p) => Math.min(p + 1, totalPages))}
                    className="px-3.5 py-1.5 rounded-xl border border-slate-200 dark:border-[#282A3D] text-xs font-bold text-slate-700 dark:text-slate-300 bg-white hover:bg-slate-50 dark:bg-[#25273A]/60 disabled:opacity-40 disabled:cursor-not-allowed transition-colors"
                  >
                    Next
                  </button>
                </div>
              </div>
            )}
          </div>
        )}

        {/* Annotator Modal */}
        {editingSample && typeof document !== "undefined" && createPortal(
          <div className="fixed inset-0 z-9999 bg-black/70 backdrop-blur-sm flex items-center justify-center p-4 overflow-y-auto animate-in fade-in duration-150">
            <div className="w-full max-w-2xl bg-white dark:bg-[#1C1D2B] rounded-3xl p-6 shadow-2xl border border-slate-200 dark:border-[#282A3D] space-y-4 animate-in fade-in zoom-in-95 max-h-[90vh] overflow-y-auto">
              <div className="flex items-center justify-between pb-3 border-b border-slate-100 dark:border-[#282A3D]">
                <div className="flex items-center gap-2.5">
                  <div className="w-8 h-8 rounded-xl bg-blue-50 text-blue-600 flex items-center justify-center font-bold">
                    <Edit3 className="w-4 h-4" />
                  </div>
                  <div>
                    <h3 className="font-extrabold text-sm text-slate-900 dark:text-white">Annotate AI Training Sample</h3>
                    <p className="text-[11px] text-slate-400">{editingSample.institutionName} • {editingSample.role}</p>
                  </div>
                </div>
                <button onClick={() => setEditingSample(null)} className="p-1.5 rounded-xl hover:bg-slate-100 dark:bg-[#25273A] text-slate-400">
                  <X className="w-4 h-4" />
                </button>
              </div>

              <div className="space-y-4 text-xs">
                {/* Quality Status Selector */}
                <div className="space-y-1">
                  <label className="font-bold text-slate-600 dark:text-slate-400 uppercase tracking-wider text-[10px]">Dataset Quality Tag</label>
                  <div className="grid grid-cols-3 gap-2">
                    <button
                      type="button"
                      onClick={() => setEditQuality("clean")}
                      className={`p-2.5 rounded-xl font-bold border transition-colors ${
                        editQuality === "clean" ? "bg-emerald-500 text-white border-emerald-500 shadow-xs" : "bg-slate-50 dark:bg-[#25273A]/60 text-slate-700 dark:text-slate-300 border-slate-200 dark:border-[#282A3D]"
                      }`}
                    >
                      Clean & High Quality
                    </button>
                    <button
                      type="button"
                      onClick={() => setEditQuality("unreviewed")}
                      className={`p-2.5 rounded-xl font-bold border transition-colors ${
                        editQuality === "unreviewed" ? "bg-slate-900 text-white border-slate-900 shadow-xs" : "bg-slate-50 dark:bg-[#25273A]/60 text-slate-700 dark:text-slate-300 border-slate-200 dark:border-[#282A3D]"
                      }`}
                    >
                      Unreviewed
                    </button>
                    <button
                      type="button"
                      onClick={() => setEditQuality("flagged")}
                      className={`p-2.5 rounded-xl font-bold border transition-colors ${
                        editQuality === "flagged" ? "bg-rose-500 text-white border-rose-500 shadow-xs" : "bg-slate-50 dark:bg-[#25273A]/60 text-slate-700 dark:text-slate-300 border-slate-200 dark:border-[#282A3D]"
                      }`}
                    >
                      Flagged / Blurred
                    </button>
                  </div>
                </div>

                {/* Edit Raw OCR Text */}
                <div className="space-y-1">
                  <label className="font-bold text-slate-600 dark:text-slate-400 uppercase tracking-wider text-[10px]">Corrected OCR Text Stream</label>
                  <textarea
                    rows={6}
                    value={editOcrText}
                    onChange={(e) => setEditOcrText(e.target.value)}
                    className="w-full p-3 rounded-2xl bg-slate-50 dark:bg-[#25273A]/60 border border-slate-200 dark:border-[#282A3D] text-slate-900 dark:text-white font-mono text-[11px] focus:outline-blue-600 leading-relaxed"
                  />
                </div>

                <div className="flex items-center justify-end gap-2 pt-3 border-t border-slate-100 dark:border-[#282A3D]">
                  <button onClick={() => setEditingSample(null)} className="px-4 py-2 rounded-xl text-slate-500 dark:text-slate-400 hover:bg-slate-100 dark:bg-[#25273A] font-bold">
                    Cancel
                  </button>
                  <button
                    onClick={handleSaveAnnotatedSample}
                    className="px-5 py-2.5 rounded-xl bg-blue-600 hover:bg-blue-700 text-white font-bold shadow-xs transition-colors"
                  >
                    Save Cleaned Annotation
                  </button>
                </div>
              </div>
            </div>
          </div>,
          document.body
        )}
      </main>
    </>
  );
}
