"use client";
import { useEffect } from "react";
import { useRouter } from "next/navigation";

export default function EngagementNewPage() {
  const router = useRouter();
  useEffect(() => {
    router.replace("/engagement?create=1");
  }, [router]);
  return null;
}
