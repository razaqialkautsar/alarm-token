import type { Metadata } from "next";
import Link from "next/link";
import { ConnectWallet } from "@/components/dashboard/ConnectWallet";
import { NetworkGuard } from "@/components/dashboard/NetworkGuard";
import { Providers } from "@/components/dashboard/Providers";

export const metadata: Metadata = {
  title: "Dashboard · nothief",
  description: "nothief dashboard on testnet. Every number is read on-chain and links to its source.",
};

export default function DashboardLayout({ children }: LayoutProps<"/dashboard">) {
  return (
    <Providers>
      <header className="flex flex-wrap items-center justify-between gap-4 border-b border-paper/15 px-6 py-4">
        <div className="flex items-baseline gap-3">
          <Link href="/" className="font-display text-xl">
            nothief
          </Link>
          <span className="rounded-full border border-paper/30 px-2 py-0.5 text-xs text-paper/80">Testnet</span>
        </div>
        <ConnectWallet />
      </header>
      <NetworkGuard />
      <main className="mx-auto max-w-6xl px-6 py-10">{children}</main>
    </Providers>
  );
}
