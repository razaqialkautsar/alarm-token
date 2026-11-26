// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {Test} from "forge-std/Test.sol";
import {DeploymentRecorder} from "../../script/DeploymentRecorder.sol";

/// @dev Writes to cache/test-deployments instead of deployments/, and exposes the internals.
contract RecorderHarness is DeploymentRecorder {
    function _path(uint256 chainId) internal view override returns (string memory) {
        return string.concat(vm.projectRoot(), "/cache/test-deployments/", _chainName(chainId), ".json");
    }

    function path(uint256 chainId) external view returns (string memory) {
        return _path(chainId);
    }

    function write(uint256 chainId, string memory name, address addr) external {
        _write(chainId, name, addr);
    }

    function record(string memory name, address addr) external {
        _record(name, addr);
    }

    function chainName(uint256 chainId) external pure returns (string memory) {
        return _chainName(chainId);
    }
}

contract DeploymentRecorderTest is Test {
    uint256 internal constant BASE_SEPOLIA_CHAIN_ID = 84532;
    uint256 internal constant ETHEREUM_SEPOLIA_CHAIN_ID = 11155111;

    RecorderHarness internal recorder;

    uint256 internal constant UNICHAIN_SEPOLIA_CHAIN_ID = 1301;

    function setUp() public {
        recorder = new RecorderHarness();
        // CI starts without a cache directory. Each test uses its own chain file because tests run in parallel.
        vm.createDir(string.concat(vm.projectRoot(), "/cache/test-deployments"), true);
    }

    function _fresh(uint256 chainId) internal returns (string memory file) {
        file = recorder.path(chainId);
        if (vm.exists(file)) vm.removeFile(file);
    }

    function test_write_createsTheFileWithChainIdAndAddress() public {
        string memory file = _fresh(ETHEREUM_SEPOLIA_CHAIN_ID);
        recorder.write(ETHEREUM_SEPOLIA_CHAIN_ID, "DemoOFT", address(0xBEEF));

        string memory json = vm.readFile(file);
        assertEq(vm.parseJsonUint(json, ".chainId"), ETHEREUM_SEPOLIA_CHAIN_ID);
        assertEq(vm.parseJsonAddress(json, ".contracts.DemoOFT.address"), address(0xBEEF));
    }

    function test_write_keepsOtherEntriesAndOverwritesTheSameName() public {
        _fresh(BASE_SEPOLIA_CHAIN_ID);
        recorder.write(BASE_SEPOLIA_CHAIN_ID, "DemoOFT", address(0xBEEF));
        recorder.write(BASE_SEPOLIA_CHAIN_ID, "Pool", address(0xCAFE));
        recorder.write(BASE_SEPOLIA_CHAIN_ID, "DemoOFT", address(0xF00D));

        string memory json = vm.readFile(recorder.path(BASE_SEPOLIA_CHAIN_ID));
        assertEq(vm.parseJsonAddress(json, ".contracts.DemoOFT.address"), address(0xF00D));
        assertEq(vm.parseJsonAddress(json, ".contracts.Pool.address"), address(0xCAFE));
    }

    function test_record_doesNotWriteOutsideABroadcast() public {
        string memory file = _fresh(UNICHAIN_SEPOLIA_CHAIN_ID);
        vm.chainId(UNICHAIN_SEPOLIA_CHAIN_ID);
        recorder.record("DemoOFT", address(0xBEEF));

        assertFalse(vm.exists(file));
    }

    function test_chainName_coversEveryTestnet() public view {
        assertEq(recorder.chainName(84532), "base-sepolia");
        assertEq(recorder.chainName(ETHEREUM_SEPOLIA_CHAIN_ID), "ethereum-sepolia");
        assertEq(recorder.chainName(1301), "unichain-sepolia");
        assertEq(recorder.chainName(5318007), "reactive-lasna");
    }

    function test_chainName_revertsOnMainnet() public {
        vm.expectRevert(abi.encodeWithSelector(DeploymentRecorder.NoDeploymentFileForChain.selector, uint256(1)));
        recorder.chainName(1);
    }
}
