"use client";

import { createPortal } from "react-dom";

import { useEffect, useState, useRef } from "react";
import { 
  collection, 
  onSnapshot, 
  query, 
  orderBy, 
  doc, 
  setDoc, 
  deleteDoc, 
  writeBatch,
  serverTimestamp 
} from "firebase/firestore";
import { db, auth } from "@/lib/firebase";
import { Institution } from "@/lib/types";
import { Header } from "@/components/Header";
import { ConfirmModal } from "@/components/ConfirmModal";
import { CustomDropdown } from "@/components/CustomDropdown";
import { SkeletonCardGrid } from "@/components/Skeleton";
import codebaseInstitutions from "@/lib/codebase_institutions.json";
import { downloadJsonFile, downloadCsvFile } from "@/lib/exportUtils";
import { 
  School, 
  Plus, 
  Search, 
  Trash2, 
  Edit3, 
  CheckCircle2, 
  Sparkles, 
  Building2, 
  X, 
  UploadCloud, 
  Loader2, 
  Check, 
  ChevronLeft, 
  ChevronRight,
  Filter,
  MapPin,
  CheckSquare,
  Square,
  Download,
  Layers,
  Tag
} from "lucide-react";

// Normalizes any category string to the 4 standard executive sectors
function normalizeCategoryLabel(cat?: string, name?: string, shortName?: string): string {
  const n = ((name || "") + " " + (shortName || "")).toLowerCase();
  if (
    n.includes("government") ||
    n.includes("city hall") ||
    n.includes("municipal hall") ||
    n.includes("provincial capitol") ||
    n.includes("capitol (") ||
    n.includes("hall)") ||
    n.includes("deped") ||
    n.includes("bureau of") ||
    n.includes("department of") ||
    n.includes("lgu ") ||
    n.includes("police") ||
    n.includes("barangay")
  ) {
    return "Government Sector";
  }
  if (
    n.includes("hospital") ||
    n.includes("medical center") ||
    n.includes("medical clinic") ||
    n.includes("health center") ||
    n.includes("sanitarium") ||
    n.includes("infirmary") ||
    n.includes("dialysis") ||
    n.includes("doctors hospital")
  ) {
    return "Healthcare & Duty Roster";
  }
  if (
    n.includes("jollibee") ||
    n.includes("mcdonald's") ||
    n.includes("chowking") ||
    n.includes("mang inasal") ||
    n.includes("greenwich") ||
    n.includes("kfc") ||
    n.includes("7-eleven") ||
    n.includes("gaisano") ||
    n.includes("sm city") ||
    n.includes("sm mall") ||
    n.includes("sm prime") ||
    n.includes("robinsons mall") ||
    n.includes("ayala mall") ||
    n.includes("abreeza") ||
    n.includes("supermarket") ||
    n.includes("department store") ||
    n.includes("bpo") ||
    n.includes("concentrix") ||
    n.includes("teleperformance")
  ) {
    return "Private Workplace / Retail";
  }

  const c = (cat || "").toLowerCase();
  if (c.includes("hospital") || c.includes("clinic") || c.includes("health") || c.includes("duty") || c.includes("medic")) {
    return "Healthcare & Duty Roster";
  }
  if (c.includes("work") || c.includes("corp") || c.includes("retail") || c.includes("bpo") || c.includes("mall") || c.includes("fast food") || c.includes("store")) {
    return "Private Workplace / Retail";
  }
  if (c.includes("gov") || c.includes("public") || c.includes("hall") || c.includes("capitol") || c.includes("deped")) {
    return "Government Sector";
  }
  return "Student / University";
}

