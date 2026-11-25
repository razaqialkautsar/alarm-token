// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {Test} from "forge-std/Test.sol";
import {WireDemoOFT} from "../../script/WireDemoOFT.s.sol";
import {DemoOFT} from "../../src/demo/DemoOFT.sol";
import {MockEndpoint} from "./DeployDemoOFT.t.sol";

contract WireDemoOFTTest is Test {
    address internal constant ENDPOINT = 0x6EDCE65403992e310A62460808c4b910D972f10f;
    uint256 internal constant BASE_SEPOLIA_CHAIN_ID = 84532;
    uint32 internal constant BASE_SEPOLIA_EID = 40245;
    uint32 internal constant ETHEREUM_SEPOLIA_EID = 40161;
    uint32 internal constant UNKNOWN_EID = 1;
    address internal constant REMOTE_OFT = address(0xBEEF);

    WireDemoOFT internal wirer;
    DemoOFT internal token;

    function setUp() public {
        wirer = new WireDemoOFT();
        vm.chainId(BASE_SEPOLIA_CHAIN_ID);
        vm.etch(ENDPOINT, address(new MockEndpoint(BASE_SEPOLIA_EID)).code);
        vm.store(ENDPOINT, bytes32(uint256(0)), bytes32(uint256(BASE_SEPOLIA_EID)));
        // The script signs as the default sender inside tests, so the token must be owned by that account.
        (, address signer,) = vm.readCallers();
        token = new DemoOFT("Demo", "DEMO", ENDPOINT, signer, 0);
    }

    function test_wire_setsPeer() public {
        wirer.wire(address(token), ETHEREUM_SEPOLIA_EID, REMOTE_OFT);

        assertEq(token.peers(ETHEREUM_SEPOLIA_EID), bytes32(uint256(uint160(REMOTE_OFT))));
    }

    function test_wire_isIdempotent() public {
        wirer.wire(address(token), ETHEREUM_SEPOLIA_EID, REMOTE_OFT);

        vm.recordLogs();
        wirer.wire(address(token), ETHEREUM_SEPOLIA_EID, REMOTE_OFT);

        assertEq(vm.getRecordedLogs().length, 0, "no PeerSet on a repeat run");
    }

    function test_wire_revertsOnSameChainPeer() public {
        vm.expectRevert(abi.encodeWithSelector(WireDemoOFT.SameChainPeer.selector, BASE_SEPOLIA_EID));
        wirer.wire(address(token), BASE_SEPOLIA_EID, REMOTE_OFT);
    }

    function test_wire_revertsOnUnknownRemoteEid() public {
        vm.expectRevert(abi.encodeWithSelector(WireDemoOFT.RemoteEidNotAllowed.selector, UNKNOWN_EID));
        wirer.wire(address(token), UNKNOWN_EID, REMOTE_OFT);
    }

    function test_wire_revertsOnZeroRemote() public {
        vm.expectRevert(WireDemoOFT.ZeroAddress.selector);
        wirer.wire(address(token), ETHEREUM_SEPOLIA_EID, address(0));
    }

    function test_wire_revertsWhenSignerIsNotOwner() public {
        address otherOwner = address(0xB0B);
        vm.prank(token.owner());
        token.transferOwnership(otherOwner);

        (, address signer,) = vm.readCallers();
        vm.expectRevert(abi.encodeWithSelector(WireDemoOFT.NotOwner.selector, signer, otherOwner));
        wirer.wire(address(token), ETHEREUM_SEPOLIA_EID, REMOTE_OFT);
    }
}
