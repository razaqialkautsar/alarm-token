// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {Script, console} from "forge-std/Script.sol";
import {DemoOFT} from "../src/demo/DemoOFT.sol";
import {TestnetGuard} from "./TestnetGuard.sol";

/// @title DeployDemoOFT
/// @notice Deploys one `DemoOFT` on the chain the script runs against. Testnet only (CLAUDE.md sections 2.4 and 7).
/// @dev Chain X is chosen by the RPC URL, not by code, so the same script serves Ethereum Sepolia (default) and
///      Unichain Sepolia (only if ESC is reopened). The deployer becomes owner and initial LayerZero delegate.
///      Run once per chain, then wire the peers (setPeer on both sides) before sending.
///
///      Usage (dry run, then add --broadcast):
///        forge script script/DeployDemoOFT.s.sol --rpc-url $BASE_SEPOLIA_RPC_URL --private-key $PRIVATE_KEY
///      Optional env: DEMO_OFT_NAME, DEMO_OFT_SYMBOL, DEMO_OFT_INITIAL_SUPPLY (whole tokens, 18 decimals).
contract DeployDemoOFT is Script, TestnetGuard {
    uint256 internal constant TOKEN_DECIMALS = 1e18;
    uint256 internal constant DEFAULT_INITIAL_SUPPLY_TOKENS = 1_000_000;
    string internal constant DEFAULT_NAME = "Alarm Demo OFT";
    string internal constant DEFAULT_SYMBOL = "ADEMO";

    /// @notice Script entry point. Reads optional env overrides, checks the chain, deploys, and logs the result.
    function run() external returns (DemoOFT token) {
        string memory name = vm.envOr("DEMO_OFT_NAME", DEFAULT_NAME);
        string memory symbol = vm.envOr("DEMO_OFT_SYMBOL", DEFAULT_SYMBOL);
        uint256 supply = vm.envOr("DEMO_OFT_INITIAL_SUPPLY", DEFAULT_INITIAL_SUPPLY_TOKENS) * TOKEN_DECIMALS;

        uint32 expectedEid = _expectedEid(block.chainid);
        _checkEndpoint(expectedEid);

        console.log("Chain ID:", block.chainid);
        console.log("LayerZero EID:", expectedEid);
        console.log("Endpoint:", LZ_ENDPOINT_V2);

        vm.startBroadcast();
        // Inside a broadcast, `msg.sender` of `run()` can differ from the account that signs. Ask the cheatcode for
        // the broadcaster so the owner is always the signing account.
        (, address owner,) = vm.readCallers();
        token = new DemoOFT(name, symbol, LZ_ENDPOINT_V2, owner, supply);
        vm.stopBroadcast();

        console.log("DemoOFT deployed at:", address(token));
        console.log("Owner and delegate:", owner);
        console.log("Initial supply (wei):", supply);
    }
}
