// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {TestHelperOz5} from "@layerzerolabs/test-devtools-evm-foundry/contracts/TestHelperOz5.sol";
import {SendDemoOFT} from "../../script/SendDemoOFT.s.sol";
import {TestnetGuard} from "../../script/TestnetGuard.sol";
import {DemoOFT} from "../../src/demo/DemoOFT.sol";
import {MockEndpoint} from "./DeployDemoOFT.t.sol";

/// @dev Skips the route check so the script's send logic runs against mocked LayerZero endpoints (EIDs 1 and 2).
contract SendHarness is SendDemoOFT {
    function _validateRoute(DemoOFT, uint32) internal view override {}
}

/// @notice Mocked endpoints only: this is not evidence of testnet delivery (that is gate G2).
contract SendDemoOFTTest is TestHelperOz5 {
    uint32 private constant EID_A = 1;
    uint32 private constant EID_B = 2;
    uint256 private constant SUPPLY = 1_000 ether;
    uint128 private constant GAS = 200_000;
    uint256 private constant NATIVE = 10 ether;

    address private constant MOCK_ENDPOINT = 0x6EDCE65403992e310A62460808c4b910D972f10f;
    uint256 private constant BASE_SEPOLIA_CHAIN_ID = 84532;
    uint32 private constant BASE_SEPOLIA_EID = 40245;
    uint32 private constant ETHEREUM_SEPOLIA_EID = 40161;

    SendHarness private harness;
    SendDemoOFT private script;
    DemoOFT private tokenA;
    DemoOFT private tokenB;
    address private signer;
    address private recipient = makeAddr("recipient");

    function setUp() public virtual override {
        super.setUp();
        (, signer,) = vm.readCallers();
        setUpEndpoints(2, LibraryType.UltraLightNode);

        tokenA = DemoOFT(
            _deployOApp(
                type(DemoOFT).creationCode, abi.encode("Demo", "DEMO", address(endpoints[EID_A]), address(this), SUPPLY)
            )
        );
        tokenB = DemoOFT(
            _deployOApp(
                type(DemoOFT).creationCode, abi.encode("Demo", "DEMO", address(endpoints[EID_B]), address(this), 0)
            )
        );
        address[] memory oapps = new address[](2);
        oapps[0] = address(tokenA);
        oapps[1] = address(tokenB);
        // wireOApps calls setPeer as this contract, so it owns the tokens until wiring is done.
        this.wireOApps(oapps);
        assertTrue(tokenA.transfer(signer, SUPPLY));
        tokenA.transferOwnership(signer);
        tokenB.transferOwnership(signer);

        harness = new SendHarness();
        vm.deal(signer, NATIVE);
    }

    function test_send_deliversToTheSignerByDefault() public {
        harness.send(address(tokenA), EID_B, address(0), 10, GAS);
        verifyPackets(EID_B, addressToBytes32(address(tokenB)));

        assertEq(tokenA.balanceOf(signer), SUPPLY - 10 ether);
        assertEq(tokenB.balanceOf(signer), 10 ether);
    }

    function test_send_deliversToAnotherRecipient() public {
        harness.send(address(tokenA), EID_B, recipient, 5, GAS);
        verifyPackets(EID_B, addressToBytes32(address(tokenB)));

        assertEq(tokenB.balanceOf(recipient), 5 ether);
    }

    function test_send_revertsOnZeroAmount() public {
        vm.expectRevert(SendDemoOFT.ZeroAmount.selector);
        harness.send(address(tokenA), EID_B, address(0), 0, GAS);
    }

    function test_send_revertsWhenPeerNotSet() public {
        vm.expectRevert(abi.encodeWithSelector(SendDemoOFT.PeerNotSet.selector, uint32(99)));
        harness.send(address(tokenA), 99, address(0), 1, GAS);
    }

    function test_send_revertsWhenSignerLacksTokens() public {
        vm.expectRevert(abi.encodeWithSelector(SendDemoOFT.InsufficientTokens.selector, SUPPLY, SUPPLY + 1 ether));
        harness.send(address(tokenA), EID_B, address(0), 1_001, GAS);
    }

    function test_send_revertsWhenSignerLacksNativeForTheFee() public {
        vm.deal(signer, 0);
        vm.expectRevert();
        harness.send(address(tokenA), EID_B, address(0), 1, GAS);
    }

    // --- Route guard, using the real script and a mocked endpoint at the Base Sepolia endpoint address ---

    function _tokenOnMockEndpoint() internal returns (DemoOFT token) {
        script = new SendDemoOFT();
        vm.chainId(BASE_SEPOLIA_CHAIN_ID);
        vm.etch(MOCK_ENDPOINT, address(new MockEndpoint(BASE_SEPOLIA_EID)).code);
        token = new DemoOFT("Demo", "DEMO", MOCK_ENDPOINT, signer, SUPPLY);
        vm.prank(signer);
        token.setPeer(ETHEREUM_SEPOLIA_EID, bytes32(uint256(1)));
    }

    function test_route_revertsOnUnsupportedChain() public {
        DemoOFT token = _tokenOnMockEndpoint();
        vm.chainId(1);
        vm.expectRevert(abi.encodeWithSelector(TestnetGuard.UnsupportedChain.selector, uint256(1)));
        script.send(address(token), ETHEREUM_SEPOLIA_EID, address(0), 1, GAS);
    }

    function test_route_revertsOnSameChain() public {
        DemoOFT token = _tokenOnMockEndpoint();
        vm.expectRevert(abi.encodeWithSelector(SendDemoOFT.SameChainRoute.selector, BASE_SEPOLIA_EID));
        script.send(address(token), BASE_SEPOLIA_EID, address(0), 1, GAS);
    }

    function test_route_revertsOnUnknownDestination() public {
        DemoOFT token = _tokenOnMockEndpoint();
        vm.expectRevert(abi.encodeWithSelector(SendDemoOFT.DstEidNotAllowed.selector, uint32(7)));
        script.send(address(token), 7, address(0), 1, GAS);
    }

    function test_route_revertsWhenTokenUsesAnotherEndpoint() public {
        _tokenOnMockEndpoint();
        // A token on a different endpoint address than the one this chain should use.
        address other = address(new MockEndpoint(BASE_SEPOLIA_EID));
        DemoOFT token = new DemoOFT("Demo", "DEMO", other, signer, SUPPLY);

        vm.expectRevert(abi.encodeWithSelector(SendDemoOFT.WrongEndpointForChain.selector, other, MOCK_ENDPOINT));
        script.send(address(token), ETHEREUM_SEPOLIA_EID, address(0), 1, GAS);
    }
}
