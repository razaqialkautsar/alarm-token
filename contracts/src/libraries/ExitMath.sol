// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";

/// @title ExitMath
/// @notice Pure arithmetic for `AlarmExecutor` exits (PRD.md section 7.5 F3): how much to take from a user, which price
///         to trust, and the minimum stablecoin output for a swap.
/// @dev Price unit: stablecoin smallest units per token smallest unit, scaled by `PRICE_SCALE` (1e36). Example: a token
///      with 18 decimals at 0.0001 USDC (6 decimals) is 1e-4 * 1e6 / 1e18 = 1e-16 raw, so `price` = 1e20. The scale is
///      large so that cheap tokens keep precision. `AlarmReactive` produces it from a Uniswap v3 `Swap` event with
///      `priceFromSqrtPriceX96` (agreed by Aga and Razaqi, 27 Nov 2026).
library ExitMath {
    uint256 internal constant BPS = 10_000;
    uint256 internal constant PRICE_SCALE = 1e36;
    /// @dev Uniswap v3 prices are Q64.96 square roots: sqrtPriceX96 = sqrt(token1 raw / token0 raw) * 2^96.
    uint256 internal constant Q96 = 2 ** 96;
    /// @dev Bounds of a Uniswap v3 sqrtPriceX96. Source: Uniswap v3-core `TickMath.sol` (`MIN_SQRT_RATIO`,
    ///      `MAX_SQRT_RATIO`), checked 27 Nov 2026. A pool never reports a value outside them.
    uint256 internal constant MIN_SQRT_PRICE_X96 = 4_295_128_739;
    uint256 internal constant MAX_SQRT_PRICE_X96 = 1_461_446_703_485_210_103_287_273_052_203_988_822_378_723_970_342;

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

    /// @notice Converts a Uniswap v3 pool price into this library's price unit for the protected token.
    /// @dev Never reverts, so it is safe inside `react()`. Input outside the Uniswap v3 bounds (which includes zero
    ///      and any dirty word above 160 bits) returns 0, which `effectivePrice` treats as a missing reference. Pass
    ///      the `Swap` event's sqrtPriceX96 word as decoded (`uint256`), without truncating it first.
    ///      Token is token0: price = sqrtP^2 / 2^192 (stablecoin is token1).
    ///      Token is token1: price = 2^192 / sqrtP^2 (stablecoin is token0).
    ///      Each case is two `mulDiv` steps through 2^96. With sqrtP between 2^32 and 2^160, every step stays below
    ///      2^248, so nothing overflows. Rounds down; tiny prices can round to 0.
    /// @param sqrtPriceX96 sqrt(token1 raw / token0 raw) * 2^96, from the pool's `Swap` event or `slot0()`.
    /// @param tokenIsToken0 True when the protected token is the pool's token0 (its address sorts below the
    ///        stablecoin's).
    /// @return price Stablecoin smallest units per token smallest unit, scaled by `PRICE_SCALE`.
    function priceFromSqrtPriceX96(uint256 sqrtPriceX96, bool tokenIsToken0) internal pure returns (uint256 price) {
        if (sqrtPriceX96 < MIN_SQRT_PRICE_X96 || sqrtPriceX96 > MAX_SQRT_PRICE_X96) return 0;
        if (tokenIsToken0) {
            return Math.mulDiv(Math.mulDiv(sqrtPriceX96, PRICE_SCALE, Q96), sqrtPriceX96, Q96);
        }
        return Math.mulDiv(Math.mulDiv(PRICE_SCALE, Q96, sqrtPriceX96), Q96, sqrtPriceX96);
    }
}
