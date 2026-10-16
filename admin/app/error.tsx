"use client";

import { useEffect } from "react";
import { ErrorPanel } from "@/components/ui/error-panel";

export default function RootError({
  error,
  retry,
}: {
  error: Error & { digest?: string };
  retry: () => void;
}) {
  useEffect(() => {
    console.error(error);
  }, [error]);

  return (
    <main className="grid min-h-dvh place-items-center px-4">
      <ErrorPanel digest={error.digest} onRetry={retry} homeHref="/login" />
    </main>
  );
}
