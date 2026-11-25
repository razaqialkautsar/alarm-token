// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

/// @notice Minimal view of LayerZero EndpointV2 used for the pre-deploy check.
interface ILayerZeroEndpointEid {
    function eid() external view returns (uint32);
}

/// @title TestnetGuard
/// @notice Shared chain and endpoint checks for the DemoOFT scripts. Testnet only (CLAUDE.md sections 2.4 and 7).
abstract contract TestnetGuard {
    /// @dev Testnet chain IDs (PRD.md section 7.1). No mainnet ID is accepted.
    uint256 internal constant BASE_SEPOLIA_CHAIN_ID = 84532;
    uint256 internal constant ETHEREUM_SEPOLIA_CHAIN_ID = 11155111;
    uint256 internal constant UNICHAIN_SEPOLIA_CHAIN_ID = 1301;

    /// @dev LayerZero V2 endpoint IDs for those chains (PRD.md section 7.1).
    uint32 internal constant BASE_SEPOLIA_EID = 40245;
    uint32 internal constant ETHEREUM_SEPOLIA_EID = 40161;
    uint32 internal constant UNICHAIN_SEPOLIA_EID = 40333;

    /// @dev LayerZero EndpointV2 on all three testnets. Source: LayerZero `/v1/metadata/deployments`
    ///      (basesep-testnet and sepolia-testnet, checked 25 Nov 2026), and `eid()` read on-chain for Base Sepolia
    ///      (40245) and Ethereum Sepolia (40161). Unichain Sepolia is not verified (DEPRECATED in the metadata);
    ///      the `eid()` check below still guards it.
    address internal constant LZ_ENDPOINT_V2 = 0x6EDCE65403992e310A62460808c4b910D972f10f;

    error UnsupportedChain(uint256 chainId);
    error EndpointMissing(address endpoint);
    error EndpointEidMismatch(uint32 expected, uint32 actual);

    /// @dev Returns the LayerZero EID for an allowed testnet chain, and reverts on any other chain.
    function _expectedEid(uint256 chainId) internal pure returns (uint32) {
        if (chainId == BASE_SEPOLIA_CHAIN_ID) return BASE_SEPOLIA_EID;
        if (chainId == ETHEREUM_SEPOLIA_CHAIN_ID) return ETHEREUM_SEPOLIA_EID;
        if (chainId == UNICHAIN_SEPOLIA_CHAIN_ID) return UNICHAIN_SEPOLIA_EID;
        revert UnsupportedChain(chainId);
    }

    /// @dev Confirms the endpoint has code and reports the EID expected for this chain.
    function _checkEndpoint(uint32 expectedEid) internal view {
        if (LZ_ENDPOINT_V2.code.length == 0) revert EndpointMissing(LZ_ENDPOINT_V2);
        uint32 actual = ILayerZeroEndpointEid(LZ_ENDPOINT_V2).eid();
        if (actual != expectedEid) revert EndpointEidMismatch(expectedEid, actual);
    }
}
