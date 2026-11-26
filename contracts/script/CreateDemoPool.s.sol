// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {Script, console} from "forge-std/Script.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {IUniswapV3Factory, INonfungiblePositionManager} from "./UniswapV3Interfaces.sol";
import {DeploymentRecorder} from "./DeploymentRecorder.sol";

/// @title CreateDemoPool
/// @notice Creates a Uniswap v3 DemoOFT/USDC pool on Base Sepolia and seeds it with full-range liquidity (gate G6).
/// @dev Base Sepolia only. The signer must hold both tokens: DemoOFT from `DeployDemoOFT`, USDC from the Circle faucet.
///      The starting price is set by the two amounts, so the ratio DEMO_TOKENS : USDC_TOKENS is the price.
///      Required env: DEMO_OFT, DEMO_TOKENS (whole tokens, 18 decimals), USDC_TOKENS (whole USDC, 6 decimals).
///      Optional env: POOL_FEE (default 3000 = 0.3%).
///
///      Usage (dry run, then add --broadcast):
///        DEMO_OFT=0x.. DEMO_TOKENS=100000 USDC_TOKENS=10 \
///        forge script script/CreateDemoPool.s.sol --rpc-url $BASE_SEPOLIA_RPC_URL --private-key $PRIVATE_KEY
contract CreateDemoPool is Script, DeploymentRecorder {
    uint256 internal constant BASE_SEPOLIA_CHAIN_ID = 84532;

    /// @dev Uniswap v3 on Base Sepolia. Source: docs.uniswap.org v3 Base deployments page (checked 25 Nov 2026).
    ///      On-chain: `NonfungiblePositionManager.factory()` returns this factory, and `WETH9()` returns 0x4200..0006.
    address internal constant UNISWAP_V3_FACTORY = 0x4752ba5DBc23f44D87826276BF6Fd6b1C372aD24;
    address internal constant POSITION_MANAGER = 0x27F971cb582BF9E50F397e4d29a5C7A34f11faA2;

    /// @dev USDC on Base Sepolia. Source: Circle docs (PRD.md section 8.5). `symbol()` = USDC and `decimals()` = 6
    ///      were read on-chain on 25 Nov 2026.
    address internal constant USDC = 0x036CbD53842c5426634e7929541eC2318f3dCF7e;

    uint256 internal constant DEMO_DECIMALS = 1e18;
    uint256 internal constant USDC_DECIMALS = 1e6;
    uint24 internal constant DEFAULT_POOL_FEE = 3000;
    /// @dev Full range is MIN_TICK/MAX_TICK rounded inward to the fee tier's tick spacing.
    int24 internal constant MAX_TICK = 887272;
    /// @dev Minimum share of each desired amount that must be used. Guards against a pool that already existed
    ///      at a different price.
    uint256 internal constant MIN_AMOUNT_BPS = 9900;
    uint256 internal constant BPS_DENOMINATOR = 10_000;
    uint256 internal constant DEADLINE_WINDOW = 1 hours;
    uint256 internal constant Q192_SHIFT = 192;

    struct Plan {
        address token0;
        address token1;
        uint24 fee;
        int24 tickUpper;
        uint256 amount0;
        uint256 amount1;
        uint160 sqrtPriceX96;
    }

    error UnsupportedChain(uint256 chainId);
    error ZeroAmount();
    error SameToken();
    error FeeTierNotEnabled(uint24 fee);
    error InsufficientBalance(address token, uint256 have, uint256 need);

    /// @notice Script entry point. Reads env, creates and initializes the pool, then mints the position.
    function run() external {
        run(vm.envAddress("DEMO_OFT"), vm.envUint("DEMO_TOKENS"), vm.envUint("USDC_TOKENS"), _fee());
    }

    /// @notice Creates the pool at the price implied by the amounts and seeds full-range liquidity.
    /// @param demoOft DemoOFT on Base Sepolia.
    /// @param demoTokens Whole DemoOFT tokens to add.
    /// @param usdcTokens Whole USDC to add.
    /// @param fee Uniswap v3 fee tier.
    function run(address demoOft, uint256 demoTokens, uint256 usdcTokens, uint24 fee) public {
        if (block.chainid != BASE_SEPOLIA_CHAIN_ID) revert UnsupportedChain(block.chainid);
        if (demoTokens == 0 || usdcTokens == 0) revert ZeroAmount();
        if (demoOft == USDC) revert SameToken();

        int24 spacing = IUniswapV3Factory(UNISWAP_V3_FACTORY).feeAmountTickSpacing(fee);
        if (spacing == 0) revert FeeTierNotEnabled(fee);

        Plan memory plan = _plan(demoOft, demoTokens * DEMO_DECIMALS, usdcTokens * USDC_DECIMALS, fee, spacing);

        console.log("Chain ID:", block.chainid);
        console.log("token0:", plan.token0);
        console.log("token1:", plan.token1);
        console.log("Fee:", fee);
        console.log("sqrtPriceX96:", uint256(plan.sqrtPriceX96));

        vm.startBroadcast();
        (, address signer,) = vm.readCallers();
        _requireBalance(demoOft, signer, demoTokens * DEMO_DECIMALS);
        _requireBalance(USDC, signer, usdcTokens * USDC_DECIMALS);
        _createAndSeed(plan, signer);
        vm.stopBroadcast();
    }

    /// @dev Orders the pair by address (Uniswap requires token0 < token1) and derives the starting price.
    function _plan(address demoOft, uint256 demoAmount, uint256 usdcAmount, uint24 fee, int24 spacing)
        internal
        pure
        returns (Plan memory plan)
    {
        bool demoIsToken0 = demoOft < USDC;
        plan.fee = fee;
        // Rounding down to a multiple of the tick spacing is the intent here.
        // forge-lint: disable-next-line(divide-before-multiply)
        plan.tickUpper = (MAX_TICK / spacing) * spacing;
        (plan.token0, plan.token1) = demoIsToken0 ? (demoOft, USDC) : (USDC, demoOft);
        (plan.amount0, plan.amount1) = demoIsToken0 ? (demoAmount, usdcAmount) : (usdcAmount, demoAmount);
        plan.sqrtPriceX96 = _sqrtPriceX96(plan.amount0, plan.amount1);
    }

    /// @dev Creates and initializes the pool, approves both tokens, and mints the full-range position to `signer`.
    function _createAndSeed(Plan memory plan, address signer) internal {
        INonfungiblePositionManager pm = INonfungiblePositionManager(POSITION_MANAGER);
        address pool = pm.createAndInitializePoolIfNecessary(plan.token0, plan.token1, plan.fee, plan.sqrtPriceX96);

        IERC20(plan.token0).approve(POSITION_MANAGER, plan.amount0);
        IERC20(plan.token1).approve(POSITION_MANAGER, plan.amount1);

        (uint256 tokenId, uint128 liquidity, uint256 used0, uint256 used1) = pm.mint(
            INonfungiblePositionManager.MintParams({
                token0: plan.token0,
                token1: plan.token1,
                fee: plan.fee,
                tickLower: -plan.tickUpper,
                tickUpper: plan.tickUpper,
                amount0Desired: plan.amount0,
                amount1Desired: plan.amount1,
                amount0Min: (plan.amount0 * MIN_AMOUNT_BPS) / BPS_DENOMINATOR,
                amount1Min: (plan.amount1 * MIN_AMOUNT_BPS) / BPS_DENOMINATOR,
                recipient: signer,
                deadline: block.timestamp + DEADLINE_WINDOW
            })
        );

        console.log("Pool:", pool);
        // Key includes the fee tier, because each tier is a separate pool.
        _record(string.concat("UniswapV3Pool_DemoOFT_USDC_", vm.toString(uint256(plan.fee))), pool);
        console.log("Position NFT id:", tokenId);
        console.log("Liquidity:", uint256(liquidity));
        console.log("Used token0:", used0);
        console.log("Used token1:", used1);
    }

    /// @dev sqrtPriceX96 = sqrt(amount1 / amount0) * 2^96, computed as sqrt(amount1 * 2^192 / amount0) with a
    ///      512-bit intermediate so large amounts do not overflow.
    function _sqrtPriceX96(uint256 amount0, uint256 amount1) internal pure returns (uint160) {
        uint256 ratioX192 = Math.mulDiv(amount1, uint256(1) << Q192_SHIFT, amount0);
        return uint160(Math.sqrt(ratioX192));
    }

    function _requireBalance(address token, address account, uint256 need) internal view {
        uint256 have = IERC20(token).balanceOf(account);
        if (have < need) revert InsufficientBalance(token, have, need);
    }

    function _fee() internal view returns (uint24) {
        return uint24(vm.envOr("POOL_FEE", uint256(DEFAULT_POOL_FEE)));
    }
}
