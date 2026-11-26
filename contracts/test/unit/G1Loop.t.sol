// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {Test, Vm} from "forge-std/Test.sol";
import {ISystemContract} from "@reactive/src/interfaces/ISystemContract.sol";
import {IReactive} from "@reactive/src/interfaces/IReactive.sol";
import {AbstractPayer} from "@reactive/src/base/AbstractPayer.sol";
import {AbstractCallback} from "@reactive/src/base/AbstractCallback.sol";
import {G1Reactive} from "../../src/gates/G1Reactive.sol";
import {G1Receiver} from "../../src/gates/G1Receiver.sol";
import {BaselineReporter} from "../../src/reporter/BaselineReporter.sol";

/// @notice Stand-in for the Reactive system contract. Etched at 0x8888...8888; records what the reactive contract asks.
contract MockSystem {
    struct Sub {
        uint256 chainId;
        address emitter;
        uint256 topic0;
        uint256 topic1;
        uint256 topic2;
        uint256 topic3;
    }

    Sub[] public subs;
    Sub[] public unsubs;
    ISystemContract.CallbackConfiguration_V_1_0[] internal requests;

    function subscribe(uint256 c, address e, uint256 t0, uint256 t1, uint256 t2, uint256 t3) external {
        subs.push(Sub(c, e, t0, t1, t2, t3));
    }

    function unsubscribe(uint256 c, address e, uint256 t0, uint256 t1, uint256 t2, uint256 t3) external {
        unsubs.push(Sub(c, e, t0, t1, t2, t3));
    }

    function requestCallbackV_1_0(ISystemContract.CallbackConfiguration_V_1_0 memory config) external {
        requests.push(config);
    }

    function debt(address) external pure returns (uint256) {
        return 0;
    }

    function subCount() external view returns (uint256) {
        return subs.length;
    }

    function unsubCount() external view returns (uint256) {
        return unsubs.length;
    }

    function requestCount() external view returns (uint256) {
        return requests.length;
    }

    function request(uint256 i) external view returns (ISystemContract.CallbackConfiguration_V_1_0 memory) {
        return requests[i];
    }

    receive() external payable {}
}

