// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {Test, Vm} from "forge-std/Test.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {DeployDemoOFT} from "../../script/DeployDemoOFT.s.sol";
import {CreateDemoPool} from "../../script/CreateDemoPool.s.sol";
import {SwapDemoPool} from "../../script/SwapDemoPool.s.sol";
import {IUniswapV3Factory} from "../../script/UniswapV3Interfaces.sol";
import {DemoOFT} from "../../src/demo/DemoOFT.sol";

/// @notice Runs the G6 scripts against a Base Sepolia fork. Skipped when BASE_SEPOLIA_RPC_URL is not set.
/// @dev This is a rehearsal on forked state, not on-chain evidence. Gate results need real tx hashes in docs/gates.md.
contract DemoPoolForkTest is Test {
    address internal constant USDC = 0x036CbD53842c5426634e7929541eC2318f3dCF7e;
    address internal constant UNISWAP_V3_FACTORY = 0x4752ba5DBc23f44D87826276BF6Fd6b1C372aD24;
    uint24 internal constant POOL_FEE = 3000;
    uint256 internal constant DEMO_TOKENS = 100_000;
    uint256 internal constant USDC_TOKENS = 10;
    uint256 internal constant SELL_TOKENS = 1000;
    uint256 internal constant USDC_DECIMALS = 1e6;
    /// @dev keccak256("Swap(address,address,int256,int256,uint160,uint128,int24)")
    bytes32 internal constant SWAP_TOPIC = 0xc42079f94a6350d7e6235f29174924f928cc2ac818eb64fed8004e115fbcca67;

    function setUp() public {
        string memory rpc = vm.envOr("BASE_SEPOLIA_RPC_URL", string(""));
        if (bytes(rpc).length == 0) vm.skip(true);
        vm.createSelectFork(rpc);
    }

    function test_createPoolThenSwap() public {
        DemoOFT token = new DeployDemoOFT().run();
        address owner = token.owner();
        deal(USDC, owner, USDC_TOKENS * USDC_DECIMALS);

        new CreateDemoPool().run(address(token), DEMO_TOKENS, USDC_TOKENS, POOL_FEE);
        address pool = IUniswapV3Factory(UNISWAP_V3_FACTORY).getPool(address(token), USDC, POOL_FEE);
        assertTrue(pool != address(0), "pool created");

        uint256 usdcBefore = IERC20(USDC).balanceOf(owner);
        vm.recordLogs();
        new SwapDemoPool().run(address(token), SELL_TOKENS, POOL_FEE);

        assertGt(IERC20(USDC).balanceOf(owner), usdcBefore, "received USDC");

        Vm.Log[] memory logs = vm.getRecordedLogs();
        bool sawSwap;
        for (uint256 i; i < logs.length; i++) {
            if (logs[i].emitter == pool && logs[i].topics[0] == SWAP_TOPIC) {
                sawSwap = true;
                assertEq(logs[i].topics.length, 3, "Swap has two indexed params (sender, recipient)");
            }
        }
        assertTrue(sawSwap, "pool emitted Swap");
    }
}
