// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {Test} from "forge-std/Test.sol";
import {DeployBaselineReporter} from "../../script/DeployBaselineReporter.s.sol";
import {TestnetGuard} from "../../script/TestnetGuard.sol";
import {BaselineReporter} from "../../src/reporter/BaselineReporter.sol";
import {MockEndpoint} from "./DeployDemoOFT.t.sol";

contract DeployBaselineReporterTest is Test {
    address internal constant ENDPOINT = 0x6EDCE65403992e310A62460808c4b910D972f10f;
    uint256 internal constant ETHEREUM_SEPOLIA_CHAIN_ID = 11155111;
    uint32 internal constant ETHEREUM_SEPOLIA_EID = 40161;

    DeployBaselineReporter internal deployer;

    function setUp() public {
        deployer = new DeployBaselineReporter();
    }

    function test_run_bindsTheReporterToTheChainEndpoint() public {
        vm.chainId(ETHEREUM_SEPOLIA_CHAIN_ID);
        vm.etch(ENDPOINT, address(new MockEndpoint(ETHEREUM_SEPOLIA_EID)).code);
        vm.store(ENDPOINT, bytes32(uint256(0)), bytes32(uint256(ETHEREUM_SEPOLIA_EID)));

        BaselineReporter reporter = deployer.run();

        assertEq(address(reporter.ENDPOINT()), ENDPOINT);
    }

    function test_run_revertsOnUnsupportedChain() public {
        vm.chainId(1);
        vm.expectRevert(abi.encodeWithSelector(TestnetGuard.UnsupportedChain.selector, uint256(1)));
        deployer.run();
    }

    function test_run_revertsOnEidMismatch() public {
        vm.chainId(ETHEREUM_SEPOLIA_CHAIN_ID);
        vm.etch(ENDPOINT, address(new MockEndpoint(1)).code);
        vm.store(ENDPOINT, bytes32(uint256(0)), bytes32(uint256(1)));

        vm.expectRevert(
            abi.encodeWithSelector(TestnetGuard.EndpointEidMismatch.selector, ETHEREUM_SEPOLIA_EID, uint32(1))
        );
        deployer.run();
    }
}
