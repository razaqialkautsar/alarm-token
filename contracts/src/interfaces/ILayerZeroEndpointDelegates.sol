// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

/// @title ILayerZeroEndpointDelegates
/// @notice The one EndpointV2 getter `BaselineReporter` needs. `EndpointV2.delegates` is a public mapping.
interface ILayerZeroEndpointDelegates {
    /// @notice Returns the delegate that may configure `oapp` on the endpoint.
    /// @param oapp The OApp (token) address.
    function delegates(address oapp) external view returns (address);
}
