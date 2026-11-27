import type { Hash } from "viem";
import { type AppChainId, baseSepolia, lasna } from "./chains";

// Gate G1, run 2 (26 Nov 2026): the basic loop and the keeperless `Progress` loop. A testnet drill played by the team.
// Hashes copied from `docs/gates.md` (G1 run 2 table). The panel reads every receipt and block on-chain; nothing below
// is shown without that read.

export type EvidenceStep = {
  label: string;
  chainId: AppChainId;
  hash: Hash;
  kind: "origin" | "reactive" | "callback";
};

export const G1_RUN2: readonly EvidenceStep[] = [
  {
    label: "Ping(3), origin",
    chainId: baseSepolia.id,
    hash: "0x7e2571adf2638b371b75016eae27e2790a57c1cea26c6e1c98160075a0ebdc03",
    kind: "origin",
  },
  {
    label: "Reactive tx, round 3",
    chainId: lasna.id,
    hash: "0x69142fa0d52fc8745951c2ba021c768effa302055c754588823fff59635b2a67",
    kind: "reactive",
  },
  {
    label: "Callback onRound(3)",
    chainId: baseSepolia.id,
    hash: "0x771bf2c27ad99bdc7cce61fd67ffc850809ef31dcbca31a5aafc2b369b0dd392",
    kind: "callback",
  },
  {
    label: "Reactive tx, round 2",
    chainId: lasna.id,
    hash: "0x7f38f484c71ac9d430b27f3302c7a7e3d627f3824beeaeba36c640c9d9cab79e",
    kind: "reactive",
  },
  {
    label: "Callback onRound(2)",
    chainId: baseSepolia.id,
    hash: "0x807e41331509ee94af4170fc1070fa270ce4cf7b5d87ee869be4b89bb744b12a",
    kind: "callback",
  },
  {
    label: "Reactive tx, round 1",
    chainId: lasna.id,
    hash: "0x83c3f7f0de2edfd07709cb4593b254108eb56abf194e5ce918aed75c4cbcde37",
    kind: "reactive",
  },
  {
    label: "Callback onRound(1)",
    chainId: baseSepolia.id,
    hash: "0xb953f95bf0a43aa01f931a601afd823d5e4a370774179b3bdff0c209c71a5669",
    kind: "callback",
  },
];

export const GATES_DOC_URL = "https://github.com/razaqialkautsar/nothief/blob/main/docs/gates.md#g1";
