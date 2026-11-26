// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {IOAppCore} from "@layerzerolabs/oapp-evm/contracts/oapp/interfaces/IOAppCore.sol";
import {ILayerZeroEndpointDelegates} from "../interfaces/ILayerZeroEndpointDelegates.sol";

/// @title BaselineReporter
/// @notice Publishes the current LayerZero trust settings of a token on this chain (its peer for one remote EID and its
///         delegate) as an event, so that `AlarmReactive` can store them as the baseline to compare later changes against.
/// @dev Permissionless and stateless. Both values are read on-chain: the peer from the token, the delegate from the
///      EndpointV2 fixed at deployment. The delegate is deliberately not read through `token.endpoint()`, because a
///      hostile token could point that at a contract that reports whatever it likes. `token.endpoint()` is only checked
///      to match, to reject tokens that do not belong to this chain's endpoint.
///      Deployed on chain X (PRD.md sections 7.2 and 8.3).
contract BaselineReporter {
    /// @notice LayerZero EndpointV2 of this chain. Source of every delegate value.
    ILayerZeroEndpointDelegates public immutable ENDPOINT;

    /// @notice Baseline of a token's trust settings at the time of the call.
    /// @param token The token (OApp) that was read.
    /// @param remoteEid The remote endpoint ID whose peer was read.
    /// @param peer `token.peers(remoteEid)`. Zero when no peer is set.
    /// @param delegate `ENDPOINT.delegates(token)`.
    event Baseline(address indexed token, uint32 indexed remoteEid, bytes32 peer, address delegate);

    error ZeroAddress();
    error NotAContract(address account);
    error WrongEndpoint(address token, address tokenEndpoint);

    /// @param endpoint_ LayerZero EndpointV2 on this chain.
    constructor(address endpoint_) {
        if (endpoint_ == address(0)) revert ZeroAddress();
        if (endpoint_.code.length == 0) revert NotAContract(endpoint_);
        ENDPOINT = ILayerZeroEndpointDelegates(endpoint_);
    }

    /// @notice Reads the peer and delegate of `token` and emits them as a `Baseline` event. Anyone may call it.
    /// @param token The token (OApp) on this chain.
    /// @param remoteEid The remote endpoint ID whose peer is wanted.
    /// @return peer The current `token.peers(remoteEid)`.
    /// @return delegate The current `ENDPOINT.delegates(token)`.
    function report(address token, uint32 remoteEid) external returns (bytes32 peer, address delegate) {
        if (token == address(0)) revert ZeroAddress();
        if (token.code.length == 0) revert NotAContract(token);
        // Sanity filter, not a trust source: rejects addresses that are not an OApp on this chain's endpoint, such as a
        // Base token address passed on chain X. The delegate below is still read from ENDPOINT, never from the token.
        address tokenEndpoint = address(IOAppCore(token).endpoint());
        if (tokenEndpoint != address(ENDPOINT)) revert WrongEndpoint(token, tokenEndpoint);

        peer = IOAppCore(token).peers(remoteEid);
        delegate = ENDPOINT.delegates(token);

        emit Baseline(token, remoteEid, peer, delegate);
    }
}
