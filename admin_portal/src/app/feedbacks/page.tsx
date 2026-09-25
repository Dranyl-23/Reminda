"use client";

function formatFeedbackDate(timestamp: any, createdAtIso?: string): string {
  try {
    if (timestamp?.toMillis) {
      return new Date(timestamp.toMillis()).toLocaleString("en-US", { month: "short", day: "numeric", hour: "numeric", minute: "2-digit" });
    }
    if (timestamp?.seconds) {
      return new Date(timestamp.seconds * 1000).toLocaleString("en-US", { month: "short", day: "numeric", hour: "numeric", minute: "2-digit" });
    }
    if (createdAtIso) {
      return new Date(createdAtIso).toLocaleString("en-US", { month: "short", day: "numeric", hour: "numeric", minute: "2-digit" });
    }
    if (typeof timestamp === "string") {
      const d = new Date(timestamp);
      if (!isNaN(d.getTime())) {
        return d.toLocaleString("en-US", { month: "short", day: "numeric", hour: "numeric", minute: "2-digit" });
      }
    }
  } catch (_) {}
  return "Just now";
}

import { useEffect, useState } from "react";
import { createPortal } from "react-dom";
import { collection, onSnapshot, query, orderBy, doc, deleteDoc, updateDoc, writeBatch } from "firebase/firestore";
import { db, auth } from "@/lib/firebase";
import { UserFeedback, UserAccount } from "@/lib/types";
import { Header } from "@/components/Header";
import { ConfirmModal } from "@/components/ConfirmModal";
import { CustomDropdown } from "@/components/CustomDropdown";
import { SkeletonCardGrid } from "@/components/Skeleton";
import { downloadJsonFile, downloadCsvFile } from "@/lib/exportUtils";
import { 
  MessageSquare, 
  Search, 
  Trash2, 
  Mail, 
  Send, 
  CheckCircle2, 
  X,
  Copy,
  Check,
  ExternalLink,
  Star,
  CheckSquare,
  Square,
  Download,
  CheckCheck,
  Clock,
  Layers
} from "lucide-react";

