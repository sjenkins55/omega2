"use client";
import { useState, useRef } from "react";
import { useQuery, useMutation, useQueryClient } from "@tanstack/react-query";
import { ingestionApi } from "@/lib/api";
import { Document } from "@/types";
import { cn, formatDateTime } from "@/lib/utils";
import { Upload, FileText, AlertCircle, CheckCircle2, Loader2, Search, ChevronRight } from "lucide-react";
import Link from "next/link";

const STATUS_COLORS: Record<string, string> = {
  received: "bg-gray-100 text-gray-600",
  processing: "bg-blue-50 text-blue-700",
  classified: "bg-yellow-50 text-yellow-700",
  indexed: "bg-green-50 text-green-700",
  failed: "bg-red-50 text-red-700",
};

export default function IngestionPage() {
  const qc = useQueryClient();
  const fileRef = useRef<HTMLInputElement>(null);
  const [search, setSearch] = useState("");
  const [dragOver, setDragOver] = useState(false);

  const { data, isLoading } = useQuery({
    queryKey: ["documents"],
    queryFn: () => ingestionApi.listDocuments(),
    refetchInterval: 5000,
  });

  const uploadMutation = useMutation({
    mutationFn: (file: File) => {
      const fd = new FormData();
      fd.append("file", file);
      return ingestionApi.upload(fd);
    },
    onSuccess: () => qc.invalidateQueries({ queryKey: ["documents"] }),
  });

  const docs: Document[] = (data?.data ?? []).filter(
    (d: Document) => !search || d.file_name.toLowerCase().includes(search.toLowerCase())
  );
  const needsReview = docs.filter((d) => d.requires_action && !d.patient_id);

  const handleDrop = (e: React.DragEvent) => {
    e.preventDefault();
    setDragOver(false);
    const file = e.dataTransfer.files[0];
    if (file) uploadMutation.mutate(file);
  };

  return (
    <div className="space-y-5">
      <div>
        <h1 className="text-2xl font-semibold text-gray-900">Inbox / Document Ingestion</h1>
        <p className="text-sm text-gray-500">Incoming faxes and documents — AI classifies and indexes automatically</p>
      </div>

      {needsReview.length > 0 && (
        <div className="bg-amber-50 border border-amber-200 rounded-xl p-4 flex items-start gap-3">
          <AlertCircle className="w-5 h-5 text-amber-600 shrink-0 mt-0.5" />
          <div>
            <div className="font-medium text-amber-900">{needsReview.length} document{needsReview.length > 1 ? "s" : ""} need patient assignment</div>
            <p className="text-sm text-amber-700 mt-0.5">AI couldn't automatically match these to a patient. Review and assign below.</p>
          </div>
        </div>
      )}

      {/* Upload zone */}
      <div
        onDragOver={(e) => { e.preventDefault(); setDragOver(true); }}
        onDragLeave={() => setDragOver(false)}
        onDrop={handleDrop}
        onClick={() => fileRef.current?.click()}
        className={cn(
          "border-2 border-dashed rounded-xl p-8 text-center cursor-pointer transition-colors",
          dragOver ? "border-blue-400 bg-blue-50" : "border-gray-200 hover:border-blue-300 hover:bg-gray-50"
        )}
      >
        <input
          ref={fileRef}
          type="file"
          className="hidden"
          accept=".pdf,.jpg,.jpeg,.png,.tiff"
          onChange={(e) => e.target.files?.[0] && uploadMutation.mutate(e.target.files[0])}
        />
        {uploadMutation.isPending ? (
          <div className="flex flex-col items-center gap-2">
            <Loader2 className="w-8 h-8 text-blue-500 animate-spin" />
            <p className="text-sm text-gray-600">Uploading and processing...</p>
          </div>
        ) : (
          <div className="flex flex-col items-center gap-2">
            <Upload className="w-8 h-8 text-gray-400" />
            <p className="text-sm font-medium text-gray-700">Drop a file or click to upload</p>
            <p className="text-xs text-gray-400">PDF, JPG, PNG, TIFF · AI will classify and extract data automatically</p>
          </div>
        )}
      </div>

      {/* Document list */}
      <div className="bg-white rounded-xl border border-gray-200">
        <div className="px-5 py-3 border-b border-gray-100 flex items-center gap-3">
          <Search className="w-4 h-4 text-gray-400" />
          <input
            value={search}
            onChange={(e) => setSearch(e.target.value)}
            placeholder="Search documents..."
            className="flex-1 text-sm focus:outline-none"
          />
          {isLoading && <Loader2 className="w-4 h-4 animate-spin text-gray-400" />}
        </div>

        <div className="divide-y divide-gray-50">
          {docs.map((doc) => (
            <Link key={doc.id} href={`/ingestion/${doc.id}`} className="flex items-center gap-4 px-5 py-3 hover:bg-gray-50">
              <div className={cn(
                "w-9 h-9 rounded-lg flex items-center justify-center shrink-0",
                doc.requires_action ? "bg-amber-100" : "bg-blue-50"
              )}>
                <FileText className={cn("w-4 h-4", doc.requires_action ? "text-amber-600" : "text-blue-600")} />
              </div>
              <div className="flex-1 min-w-0">
                <div className="flex items-center gap-2">
                  <span className="text-sm font-medium text-gray-900 truncate">{doc.file_name}</span>
                  <span className={cn("text-xs font-medium px-1.5 py-0.5 rounded-full shrink-0", STATUS_COLORS[doc.status] ?? "bg-gray-100 text-gray-600")}>
                    {doc.status}
                  </span>
                  {doc.requires_action && (
                    <span className="text-xs bg-amber-100 text-amber-700 px-1.5 py-0.5 rounded-full shrink-0 font-medium">
                      Needs Review
                    </span>
                  )}
                </div>
                <div className="text-xs text-gray-500 mt-0.5">
                  {doc.doc_type.replace(/_/g, " ")}
                  {doc.source_fax_number && <> · From: {doc.source_fax_number}</>}
                  {doc.ai_summary && <> · {doc.ai_summary.slice(0, 60)}...</>}
                </div>
              </div>
              <div className="text-xs text-gray-400 shrink-0">{formatDateTime(doc.received_at)}</div>
              <ChevronRight className="w-4 h-4 text-gray-300 shrink-0" />
            </Link>
          ))}
          {docs.length === 0 && !isLoading && (
            <div className="py-12 text-center text-sm text-gray-400">No documents yet</div>
          )}
        </div>
      </div>
    </div>
  );
}