export default function InstitutionsPage() {
  const [institutions, setInstitutions] = useState<Institution[]>([]);
  const [selectedIds, setSelectedIds] = useState<Set<string>>(new Set());
  const [isBatchDeleting, setIsBatchDeleting] = useState(false);
  const [isBatchCategoryModalOpen, setIsBatchCategoryModalOpen] = useState(false);
  const [batchCategory, setBatchCategory] = useState("Student / University");
  const [searchQuery, setSearchQuery] = useState("");
  const [selectedCategory, setSelectedCategory] = useState("All");
  const [selectedRegion, setSelectedRegion] = useState("All");
  const [currentPage, setCurrentPage] = useState(1);
  const itemsPerPage = 24;

  const [isModalOpen, setIsModalOpen] = useState(false);
  useEffect(() => {
    if (isModalOpen) {
      document.body.style.overflow = "hidden";
    } else {
      document.body.style.overflow = "";
    }
    return () => { document.body.style.overflow = ""; };
  }, [isModalOpen]);
  const [editingId, setEditingId] = useState<string | null>(null);
  const [toastMessage, setToastMessage] = useState<string | null>(null);
  const [deleteTarget, setDeleteTarget] = useState<{ id: string; name: string } | null>(null);
  const [isSyncingAll, setIsSyncingAll] = useState(false);
  const [syncProgress, setSyncProgress] = useState("");
  const [isLoading, setIsLoading] = useState(true);

  // Form State
  const [name, setName] = useState("");
  const [shortName, setShortName] = useState("");
  const [category, setCategory] = useState("Student / University");
  const [regionCode, setRegionCode] = useState("Region XI — Davao Region");
  const [city, setCity] = useState("Davao City");
  const [themeColor, setThemeColor] = useState("#2563EB");
  const [logoUrl, setLogoUrl] = useState("");
  const [emblemInitials, setEmblemInitials] = useState("");

  // Upload State
  const [isUploading, setIsUploading] = useState(false);
  const [uploadSuccess, setUploadSuccess] = useState(false);
  const [isDragging, setIsDragging] = useState(false);
  const fileInputRef = useRef<HTMLInputElement>(null);

  useEffect(() => {
    const q = query(collection(db, "institutions"), orderBy("name", "asc"));
    const unsub = onSnapshot(q, (snap) => {
      const list: Institution[] = [];
      snap.forEach((doc) => {
        list.push({ id: doc.id, ...doc.data() } as Institution);
      });
      setInstitutions(list);
      setIsLoading(false);
    }, (err: any) => { 
      console.warn("Snapshot notice:", err.message);
      setIsLoading(false);
    });
    return () => unsub();
  }, []);

  const showToast = (msg: string) => {
    setToastMessage(msg);
    setTimeout(() => setToastMessage(null), 4000);
  };

  const openAddModal = () => {
    setEditingId(null);
    setName("");
    setShortName("");
    setCategory("Student / University");
    setRegionCode("Region XI — Davao Region");
    setCity("Davao City");
    setThemeColor("#2563EB");
    setLogoUrl("");
    setEmblemInitials("");
    setUploadSuccess(false);
    setIsModalOpen(true);
  };

  const openEditModal = (item: Institution) => {
    setEditingId(item.id);
    setName(item.name);
    setShortName(item.shortName);
    setCategory(item.category);
    setRegionCode(item.regionCode);
    setCity(item.city);
    setThemeColor(item.themeColor || "#2563EB");
    setLogoUrl(item.logoUrl || "");
    setEmblemInitials(item.emblemInitials || "");
    setUploadSuccess(!!item.logoUrl);
    setIsModalOpen(true);
  };

  // Client-side universal image thumbnail compressor (supports AVIF, WebP, PNG, JPG, SVG, etc.)
  const compressImage = async (file: File): Promise<string> => {
    try {
      if (typeof window !== "undefined" && "createImageBitmap" in window) {
        const bitmap = await createImageBitmap(file);
        const canvas = document.createElement("canvas");
        const maxDim = 256;
        let width = bitmap.width;
        let height = bitmap.height;

        if (width > height) {
          if (width > maxDim) {
            height = Math.round((height * maxDim) / width);
            width = maxDim;
          }
        } else {
          if (height > maxDim) {
            width = Math.round((width * maxDim) / height);
            height = maxDim;
          }
        }

        canvas.width = width;
        canvas.height = height;
        const ctx = canvas.getContext("2d");
        if (ctx) {
          ctx.clearRect(0, 0, width, height);
          ctx.drawImage(bitmap, 0, 0, width, height);
          try {
            return canvas.toDataURL("image/webp", 0.85);
          } catch {
            return canvas.toDataURL("image/png");
          }
        }
      }
    } catch (e) {
      console.warn("createImageBitmap fallback:", e);
    }

    return new Promise((resolve, reject) => {
      const reader = new FileReader();
      reader.onload = (event) => {
        const img = new Image();
        img.onload = () => {
          const canvas = document.createElement("canvas");
          const maxDim = 256;
          let width = img.width;
          let height = img.height;

          if (width > height) {
            if (width > maxDim) {
              height = Math.round((height * maxDim) / width);
              width = maxDim;
            }
          } else {
            if (height > maxDim) {
              width = Math.round((width * maxDim) / height);
              height = maxDim;
            }
          }

          canvas.width = width;
          canvas.height = height;
          const ctx = canvas.getContext("2d");
          if (ctx) {
            ctx.clearRect(0, 0, width, height);
            ctx.drawImage(img, 0, 0, width, height);
            try {
              resolve(canvas.toDataURL("image/webp", 0.85));
            } catch {
              resolve(canvas.toDataURL("image/png"));
            }
          } else {
            resolve(event.target?.result as string);
          }
        };
        img.onerror = () => {
          // If image element fails, return raw dataUrl directly
          resolve(event.target?.result as string);
        };
        img.src = event.target?.result as string;
      };
      reader.onerror = (err) => reject(err);
      reader.readAsDataURL(file);
    });
  };

  // Image Upload Handler (Routes through /api/upload server proxy for CDN URL with inline fallback)
  const handleFileUpload = async (file: File) => {
    const isImage = file.type.startsWith("image/") || /\.(avif|webp|png|jpe?g|svg|gif|bmp|ico)$/i.test(file.name);
    if (!isImage) {
      showToast("Please select a valid image file (.avif, .png, .jpg, .webp).");
      return;
    }

    try {
      setIsUploading(true);
      setUploadSuccess(false);

      const optimizedBase64 = await compressImage(file);
      let finalLogoUrl = optimizedBase64;

      try {
        const idToken = await auth.currentUser?.getIdToken();
        if (idToken) {
          const uploadRes = await fetch("/api/upload", {
            method: "POST",
            headers: {
              "Content-Type": "application/json",
              Authorization: `Bearer ${idToken}`,
            },
            body: JSON.stringify({
              base64Image: optimizedBase64,
              name: shortName || name || file.name,
            }),
          });
          if (uploadRes.ok) {
            const data = await uploadRes.json();
            if (data.url) {
              finalLogoUrl = data.url;
            }
          }
        }
      } catch {
        // Fallback to optimizedBase64 if offline or server proxy unreachable
      }

      setLogoUrl(finalLogoUrl);
      setUploadSuccess(true);
    } catch (err: any) {
      console.error("Logo processing error:", err);
      showToast("Failed to process image: " + err.message);
    } finally {
      setIsUploading(false);
    }
  };

    const handleDragOver = (e: React.DragEvent) => {
    e.preventDefault();
    setIsDragging(true);
  };

  const handleDragLeave = () => {
    setIsDragging(false);
  };

  const handleDrop = (e: React.DragEvent) => {
    e.preventDefault();
    setIsDragging(false);
    if (e.dataTransfer.files && e.dataTransfer.files[0]) {
      handleFileUpload(e.dataTransfer.files[0]);
    }
  };

  const handleSaveInstitution = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!name.trim() || !shortName.trim()) {
      showToast("Please fill in the institution name and short acronym.");
      return;
    }

    try {
      const docId = editingId || name.toLowerCase().replace(/[^a-z0-9]/g, "-").slice(0, 40) + `-${Date.now().toString().slice(-4)}`;
      const docRef = doc(db, "institutions", docId);

      const savedData: Institution = {
        id: docId,
        name: name.trim(),
        shortName: shortName.trim(),
        category,
        regionCode,
        city: city.trim(),
        themeColor,
        logoUrl: logoUrl.trim(),
        emblemInitials: emblemInitials.trim() || shortName.trim().slice(0, 4).toUpperCase(),
        isOfficial: true,
      };

      // Optimistically update local state immediately
      setInstitutions((prev) => {
        const exists = prev.some((item) => item.id === docId);
        if (exists) {
          return prev.map((item) => (item.id === docId ? { ...item, ...savedData } : item));
        } else {
          return [savedData, ...prev];
        }
      });

      setIsModalOpen(false);

      await setDoc(docRef, {
        name: name.trim(),
        shortName: shortName.trim(),
        category,
        regionCode,
        city: city.trim(),
        themeColor,
        logoUrl: logoUrl.trim(),
        emblemInitials: emblemInitials.trim() || shortName.trim().slice(0, 4).toUpperCase(),
        isOfficial: true,
        updatedAt: serverTimestamp(),
        createdAt: serverTimestamp()
      }, { merge: true });

      showToast(editingId ? `Institution "${shortName}" updated successfully!` : `New Institution "${shortName}" added!`);
    } catch (err: any) {
      console.error("Error saving institution:", err);
      showToast("Failed to save institution: " + err.message);
    }
  };

    const handleConfirmDelete = async () => {
    if (!deleteTarget) return;
    try {
      await deleteDoc(doc(db, "institutions", deleteTarget.id));
      showToast(`Deleted "${deleteTarget.name}" from directory.`);
    } catch (err: any) {
      console.error("Delete error:", err);
      showToast("Failed to delete institution.");
    } finally {
      setDeleteTarget(null);
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
    if (selectedIds.size === paginatedItems.length && paginatedItems.length > 0) {
      setSelectedIds(new Set());
    } else {
      setSelectedIds(new Set(paginatedItems.map((i) => i.id)));
    }
  };

  const handleDeselectAll = () => {
    setSelectedIds(new Set());
  };

  const handleBatchDelete = async () => {
    if (selectedIds.size === 0) return;
    try {
      const batch = writeBatch(db);
      selectedIds.forEach((id) => {
        batch.delete(doc(db, "institutions", id));
      });
      await batch.commit();
      showToast(`Deleted ${selectedIds.size} institutions from directory.`);
      setSelectedIds(new Set());
      setIsBatchDeleting(false);
    } catch (err: any) {
      console.error("Batch delete error:", err);
      showToast("Batch delete failed: " + err.message);
    }
  };

  const handleBatchCategorySubmit = async () => {
    if (selectedIds.size === 0) return;
    try {
      const batch = writeBatch(db);
      selectedIds.forEach((id) => {
        batch.update(doc(db, "institutions", id), { category: batchCategory });
      });
      await batch.commit();
      showToast(`Updated ${selectedIds.size} institutions to category "${batchCategory}".`);
      setSelectedIds(new Set());
      setIsBatchCategoryModalOpen(false);
    } catch (err: any) {
      console.error("Batch category error:", err);
      showToast("Batch category update failed: " + err.message);
    }
  };

  const handleBatchExportJson = () => {
    const targets = institutions.filter((i) => selectedIds.has(i.id));
    if (targets.length === 0) return;
    downloadJsonFile(`reminda_institutions_${new Date().toISOString().slice(0, 10)}.json`, targets);
    showToast(`Exported ${targets.length} institutions as JSON.`);
  };

  const handleBatchExportCsv = () => {
    const targets = institutions.filter((i) => selectedIds.has(i.id));
    if (targets.length === 0) return;
    const headers = ["ID", "Name", "Acronym", "Category", "Region", "City", "Theme Color", "Emblem Initials", "Logo URL"];
    const rows = targets.map((item) => [
      item.id,
      item.name,
      item.shortName,
      item.category,
      item.regionCode,
      item.city,
      item.themeColor,
      item.emblemInitials || "",
      item.logoUrl || ""
    ]);
    downloadCsvFile(`reminda_institutions_${new Date().toISOString().slice(0, 10)}.csv`, headers, rows);
    showToast(`Exported ${targets.length} institutions as CSV.`);
  };

  // Bulk Sync all 556 Codebase Institutions in Batches
  const handleSyncAll556 = async () => {
    try {
      setIsSyncingAll(true);
      const total = codebaseInstitutions.length;
      setSyncProgress(`0 / ${total}`);

      const chunkSize = 400;
      for (let i = 0; i < total; i += chunkSize) {
        const chunk = codebaseInstitutions.slice(i, i + chunkSize);
        const batch = writeBatch(db);

        for (const item of chunk) {
          const docRef = doc(db, "institutions", item.id);
          batch.set(docRef, {
            name: item.name,
            shortName: item.shortName,
            category: item.category,
            regionCode: item.regionCode,
            city: item.city,
            themeColor: item.themeColor,
            logoUrl: item.logoUrl || "",
            emblemInitials: item.emblemInitials || item.shortName.slice(0, 4).toUpperCase(),
            isOfficial: true,
            createdAt: serverTimestamp()
          }, { merge: true });
        }

        await batch.commit();
        setSyncProgress(`${Math.min(i + chunkSize, total)} / ${total}`);
      }

      showToast(`Successfully synced all ${total} Philippine Institutions to Cloud Firestore!`);
    } catch (err: any) {
      console.error("Sync error:", err);
      showToast("Error syncing full directory: " + err.message);
    } finally {
      setIsSyncingAll(false);
      setSyncProgress("");
    }
  };

  const categories = [
    "All",
    "Student / University",
    "Private Workplace / Retail",
    "Healthcare & Duty Roster",
    "Government Sector"
  ];
  
  const regions = [
    "All",
    "NCR",
    "CAR",
    "R01",
    "R02",
    "R03",
    "R04A",
    "R04B",
    "R05",
    "R06",
    "R07",
    "R08",
    "R09",
    "R10",
    "R11",
    "R12",
    "R13",
    "BARMM"
  ];

  const filtered = institutions.filter((item) => {
    const matchesSearch = 
      (item.name || "").toLowerCase().includes(searchQuery.toLowerCase()) ||
      (item.shortName || "").toLowerCase().includes(searchQuery.toLowerCase()) ||
      (item.city || "").toLowerCase().includes(searchQuery.toLowerCase());
    const matchesCat = selectedCategory === "All" || normalizeCategoryLabel(item.category, item.name, item.shortName) === selectedCategory;
    const matchesReg = selectedRegion === "All" || (item.regionCode || "").includes(selectedRegion);
    return matchesSearch && matchesCat && matchesReg;
  });

  const totalPages = Math.ceil(filtered.length / itemsPerPage) || 1;
  const paginatedItems = filtered.slice((currentPage - 1) * itemsPerPage, currentPage * itemsPerPage);

  return (
    <>
      <Header title="Institutions & Schools" />
      <main className="flex-1 px-8 pb-12 space-y-6 max-w-[1600px] w-full">
        {/* Custom Delete Confirmation Modal */}
        <ConfirmModal
          isOpen={!!deleteTarget}
          title="Delete Institution?"
          message={`Are you sure you want to delete "${deleteTarget?.name}" from the global directory? Mobile apps will no longer suggest this institution.`}
          confirmText="Yes, Delete Institution"
          cancelText="Keep"
          onConfirm={handleConfirmDelete}
          onCancel={() => setDeleteTarget(null)}
        />

        {/* Batch Delete Confirmation Modal */}
        <ConfirmModal
          isOpen={isBatchDeleting}
          title="Delete Selected Institutions?"
          message={`Are you sure you want to permanently delete ${selectedIds.size} institutions from the global directory? This cannot be undone.`}
          confirmText={`Yes, Delete ${selectedIds.size} Institutions`}
          cancelText="Cancel"
          onConfirm={handleBatchDelete}
          onCancel={() => setIsBatchDeleting(false)}
        />

        {/* Batch Change Category Modal */}
        {isBatchCategoryModalOpen && typeof document !== "undefined" && createPortal(
          <div className="fixed inset-0 z-9999 bg-black/60 backdrop-blur-sm flex items-center justify-center p-4">
            <div className="w-full max-w-md bg-white dark:bg-[#1C1D2B] rounded-3xl p-6 shadow-2xl border border-slate-200 dark:border-[#282A3D] space-y-4">
              <div className="flex items-center justify-between pb-3 border-b border-slate-100 dark:border-[#282A3D]">
                <h3 className="font-extrabold text-sm text-slate-900 dark:text-white">Batch Change Category ({selectedIds.size} Selected)</h3>
                <button onClick={() => setIsBatchCategoryModalOpen(false)} className="p-1 rounded-xl text-slate-400 hover:bg-slate-100 dark:bg-[#25273A]">
                  <X className="w-4 h-4" />
                </button>
              </div>

              <div className="space-y-2">
                <label className="text-xs font-bold text-slate-600 dark:text-slate-300">Select New Category</label>
                <CustomDropdown
                  value={batchCategory}
                  onChange={setBatchCategory}
                  options={[
                    "Student / University",
                    "Private Workplace / Retail",
                    "Healthcare & Duty Roster",
                    "Government Sector"
                  ]}
                />
              </div>

              <div className="flex items-center justify-end gap-2 pt-3 border-t border-slate-100 dark:border-[#282A3D]">
                <button
                  onClick={() => setIsBatchCategoryModalOpen(false)}
                  className="px-4 py-2 rounded-xl text-xs font-bold text-slate-600 dark:text-slate-300 hover:bg-slate-100 dark:bg-[#25273A]"
                >
                  Cancel
                </button>
                <button
                  onClick={handleBatchCategorySubmit}
                  className="px-4 py-2 rounded-xl bg-blue-600 hover:bg-blue-700 text-white text-xs font-bold shadow-xs"
                >
                  Apply to {selectedIds.size} Institutions
                </button>
              </div>
            </div>
          </div>,
          document.body
        )}

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
                onClick={() => setIsBatchCategoryModalOpen(true)}
                className="px-3 py-1.5 rounded-xl bg-indigo-600 hover:bg-indigo-500 text-white text-xs font-bold flex items-center gap-1.5 transition-all shadow-xs"
              >
                <Tag className="w-3.5 h-3.5" />
                <span>Change Category</span>
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

        {/* Top Header Actions */}
        <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-4">
          <div>
            <p className="text-xs text-slate-500 dark:text-slate-400 font-semibold flex items-center gap-1.5">
              <span>Live Cloud Directory ({institutions.length} Active Institutions across the Philippines)</span>
            </p>
          </div>

          <div className="flex items-center gap-3">
            <button
              onClick={handleSyncAll556}
              disabled={isSyncingAll}
              className="px-4 py-2 rounded-2xl bg-amber-50 hover:bg-amber-100 border border-amber-200/80 text-amber-800 font-bold text-xs shadow-xs transition-colors flex items-center gap-2 disabled:opacity-50"
              title="Import all 556 Colleges, Hospitals, Fast Food & Malls from codebase"
            >
              {isSyncingAll ? (
                <Loader2 className="w-4 h-4 text-amber-600 animate-spin" />
              ) : (
                <Sparkles className="w-4 h-4 text-amber-500" />
              )}
              <span>{isSyncingAll ? `Syncing ${syncProgress}...` : `Sync All 556 Codebase Presets`}</span>
            </button>

            <button
              onClick={openAddModal}
              className="px-4 py-2.5 rounded-2xl bg-blue-600 hover:bg-blue-700 text-white font-bold text-xs shadow-xs transition-colors flex items-center gap-2"
            >
              <Plus className="w-4 h-4" />
              Add Institution
            </button>
          </div>
        </div>

        {/* Search, Region & Category Filter Bar */}
        <div className="p-4 rounded-3xl bg-white dark:bg-[#1C1D2B] border border-slate-200 dark:border-[#282A3D] shadow-xs flex flex-col lg:flex-row items-center gap-4">
          <div className="relative flex-1 w-full">
            <Search className="w-4 h-4 text-slate-400 absolute left-3.5 top-1/2 -translate-y-1/2" />
            <input
              type="text"
              placeholder="Search across 500+ Philippine schools, hospitals, fast-food, or cities..."
              value={searchQuery}
              onChange={(e) => {
                setSearchQuery(e.target.value);
                setCurrentPage(1);
              }}
              className="w-full pl-10 pr-4 py-2 rounded-2xl bg-slate-50 dark:bg-[#25273A]/60 border border-slate-200 dark:border-[#282A3D]/70 text-slate-900 dark:text-white text-xs placeholder-slate-400 focus:outline-none focus:border-blue-500"
            />
          </div>

          {/* Region Dropdown Filter */}
          <div className="flex items-center gap-2 w-full lg:w-auto">
            <div className="flex items-center gap-1.5 px-3 py-1.5 rounded-xl bg-slate-50 dark:bg-[#25273A]/60 border border-slate-200 dark:border-[#282A3D]/70 text-xs font-bold text-slate-700 dark:text-slate-300">
              <MapPin className="w-3.5 h-3.5 text-slate-400" />
              <CustomDropdown
                value={selectedRegion}
                onChange={(val) => {
                  setSelectedRegion(val);
                  setCurrentPage(1);
                }}
                compact
                buttonClassName="bg-transparent border-none p-0 text-slate-700 dark:text-slate-300 hover:text-blue-600"
                options={[
                  { value: "All", label: "All Regions (PH)" },
                  ...regions.filter(r => r !== "All").map(reg => ({ value: reg, label: reg }))
                ]}
              />
            </div>

            {/* Category Chips */}
            <div className="flex items-center gap-1.5 overflow-x-auto pb-1 lg:pb-0">
              {categories.map((cat) => (
                <button
                  key={cat}
                  onClick={() => {
                    setSelectedCategory(cat);
                    setCurrentPage(1);
                  }}
                  className={`px-3 py-1.5 rounded-xl text-xs font-bold whitespace-nowrap transition-colors ${
                    selectedCategory === cat
                      ? "bg-blue-600 text-white shadow-xs"
                      : "bg-slate-100 dark:bg-[#25273A] text-slate-600 dark:text-slate-400 hover:bg-slate-200/80"
                  }`}
                >
                  {cat}
                </button>
              ))}
            </div>
          </div>
        </div>

        {/* Institutions Grid / Cards */}
        {isLoading ? (
          <SkeletonCardGrid count={8} />
        ) : filtered.length === 0 ? (
          <div className="py-20 text-center rounded-3xl bg-white dark:bg-[#1C1D2B] border border-slate-200 dark:border-[#282A3D] text-slate-400 text-xs space-y-4">
            <School className="w-12 h-12 mx-auto text-slate-300" />
            <div>
              <p className="font-bold text-sm text-slate-800 dark:text-slate-200">No institutions found</p>
              <p className="text-slate-400 mt-0.5">Click the button below to sync all 556 Philippine colleges, hospitals, and workplaces!</p>
            </div>
            <button
              onClick={handleSyncAll556}
              disabled={isSyncingAll}
              className="px-5 py-2.5 rounded-2xl bg-amber-500 hover:bg-amber-600 text-white font-bold text-xs shadow-xs inline-flex items-center gap-2 transition-colors"
            >
              <Sparkles className="w-4 h-4" />
              Sync All 556 Codebase Presets
            </button>
          </div>
        ) : (
          <>
            {/* Select All on Page Toolbar */}
            <div className="flex items-center justify-between px-2 py-1">
              <button
                onClick={handleSelectAll}
                className="flex items-center gap-2 text-xs font-bold text-slate-600 dark:text-slate-300 hover:text-blue-600 transition-colors"
              >
                {selectedIds.size === paginatedItems.length && paginatedItems.length > 0 ? (
                  <CheckSquare className="w-4 h-4 text-blue-600" />
                ) : (
                  <Square className="w-4 h-4 text-slate-400" />
                )}
                <span>Select All on Page ({paginatedItems.length})</span>
              </button>

              {selectedIds.size > 0 && (
                <span className="text-xs font-extrabold text-blue-600 dark:text-blue-400">
                  {selectedIds.size} institution{selectedIds.size > 1 ? "s" : ""} selected
                </span>
              )}
            </div>

            <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 xl:grid-cols-4 gap-5">
              {paginatedItems.map((item) => {
                const isSelected = selectedIds.has(item.id);

                return (
                  <div
                    key={item.id}
                    onClick={() => handleToggleSelect(item.id)}
                    className={`p-5 rounded-3xl border transition-all flex flex-col justify-between cursor-pointer ${
                      isSelected
                        ? "bg-blue-50/40 dark:bg-[#20253B] border-blue-400/80 shadow-md ring-2 ring-blue-500/20"
                        : "bg-white dark:bg-[#1C1D2B] border-slate-200 dark:border-[#282A3D]/70 shadow-xs hover:shadow-md hover:border-slate-300"
                    }`}
                  >
                    <div>
                      <div className="flex items-start justify-between gap-3 mb-3">
                        <div className="flex items-center gap-2.5">
                          {/* Selection Checkbox */}
                          <div className="shrink-0">
                            {isSelected ? (
                              <CheckSquare className="w-5 h-5 text-blue-600 fill-blue-50" />
                            ) : (
                              <Square className="w-5 h-5 text-slate-300 hover:text-slate-400" />
                            )}
                          </div>

                          {/* Emblem / Logo */}
                          <div 
                            className="w-12 h-12 rounded-2xl flex items-center justify-center font-black text-sm text-white shadow-xs overflow-hidden bg-white border border-slate-100 dark:border-[#282A3D] p-1 shrink-0 relative"
                          >
                            {item.logoUrl ? (
                              <img 
                                src={item.logoUrl} 
                                alt={item.shortName} 
                                className="w-full h-full object-contain"
                                referrerPolicy="no-referrer"
                                onError={(e) => {
                                  const target = e.target as HTMLElement;
                                  target.style.display = 'none';
                                  const fallback = target.parentElement?.querySelector('.card-fallback-emblem') as HTMLElement;
                                  if (fallback) fallback.style.display = 'flex';
                                }}
                              />
                            ) : null}
                            <div 
                              className={`card-fallback-emblem w-full h-full rounded-xl items-center justify-center text-white text-[11px] font-bold ${
                                item.logoUrl ? 'hidden' : 'flex'
                              }`}
                              style={{ backgroundColor: item.themeColor || "#2563EB" }}
                            >
                              <span>{item.emblemInitials || (item.shortName || "").slice(0, 3)}</span>
                            </div>
                          </div>
                        </div>

                        <span className="px-2 py-0.5 rounded-lg text-[10px] font-bold bg-slate-100 dark:bg-[#25273A] text-slate-700 dark:text-slate-300 truncate max-w-25">
                          {item.shortName}
                        </span>
                      </div>

                      <h4 className="font-extrabold text-sm text-slate-900 dark:text-white leading-snug line-clamp-2" title={item.name}>
                        {item.name}
                      </h4>

                      <p className="text-xs text-slate-500 dark:text-slate-400 mt-1 flex items-center gap-1">
                        <span>{item.city}</span>
                        <span>•</span>
                        <span className="text-[11px] font-medium">{normalizeCategoryLabel(item.category, item.name, item.shortName)}</span>
                      </p>
                    </div>

                    <div 
                      onClick={(e) => e.stopPropagation()}
                      className="flex items-center justify-between pt-4 mt-4 border-t border-slate-100 dark:border-[#282A3D] text-xs"
                    >
                      <div className="flex items-center gap-1.5">
                        <span className="w-2.5 h-2.5 rounded-full" style={{ backgroundColor: item.themeColor || "#2563EB" }} />
                        <span className="text-[10px] font-mono text-slate-400">{item.regionCode || "PH"}</span>
                      </div>

                      <div className="flex items-center gap-1">
                        <button
                          onClick={(e) => {
                            e.stopPropagation();
                            openEditModal(item);
                          }}
                          className="p-1.5 rounded-xl hover:bg-slate-100 dark:bg-[#25273A] text-slate-500 dark:text-slate-400 transition-colors"
                          title="Edit"
                        >
                          <Edit3 className="w-4 h-4" />
                        </button>
                        <button
                          onClick={(e) => {
                            e.stopPropagation();
                            setDeleteTarget({ id: item.id, name: item.name });
                          }}
                          className="p-1.5 rounded-xl hover:bg-red-50 text-slate-400 hover:text-red-600 transition-colors"
                          title="Delete"
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
              <div className="flex items-center justify-between p-4 rounded-3xl bg-white dark:bg-[#1C1D2B] border border-slate-200 dark:border-[#282A3D]/70 shadow-xs">
                <p className="text-xs text-slate-500 dark:text-slate-400 font-semibold">
                  Showing {(currentPage - 1) * itemsPerPage + 1} to {Math.min(currentPage * itemsPerPage, filtered.length)} of {filtered.length} institutions
                </p>

                <div className="flex items-center gap-2">
                  <button
                    onClick={() => setCurrentPage(p => Math.max(p - 1, 1))}
                    disabled={currentPage === 1}
                    className="p-2 rounded-xl bg-slate-50 dark:bg-[#25273A]/60 hover:bg-slate-100 dark:hover:bg-[#25273A] disabled:opacity-40 text-slate-600 dark:text-slate-400 transition-colors"
                  >
                    <ChevronLeft className="w-4 h-4" />
                  </button>

                  <span className="px-3 py-1 text-xs font-bold text-slate-800 dark:text-slate-200">
                    Page {currentPage} of {totalPages}
                  </span>

                  <button
                    onClick={() => setCurrentPage(p => Math.min(p + 1, totalPages))}
                    disabled={currentPage === totalPages}
                    className="p-2 rounded-xl bg-slate-50 dark:bg-[#25273A]/60 hover:bg-slate-100 dark:hover:bg-[#25273A] disabled:opacity-40 text-slate-600 dark:text-slate-400 transition-colors"
                  >
                    <ChevronRight className="w-4 h-4" />
                  </button>
                </div>
              </div>
            )}
          </>
        )}

        {/* Add / Edit Institution Modal */}
        {isModalOpen && typeof document !== "undefined" && createPortal(
          <div className="fixed inset-0 z-9999 bg-black/70 backdrop-blur-sm flex items-center justify-center p-4 overflow-y-auto animate-in fade-in duration-150">
            <div className="w-full max-w-lg bg-white dark:bg-[#1C1D2B] rounded-3xl p-6 shadow-2xl border border-slate-200 dark:border-[#282A3D] space-y-4 animate-in fade-in zoom-in-95 max-h-[90vh] overflow-y-auto">
              <div className="flex items-center justify-between pb-3 border-b border-slate-100 dark:border-[#282A3D]">
                <div className="flex items-center gap-2.5">
                  <div className="w-8 h-8 rounded-xl bg-blue-50 text-blue-600 flex items-center justify-center font-bold">
                    <Building2 className="w-4 h-4" />
                  </div>
                  <div>
                    <h3 className="font-extrabold text-sm text-slate-900 dark:text-white">
                      {editingId ? "Edit Institution" : "Add New Institution"}
                    </h3>
                    <p className="text-[11px] text-slate-400">Live sync to Reminda mobile apps</p>
                  </div>
                </div>
                <button
                  onClick={() => setIsModalOpen(false)}
                  className="p-1.5 rounded-xl hover:bg-slate-100 dark:bg-[#25273A] text-slate-400"
                >
                  <X className="w-4 h-4" />
                </button>
              </div>

              <form onSubmit={handleSaveInstitution} className="space-y-4 text-xs">
                {/* 1. Drag & Drop Logo Uploader Box */}
                <div className="space-y-1.5">
                  <label className="font-bold text-slate-700 dark:text-slate-300 uppercase tracking-wider text-[10px] flex items-center justify-between">
                    <span>Institution Logo (Free Cloud CDN)</span>
                    {uploadSuccess && (
                      <span className="text-emerald-600 font-bold flex items-center gap-1 normal-case text-[11px]">
                        <Check className="w-3.5 h-3.5" /> Logo Ready
                      </span>
                    )}
                  </label>

                  <input
                    type="file"
                    ref={fileInputRef}
                    accept="image/*,.avif,.webp,.png,.jpg,.jpeg,.svg,.gif,.bmp,.ico"
                    className="hidden"
                    onChange={(e) => {
                      if (e.target.files && e.target.files[0]) {
                        handleFileUpload(e.target.files[0]);
                      }
                    }}
                  />

                  <div
                    onDragOver={handleDragOver}
                    onDragLeave={handleDragLeave}
                    onDrop={handleDrop}
                    onClick={() => fileInputRef.current?.click()}
                    className={`border-2 border-dashed rounded-2xl p-4 flex flex-col items-center justify-center gap-2 cursor-pointer transition-all ${
                      isDragging 
                        ? "border-blue-500 bg-blue-50/50" 
                        : logoUrl 
                        ? "border-slate-200 dark:border-[#282A3D] bg-slate-50 dark:bg-[#25273A]/60/50 hover:border-slate-300" 
                        : "border-slate-200 dark:border-[#282A3D] hover:border-blue-400 bg-slate-50 dark:bg-[#25273A]/60/30"
                    }`}
                  >
                    {isUploading ? (
                      <div className="flex flex-col items-center gap-2 py-3 text-slate-500 dark:text-slate-400">
                        <Loader2 className="w-6 h-6 animate-spin text-blue-600" />
                        <span className="font-semibold text-xs">Uploading to Free Cloud CDN...</span>
                      </div>
                    ) : logoUrl ? (
                      <div className="flex items-center gap-3 w-full">
                        <div className="w-12 h-12 rounded-xl bg-white border border-slate-200 dark:border-[#282A3D] p-1 flex items-center justify-center overflow-hidden shrink-0">
                          <img src={logoUrl} alt="Preview" className="w-full h-full object-contain" />
                        </div>
                        <div className="flex-1 min-w-0 text-left">
                          <p className="text-xs font-bold text-slate-900 dark:text-white truncate">Logo Uploaded</p>
                          <p className="text-[10px] text-slate-400 truncate font-mono">{logoUrl}</p>
                        </div>
                        <button
                          type="button"
                          onClick={(e) => {
                            e.stopPropagation();
                            fileInputRef.current?.click();
                          }}
                          className="px-3 py-1 rounded-lg bg-white border border-slate-200 dark:border-[#282A3D] text-slate-700 dark:text-slate-300 font-bold text-[10px] hover:bg-slate-50 dark:bg-[#25273A]/60"
                        >
                          Change
                        </button>
                      </div>
                    ) : (
                      <div className="flex flex-col items-center gap-1 text-center py-2">
                        <div className="w-9 h-9 rounded-xl bg-blue-50 text-blue-600 flex items-center justify-center mb-1">
                          <UploadCloud className="w-5 h-5" />
                        </div>
                        <p className="text-xs font-bold text-slate-700 dark:text-slate-300">
                          Drag & drop logo image here, or <span className="text-blue-600 underline">browse</span>
                        </p>
                        <p className="text-[10px] text-slate-400">AVIF, PNG, JPG, WEBP, or SVG (Transparent background recommended)</p>
                      </div>
                    )}
                  </div>
                </div>

                {/* Name */}
                <div className="space-y-1">
                  <label className="font-bold text-slate-600 dark:text-slate-400 uppercase tracking-wider text-[10px]">
                    Institution / University Name *
                  </label>
                  <input
                    type="text"
                    required
                    placeholder="e.g. Davao del Sur State College"
                    value={name}
                    onChange={(e) => setName(e.target.value)}
                    className="w-full p-2.5 rounded-xl bg-slate-50 dark:bg-[#25273A]/60 border border-slate-200 dark:border-[#282A3D] text-slate-900 dark:text-white focus:outline-none focus:border-blue-500"
                  />
                </div>

                {/* Short Name & Category */}
                <div className="grid grid-cols-2 gap-3">
                  <div className="space-y-1">
                    <label className="font-bold text-slate-600 dark:text-slate-400 uppercase tracking-wider text-[10px]">
                      Acronym / Short Name *
                    </label>
                    <input
                      type="text"
                      required
                      placeholder="e.g. DSSC"
                      value={shortName}
                      onChange={(e) => setShortName(e.target.value)}
                      className="w-full p-2.5 rounded-xl bg-slate-50 dark:bg-[#25273A]/60 border border-slate-200 dark:border-[#282A3D] text-slate-900 dark:text-white focus:outline-none focus:border-blue-500 font-bold"
                    />
                  </div>

                  <div className="space-y-1">
                    <label className="font-bold text-slate-600 dark:text-slate-400 uppercase tracking-wider text-[10px]">
                      Sector Category
                    </label>
                    <CustomDropdown
                      value={category}
                      onChange={setCategory}
                      options={[
                        "Student / University",
                        "Private Workplace / Retail",
                        "Healthcare & Duty Roster",
                        "Government Sector",
                      ]}
                    />
                  </div>
                </div>

                {/* Region & City */}
                <div className="grid grid-cols-2 gap-3">
                  <div className="space-y-1">
                    <label className="font-bold text-slate-600 dark:text-slate-400 uppercase tracking-wider text-[10px]">
                      Region
                    </label>
                    <input
                      type="text"
                      placeholder="e.g. Region XI — Davao Region"
                      value={regionCode}
                      onChange={(e) => setRegionCode(e.target.value)}
                      className="w-full p-2.5 rounded-xl bg-slate-50 dark:bg-[#25273A]/60 border border-slate-200 dark:border-[#282A3D] text-slate-900 dark:text-white focus:outline-none"
                    />
                  </div>

                  <div className="space-y-1">
                    <label className="font-bold text-slate-600 dark:text-slate-400 uppercase tracking-wider text-[10px]">
                      City / Location
                    </label>
                    <input
                      type="text"
                      placeholder="e.g. Digos City"
                      value={city}
                      onChange={(e) => setCity(e.target.value)}
                      className="w-full p-2.5 rounded-xl bg-slate-50 dark:bg-[#25273A]/60 border border-slate-200 dark:border-[#282A3D] text-slate-900 dark:text-white focus:outline-none"
                    />
                  </div>
                </div>

                {/* Theme Color */}
                <div className="space-y-1">
                  <label className="font-bold text-slate-600 dark:text-slate-400 uppercase tracking-wider text-[10px]">
                    Brand Theme Color (Hex)
                  </label>
                  <div className="flex items-center gap-2">
                    <input
                      type="color"
                      value={themeColor}
                      onChange={(e) => setThemeColor(e.target.value)}
                      className="w-8 h-8 rounded-lg cursor-pointer border border-slate-200 dark:border-[#282A3D]"
                    />
                    <input
                      type="text"
                      value={themeColor}
                      onChange={(e) => setThemeColor(e.target.value)}
                      className="flex-1 p-2 rounded-xl bg-slate-50 dark:bg-[#25273A]/60 border border-slate-200 dark:border-[#282A3D] text-slate-900 dark:text-white font-mono focus:outline-none"
                    />
                  </div>
                </div>

                {/* Actions */}
                <div className="flex items-center justify-end gap-2 pt-3 border-t border-slate-100 dark:border-[#282A3D]">
                  <button
                    type="button"
                    onClick={() => setIsModalOpen(false)}
                    className="px-4 py-2 rounded-xl text-slate-500 dark:text-slate-400 hover:bg-slate-100 dark:bg-[#25273A] font-bold"
                  >
                    Cancel
                  </button>
                  <button
                    type="submit"
                    className="px-5 py-2.5 rounded-xl bg-blue-600 hover:bg-blue-700 text-white font-bold shadow-xs transition-colors"
                  >
                    {editingId ? "Save Changes" : "Create Institution"}
                  </button>
                </div>
              </form>
            </div>
          </div>,
          document.body
        )}
      </main>
    </>
  );
}
