// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {Script, console} from "forge-std/Script.sol";
import {BaselineReporter} from "../src/reporter/BaselineReporter.sol";
import {TestnetGuard} from "./TestnetGuard.sol";
import {DeploymentRecorder} from "./DeploymentRecorder.sol";

/// @title DeployBaselineReporter
/// @notice Deploys `BaselineReporter` on the chain behind the RPC URL, bound to that chain's LayerZero EndpointV2.
/// @dev Testnet only. Intended for chain X (Ethereum Sepolia by default). The endpoint is fixed at deployment, so a
///      wrong chain means a redeploy; the chain and endpoint EID are checked first.
///
///      Usage (dry run, then add --broadcast):
///        forge script script/DeployBaselineReporter.s.sol --rpc-url $ETH_SEPOLIA_RPC_URL --private-key $PRIVATE_KEY
contract DeployBaselineReporter is Script, TestnetGuard, DeploymentRecorder {
    /// @notice Script entry point. Checks the chain and endpoint, deploys, and logs the result.
    function run() external returns (BaselineReporter reporter) {
        uint32 expectedEid = _expectedEid(block.chainid);
        _checkEndpoint(expectedEid);
        address endpoint = _endpoint(block.chainid);

        console.log("Chain ID:", block.chainid);
        console.log("LayerZero EID:", expectedEid);
        console.log("Endpoint:", endpoint);

        vm.startBroadcast();
        reporter = new BaselineReporter(endpoint);
        vm.stopBroadcast();

        console.log("BaselineReporter deployed at:", address(reporter));
        _record("BaselineReporter", address(reporter));
    }
}
