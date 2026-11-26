// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {Script, console} from "forge-std/Script.sol";
import {G1Reactive} from "../src/gates/G1Reactive.sol";
import {DeploymentRecorder} from "./DeploymentRecorder.sol";

/// @title DeployG1Reactive
/// @notice Gate G1, step 1: deploys `G1Reactive` on Reactive Lasna, optionally funded with lREACT at deployment.
/// @dev Lasna only. `configure` is called later, after `G1Receiver` exists on Base Sepolia (Reactive deploy order).
///
///      Usage (dry run, then add --broadcast):
///        G1_FUND_WEI=100000000000000000 \
///          forge script script/DeployG1Reactive.s.sol --rpc-url $LASNA_RPC_URL --private-key $PRIVATE_KEY
contract DeployG1Reactive is DeploymentRecorder {
    error NotLasna(uint256 chainId);

    /// @notice Script entry point. Checks the chain, deploys, and logs the result.
    /// @dev Optional env: `G1_FUND_WEI`, lREACT sent with the deployment (default 0).
    function run() external returns (G1Reactive reactive) {
        if (block.chainid != LASNA_CHAIN_ID) revert NotLasna(block.chainid);
        uint256 fund = vm.envOr("G1_FUND_WEI", uint256(0));

        console.log("Chain ID:", block.chainid);
        console.log("Funding (wei):", fund);

        vm.startBroadcast();
        reactive = new G1Reactive{value: fund}();
        vm.stopBroadcast();

        console.log("G1Reactive deployed at:", address(reactive));
        _record("G1Reactive", address(reactive));
    }
}
