/**
 * Helper to download JSON data as a file in the browser
 */
export function downloadJsonFile(filename: string, data: any) {
  if (typeof window === "undefined") return;
  const jsonStr = JSON.stringify(data, null, 2);
  const blob = new Blob([jsonStr], { type: "application/json;charset=utf-8;" });
  const url = URL.createObjectURL(blob);
  const link = document.createElement("a");
  link.href = url;
  link.setAttribute("download", filename);
  document.body.appendChild(link);
  link.click();
  document.body.removeChild(link);
  URL.revokeObjectURL(url);
}

/**
 * Helper to download tabular data as a CSV file in the browser
 */
export function downloadCsvFile(filename: string, headers: string[], rows: (string | number | boolean | null | undefined)[][]) {
  if (typeof window === "undefined") return;
  const escapeCell = (cell: any) => {
    if (cell === null || cell === undefined) return '""';
    const str = String(cell).replace(/"/g, '""');
    return `"${str}"`;
  };

  const csvRows = [
    headers.map(escapeCell).join(","),
    ...rows.map(row => row.map(escapeCell).join(","))
  ];

  const blob = new Blob(["\uFEFF" + csvRows.join("\r\n")], { type: "text/csv;charset=utf-8;" });
  const url = URL.createObjectURL(blob);
  const link = document.createElement("a");
  link.href = url;
  link.setAttribute("download", filename);
  document.body.appendChild(link);
  link.click();
  document.body.removeChild(link);
  URL.revokeObjectURL(url);
}

/**
 * Helper to download JSON Lines (.jsonl) data for LLM Fine-Tuning (OpenAI / Llama / Gemini ChatML format)
 */
export function downloadJsonlFile(filename: string, lines: Record<string, unknown>[]) {
  if (typeof window === "undefined") return;
  const jsonlContent = lines.map((line) => JSON.stringify(line)).join("\n") + "\n";
  const blob = new Blob([jsonlContent], { type: "application/jsonl;charset=utf-8;" });
  const url = URL.createObjectURL(blob);
  const link = document.createElement("a");
  link.href = url;
  link.setAttribute("download", filename);
  document.body.appendChild(link);
  link.click();
  document.body.removeChild(link);
  URL.revokeObjectURL(url);
}
