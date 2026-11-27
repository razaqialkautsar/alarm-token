import type { Address, Log } from "viem";

/** topic0 of `CallbackFailure(address,bytes)`, emitted by the callback proxy when the callback reverts. */
export const CALLBACK_FAILURE_TOPIC0 = "0xc8313f695443128e273f1edfcec40b94b7deea8dfbeafd0043290d6601d999db";

export type CallbackOutcome = "delivered" | "failed" | "unknown";

/**
 * Outcome of one callback tx, from its own receipt logs.
 * Do not rely on `getCallbacks(reactiveTxHash)` on the system contract: in gate G1 it returned `[]` after the callback
 * had been delivered (docs/gates.md, G1 finding 4).
 * - failed: the proxy emitted `CallbackFailure` with topic1 = the reactive sender. In G1 run 1 (Base Sepolia tx
 *   0x120b83b9…468a) topic1 was the reactive contract on Lasna, not the receiver, and data held the callback payload.
 * - delivered: the receiver emitted at least one log in the tx and there was no failure.
 */
export function callbackOutcome(
  logs: readonly Pick<Log, "address" | "topics">[],
  proxy: Address,
  reactive: Address,
  receiver: Address,
): CallbackOutcome {
  const reactiveTopic = `0x${reactive.slice(2).toLowerCase().padStart(64, "0")}`;
  const failed = logs.some(
    (log) =>
      log.address.toLowerCase() === proxy.toLowerCase() &&
      log.topics[0] === CALLBACK_FAILURE_TOPIC0 &&
      log.topics[1]?.toLowerCase() === reactiveTopic,
  );
  if (failed) return "failed";
  if (logs.some((log) => log.address.toLowerCase() === receiver.toLowerCase())) return "delivered";
  return "unknown";
}
