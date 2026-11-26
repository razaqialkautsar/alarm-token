// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {Test} from "forge-std/Test.sol";
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
}
