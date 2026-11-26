// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {AbstractReactive} from "@reactive/src/base/AbstractReactive.sol";
import {ISystemContract} from "@reactive/src/interfaces/ISystemContract.sol";
import {G1Receiver} from "./G1Receiver.sol";

/// @title G1Reactive (GATE G1 ONLY)
/// @notice Reactive contract on Reactive Lasna for gate G1 (PRD.md section 14), using the Omni API. It proves:
///         - basic loop: `Ping` on Base Sepolia -> `react()` -> `onRound` callback on Base Sepolia;
///         - (ii) keeperless continuation: each `Progress` emitted by the callback triggers the next round;
///         - (i) dynamic subscription: `react()` subscribes to `Baseline` on chain X when a `Watch` arrives, and
///           unsubscribes after the first `Baseline` (the pattern proposed for `AlarmReactive`);
///         - (iii) `BaselineReporter` events reach `react()`, and their values reach Base through a callback.
/// @dev Gate experiment, not `AlarmReactive`. `react()` never reverts to filter logs (reverts are charged in full);
///      non-matching logs are ignored. Log data is length-checked and decoded without abi address validation, so dirty
///      input cannot make it revert. Subscribe and unsubscribe for `Baseline` share one helper so the six arguments
///      always match (unsubscribe silently fails otherwise).
contract G1Reactive is AbstractReactive {
    /// @notice Shown on explorers so nobody mistakes this contract for part of nothief's protection loop.
    string public constant GATE_NOTICE =
        "GATE G1 ONLY: nothief testnet loop experiment. Not part of the protection loop.";

    /// @notice Gas limit for every callback. Reactive drops requests below 100,000. The real executor value comes from
    ///         gate G4; this one only has to cover `G1Receiver`'s small callbacks.
    uint64 public constant CALLBACK_GAS_LIMIT = 200_000;

    /// @notice topic0 values of the events this contract reacts to.
    uint256 public constant PING_TOPIC0 = uint256(keccak256("Ping(uint256)"));
    uint256 public constant PROGRESS_TOPIC0 = uint256(keccak256("Progress(uint256)"));
    uint256 public constant WATCH_TOPIC0 = uint256(keccak256("Watch(address)"));
    uint256 public constant BASELINE_TOPIC0 = uint256(keccak256("Baseline(address,uint32,bytes32,address)"));

    /// @dev Number of topics per event (`LogRecord.opCode`), including topic0.
    uint256 private constant ONE_TOPIC = 1;
    uint256 private constant TWO_TOPICS = 2;
    uint256 private constant THREE_TOPICS = 3;
    /// @dev ABI length of one and two static words in `LogRecord.data`.
    uint256 private constant ONE_WORD = 32;
    uint256 private constant TWO_WORDS = 64;

    /// @notice Account allowed to configure the contract.
    address public immutable OWNER;

    /// @notice Chain and address of `G1Receiver` (Base Sepolia).
    uint256 public receiverChainId;
    address public receiver;

    /// @notice Chain and address of `BaselineReporter` (chain X).
    uint256 public reporterChainId;
    address public reporter;

    /// @notice Chain-X tokens with an active `Baseline` subscription (subscriptions cannot be read on-chain).
    mapping(address token => bool) public watching;

    event Configured(uint256 receiverChainId, address receiver, uint256 reporterChainId, address reporter);
    event Subscribed(uint256 indexed chainId, address indexed emitter, uint256 indexed topic0, uint256 topic1);
    event Unsubscribed(uint256 indexed chainId, address indexed emitter, uint256 indexed topic0, uint256 topic1);
    /// @param originTxHash Hash of the origin-chain tx whose log caused the request, for the latency tool.
    event CallbackRequested(uint256 indexed chainId, address indexed recipient, bytes4 selector, uint256 originTxHash);

    error NotOwner(address caller);
    error ZeroValue();
    error AlreadyConfigured();

    /// @dev Payable so the deploy can fund the contract with lREACT (`--value` reverts otherwise).
    constructor() payable {
        OWNER = msg.sender;
    }

    modifier onlyOwner() {
        if (msg.sender != OWNER) revert NotOwner(msg.sender);
        _;
    }

    /// @notice One-time setup after `G1Receiver` is deployed (deploy order: reactive, callback, then this setter).
    ///         Subscribes to `Ping`, `Progress` and `Watch` from the receiver.
    /// @param receiverChainId_ Chain ID of `G1Receiver` (Base Sepolia).
    /// @param receiver_ `G1Receiver` address.
    /// @param reporterChainId_ Chain ID of `BaselineReporter` (chain X).
    /// @param reporter_ `BaselineReporter` address.
    function configure(uint256 receiverChainId_, address receiver_, uint256 reporterChainId_, address reporter_)
        external
        onlyOwner
    {
        if (receiver != address(0)) revert AlreadyConfigured();
        if (receiverChainId_ == 0 || receiver_ == address(0) || reporterChainId_ == 0 || reporter_ == address(0)) {
            revert ZeroValue();
        }
        receiverChainId = receiverChainId_;
        receiver = receiver_;
        reporterChainId = reporterChainId_;
        reporter = reporter_;
        emit Configured(receiverChainId_, receiver_, reporterChainId_, reporter_);

        _subscribe(receiverChainId_, receiver_, PING_TOPIC0, REACTIVE_IGNORE);
        _subscribe(receiverChainId_, receiver_, PROGRESS_TOPIC0, REACTIVE_IGNORE);
        _subscribe(receiverChainId_, receiver_, WATCH_TOPIC0, REACTIVE_IGNORE);
    }

    /// @notice Entry point for subscribed logs. Only the system contract may call it. Never reverts on unknown input.
    /// @param log The log record.
    function react(LogRecord calldata log) external onlySystem {
        if (log.chainId == receiverChainId && log.contractAddress == receiver) {
            _reactToReceiver(log);
        } else if (log.chainId == reporterChainId && log.contractAddress == reporter) {
            _reactToReporter(log);
        }
    }

    /// @notice Pays any debt to the system contract from this contract's balance. Anyone may call it.
    function coverDebt() external {
        _coverDebt();
    }

    function _reactToReceiver(LogRecord calldata log) private {
        if (
            (log.topic0 == PING_TOPIC0 || log.topic0 == PROGRESS_TOPIC0) && log.opCode == ONE_TOPIC
                && log.data.length == ONE_WORD
        ) {
            uint256 roundsLeft = abi.decode(log.data, (uint256));
            _requestCallback(abi.encodeCall(G1Receiver.onRound, (address(0), roundsLeft)), log.txHash);
        } else if (log.topic0 == WATCH_TOPIC0 && log.opCode == TWO_TOPICS) {
            address token = address(uint160(log.topic1));
            if (token == address(0) || watching[token]) return;
            watching[token] = true;
            _setBaselineSubscription(token, true);
        }
    }

    function _reactToReporter(LogRecord calldata log) private {
        if (log.topic0 != BASELINE_TOPIC0 || log.opCode != THREE_TOPICS || log.data.length != TWO_WORDS) return;
        address token = address(uint160(log.topic1));
        if (!watching[token]) return;

        // Decode as words, not as (bytes32, address): abi.decode reverts on an address with dirty upper bits.
        (bytes32 peer, uint256 delegateWord) = abi.decode(log.data, (bytes32, uint256));
        uint32 remoteEid = uint32(log.topic2);

        watching[token] = false;
        _setBaselineSubscription(token, false);
        // Truncation is intended: an address is the low 160 bits of its ABI word.
        // forge-lint: disable-next-line(unsafe-typecast)
        address delegate = address(uint160(delegateWord));
        _requestCallback(
            abi.encodeCall(G1Receiver.onBaseline, (address(0), token, remoteEid, peer, delegate)), log.txHash
        );
    }

    /// @dev Single source of the six arguments for the `Baseline` subscription, used for both directions.
    function _setBaselineSubscription(address token, bool on) private {
        uint256 topic1 = uint256(uint160(token));
        if (on) {
            _subscribe(reporterChainId, reporter, BASELINE_TOPIC0, topic1);
        } else {
            SYSTEM.unsubscribe(reporterChainId, reporter, BASELINE_TOPIC0, topic1, REACTIVE_IGNORE, REACTIVE_IGNORE);
            emit Unsubscribed(reporterChainId, reporter, BASELINE_TOPIC0, topic1);
        }
    }

    function _subscribe(uint256 chainId, address emitter, uint256 topic0, uint256 topic1) private {
        SYSTEM.subscribe(chainId, emitter, topic0, topic1, REACTIVE_IGNORE, REACTIVE_IGNORE);
        emit Subscribed(chainId, emitter, topic0, topic1);
    }

    /// @dev The payload's first argument is `address(0)`; Reactive overwrites it with this contract's address.
    function _requestCallback(bytes memory payload, uint256 originTxHash) private {
        SYSTEM.requestCallbackV_1_0(
            ISystemContract.CallbackConfiguration_V_1_0({
                chainId: receiverChainId, recipient: receiver, gasLimit: CALLBACK_GAS_LIMIT, payload: payload
            })
        );
        // Truncation is intended: the selector is the first four bytes of the payload.
        // forge-lint: disable-next-line(unsafe-typecast)
        emit CallbackRequested(receiverChainId, receiver, bytes4(payload), originTxHash);
    }
}
