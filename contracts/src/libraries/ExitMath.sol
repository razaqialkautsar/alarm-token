// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";

/// @title ExitMath
/// @notice Pure arithmetic for `AlarmExecutor` exits (PRD.md section 7.5 F3): how much to take from a user, which price
///         to trust, and the minimum stablecoin output for a swap.
/// @dev Price unit: stablecoin smallest units per token smallest unit, scaled by `PRICE_SCALE` (1e36). Example: a token
///      with 18 decimals at 0.0001 USDC (6 decimals) is 1e-4 * 1e6 / 1e18 = 1e-16 raw, so `price` = 1e20. The scale is
///      large so that cheap tokens keep precision. How `AlarmReactive` produces this value is not decided yet.
library ExitMath {
    uint256 internal constant BPS = 10_000;
    uint256 internal constant PRICE_SCALE = 1e36;

    error BpsOutOfRange(uint256 bps);

    /// @notice Amount the executor may take from a user: `min(balance, allowance)` times the user's portion.
    /// @dev Executor invariant 3: the result never exceeds `min(balance, allowance)`. Rounds down.
    /// @param balance The user's token balance at callback time.
    /// @param allowance The user's allowance to the executor.
    /// @param portionBps Share to sell, in basis points (10,000 = 100%).
    function exitAmount(uint256 balance, uint256 allowance, uint256 portionBps) internal pure returns (uint256) {
        if (portionBps > BPS) revert BpsOutOfRange(portionBps);
        return Math.mulDiv(Math.min(balance, allowance), portionBps, BPS);
    }

    /// @notice Minimum stablecoin output for selling `amountIn` at `price` with `slippageBps` tolerance.
    /// @dev Rounds down. A slippage of 10,000 bps gives 0, which means "any price".
    /// @param amountIn Token amount to sell, in smallest units.
    /// @param price Price in the unit described above (`PRICE_SCALE`).
    /// @param slippageBps Accepted loss against `price`, in basis points.
    function minOut(uint256 amountIn, uint256 price, uint256 slippageBps) internal pure returns (uint256) {
        if (slippageBps > BPS) revert BpsOutOfRange(slippageBps);
        uint256 expected = Math.mulDiv(amountIn, price, PRICE_SCALE);
        return Math.mulDiv(expected, BPS - slippageBps, BPS);
    }

    /// @notice Chooses the price to base `minOut` on: the reference price while it is fresh, otherwise the user's
    ///         floor price (PRD.md F3 step 4).
    /// @dev `refTs` comes from Lasna (`LogRecord` has no origin timestamp) and `nowTs` from Base, so the clocks can
    ///      differ slightly. A reference stamped in the future counts as age 0. A zero reference counts as missing.
    /// @param refPrice Reference price from `AlarmReactive`.
    /// @param refTs Timestamp of the reference price.
    /// @param floorPrice The user's floor price, same unit.
    /// @param maxAge Maximum accepted age of the reference, in seconds. Inclusive.
    /// @param nowTs Current timestamp on the executor chain.
    /// @return price The price to use.
    /// @return usedFloor True when the floor price was chosen.
    function effectivePrice(uint256 refPrice, uint256 refTs, uint256 floorPrice, uint256 maxAge, uint256 nowTs)
        internal
        pure
        returns (uint256 price, bool usedFloor)
    {
        uint256 age = nowTs > refTs ? nowTs - refTs : 0;
        if (refPrice == 0 || age > maxAge) return (floorPrice, true);
        return (refPrice, false);
    }
}
