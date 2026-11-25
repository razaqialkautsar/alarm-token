// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {Test} from "forge-std/Test.sol";
import {DeployDemoOFT} from "../../script/DeployDemoOFT.s.sol";
import {TestnetGuard} from "../../script/TestnetGuard.sol";
import {DemoOFT} from "../../src/demo/DemoOFT.sol";

/// @dev Stands in for EndpointV2 at the real address: answers `eid()` and accepts `setDelegate` from the OApp constructor.
contract MockEndpoint {
    uint32 public eid;

    constructor(uint32 eid_) {
        eid = eid_;
    }

    function setDelegate(address) external {}
}

contract DeployDemoOFTTest is Test {
    address internal constant ENDPOINT = 0x6EDCE65403992e310A62460808c4b910D972f10f;
    address internal constant UNICHAIN_ENDPOINT = 0xb8815f3f882614048CbE201a67eF9c6F10fe5035;
    uint256 internal constant UNICHAIN_SEPOLIA_CHAIN_ID = 1301;
    uint32 internal constant UNICHAIN_SEPOLIA_EID = 40333;
    uint256 internal constant BASE_SEPOLIA_CHAIN_ID = 84532;
    uint256 internal constant ETHEREUM_SEPOLIA_CHAIN_ID = 11155111;
    uint256 internal constant MAINNET_CHAIN_ID = 1;
    uint32 internal constant BASE_SEPOLIA_EID = 40245;
    uint32 internal constant ETHEREUM_SEPOLIA_EID = 40161;
    uint256 internal constant DEFAULT_SUPPLY = 1_000_000 ether;

    DeployDemoOFT internal deployer;

    function setUp() public {
        deployer = new DeployDemoOFT();
    }

    function _etchEndpoint(uint32 eid) internal {
        vm.etch(ENDPOINT, address(new MockEndpoint(eid)).code);
        // Code is copied without storage, so write `eid` (slot 0) directly.
        vm.store(ENDPOINT, bytes32(uint256(0)), bytes32(uint256(eid)));
    }

    function test_run_deploysOnBaseSepolia() public {
        vm.chainId(BASE_SEPOLIA_CHAIN_ID);
        _etchEndpoint(BASE_SEPOLIA_EID);

        DemoOFT token = deployer.run();

        assertEq(address(token.endpoint()), ENDPOINT);
        assertEq(token.totalSupply(), DEFAULT_SUPPLY);
        assertTrue(token.owner() != address(0));
        assertEq(token.balanceOf(token.owner()), DEFAULT_SUPPLY);
    }

    function test_run_deploysOnEthereumSepolia() public {
        vm.chainId(ETHEREUM_SEPOLIA_CHAIN_ID);
        _etchEndpoint(ETHEREUM_SEPOLIA_EID);

        DemoOFT token = deployer.run();

        assertEq(token.totalSupply(), DEFAULT_SUPPLY);
    }

    function test_run_deploysOnUnichainSepoliaWithItsOwnEndpoint() public {
        vm.chainId(UNICHAIN_SEPOLIA_CHAIN_ID);
        vm.etch(UNICHAIN_ENDPOINT, address(new MockEndpoint(UNICHAIN_SEPOLIA_EID)).code);
        vm.store(UNICHAIN_ENDPOINT, bytes32(uint256(0)), bytes32(uint256(UNICHAIN_SEPOLIA_EID)));

        DemoOFT token = deployer.run();

        assertEq(address(token.endpoint()), UNICHAIN_ENDPOINT);
    }

    function test_run_revertsOnUnichainWhenOnlyTheBaseEndpointExists() public {
        // The Base/Ethereum endpoint address has no code on Unichain Sepolia, so the guard must refuse to deploy.
        vm.chainId(UNICHAIN_SEPOLIA_CHAIN_ID);
        _etchEndpoint(UNICHAIN_SEPOLIA_EID);
        vm.etch(UNICHAIN_ENDPOINT, "");

        vm.expectRevert(abi.encodeWithSelector(TestnetGuard.EndpointMissing.selector, UNICHAIN_ENDPOINT));
        deployer.run();
    }

    function test_run_revertsOnUnsupportedChain() public {
        vm.chainId(MAINNET_CHAIN_ID);
        _etchEndpoint(BASE_SEPOLIA_EID);

        vm.expectRevert(abi.encodeWithSelector(TestnetGuard.UnsupportedChain.selector, MAINNET_CHAIN_ID));
        deployer.run();
    }

    function test_run_revertsWhenEndpointMissing() public {
        vm.chainId(BASE_SEPOLIA_CHAIN_ID);
        vm.etch(ENDPOINT, "");

        vm.expectRevert(abi.encodeWithSelector(TestnetGuard.EndpointMissing.selector, ENDPOINT));
        deployer.run();
    }

    function test_run_revertsOnEidMismatch() public {
        vm.chainId(BASE_SEPOLIA_CHAIN_ID);
        _etchEndpoint(ETHEREUM_SEPOLIA_EID);

        vm.expectRevert(
            abi.encodeWithSelector(TestnetGuard.EndpointEidMismatch.selector, BASE_SEPOLIA_EID, ETHEREUM_SEPOLIA_EID)
        );
        deployer.run();
    }
}