export default function FeedbacksPage() {
  const [feedbacks, setFeedbacks] = useState<UserFeedback[]>([]);
  const [selectedIds, setSelectedIds] = useState<Set<string>>(new Set());
  const [isBatchDeleting, setIsBatchDeleting] = useState(false);
  const [searchQuery, setSearchQuery] = useState("");
  const [selectedCategory, setSelectedCategory] = useState("All");
  const [selectedStatus, setSelectedStatus] = useState<"all" | "pending" | "in-progress" | "resolved">("all");
  const [toastMessage, setToastMessage] = useState<string | null>(null);
  const [replyModalFeedback, setReplyModalFeedback] = useState<UserFeedback | null>(null);
  useEffect(() => {
    if (replyModalFeedback) document.body.style.overflow = "hidden";
    else document.body.style.overflow = "";
    return () => { document.body.style.overflow = ""; };
  }, [replyModalFeedback]);
  const [replyText, setReplyText] = useState("");
  const [deleteTargetId, setDeleteTargetId] = useState<string | null>(null);
  const [isLoading, setIsLoading] = useState(true);
  const [copied, setCopied] = useState(false);
  const [currentPage, setCurrentPage] = useState(1);
  const itemsPerPage = 9;
  const [userPhotos, setUserPhotos] = useState<Record<string, string>>({});

  // BUG FIX (Critical #8): Track whether pending feedbacks need a MongoDB sync.
  // Previously, fetch("/api/mongodb/sync") was called inside the onSnapshot
  // callback, meaning the ENTIRE collection was re-uploaded to MongoDB on
  // EVERY Firestore change (every status update, every new feedback, etc.).
  // This caused extreme bandwidth usage and potential rate-limiting.
  // Now syncing is done only on explicit user action via a Sync button.
  const [pendingSync, setPendingSync] = useState(false);
  const [isSyncing, setIsSyncing] = useState(false);

  const syncToMongoDB = async (data: UserFeedback[]) => {
    if (data.length === 0 || isSyncing) return;
    setIsSyncing(true);
    try {
      const idToken = await auth.currentUser?.getIdToken();
      await fetch("/api/mongodb/sync", {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          ...(idToken ? { Authorization: `Bearer ${idToken}` } : {}),
        },
        body: JSON.stringify({ collectionName: "customer_feedbacks", documents: data })
      });
      setPendingSync(false);
    } catch {
      // Sync failure is non-critical; user can retry via button
    } finally {
      setIsSyncing(false);
    }
  };

  useEffect(() => {
    // Listen to users collection to automatically enrich avatars
    const unsubUsers = onSnapshot(collection(db, "users"), (snap) => {
      const map: Record<string, string> = {};
      snap.forEach((d) => {
        const u = d.data() as UserAccount;
        if (u.photoUrl) {
          map[d.id] = u.photoUrl;
          if (u.email) map[u.email.toLowerCase()] = u.photoUrl;
        }
      });
      setUserPhotos(map);
    }, () => {});

    // Index-free direct collection listener with robust client-side sort
    const colRef = collection(db, "user_feedback");
    const unsub = onSnapshot(colRef, (snap) => {
      const list: UserFeedback[] = [];
      snap.forEach((doc) => {
        const data = doc.data();
        list.push({ 
          id: doc.id, 
          status: data.status || "pending",
          ...data 
        } as UserFeedback);
      });

      // Sort newest first by timestamp or createdAtIso
      list.sort((a, b) => {
        const tA = (a.timestamp as any)?.toMillis ? (a.timestamp as any).toMillis() : (a.createdAtIso ? new Date(a.createdAtIso).getTime() : 0);
        const tB = (b.timestamp as any)?.toMillis ? (b.timestamp as any).toMillis() : (b.createdAtIso ? new Date(b.createdAtIso).getTime() : 0);
        return tB - tA;
      });

      setFeedbacks(list);
      setIsLoading(false);
      // Mark that a sync is available — user can trigger it via the Sync button
      if (list.length > 0) setPendingSync(true);
    }, (err: any) => {
      console.warn("Feedback snapshot notice:", err.message);
      setIsLoading(false);
    });

    return () => { unsub(); unsubUsers(); };
  }, []);

  const showToast = (msg: string) => {
    setToastMessage(msg);
    setTimeout(() => setToastMessage(null), 3500);
  };

  const handleUpdateStatus = async (id: string, newStatus: "pending" | "in-progress" | "resolved") => {
    try {
      await updateDoc(doc(db, "user_feedback", id), {
        status: newStatus,
        updatedAt: new Date().toISOString()
      });
      showToast(`Status updated to "${newStatus.toUpperCase()}"!`);
    } catch (err: any) {
      showToast("Error updating status: " + err.message);
    }
  };

  const handleConfirmDelete = async () => {
    if (!deleteTargetId) return;
    try {
      await deleteDoc(doc(db, "user_feedback", deleteTargetId));
      showToast("Feedback deleted successfully.");
    } catch (err: any) {
      showToast("Error deleting feedback: " + err.message);
    } finally {
      setDeleteTargetId(null);
    }
  };

  const handleSendEmail = () => {
    if (!replyModalFeedback || !replyModalFeedback.contactEmail) {
      showToast("No email address provided by user.");
      return;
    }
    const subject = encodeURIComponent("Response from Reminda Support Team");
    const body = encodeURIComponent(replyText);
    window.open(`mailto:${replyModalFeedback.contactEmail}?subject=${subject}&body=${body}`, "_blank");
    setReplyModalFeedback(null);
    setReplyText("");
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
    if (selectedIds.size === paginatedFeedbacks.length && paginatedFeedbacks.length > 0) {
      setSelectedIds(new Set());
    } else {
      setSelectedIds(new Set(paginatedFeedbacks.map((f) => f.id)));
    }
  };

  const handleDeselectAll = () => {
    setSelectedIds(new Set());
  };

  const handleBatchStatus = async (newStatus: "pending" | "in-progress" | "resolved") => {
    if (selectedIds.size === 0) return;
    try {
      const batch = writeBatch(db);
      selectedIds.forEach((id) => {
        batch.update(doc(db, "user_feedback", id), { status: newStatus });
      });
      await batch.commit();
      showToast(`Updated ${selectedIds.size} feedbacks to "${newStatus.toUpperCase()}".`);
      setSelectedIds(new Set());
    } catch (err: any) {
      showToast("Batch status update failed: " + err.message);
    }
  };

  const handleBatchDelete = async () => {
    if (selectedIds.size === 0) return;
    try {
      const batch = writeBatch(db);
      selectedIds.forEach((id) => {
        batch.delete(doc(db, "user_feedback", id));
      });
      await batch.commit();
      showToast(`Deleted ${selectedIds.size} feedback messages.`);
      setSelectedIds(new Set());
      setIsBatchDeleting(false);
    } catch (err: any) {
      showToast("Batch delete failed: " + err.message);
    }
  };

  const handleBatchExportJson = () => {
    const targets = feedbacks.filter((f) => selectedIds.has(f.id));
    if (targets.length === 0) return;
    downloadJsonFile(`reminda_feedbacks_${new Date().toISOString().slice(0, 10)}.json`, targets);
    showToast(`Exported ${targets.length} feedback records as JSON.`);
  };

  const handleBatchExportCsv = () => {
    const targets = feedbacks.filter((f) => selectedIds.has(f.id));
    if (targets.length === 0) return;
    const headers = ["ID", "User Name", "Contact Email", "Rating", "Category", "Message", "Status", "Platform", "App Version", "Date"];
    const rows = targets.map((f) => [
      f.id,
      f.userName || "User",
      f.contactEmail || "",
      f.rating || 5,
      f.category || "General",
      f.comment || f.message || "",
      f.status || "pending",
      f.platform || "Android",
      f.appVersion || "1.0.0",
      f.createdAtIso || ""
    ]);
    downloadCsvFile(`reminda_feedbacks_${new Date().toISOString().slice(0, 10)}.csv`, headers, rows);
    showToast(`Exported ${targets.length} feedback records as CSV.`);
  };

  const handleCopyEmail = (email: string) => {
    navigator.clipboard.writeText(email);
    setCopied(true);
    showToast("Email address copied to clipboard!");
    setTimeout(() => setCopied(false), 2000);
  };

  const filteredFeedbacks = feedbacks.filter((f) => {
    const q = searchQuery.toLowerCase();
    const matchesQuery = 
      (f.userName || "").toLowerCase().includes(q) ||
      (f.contactEmail || "").toLowerCase().includes(q) ||
      (f.comment || "").toLowerCase().includes(q);
    const matchesCategory = selectedCategory === "All" || f.category === selectedCategory;
    const matchesStatus = selectedStatus === "all" || (f.status || "pending") === selectedStatus;
    return matchesQuery && matchesCategory && matchesStatus;
  });

  const totalPages = Math.ceil(filteredFeedbacks.length / itemsPerPage) || 1;
  const paginatedFeedbacks = filteredFeedbacks.slice((currentPage - 1) * itemsPerPage, currentPage * itemsPerPage);

  const pendingCount = feedbacks.filter((f) => !f.status || f.status === "pending").length;
  const inProgressCount = feedbacks.filter((f) => f.status === "in-progress").length;
  const resolvedCount = feedbacks.filter((f) => f.status === "resolved").length;

  return (
    <>
      <Header title="Messages & User Reviews" />
      <main className="flex-1 px-8 pb-12 space-y-6 max-w-[1600px] w-full">
        {/* Custom Delete Confirmation Modal */}
        <ConfirmModal
          isOpen={!!deleteTargetId}
          title="Delete Feedback Message?"
          message="Are you sure you want to delete this customer feedback message?"
          confirmText="Yes, Delete Message"
          cancelText="Cancel"
          onConfirm={handleConfirmDelete}
          onCancel={() => setDeleteTargetId(null)}
        />

        {/* Batch Delete Confirmation Modal */}
        <ConfirmModal
          isOpen={isBatchDeleting}
          title="Delete Selected Feedback Messages?"
          message={`Are you sure you want to permanently delete ${selectedIds.size} feedback messages? This action cannot be undone.`}
          confirmText={`Yes, Delete ${selectedIds.size} Messages`}
          cancelText="Cancel"
          onConfirm={handleBatchDelete}
          onCancel={() => setIsBatchDeleting(false)}
        />

        {/* Toast Notification */}
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
                onClick={() => handleBatchStatus("resolved")}
                className="px-3 py-1.5 rounded-xl bg-emerald-600 hover:bg-emerald-500 text-white text-xs font-bold flex items-center gap-1.5 transition-all shadow-xs"
              >
                <CheckCheck className="w-3.5 h-3.5" />
                <span>Mark Resolved</span>
              </button>

              <button
                onClick={() => handleBatchStatus("in-progress")}
                className="px-3 py-1.5 rounded-xl bg-blue-600 hover:bg-blue-500 text-white text-xs font-bold flex items-center gap-1.5 transition-all shadow-xs"
              >
                <Clock className="w-3.5 h-3.5" />
                <span>In Progress</span>
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
                onClick={() => setIsBatchDeleting(true)}
                className="px-3 py-1.5 rounded-xl bg-rose-600 hover:bg-rose-500 text-white text-xs font-bold flex items-center gap-1.5 transition-all shadow-xs"
              >
                <Trash2 className="w-3.5 h-3.5" />
                <span>Delete</span>
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

        {/* Top Status Tabs Bar */}
        <div className="flex flex-wrap items-center justify-between gap-4">
          <div className="flex items-center gap-2 p-1.5 rounded-2xl bg-white dark:bg-[#1C1D2B] border border-slate-200 dark:border-[#282A3D]/70 shadow-xs">
            <button
              onClick={() => { setSelectedStatus("all"); setCurrentPage(1); }}
              className={`px-4 py-2 rounded-xl text-xs font-bold transition-all ${
                selectedStatus === "all"
                  ? "bg-slate-900 text-white shadow-xs"
                  : "text-slate-600 dark:text-slate-400 hover:text-slate-900"
              }`}
            >
              All ({feedbacks.length})
            </button>
            <button
              onClick={() => { setSelectedStatus("pending"); setCurrentPage(1); }}
              className={`px-4 py-2 rounded-xl text-xs font-bold transition-all flex items-center gap-1.5 ${
                selectedStatus === "pending"
                  ? "bg-amber-500 text-white shadow-xs"
                  : "text-amber-700 hover:bg-amber-50"
              }`}
            >
              <span className="w-2 h-2 rounded-full bg-amber-400" />
              Pending ({pendingCount})
            </button>
            <button
              onClick={() => { setSelectedStatus("in-progress"); setCurrentPage(1); }}
              className={`px-4 py-2 rounded-xl text-xs font-bold transition-all flex items-center gap-1.5 ${
                selectedStatus === "in-progress"
                  ? "bg-blue-600 text-white shadow-xs"
                  : "text-blue-700 hover:bg-blue-50"
              }`}
            >
              <span className="w-2 h-2 rounded-full bg-blue-400" />
              In Progress ({inProgressCount})
            </button>
            <button
              onClick={() => { setSelectedStatus("resolved"); setCurrentPage(1); }}
              className={`px-4 py-2 rounded-xl text-xs font-bold transition-all flex items-center gap-1.5 ${
                selectedStatus === "resolved"
                  ? "bg-emerald-600 text-white shadow-xs"
                  : "text-emerald-700 hover:bg-emerald-50"
              }`}
            >
              <span className="w-2 h-2 rounded-full bg-emerald-400" />
              Resolved ({resolvedCount})
            </button>
          </div>

          {/* Search Bar */}
          <div className="relative flex-1 max-w-md">
            <Search className="w-4 h-4 text-slate-400 absolute left-3.5 top-1/2 -translate-y-1/2" />
            <input
              type="text"
              placeholder="Search by customer name, email, or message..."
              value={searchQuery}
              onChange={(e) => { setSearchQuery(e.target.value); setCurrentPage(1); }}
              className="w-full pl-10 pr-4 py-2.5 rounded-2xl bg-white dark:bg-[#1C1D2B] border border-slate-200 dark:border-[#282A3D] text-xs font-semibold text-slate-800 dark:text-slate-200 placeholder:text-slate-400 focus:outline-blue-600 shadow-xs"
            />
          </div>
        </div>

        {/* Category Filters Bar */}
        <div className="flex items-center gap-2 overflow-x-auto pb-2">
          {["All", "Bug Report", "Feature Request", "UI/UX Feedback", "Schedule Parsing", "General"].map((cat) => (
            <button
              key={cat}
              onClick={() => { setSelectedCategory(cat); setCurrentPage(1); }}
              className={`px-3.5 py-1.5 rounded-xl text-xs font-bold transition-colors shrink-0 ${
                selectedCategory === cat
                  ? "bg-blue-50 text-blue-600 border border-blue-200 shadow-xs"
                  : "bg-slate-100 dark:bg-[#25273A] text-slate-600 dark:text-slate-400 hover:bg-slate-200/80"
              }`}
            >
              {cat}
            </button>
          ))}
        </div>

        {/* Feedback Cards Stream */}
        {isLoading ? (
          <SkeletonCardGrid count={6} />
        ) : filteredFeedbacks.length === 0 ? (
          <div className="py-20 text-center rounded-3xl bg-white dark:bg-[#1C1D2B] border border-slate-200 dark:border-[#282A3D]/70 text-slate-400 text-xs space-y-2">
            <MessageSquare className="w-8 h-8 mx-auto text-slate-300" />
            <p>No feedback submissions found matching your filter.</p>
          </div>
        ) : (
          <div className="space-y-4">
            {/* Select All on Page Toolbar */}
            <div className="flex items-center justify-between px-2 py-1">
              <button
                onClick={handleSelectAll}
                className="flex items-center gap-2 text-xs font-bold text-slate-600 dark:text-slate-300 hover:text-blue-600 transition-colors"
              >
                {selectedIds.size === paginatedFeedbacks.length && paginatedFeedbacks.length > 0 ? (
                  <CheckSquare className="w-4 h-4 text-blue-600" />
                ) : (
                  <Square className="w-4 h-4 text-slate-400" />
                )}
                <span>Select All on Page ({paginatedFeedbacks.length})</span>
              </button>

              {selectedIds.size > 0 && (
                <span className="text-xs font-extrabold text-blue-600 dark:text-blue-400">
                  {selectedIds.size} feedback{selectedIds.size > 1 ? "s" : ""} selected
                </span>
              )}
            </div>

            <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-5">
              {paginatedFeedbacks.map((f) => {
                const currentStatus = f.status || "pending";
                const isSelected = selectedIds.has(f.id);

                return (
                  <div
                    key={f.id}
                    onClick={() => handleToggleSelect(f.id)}
                    className={`p-6 rounded-3xl border transition-all flex flex-col justify-between cursor-pointer ${
                      isSelected
                        ? "bg-blue-50/40 dark:bg-[#20253B] border-blue-400/80 shadow-md ring-2 ring-blue-500/20"
                        : "bg-white dark:bg-[#1C1D2B] border-slate-200 dark:border-[#282A3D]/70 shadow-xs hover:shadow-md hover:border-slate-300"
                    }`}
                  >
                    <div>
                      {/* User Header & Star Rating */}
                      <div className="flex items-start justify-between gap-3 mb-3">
                        <div className="flex items-center gap-3">
                          {/* Selection Checkbox */}
                          <div className="shrink-0">
                            {isSelected ? (
                              <CheckSquare className="w-5 h-5 text-blue-600 fill-blue-50" />
                            ) : (
                              <Square className="w-5 h-5 text-slate-300 hover:text-slate-400" />
                            )}
                          </div>

                          {(() => {
                            const photo = f.userPhotoUrl || f.photoUrl || userPhotos[f.userId] || (f.contactEmail ? userPhotos[f.contactEmail.toLowerCase()] : null);
                            return photo ? (
                              <img
                                src={photo}
                                alt={f.userName || "User"}
                                className="w-10 h-10 rounded-full object-cover border border-slate-200 dark:border-[#282A3D] shadow-xs shrink-0"
                                referrerPolicy="no-referrer"
                              />
                            ) : (
                              <div className="w-10 h-10 rounded-full bg-linear-to-tr from-blue-600 to-indigo-600 text-white flex items-center justify-center font-black text-sm shadow-xs shrink-0">
                                {(f.userName || "U")[0].toUpperCase()}
                              </div>
                            );
                          })()}
                          <div>
                            <h4 className="font-extrabold text-sm text-slate-900 dark:text-white">{f.userName || "User"}</h4>
                            <p className="text-[11px] text-slate-400 font-mono flex items-center gap-1">
                              <Mail className="w-3 h-3 text-slate-400" />
                              {f.contactEmail || "Anonymous / Guest"}
                            </p>
                          </div>
                        </div>

                        {/* Rating */}
                        <div className="flex items-center gap-0.5 text-yellow-400">
                          {Array.from({ length: 5 }).map((_, i) => (
                            <Star
                              key={i}
                              className={`w-3.5 h-3.5 ${
                                i < (f.rating || 5) ? "fill-yellow-400 text-yellow-400" : "text-slate-200"
                              }`}
                            />
                          ))}
                        </div>
                      </div>

                      {/* Feedback Category Badge & Timestamp */}
                      <div className="flex items-center gap-2 mb-3">
                        <span className="px-2.5 py-0.5 rounded-lg text-[10px] font-bold bg-slate-100 dark:bg-[#25273A] text-slate-700 dark:text-slate-300">
                          {f.category || "General Feedback"}
                        </span>
                        <span className="text-[10px] text-slate-400 font-medium">
                          {formatFeedbackDate(f.timestamp, f.createdAtIso)}
                        </span>
                      </div>

                      {/* Comment Message Body */}
                      <p className="text-xs text-slate-700 dark:text-slate-300 leading-relaxed bg-slate-50 dark:bg-[#25273A]/50 p-3.5 rounded-2xl border border-slate-100 dark:border-[#282A3D] mb-4 whitespace-pre-wrap">
                        {f.comment || f.message || "No detailed comment provided."}
                      </p>
                    </div>

                    {/* Footer Actions & Status Select */}
                    <div 
                      onClick={(e) => e.stopPropagation()}
                      className="pt-3 border-t border-slate-100 dark:border-[#282A3D] flex items-center justify-between gap-2"
                    >
                      <div className="flex-1 max-w-32.5">
                        <CustomDropdown
                          value={currentStatus}
                          onChange={(val) => handleUpdateStatus(f.id, val as any)}
                          compact
                          options={[
                            { value: "pending", label: "Pending" },
                            { value: "in-progress", label: "In Progress" },
                            { value: "resolved", label: "Resolved" }
                          ]}
                        />
                      </div>

                      <div className="flex items-center gap-1.5">
                        {f.contactEmail && (
                          <>
                            <button
                              onClick={(e) => {
                                e.stopPropagation();
                                handleCopyEmail(f.contactEmail!);
                              }}
                              className="p-2 rounded-xl text-slate-400 hover:text-slate-700 dark:text-slate-300 hover:bg-slate-100 dark:bg-[#25273A] transition-colors"
                              title="Copy Email"
                            >
                              {copied ? <Check className="w-4 h-4 text-emerald-500" /> : <Copy className="w-4 h-4" />}
                            </button>
                            <button
                              onClick={(e) => {
                                e.stopPropagation();
                                setReplyModalFeedback(f);
                                setReplyText(`Hi ${f.userName || "there"},

Thank you for reaching out to the Reminda Team regarding your feedback on "${f.category || "the app"}".

`);
                              }}
                              className="p-2 rounded-xl bg-blue-50 text-blue-600 hover:bg-blue-100 transition-colors font-bold text-xs flex items-center gap-1"
                              title="Reply via Email"
                            >
                              <Send className="w-3.5 h-3.5" />
                              <span>Reply</span>
                            </button>
                          </>
                        )}

                        <button
                          onClick={(e) => {
                            e.stopPropagation();
                            setDeleteTargetId(f.id);
                          }}
                          className="p-2 rounded-xl text-slate-400 hover:text-red-600 hover:bg-red-50 transition-colors"
                          title="Delete feedback"
                        >
                          <Trash2 className="w-4 h-4" />
                        </button>
                      </div>
                    </div>
                  </div>
                );
              })}
            </div>

            {/* Pagination Controls */}
            {totalPages > 1 && (
              <div className="flex items-center justify-between px-6 py-4 bg-white dark:bg-[#1C1D2B] rounded-2xl border border-slate-200 dark:border-[#282A3D]/70 shadow-xs">
                <span className="text-xs font-semibold text-slate-500 dark:text-slate-400">
                  Showing {Math.min((currentPage - 1) * itemsPerPage + 1, filteredFeedbacks.length)} to {Math.min(currentPage * itemsPerPage, filteredFeedbacks.length)} of {filteredFeedbacks.length} feedbacks
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

        {/* Interactive Reply Modal */}
        {replyModalFeedback && typeof document !== "undefined" && createPortal(
          <div className="fixed inset-0 z-9999 bg-black/70 backdrop-blur-sm flex items-center justify-center p-4 overflow-y-auto animate-in fade-in duration-150">
            <div className="w-full max-w-lg bg-white dark:bg-[#1C1D2B] rounded-3xl p-6 shadow-2xl border border-slate-200 dark:border-[#282A3D] space-y-4 animate-in fade-in zoom-in-95">
              <div className="flex items-center justify-between pb-3 border-b border-slate-100 dark:border-[#282A3D]">
                <div className="flex items-center gap-2.5">
                  <div className="w-8 h-8 rounded-xl bg-blue-50 text-blue-600 flex items-center justify-center font-bold">
                    <Send className="w-4 h-4" />
                  </div>
                  <div>
                    <h3 className="font-extrabold text-sm text-slate-900 dark:text-white">Reply to {replyModalFeedback.userName || "User"}</h3>
                    <p className="text-[11px] text-slate-400 font-mono">{replyModalFeedback.contactEmail}</p>
                  </div>
                </div>
                <button onClick={() => setReplyModalFeedback(null)} className="p-1.5 rounded-xl hover:bg-slate-100 dark:bg-[#25273A] text-slate-400">
                  <X className="w-4 h-4" />
                </button>
              </div>

              <div className="space-y-2">
                <label className="font-bold text-slate-600 dark:text-slate-400 uppercase tracking-wider text-[10px]">Email Message Body</label>
                <textarea
                  rows={6}
                  value={replyText}
                  onChange={(e) => setReplyText(e.target.value)}
                  placeholder="Type your official reply here..."
                  className="w-full p-3 rounded-2xl bg-slate-50 dark:bg-[#25273A]/60 border border-slate-200 dark:border-[#282A3D] text-xs text-slate-900 dark:text-white focus:outline-blue-600 leading-relaxed"
                />
              </div>

              <div className="flex items-center justify-end gap-2 pt-3 border-t border-slate-100 dark:border-[#282A3D]">
                <button
                  onClick={() => setReplyModalFeedback(null)}
                  className="px-4 py-2 rounded-xl text-slate-500 dark:text-slate-400 hover:bg-slate-100 dark:bg-[#25273A] font-bold text-xs"
                >
                  Cancel
                </button>
                <button
                  onClick={handleSendEmail}
                  className="px-4 py-2 rounded-xl bg-blue-600 hover:bg-blue-700 text-white font-bold text-xs shadow-xs flex items-center gap-1.5 transition-colors"
                >
                  <ExternalLink className="w-3.5 h-3.5" />
                  <span>Send via Email Client</span>
                </button>
              </div>
            </div>
          </div>,
          document.body
        )}
      </main>
    </>
  );
}
