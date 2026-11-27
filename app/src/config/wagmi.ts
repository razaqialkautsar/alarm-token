import { createConfig, http, injected } from "wagmi";
import { APP_CHAINS, RPC_URLS, baseSepolia, ethereumSepolia, lasna } from "./chains";

export const wagmiConfig = createConfig({
  chains: APP_CHAINS,
  connectors: [injected()],
  transports: {
    [baseSepolia.id]: http(RPC_URLS[baseSepolia.id]),
    [ethereumSepolia.id]: http(RPC_URLS[ethereumSepolia.id]),
    [lasna.id]: http(RPC_URLS[lasna.id]),
  },
  // The dashboard is prerendered; this keeps the first client render equal to the server render.
  ssr: true,
});

declare module "wagmi" {
  interface Register {
    config: typeof wagmiConfig;
  }
}
