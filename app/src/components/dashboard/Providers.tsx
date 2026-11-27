"use client";

import { QueryClient, QueryClientProvider } from "@tanstack/react-query";
import type { ReactNode } from "react";
import { WagmiProvider } from "wagmi";
import { wagmiConfig } from "@/config/wagmi";

let browserQueryClient: QueryClient | undefined;

/** One client per server render, one shared client in the browser (Next.js TanStack Query guide). */
function getQueryClient() {
  if (typeof window === "undefined") return new QueryClient();
  browserQueryClient ??= new QueryClient();
  return browserQueryClient;
}

export function Providers({ children }: { children: ReactNode }) {
  return (
    <WagmiProvider config={wagmiConfig}>
      <QueryClientProvider client={getQueryClient()}>{children}</QueryClientProvider>
    </WagmiProvider>
  );
}
