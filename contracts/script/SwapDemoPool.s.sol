// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {Script, console} from "forge-std/Script.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IUniswapV3Factory, ISwapRouter02} from "./UniswapV3Interfaces.sol";

/// @title SwapDemoPool
/// @notice Sells DemoOFT for USDC through the Uniswap v3 pool on Base Sepolia (gate G6: "swap works").
/// @dev Base Sepolia only. Use the tx hash to read the pool's `Swap` event and note its format in `docs/gates.md`.
///      Required env: DEMO_OFT, SELL_TOKENS (whole DemoOFT tokens, 18 decimals). Optional env: POOL_FEE (default 3000).
///
///      Usage (dry run, then add --broadcast):
///        DEMO_OFT=0x.. SELL_TOKENS=1000 \
///        forge script script/SwapDemoPool.s.sol --rpc-url $BASE_SEPOLIA_RPC_URL --private-key $PRIVATE_KEY
contract SwapDemoPool is Script {
    uint256 internal constant BASE_SEPOLIA_CHAIN_ID = 84532;

    /// @dev Uniswap v3 on Base Sepolia. Source: docs.uniswap.org v3 Base deployments page (checked 25 Nov 2026).
    ///      `SwapRouter02` has code and `WETH9()` returns 0x4200..0006 on-chain.
    address internal constant UNISWAP_V3_FACTORY = 0x4752ba5DBc23f44D87826276BF6Fd6b1C372aD24;
    address internal constant SWAP_ROUTER_02 = 0x94cC0AaC535CCDB3C01d6787D6413C739ae12bc4;

    /// @dev USDC on Base Sepolia. Source: Circle docs (PRD.md section 8.5).
    address internal constant USDC = 0x036CbD53842c5426634e7929541eC2318f3dCF7e;

    uint256 internal constant DEMO_DECIMALS = 1e18;
    uint24 internal constant DEFAULT_POOL_FEE = 3000;
    /// @dev 0 means no price limit. Acceptable for a testnet drill swap in a pool we control.
    uint160 internal constant NO_PRICE_LIMIT = 0;

    error UnsupportedChain(uint256 chainId);
    error ZeroAmount();
    error PoolMissing(address demoOft, uint24 fee);

    /// @notice Script entry point. Reads env and sells.
    function run() external {
        run(
            vm.envAddress("DEMO_OFT"),
            vm.envUint("SELL_TOKENS"),
            uint24(vm.envOr("POOL_FEE", uint256(DEFAULT_POOL_FEE)))
        );
    }

    /// @notice Sells `sellTokens` DemoOFT for USDC to the signer.
    /// @param demoOft DemoOFT on Base Sepolia.
    /// @param sellTokens Whole DemoOFT tokens to sell.
    /// @param fee Uniswap v3 fee tier of the pool.
    function run(address demoOft, uint256 sellTokens, uint24 fee) public {
        if (block.chainid != BASE_SEPOLIA_CHAIN_ID) revert UnsupportedChain(block.chainid);
        if (sellTokens == 0) revert ZeroAmount();
        if (IUniswapV3Factory(UNISWAP_V3_FACTORY).getPool(demoOft, USDC, fee) == address(0)) {
            revert PoolMissing(demoOft, fee);
        }

        uint256 amountIn = sellTokens * DEMO_DECIMALS;

        vm.startBroadcast();
        (, address signer,) = vm.readCallers();
        uint256 usdcBefore = IERC20(USDC).balanceOf(signer);

        IERC20(demoOft).approve(SWAP_ROUTER_02, amountIn);
        uint256 amountOut = ISwapRouter02(SWAP_ROUTER_02)
            .exactInputSingle(
                ISwapRouter02.ExactInputSingleParams({
                tokenIn: demoOft,
                tokenOut: USDC,
                fee: fee,
                recipient: signer,
                amountIn: amountIn,
                amountOutMinimum: 1,
                sqrtPriceLimitX96: NO_PRICE_LIMIT
            })
            );
        vm.stopBroadcast();

        console.log("Sold DemoOFT (wei):", amountIn);
        console.log("Received USDC (6 decimals):", amountOut);
        console.log("USDC balance before:", usdcBefore);
    }
}
