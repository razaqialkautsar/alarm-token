import { HealthPanel } from "@/components/dashboard/HealthPanel";

export default function DashboardPage() {
  return (
    <div className="space-y-14">
      <section>
        <h1 className="font-display text-3xl">Dashboard</h1>
        <p className="mt-2 max-w-2xl text-paper/80">
          Testnet only: Base Sepolia, Ethereum Sepolia and Reactive Lasna. Every number below is read on-chain and links
          to its source.
        </p>
      </section>

      <section aria-labelledby="health">
        <h2 id="health" className="font-display text-2xl">
          Health
        </h2>
        <p className="mt-2 max-w-2xl text-sm text-paper/80">
          A Reactive contract with any debt stops executing without an error. Debt is read from the Reactive system
          contract on Lasna and from the callback proxy on Base Sepolia.
        </p>
        <div className="mt-6">
          <HealthPanel />
        </div>
      </section>
    </div>
  );
}
