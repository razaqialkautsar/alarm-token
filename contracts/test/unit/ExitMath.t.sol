// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {Test} from "forge-std/Test.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {ExitMath} from "../../src/libraries/ExitMath.sol";

/// @dev External wrappers so reverts from the internal library can be asserted.
contract ExitMathHarness {
    function exitAmount(uint256 b, uint256 a, uint256 p) external pure returns (uint256) {
        return ExitMath.exitAmount(b, a, p);
    }

    function minOut(uint256 amountIn, uint256 price, uint256 slippageBps) external pure returns (uint256) {
        return ExitMath.minOut(amountIn, price, slippageBps);
    }

    function effectivePrice(uint256 r, uint256 t, uint256 f, uint256 m, uint256 n)
        external
        pure
        returns (uint256, bool)
    {
        return ExitMath.effectivePrice(r, t, f, m, n);
    }

    function priceFromSqrtPriceX96(uint256 s, bool tokenIsToken0) external pure returns (uint256) {
        return ExitMath.priceFromSqrtPriceX96(s, tokenIsToken0);
    }
}

contract ExitMathTest is Test {
    uint256 internal constant BPS = 10_000;
    uint256 internal constant FULL = 10_000;
    uint256 internal constant HALF = 5_000;
    uint256 internal constant DEFAULT_SLIPPAGE = 2_000;
    /// @dev 0.0001 USDC (6 decimals) per token (18 decimals): 1e-4 * 1e6 / 1e18 * 1e36.
    uint256 internal constant PRICE_0_0001 = 1e20;
    uint256 internal constant MAX_AGE = 60;

    ExitMathHarness internal h;

    function setUp() public {
        h = new ExitMathHarness();
    }

    // --- exitAmount ---

    function test_exitAmount_takesTheSmallerOfBalanceAndAllowance() public view {
        assertEq(h.exitAmount(100, 40, FULL), 40);
        assertEq(h.exitAmount(30, 40, FULL), 30);
    }

    function test_exitAmount_appliesThePortion() public view {
        assertEq(h.exitAmount(100, 100, HALF), 50);
        assertEq(h.exitAmount(100, 100, 0), 0);
    }

    function test_exitAmount_revertsAbove100Percent() public {
        vm.expectRevert(abi.encodeWithSelector(ExitMath.BpsOutOfRange.selector, BPS + 1));
        h.exitAmount(1, 1, BPS + 1);
    }

    /// @dev Executor invariant 3 at the library level.
    function testFuzz_exitAmount_neverExceedsBalanceOrAllowance(uint256 balance, uint256 allowance, uint256 portionBps)
        public
        view
    {
        portionBps = bound(portionBps, 0, BPS);
        uint256 amount = h.exitAmount(balance, allowance, portionBps);
        assertLe(amount, balance);
        assertLe(amount, allowance);
    }

    function testFuzz_exitAmount_fullPortionTakesExactlyTheMinimum(uint256 balance, uint256 allowance) public view {
        assertEq(h.exitAmount(balance, allowance, FULL), balance < allowance ? balance : allowance);
    }

    // --- minOut ---

    function test_minOut_knownExample() public view {
        // 1,000 tokens at 0.0001 USDC = 0.1 USDC = 100,000 units. 20% slippage leaves 80,000.
        assertEq(h.minOut(1_000 ether, PRICE_0_0001, DEFAULT_SLIPPAGE), 80_000);
    }

    function test_minOut_zeroSlippageIsTheExpectedOutput() public view {
        assertEq(h.minOut(1_000 ether, PRICE_0_0001, 0), 100_000);
    }

    function test_minOut_fullSlippageIsAnyPrice() public view {
        assertEq(h.minOut(1_000 ether, PRICE_0_0001, BPS), 0);
    }

    function test_minOut_revertsAbove100Percent() public {
        vm.expectRevert(abi.encodeWithSelector(ExitMath.BpsOutOfRange.selector, BPS + 1));
        h.minOut(1, 1, BPS + 1);
    }

    function testFuzz_minOut_neverExceedsTheExpectedOutput(uint128 amountIn, uint128 price, uint256 slippageBps)
        public
        view
    {
        slippageBps = bound(slippageBps, 0, BPS);
        uint256 expected = (uint256(amountIn) * uint256(price)) / 1e36;
        assertLe(h.minOut(amountIn, price, slippageBps), expected);
    }

    function testFuzz_minOut_moreSlippageNeverRaisesTheMinimum(uint128 amountIn, uint128 price, uint256 a, uint256 b)
        public
        view
    {
        a = bound(a, 0, BPS);
        b = bound(b, a, BPS);
        assertGe(h.minOut(amountIn, price, a), h.minOut(amountIn, price, b));
    }

    // --- effectivePrice ---

    function test_effectivePrice_usesAFreshReference() public view {
        (uint256 price, bool usedFloor) = h.effectivePrice(PRICE_0_0001, 1_000, 7, MAX_AGE, 1_000 + MAX_AGE);
        assertEq(price, PRICE_0_0001);
        assertFalse(usedFloor);
    }

    function test_effectivePrice_fallsBackToTheFloorWhenStale() public view {
        (uint256 price, bool usedFloor) = h.effectivePrice(PRICE_0_0001, 1_000, 7, MAX_AGE, 1_000 + MAX_AGE + 1);
        assertEq(price, 7);
        assertTrue(usedFloor);
    }

    function test_effectivePrice_treatsAFutureTimestampAsFresh() public view {
        (uint256 price, bool usedFloor) = h.effectivePrice(PRICE_0_0001, 2_000, 7, MAX_AGE, 1_000);
        assertEq(price, PRICE_0_0001);
        assertFalse(usedFloor);
    }

    function test_effectivePrice_treatsAZeroReferenceAsMissing() public view {
        (uint256 price, bool usedFloor) = h.effectivePrice(0, 1_000, 7, MAX_AGE, 1_000);
        assertEq(price, 7);
        assertTrue(usedFloor);
    }

    function testFuzz_effectivePrice_returnsOneOfTheTwoInputs(
        uint256 refPrice,
        uint256 refTs,
        uint256 floorPrice,
        uint256 maxAge,
        uint256 nowTs
    ) public view {
        (uint256 price, bool usedFloor) = h.effectivePrice(refPrice, refTs, floorPrice, maxAge, nowTs);
        assertEq(price, usedFloor ? floorPrice : refPrice);
    }

    // ---------------------------------------------------------------------------------------------------------------
    // priceFromSqrtPriceX96
    // ---------------------------------------------------------------------------------------------------------------

    uint256 internal constant Q96 = 2 ** 96;
    uint256 internal constant MIN_SQRT = 4_295_128_739;
    uint256 internal constant MAX_SQRT = 1_461_446_703_485_210_103_287_273_052_203_988_822_378_723_970_342;
    /// @dev The G6 demo pool: 100,000 DemoOFT (18 decimals) against 10 USDC (6 decimals), i.e. 0.0001 USDC per token.
    uint256 internal constant DEMO_AMOUNT = 100_000e18;
    uint256 internal constant USDC_AMOUNT = 10e6;
    /// @dev 1e-12 relative tolerance, in forge's 1e18 = 100% unit.
    uint256 internal constant REL_TOLERANCE = 1e6;

    /// @dev Same formula as `CreateDemoPool._sqrtPriceX96`: sqrt(amount1 * 2^192 / amount0).
    function _sqrtPriceFromAmounts(uint256 amount0, uint256 amount1) internal pure returns (uint256) {
        return Math.sqrt(Math.mulDiv(amount1, uint256(1) << 192, amount0));
    }

    function test_priceFromSqrtPriceX96_parityIsOneInBothOrders() public view {
        assertEq(h.priceFromSqrtPriceX96(Q96, true), 1e36);
        assertEq(h.priceFromSqrtPriceX96(Q96, false), 1e36);
    }

    function test_priceFromSqrtPriceX96_knownRatio() public view {
        // sqrtP = 2 * 2^96, so token1 / token0 = 4.
        assertEq(h.priceFromSqrtPriceX96(2 * Q96, true), 4e36);
        assertEq(h.priceFromSqrtPriceX96(2 * Q96, false), 0.25e36);
    }

    function test_priceFromSqrtPriceX96_demoPoolWithTokenAsToken0() public view {
        uint256 s = _sqrtPriceFromAmounts(DEMO_AMOUNT, USDC_AMOUNT);
        uint256 price = h.priceFromSqrtPriceX96(s, true);
        assertApproxEqRel(price, PRICE_0_0001, REL_TOLERANCE);
        // Selling 1,000 tokens at 0.0001 USDC is 0.1 USDC = 100,000 units.
        assertApproxEqAbs(h.minOut(1_000e18, price, 0), 100_000, 1);
    }

    function test_priceFromSqrtPriceX96_demoPoolWithTokenAsToken1() public view {
        uint256 s = _sqrtPriceFromAmounts(USDC_AMOUNT, DEMO_AMOUNT);
        uint256 price = h.priceFromSqrtPriceX96(s, false);
        assertApproxEqRel(price, PRICE_0_0001, REL_TOLERANCE);
        assertApproxEqAbs(h.minOut(1_000e18, price, 0), 100_000, 1);
    }

    function test_priceFromSqrtPriceX96_invalidInputIsAMissingPrice() public view {
        uint256[5] memory bad = [0, MIN_SQRT - 1, MAX_SQRT + 1, uint256(type(uint160).max) + 1, type(uint256).max];
        for (uint256 i; i < bad.length; ++i) {
            assertEq(h.priceFromSqrtPriceX96(bad[i], true), 0);
            assertEq(h.priceFromSqrtPriceX96(bad[i], false), 0);
        }
        // A zero reference falls back to the floor price.
        (uint256 price, bool usedFloor) = h.effectivePrice(h.priceFromSqrtPriceX96(0, true), 1_000, 7, MAX_AGE, 1_000);
        assertEq(price, 7);
        assertTrue(usedFloor);
    }

    function test_priceFromSqrtPriceX96_boundsDoNotRevert() public view {
        assertGt(h.priceFromSqrtPriceX96(MIN_SQRT, false), 0);
        assertGt(h.priceFromSqrtPriceX96(MAX_SQRT, true), 0);
        h.priceFromSqrtPriceX96(MIN_SQRT, true);
        h.priceFromSqrtPriceX96(MAX_SQRT, false);
    }

    /// @dev `react()` must never revert, so no input may make the conversion revert.
    function testFuzz_priceFromSqrtPriceX96_neverReverts(uint256 s, bool tokenIsToken0) public view {
        uint256 price = h.priceFromSqrtPriceX96(s, tokenIsToken0);
        if (s < MIN_SQRT || s > MAX_SQRT) assertEq(price, 0);
    }

    function testFuzz_priceFromSqrtPriceX96_isMonotonic(uint256 a, uint256 b) public view {
        a = bound(a, MIN_SQRT, MAX_SQRT);
        b = bound(b, a, MAX_SQRT);
        // A higher token1/token0 ratio means token0 is worth more and token1 is worth less.
        assertLe(h.priceFromSqrtPriceX96(a, true), h.priceFromSqrtPriceX96(b, true));
        assertGe(h.priceFromSqrtPriceX96(a, false), h.priceFromSqrtPriceX96(b, false));
    }

    /// @dev The two orders are reciprocals: price0 * price1 = 1 (in `PRICE_SCALE` units), up to rounding.
    function testFuzz_priceFromSqrtPriceX96_ordersAreReciprocal(uint256 s) public view {
        s = bound(s, 2 ** 64, 2 ** 128);
        uint256 asToken0 = h.priceFromSqrtPriceX96(s, true);
        uint256 asToken1 = h.priceFromSqrtPriceX96(s, false);
        assertApproxEqRel(Math.mulDiv(asToken0, asToken1, 1e36), 1e36, REL_TOLERANCE);
    }
}
