// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {Script, console} from "forge-std/Script.sol";
import {G1Receiver} from "../src/gates/G1Receiver.sol";
import {DeploymentRecorder} from "./DeploymentRecorder.sol";

/// @title DeployG1Receiver
/// @notice Gate G1, step 2: deploys `G1Receiver` on Base Sepolia, bound to the Reactive callback proxy and to the
///         `G1Reactive` address from step 1. Both are immutable; a wrong value means a redeploy.
/// @dev Base Sepolia only.
///
///      Usage (dry run, then add --broadcast):
///        G1_REACTIVE=0x... G1_FUND_WEI=10000000000000000 \
///          forge script script/DeployG1Receiver.s.sol --rpc-url $BASE_SEPOLIA_RPC_URL --private-key $PRIVATE_KEY
contract DeployG1Receiver is DeploymentRecorder {
    /// @dev Reactive callback proxy on Base Sepolia. Source: Reactive docs `/origins-and-destinations`, checked
    ///      19-20 Nov 2026 (PRD.md section 7.1) and again 26 Nov 2026. Not the LayerZero endpoint.
    address internal constant BASE_SEPOLIA_CALLBACK_PROXY = 0x476F44b11F5C942c58f4c8E3d0300E5710743585;

    error NotBaseSepolia(uint256 chainId);
    error ProxyMissing(address proxy);

    /// @notice Script entry point. Checks the chain and proxy, deploys, and logs the result.
    /// @dev Required env: `G1_REACTIVE` (G1Reactive on Lasna). Optional: `G1_FUND_WEI`, Base Sepolia ETH sent with the
    ///      deployment to pay for callbacks (default 0).
    function run() external returns (G1Receiver receiver) {
        if (block.chainid != BASE_SEPOLIA_ID) revert NotBaseSepolia(block.chainid);
        if (BASE_SEPOLIA_CALLBACK_PROXY.code.length == 0) revert ProxyMissing(BASE_SEPOLIA_CALLBACK_PROXY);
        address reactive = vm.envAddress("G1_REACTIVE");
        uint256 fund = vm.envOr("G1_FUND_WEI", uint256(0));

        console.log("Chain ID:", block.chainid);
        console.log("Callback proxy:", BASE_SEPOLIA_CALLBACK_PROXY);
        console.log("Callback sender (G1Reactive on Lasna):", reactive);
        console.log("Funding (wei):", fund);

        vm.startBroadcast();
        receiver = new G1Receiver{value: fund}(BASE_SEPOLIA_CALLBACK_PROXY, reactive);
        vm.stopBroadcast();

        console.log("G1Receiver deployed at:", address(receiver));
        _record("G1Receiver", address(receiver));
    }
}
