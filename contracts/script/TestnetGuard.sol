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

    /// @dev LayerZero EndpointV2 per chain. Source: LayerZero `/v1/metadata/deployments`, checked 25 Nov 2026.
    ///      Base Sepolia and Ethereum Sepolia share one address; Unichain Sepolia (DEPRECATED in the metadata) has a
    ///      different one, and the Base/Ethereum address has no code there. On-chain, `eid()` was read as 40245
    ///      (Base), 40161 (Ethereum) and 40333 (Unichain, through two public RPCs).
    address internal constant LZ_ENDPOINT_BASE_AND_ETHEREUM_SEPOLIA = 0x6EDCE65403992e310A62460808c4b910D972f10f;
    address internal constant LZ_ENDPOINT_UNICHAIN_SEPOLIA = 0xb8815f3f882614048CbE201a67eF9c6F10fe5035;

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

    /// @dev Returns the LayerZero EndpointV2 for an allowed testnet chain, and reverts on any other chain.
    function _endpoint(uint256 chainId) internal pure returns (address) {
        if (chainId == BASE_SEPOLIA_CHAIN_ID || chainId == ETHEREUM_SEPOLIA_CHAIN_ID) {
            return LZ_ENDPOINT_BASE_AND_ETHEREUM_SEPOLIA;
        }
        if (chainId == UNICHAIN_SEPOLIA_CHAIN_ID) return LZ_ENDPOINT_UNICHAIN_SEPOLIA;
        revert UnsupportedChain(chainId);
    }

    /// @dev Confirms the chain's endpoint has code and reports the EID expected for this chain.
    function _checkEndpoint(uint32 expectedEid) internal view {
        address endpoint = _endpoint(block.chainid);
        if (endpoint.code.length == 0) revert EndpointMissing(endpoint);
        uint32 actual = ILayerZeroEndpointEid(endpoint).eid();
        if (actual != expectedEid) revert EndpointEidMismatch(expectedEid, actual);
    }
}