contract G1LoopTest is Test {
    address internal constant SYSTEM = 0x8888888888888888888888888888888888888888;
    uint256 internal constant REACTIVE_IGNORE = 0xa65f96fc951c35ead38878e0f0b7a3c744a6f5ccc1476b313353ce31712313ad;
    uint256 internal constant BASE_SEPOLIA = 84532;
    uint256 internal constant ETH_SEPOLIA = 11155111;
    uint32 internal constant BASE_EID = 40245;

    address internal proxy = makeAddr("callbackProxy");
    address internal reporter = makeAddr("baselineReporter");
    address internal token = makeAddr("chainXToken");

    MockSystem internal sys;
    G1Reactive internal reactive;
    G1Receiver internal receiver;

    function setUp() public {
        vm.etch(SYSTEM, address(new MockSystem()).code);
        sys = MockSystem(payable(SYSTEM));

        reactive = new G1Reactive();
        receiver = new G1Receiver(proxy, address(reactive));
        reactive.configure(BASE_SEPOLIA, address(receiver), ETH_SEPOLIA, reporter);
    }

    // ---------------------------------------------------------------- helpers

    function _log(
        uint256 chainId,
        address emitter,
        uint256 opCode,
        uint256 t0,
        uint256 t1,
        uint256 t2,
        bytes memory data
    ) internal pure returns (IReactive.LogRecord memory log) {
        log.chainId = chainId;
        log.contractAddress = emitter;
        log.opCode = opCode;
        log.topic0 = t0;
        log.topic1 = t1;
        log.topic2 = t2;
        log.data = data;
        log.txHash = uint256(keccak256(abi.encode(t0, data)));
    }

    function _fromVmLog(Vm.Log memory l) internal pure returns (IReactive.LogRecord memory log) {
        log.chainId = BASE_SEPOLIA;
        log.contractAddress = l.emitter;
        log.opCode = l.topics.length;
        log.topic0 = uint256(l.topics[0]);
        if (l.topics.length > 1) log.topic1 = uint256(l.topics[1]);
        if (l.topics.length > 2) log.topic2 = uint256(l.topics[2]);
        log.data = l.data;
    }

    function _react(IReactive.LogRecord memory log) internal {
        vm.prank(SYSTEM);
        reactive.react(log);
    }

    /// @dev Delivers request `i` the way the callback proxy does: first argument replaced by the reactive address.
    function _deliver(uint256 i) internal {
        ISystemContract.CallbackConfiguration_V_1_0 memory r = sys.request(i);
        bytes memory payload = r.payload;
        bytes32 rvm = bytes32(uint256(uint160(address(reactive))));
        assembly {
            mstore(add(payload, 36), rvm)
        }
        vm.prank(proxy);
        (bool ok, bytes memory err) = r.recipient.call(payload);
        if (!ok) {
            assembly {
                revert(add(err, 32), mload(err))
            }
        }
    }

    function _assertSub(MockSystem.Sub memory s, uint256 chainId, address emitter, uint256 t0, uint256 t1)
        internal
        pure
    {
        assertEq(s.chainId, chainId);
        assertEq(s.emitter, emitter);
        assertEq(s.topic0, t0);
        assertEq(s.topic1, t1);
        assertEq(s.topic2, REACTIVE_IGNORE);
        assertEq(s.topic3, REACTIVE_IGNORE);
    }

    function _sub(uint256 i) internal view returns (MockSystem.Sub memory s) {
        (s.chainId, s.emitter, s.topic0, s.topic1, s.topic2, s.topic3) = sys.subs(i);
    }

    function _unsub(uint256 i) internal view returns (MockSystem.Sub memory s) {
        (s.chainId, s.emitter, s.topic0, s.topic1, s.topic2, s.topic3) = sys.unsubs(i);
    }

    // ---------------------------------------------------------------- topics

    function test_topics_matchReceiverAndReporterEvents() public view {
        assertEq(bytes32(reactive.PING_TOPIC0()), G1Receiver.Ping.selector);
        assertEq(bytes32(reactive.PROGRESS_TOPIC0()), G1Receiver.Progress.selector);
        assertEq(bytes32(reactive.WATCH_TOPIC0()), G1Receiver.Watch.selector);
        assertEq(bytes32(reactive.BASELINE_TOPIC0()), BaselineReporter.Baseline.selector);
    }

    // ---------------------------------------------------------------- configure

    function test_configure_subscribesToReceiverEvents() public view {
        assertEq(sys.subCount(), 3);
        _assertSub(_sub(0), BASE_SEPOLIA, address(receiver), reactive.PING_TOPIC0(), REACTIVE_IGNORE);
        _assertSub(_sub(1), BASE_SEPOLIA, address(receiver), reactive.PROGRESS_TOPIC0(), REACTIVE_IGNORE);
        _assertSub(_sub(2), BASE_SEPOLIA, address(receiver), reactive.WATCH_TOPIC0(), REACTIVE_IGNORE);
    }

    function test_configure_onlyOnce() public {
        vm.expectRevert(G1Reactive.AlreadyConfigured.selector);
        reactive.configure(BASE_SEPOLIA, address(receiver), ETH_SEPOLIA, reporter);
    }

    function test_configure_onlyOwner() public {
        G1Reactive fresh = new G1Reactive();
        address stranger = makeAddr("stranger");
        vm.expectRevert(abi.encodeWithSelector(G1Reactive.NotOwner.selector, stranger));
        vm.prank(stranger);
        fresh.configure(BASE_SEPOLIA, address(receiver), ETH_SEPOLIA, reporter);
    }

    function test_configure_rejectsZeroValues() public {
        G1Reactive fresh = new G1Reactive();
        vm.expectRevert(G1Reactive.ZeroValue.selector);
        fresh.configure(0, address(receiver), ETH_SEPOLIA, reporter);
        vm.expectRevert(G1Reactive.ZeroValue.selector);
        fresh.configure(BASE_SEPOLIA, address(0), ETH_SEPOLIA, reporter);
        vm.expectRevert(G1Reactive.ZeroValue.selector);
        fresh.configure(BASE_SEPOLIA, address(receiver), 0, reporter);
        vm.expectRevert(G1Reactive.ZeroValue.selector);
        fresh.configure(BASE_SEPOLIA, address(receiver), ETH_SEPOLIA, address(0));
    }

    function test_constructor_acceptsFunding() public {
        G1Reactive funded = new G1Reactive{value: 1 ether}();
        assertEq(address(funded).balance, 1 ether);
    }

    // ---------------------------------------------------------------- react: access and rounds

    function test_react_rejectsNonSystemCaller() public {
        IReactive.LogRecord memory log;
        address stranger = makeAddr("stranger");
        vm.expectRevert(abi.encodeWithSelector(AbstractPayer.NotAuthorized.selector, stranger, SYSTEM));
        vm.prank(stranger);
        reactive.react(log);
    }

    function test_react_pingRequestsOnRoundCallback() public {
        _react(_log(BASE_SEPOLIA, address(receiver), 1, reactive.PING_TOPIC0(), 0, 0, abi.encode(uint256(3))));

        assertEq(sys.requestCount(), 1);
        ISystemContract.CallbackConfiguration_V_1_0 memory r = sys.request(0);
        assertEq(r.chainId, BASE_SEPOLIA);
        assertEq(r.recipient, address(receiver));
        assertEq(r.gasLimit, reactive.CALLBACK_GAS_LIMIT());
        assertGe(r.gasLimit, 100_000);
        assertEq(r.payload, abi.encodeCall(G1Receiver.onRound, (address(0), uint256(3))));
    }

    function test_react_progressRequestsOnRoundCallback() public {
        _react(_log(BASE_SEPOLIA, address(receiver), 1, reactive.PROGRESS_TOPIC0(), 0, 0, abi.encode(uint256(2))));
        assertEq(sys.request(0).payload, abi.encodeCall(G1Receiver.onRound, (address(0), uint256(2))));
    }

    function test_react_ignoresPingWithWrongShape() public {
        uint256 ping = reactive.PING_TOPIC0();
        _react(_log(BASE_SEPOLIA, address(receiver), 2, ping, 0, 0, abi.encode(uint256(3)))); // wrong topic count
        _react(_log(BASE_SEPOLIA, address(receiver), 1, ping, 0, 0, hex"01")); // short data
        _react(_log(BASE_SEPOLIA, makeAddr("other"), 1, ping, 0, 0, abi.encode(uint256(3)))); // other emitter
        _react(_log(ETH_SEPOLIA, address(receiver), 1, ping, 0, 0, abi.encode(uint256(3)))); // other chain
        assertEq(sys.requestCount(), 0);
    }

    // ---------------------------------------------------------------- react: dynamic Baseline subscription

    function _watchLog(address t) internal view returns (IReactive.LogRecord memory) {
        return _log(BASE_SEPOLIA, address(receiver), 2, reactive.WATCH_TOPIC0(), uint256(uint160(t)), 0, "");
    }

    function _baselineLog(address t, bytes32 peer, uint256 delegateWord)
        internal
        view
        returns (IReactive.LogRecord memory)
    {
        return _log(
            ETH_SEPOLIA,
            reporter,
            3,
            reactive.BASELINE_TOPIC0(),
            uint256(uint160(t)),
            BASE_EID,
            abi.encode(peer, delegateWord)
        );
    }

    function test_react_watchSubscribesToBaselineForToken() public {
        _react(_watchLog(token));

        assertTrue(reactive.watching(token));
        assertEq(sys.subCount(), 4);
        _assertSub(_sub(3), ETH_SEPOLIA, reporter, reactive.BASELINE_TOPIC0(), uint256(uint160(token)));
    }

    function test_react_watchTwiceSubscribesOnce() public {
        _react(_watchLog(token));
        _react(_watchLog(token));
        assertEq(sys.subCount(), 4);
    }

    function test_react_watchIgnoresZeroToken() public {
        _react(_watchLog(address(0)));
        assertEq(sys.subCount(), 3);
    }

    function test_react_baselineForwardsAndUnsubscribesWithSameArguments() public {
        _react(_watchLog(token));
        bytes32 peer = bytes32(uint256(0xBEEF));
        address delegate = makeAddr("delegate");
        _react(_baselineLog(token, peer, uint256(uint160(delegate))));

        assertFalse(reactive.watching(token));
        assertEq(sys.unsubCount(), 1);
        MockSystem.Sub memory s = _sub(3);
        MockSystem.Sub memory u = _unsub(0);
        assertEq(keccak256(abi.encode(s)), keccak256(abi.encode(u)));

        assertEq(sys.requestCount(), 1);
        assertEq(
            sys.request(0).payload, abi.encodeCall(G1Receiver.onBaseline, (address(0), token, BASE_EID, peer, delegate))
        );
    }

    function test_react_baselineAfterFirstIsIgnored() public {
        _react(_watchLog(token));
        _react(_baselineLog(token, bytes32(uint256(1)), 1));
        _react(_baselineLog(token, bytes32(uint256(2)), 2));
        assertEq(sys.requestCount(), 1);
        assertEq(sys.unsubCount(), 1);
    }

    function test_react_baselineForUnwatchedTokenIsIgnored() public {
        _react(_baselineLog(token, bytes32(uint256(1)), 1));
        assertEq(sys.requestCount(), 0);
        assertEq(sys.unsubCount(), 0);
    }

    function test_react_baselineWithDirtyDelegateWordDoesNotRevert() public {
        _react(_watchLog(token));
        _react(_baselineLog(token, bytes32(uint256(1)), type(uint256).max));
        assertEq(sys.requestCount(), 1);
    }

    /// @dev react() must never revert on input it does not recognise (reverts are charged in full).
    function testFuzz_react_neverRevertsOnArbitraryLogs(
        bool fromReceiver,
        uint256 opCode,
        uint8 topicChoice,
        uint256 topic1,
        uint256 topic2,
        bytes calldata data
    ) public {
        uint256[5] memory topics = [
            reactive.PING_TOPIC0(),
            reactive.PROGRESS_TOPIC0(),
            reactive.WATCH_TOPIC0(),
            reactive.BASELINE_TOPIC0(),
            uint256(keccak256("Other()"))
        ];
        IReactive.LogRecord memory log = _log(
            fromReceiver ? BASE_SEPOLIA : ETH_SEPOLIA,
            fromReceiver ? address(receiver) : reporter,
            opCode,
            topics[topicChoice % 5],
            topic1,
            topic2,
            data
        );
        _react(log);
    }

    // ---------------------------------------------------------------- receiver

    function test_receiver_onRoundRejectsNonProxy() public {
        vm.expectRevert(abi.encodeWithSelector(AbstractPayer.NotAuthorized.selector, address(this), proxy));
        receiver.onRound(address(reactive), 1);
    }

    function test_receiver_onRoundRejectsWrongReactiveSender() public {
        address fake = makeAddr("fakeReactive");
        vm.expectRevert(
            abi.encodeWithSelector(AbstractCallback.CallbackNotAuthorized.selector, fake, address(reactive))
        );
        vm.prank(proxy);
        receiver.onRound(fake, 1);
    }

    function test_receiver_onBaselineRejectsWrongReactiveSender() public {
        address fake = makeAddr("fakeReactive");
        vm.expectRevert(
            abi.encodeWithSelector(AbstractCallback.CallbackNotAuthorized.selector, fake, address(reactive))
        );
        vm.prank(proxy);
        receiver.onBaseline(fake, token, BASE_EID, bytes32(0), address(0));
    }

    function test_receiver_onRoundEmitsProgressOnlyWhileRoundsLeft() public {
        vm.recordLogs();
        vm.prank(proxy);
        receiver.onRound(address(reactive), 2);
        vm.prank(proxy);
        receiver.onRound(address(reactive), 1);
        Vm.Log[] memory logs = vm.getRecordedLogs();

        uint256 progress;
        for (uint256 i; i < logs.length; i++) {
            if (logs[i].topics[0] == G1Receiver.Progress.selector) {
                progress++;
                assertEq(abi.decode(logs[i].data, (uint256)), 1);
            }
        }
        assertEq(progress, 1);
        assertEq(receiver.roundsReceived(), 2);
    }

    function test_receiver_pingBounds() public {
        vm.expectRevert(abi.encodeWithSelector(G1Receiver.RoundsOutOfRange.selector, 0));
        receiver.ping(0);
        uint256 tooMany = receiver.MAX_ROUNDS() + 1;
        vm.expectRevert(abi.encodeWithSelector(G1Receiver.RoundsOutOfRange.selector, tooMany));
        receiver.ping(tooMany);
    }

    function test_receiver_onlyOwnerStartsExperiments() public {
        address stranger = makeAddr("stranger");
        vm.startPrank(stranger);
        vm.expectRevert(abi.encodeWithSelector(G1Receiver.NotOwner.selector, stranger));
        receiver.ping(1);
        vm.expectRevert(abi.encodeWithSelector(G1Receiver.NotOwner.selector, stranger));
        receiver.watch(token);
        vm.stopPrank();
    }

    function test_receiver_rejectsZeroConstructorArgs() public {
        vm.expectRevert(G1Receiver.ZeroAddress.selector);
        new G1Receiver(address(0), address(reactive));
        vm.expectRevert(G1Receiver.ZeroAddress.selector);
        new G1Receiver(proxy, address(0));
    }

    // ---------------------------------------------------------------- simulated full loop

    /// @dev Simulates ping(3): Ping -> react -> onRound(3) -> Progress(2) -> react -> onRound(2) -> Progress(1) ->
    ///      react -> onRound(1), then nothing. No step is driven by anything but the previous step's event.
    function test_loop_pingRunsAllRoundsWithoutKeeper() public {
        vm.recordLogs();
        receiver.ping(3);
        Vm.Log[] memory logs = vm.getRecordedLogs();

        for (uint256 round; round < 10; round++) {
            uint256 before = sys.requestCount();
            for (uint256 i; i < logs.length; i++) {
                if (logs[i].emitter == address(receiver)) _react(_fromVmLog(logs[i]));
            }
            if (sys.requestCount() == before) break;
            vm.recordLogs();
            _deliver(sys.requestCount() - 1);
            logs = vm.getRecordedLogs();
        }

        assertEq(receiver.roundsReceived(), 3);
        assertEq(sys.requestCount(), 3);
    }

    function test_loop_watchThenBaselineReachesReceiver() public {
        vm.recordLogs();
        receiver.watch(token);
        Vm.Log[] memory logs = vm.getRecordedLogs();
        _react(_fromVmLog(logs[0]));

        address delegate = makeAddr("delegate");
        bytes32 peer = bytes32(uint256(0xCAFE));
        _react(_baselineLog(token, peer, uint256(uint160(delegate))));
        _deliver(0);

        (uint32 eid, bytes32 gotPeer, address gotDelegate, bool received) = receiver.baselines(token);
        assertTrue(received);
        assertEq(eid, BASE_EID);
        assertEq(gotPeer, peer);
        assertEq(gotDelegate, delegate);
    }
}
