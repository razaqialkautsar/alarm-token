// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {TestHelperOz5} from "@layerzerolabs/test-devtools-evm-foundry/contracts/TestHelperOz5.sol";
import {MessagingFee} from "@layerzerolabs/oapp-evm/contracts/oapp/OAppSender.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {AttackerPeer} from "../../src/demo/AttackerPeer.sol";
import {DemoOFT} from "../../src/demo/DemoOFT.sol";

/// @notice Drill mechanics on mocked LayerZero endpoints. EID 1 plays Base, EID 2 plays chain X.
///         Not evidence of testnet behavior (that needs real drills with tx hashes).
contract AttackerPeerTest is TestHelperOz5 {
    uint32 private constant EID_BASE = 1;
    uint32 private constant EID_X = 2;
    uint256 private constant SUPPLY = 1_000 ether;
    uint128 private constant GAS = 200_000;
    /// @dev DemoOFT: 18 local decimals, 6 shared decimals.
    uint256 private constant SHARED_TO_LOCAL = 1e12;
    uint64 private constant FAKE_AMOUNT_SHARED = 500_000 * 1e6;

    DemoOFT private baseToken;
    DemoOFT private xToken;
    address private operator = makeAddr("operator");
    address private thief = makeAddr("thief");

    event FakeMintSent(uint32 indexed dstEid, address indexed recipient, uint64 amountShared, bytes32 guid);

    function setUp() public virtual override {
        super.setUp();
        setUpEndpoints(2, LibraryType.UltraLightNode);
        baseToken = DemoOFT(
            _deployOApp(
                type(DemoOFT).creationCode,
                abi.encode("Demo", "DEMO", address(endpoints[EID_BASE]), address(this), SUPPLY)
            )
        );
        xToken = DemoOFT(
            _deployOApp(
                type(DemoOFT).creationCode, abi.encode("Demo", "DEMO", address(endpoints[EID_X]), address(this), 0)
            )
        );
        address[] memory oapps = new address[](2);
        oapps[0] = address(baseToken);
        oapps[1] = address(xToken);
        this.wireOApps(oapps);
        vm.deal(operator, 10 ether);
    }

    function _attacker(uint32 eid, uint32 victimEid, address victim) internal returns (AttackerPeer attacker) {
        attacker = new AttackerPeer(address(endpoints[eid]), operator);
        vm.prank(operator);
        attacker.setPeer(victimEid, addressToBytes32(victim));
    }

    function _fire(AttackerPeer attacker, uint32 victimEid) internal {
        MessagingFee memory fee = attacker.quoteFakeMint(victimEid, thief, FAKE_AMOUNT_SHARED, GAS);
        vm.prank(operator);
        attacker.sendFakeMint{value: fee.nativeFee}(victimEid, thief, FAKE_AMOUNT_SHARED, GAS);
    }

    /// @dev Scenario (b): the Base token's peer for chain X is switched to the attacker, then fake tokens appear on Base.
    function test_scenarioB_hijackedPeerMintsOnBase() public {
        AttackerPeer attacker = _attacker(EID_X, EID_BASE, address(baseToken));
        baseToken.setPeer(EID_X, addressToBytes32(address(attacker))); // the hijack

        _fire(attacker, EID_BASE);
        verifyPackets(EID_BASE, addressToBytes32(address(baseToken)));

        uint256 minted = uint256(FAKE_AMOUNT_SHARED) * SHARED_TO_LOCAL;
        assertEq(baseToken.balanceOf(thief), minted);
        assertEq(baseToken.totalSupply(), SUPPLY + minted, "supply grew with no burn anywhere");
    }

    /// @dev Scenario (a): the chain-X token's peer for Base is switched to an attacker deployed on Base.
    function test_scenarioA_hijackedPeerMintsOnChainX() public {
        AttackerPeer attacker = _attacker(EID_BASE, EID_X, address(xToken));
        xToken.setPeer(EID_BASE, addressToBytes32(address(attacker))); // the hijack

        _fire(attacker, EID_X);
        verifyPackets(EID_X, addressToBytes32(address(xToken)));

        assertEq(xToken.balanceOf(thief), uint256(FAKE_AMOUNT_SHARED) * SHARED_TO_LOCAL);
    }

    function test_withoutTheHijack_theVictimRejectsTheMessage() public {
        AttackerPeer attacker = _attacker(EID_X, EID_BASE, address(baseToken));
        _fire(attacker, EID_BASE);

        // The Base token still trusts xToken for EID_X, so the endpoint refuses the attacker's path
        // (`allowInitializePath` is false -> LZ_PathNotInitializable, surfaced by the helper as LZ_InvalidNonce).
        vm.expectRevert();
        this.verifyPackets(EID_BASE, addressToBytes32(address(baseToken)));
        assertEq(baseToken.balanceOf(thief), 0);
    }

    function test_sendFakeMint_emitsEvent() public {
        AttackerPeer attacker = _attacker(EID_X, EID_BASE, address(baseToken));
        MessagingFee memory fee = attacker.quoteFakeMint(EID_BASE, thief, FAKE_AMOUNT_SHARED, GAS);

        vm.expectEmit(true, true, false, false, address(attacker));
        emit FakeMintSent(EID_BASE, thief, FAKE_AMOUNT_SHARED, bytes32(0));
        vm.prank(operator);
        attacker.sendFakeMint{value: fee.nativeFee}(EID_BASE, thief, FAKE_AMOUNT_SHARED, GAS);
    }

    function test_sendFakeMint_isOwnerOnly() public {
        AttackerPeer attacker = _attacker(EID_X, EID_BASE, address(baseToken));
        vm.deal(thief, 1 ether);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, thief));
        vm.prank(thief);
        attacker.sendFakeMint{value: 0}(EID_BASE, thief, FAKE_AMOUNT_SHARED, GAS);
    }

    function test_sendFakeMint_revertsOnZeroRecipientOrAmount() public {
        AttackerPeer attacker = _attacker(EID_X, EID_BASE, address(baseToken));
        vm.startPrank(operator);
        vm.expectRevert(AttackerPeer.ZeroRecipient.selector);
        attacker.sendFakeMint(EID_BASE, address(0), FAKE_AMOUNT_SHARED, GAS);
        vm.expectRevert(AttackerPeer.ZeroAmount.selector);
        attacker.sendFakeMint(EID_BASE, thief, 0, GAS);
        vm.stopPrank();
    }

    function test_quote_revertsWithoutAPeer() public {
        AttackerPeer attacker = new AttackerPeer(address(endpoints[EID_X]), operator);
        vm.expectRevert();
        attacker.quoteFakeMint(EID_BASE, thief, FAKE_AMOUNT_SHARED, GAS);
    }

    function test_drillNotice_isPublic() public {
        AttackerPeer attacker = new AttackerPeer(address(endpoints[EID_X]), operator);
        assertGt(bytes(attacker.DRILL_NOTICE()).length, 0);
    }
}
