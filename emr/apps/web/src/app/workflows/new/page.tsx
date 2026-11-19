"use client";
import { useEffect } from "react";
import { useRouter } from "next/navigation";

export default function WorkflowsNewPage() {
  const router = useRouter();
  useEffect(() => {
    router.replace("/workflows");
  }, [router]);
  return null;
}
