// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {TestHelperOz5} from "@layerzerolabs/test-devtools-evm-foundry/contracts/TestHelperOz5.sol";
import {BaselineReporter} from "../../src/reporter/BaselineReporter.sol";
import {DemoOFT} from "../../src/demo/DemoOFT.sol";
import {ILayerZeroEndpointDelegates} from "../../src/interfaces/ILayerZeroEndpointDelegates.sol";

/// @dev A token that lies: it claims a fake endpoint and fake peers. The reporter must not trust `endpoint()`.
contract LyingToken {
    address public immutable FAKE_ENDPOINT;

    constructor(address fakeEndpoint) {
        FAKE_ENDPOINT = fakeEndpoint;
    }

    function endpoint() external view returns (address) {
        return FAKE_ENDPOINT;
    }

    function peers(uint32) external pure returns (bytes32) {
        return bytes32(uint256(0xBAD));
    }
}

/// @dev Answers `delegates` with an attacker-chosen address.
contract LyingEndpoint {
    function delegates(address) external pure returns (address) {
        return address(0xBAD);
    }
}

/// @notice Real EndpointV2 contracts from the LayerZero test helper (mocked message libraries). Not testnet evidence.
contract BaselineReporterTest is TestHelperOz5 {
    event Baseline(address indexed token, uint32 indexed remoteEid, bytes32 peer, address delegate);

    uint32 private constant EID_A = 1;
    uint32 private constant EID_B = 2;
    uint256 private constant SUPPLY = 1_000 ether;

    BaselineReporter private reporter;
    DemoOFT private tokenA;
    DemoOFT private tokenB;
    address private owner = makeAddr("owner");
    address private stranger = makeAddr("stranger");

    function setUp() public virtual override {
        super.setUp();
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
        this.wireOApps(oapps);
        tokenA.transferOwnership(owner);

        reporter = new BaselineReporter(address(endpoints[EID_A]));
    }

    function test_constructor_storesEndpoint() public view {
        assertEq(address(reporter.ENDPOINT()), address(endpoints[EID_A]));
    }

    function test_constructor_revertsOnZeroEndpoint() public {
        vm.expectRevert(BaselineReporter.ZeroAddress.selector);
        new BaselineReporter(address(0));
    }

    function test_constructor_revertsOnEoaEndpoint() public {
        vm.expectRevert(abi.encodeWithSelector(BaselineReporter.NotAContract.selector, stranger));
        new BaselineReporter(stranger);
    }

    function test_report_emitsPeerAndDelegate() public {
        // The OApp constructor sets the owner passed at deployment (this contract) as delegate. Transferring ownership
        // later does not change it.
        address delegate = address(this);
        assertEq(ILayerZeroEndpointDelegates(address(endpoints[EID_A])).delegates(address(tokenA)), delegate);

        vm.expectEmit(true, true, false, true, address(reporter));
        emit Baseline(address(tokenA), EID_B, addressToBytes32(address(tokenB)), delegate);
        (bytes32 peer, address returnedDelegate) = reporter.report(address(tokenA), EID_B);

        assertEq(peer, addressToBytes32(address(tokenB)));
        assertEq(returnedDelegate, delegate);
    }

    function test_report_isPermissionless() public {
        vm.prank(stranger);
        (bytes32 peer,) = reporter.report(address(tokenA), EID_B);
        assertEq(peer, addressToBytes32(address(tokenB)));
    }

    function test_report_reportsZeroPeerWhenNoneIsSet() public {
        (bytes32 peer,) = reporter.report(address(tokenA), 99);
        assertEq(peer, bytes32(0));
    }

    function test_report_followsLaterChanges() public {
        address newPeer = makeAddr("newPeer");
        address newDelegate = makeAddr("newDelegate");
        vm.startPrank(owner);
        tokenA.setPeer(EID_B, addressToBytes32(newPeer));
        tokenA.setDelegate(newDelegate);
        vm.stopPrank();

        (bytes32 peer, address delegate) = reporter.report(address(tokenA), EID_B);

        assertEq(peer, addressToBytes32(newPeer));
        assertEq(delegate, newDelegate);
    }

    function test_report_revertsOnZeroToken() public {
        vm.expectRevert(BaselineReporter.ZeroAddress.selector);
        reporter.report(address(0), EID_B);
    }

    function test_report_revertsOnEoaToken() public {
        vm.expectRevert(abi.encodeWithSelector(BaselineReporter.NotAContract.selector, stranger));
        reporter.report(stranger, EID_B);
    }

    function test_report_revertsWhenTheTokenClaimsAnotherEndpoint() public {
        // A token that points at a lying endpoint is rejected instead of producing a baseline.
        address fakeEndpoint = address(new LyingEndpoint());
        LyingToken liar = new LyingToken(fakeEndpoint);

        vm.expectRevert(abi.encodeWithSelector(BaselineReporter.WrongEndpoint.selector, address(liar), fakeEndpoint));
        reporter.report(address(liar), EID_B);
    }

    function test_report_revertsForATokenOnAnotherChainsEndpoint() public {
        // tokenB lives on endpoint B; this reporter is bound to endpoint A.
        vm.expectRevert(
            abi.encodeWithSelector(BaselineReporter.WrongEndpoint.selector, address(tokenB), address(endpoints[EID_B]))
        );
        reporter.report(address(tokenB), EID_A);
    }

    function test_report_readsTheDelegateFromItsOwnEndpointOnly() public {
        // The token claims the reporter's endpoint, so it passes the filter. Its delegate must still be the one the
        // real endpoint holds (none), not anything the token could report.
        LyingToken liar = new LyingToken(address(endpoints[EID_A]));

        (bytes32 peer, address delegate) = reporter.report(address(liar), EID_B);

        assertEq(peer, bytes32(uint256(0xBAD)), "peer is the token's own answer");
        assertEq(delegate, address(0), "delegate comes from the real endpoint, which has none for this token");
    }

    function testFuzz_report_matchesCurrentState(uint32 eid, bytes32 peer, address delegate) public {
        vm.assume(delegate != address(0));
        vm.startPrank(owner);
        tokenA.setPeer(eid, peer);
        tokenA.setDelegate(delegate);
        vm.stopPrank();

        (bytes32 gotPeer, address gotDelegate) = reporter.report(address(tokenA), eid);

        assertEq(gotPeer, peer);
        assertEq(gotDelegate, delegate);
    }
}
