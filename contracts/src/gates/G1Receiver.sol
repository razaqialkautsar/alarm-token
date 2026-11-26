// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {AbstractCallback} from "@reactive/src/base/AbstractCallback.sol";
import {IPayable} from "@reactive/src/interfaces/IPayable.sol";

/// @title G1Receiver (GATE G1 ONLY)
/// @notice Dummy callback contract on Base Sepolia for gate G1 (PRD.md section 14). It is both an event source and a
///         callback target for `G1Reactive` on Reactive Lasna:
///         - `ping` emits `Ping`, which `G1Reactive` answers with an `onRound` callback (basic loop).
///         - `onRound` emits `Progress` while rounds are left, which `G1Reactive` answers again (keeperless loop).
///         - `watch` emits `Watch`, which makes `G1Reactive` subscribe at runtime to `Baseline` on chain X (dynamic
///           subscription); the first `Baseline` for that token comes back here through `onBaseline`.
/// @dev Holds no user funds and moves no tokens. Its ETH balance only pays for callbacks (charged by the callback
///      proxy in Base Sepolia ETH). Not part of the protection loop.
contract G1Receiver is AbstractCallback {
    /// @notice Shown on explorers so nobody mistakes this contract for part of nothief's protection loop.
    string public constant GATE_NOTICE =
        "GATE G1 ONLY: nothief testnet loop experiment. Not part of the protection loop.";

    /// @notice Upper bound for one `ping`, so a typo cannot drain the reactive contract or this contract.
    uint256 public constant MAX_ROUNDS = 5;

    /// @notice Account allowed to start experiments.
    address public immutable OWNER;

    /// @notice Number of `onRound` callbacks received.
    uint256 public roundsReceived;

    /// @notice Last baseline received for a token through `onBaseline`.
    struct ReceivedBaseline {
        uint32 remoteEid;
        bytes32 peer;
        address delegate;
        bool received;
    }

    /// @notice Baselines received per chain-X token.
    mapping(address token => ReceivedBaseline) public baselines;

    /// @notice Starts a loop of `roundsLeft` callbacks. Watched by `G1Reactive`.
    event Ping(uint256 roundsLeft);
    /// @notice Asks for the next round. Emitted inside `onRound`. Watched by `G1Reactive`.
    event Progress(uint256 roundsLeft);
    /// @notice Asks `G1Reactive` to subscribe to `Baseline` events for `token` on chain X.
    event Watch(address indexed token);
    /// @notice An `onRound` callback arrived.
    event RoundReceived(uint256 roundsLeft, uint256 total);
    /// @notice An `onBaseline` callback arrived.
    event BaselineReceived(address indexed token, uint32 indexed remoteEid, bytes32 peer, address delegate);

    error NotOwner(address caller);
    error ZeroAddress();
    error RoundsOutOfRange(uint256 rounds);

    /// @param callbackProxy_ Reactive callback proxy on this chain (Base Sepolia: PRD.md section 7.1).
    /// @param reactive_ `G1Reactive` address on Lasna. The only accepted callback sender.
    constructor(address callbackProxy_, address reactive_)
        payable
        AbstractCallback(IPayable(payable(callbackProxy_)), reactive_)
    {
        if (callbackProxy_ == address(0) || reactive_ == address(0)) revert ZeroAddress();
        OWNER = msg.sender;
    }

    modifier onlyOwner() {
        if (msg.sender != OWNER) revert NotOwner(msg.sender);
        _;
    }

    /// @notice Starts a callback loop of `rounds` rounds.
    /// @param rounds Number of callbacks wanted, 1 to `MAX_ROUNDS`.
    function ping(uint256 rounds) external onlyOwner {
        if (rounds == 0 || rounds > MAX_ROUNDS) revert RoundsOutOfRange(rounds);
        emit Ping(rounds);
    }

    /// @notice Asks `G1Reactive` to subscribe to `Baseline` events for `token` on chain X.
    /// @param token Chain-X token address that `BaselineReporter.report` will be called for.
    function watch(address token) external onlyOwner {
        if (token == address(0)) revert ZeroAddress();
        emit Watch(token);
    }

    /// @notice Callback for one round. Emits `Progress` while more rounds are left.
    /// @param rvm Overwritten by Reactive with the sending reactive contract's address.
    /// @param roundsLeft Rounds left including this one.
    function onRound(address rvm, uint256 roundsLeft) external onlyServiceProvider onlyCallbackSender(rvm) {
        uint256 total = ++roundsReceived;
        emit RoundReceived(roundsLeft, total);
        if (roundsLeft > 1) emit Progress(roundsLeft - 1);
    }

    /// @notice Callback carrying a chain-X baseline that `G1Reactive` received from `BaselineReporter`.
    /// @param rvm Overwritten by Reactive with the sending reactive contract's address.
    /// @param token Chain-X token.
    /// @param remoteEid Remote EID whose peer was reported.
    /// @param peer Reported peer.
    /// @param delegate Reported delegate.
    function onBaseline(address rvm, address token, uint32 remoteEid, bytes32 peer, address delegate)
        external
        onlyServiceProvider
        onlyCallbackSender(rvm)
    {
        baselines[token] = ReceivedBaseline(remoteEid, peer, delegate, true);
        emit BaselineReceived(token, remoteEid, peer, delegate);
    }

    /// @notice Pays any debt to the callback proxy from this contract's balance. Anyone may call it.
    function coverDebt() external {
        _coverDebt();
    }
}
