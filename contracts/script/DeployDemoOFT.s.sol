// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {Script, console} from "forge-std/Script.sol";
import {DemoOFT} from "../src/demo/DemoOFT.sol";

/// @notice Minimal view of LayerZero EndpointV2 used for the pre-deploy check.
interface ILayerZeroEndpointEid {
    function eid() external view returns (uint32);
}

/// @title DeployDemoOFT
/// @notice Deploys one `DemoOFT` on the chain the script runs against. Testnet only (CLAUDE.md sections 2.4 and 7).
/// @dev Chain X is chosen by the RPC URL, not by code, so the same script serves Ethereum Sepolia (default) and
///      Unichain Sepolia (only if ESC is reopened). The deployer becomes owner and initial LayerZero delegate.
///      Run once per chain, then wire the peers (setPeer on both sides) before sending.
///
///      Usage (dry run, then add --broadcast):
///        forge script script/DeployDemoOFT.s.sol --rpc-url $BASE_SEPOLIA_RPC_URL --private-key $PRIVATE_KEY
///      Optional env: DEMO_OFT_NAME, DEMO_OFT_SYMBOL, DEMO_OFT_INITIAL_SUPPLY (whole tokens, 18 decimals).
contract DeployDemoOFT is Script {
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

    uint256 internal constant TOKEN_DECIMALS = 1e18;
    uint256 internal constant DEFAULT_INITIAL_SUPPLY_TOKENS = 1_000_000;
    string internal constant DEFAULT_NAME = "Alarm Demo OFT";
    string internal constant DEFAULT_SYMBOL = "ADEMO";

    error UnsupportedChain(uint256 chainId);
    error EndpointMissing(address endpoint);
    error EndpointEidMismatch(uint32 expected, uint32 actual);

    /// @notice Script entry point. Reads optional env overrides, checks the chain, deploys, and logs the result.
    function run() external returns (DemoOFT token) {
        string memory name = vm.envOr("DEMO_OFT_NAME", DEFAULT_NAME);
        string memory symbol = vm.envOr("DEMO_OFT_SYMBOL", DEFAULT_SYMBOL);
        uint256 supply = vm.envOr("DEMO_OFT_INITIAL_SUPPLY", DEFAULT_INITIAL_SUPPLY_TOKENS) * TOKEN_DECIMALS;

        uint32 expectedEid = _expectedEid(block.chainid);
        _checkEndpoint(expectedEid);

        console.log("Chain ID:", block.chainid);
        console.log("LayerZero EID:", expectedEid);
        console.log("Endpoint:", LZ_ENDPOINT_V2);

        vm.startBroadcast();
        // Inside a broadcast, `msg.sender` of `run()` can differ from the account that signs. Ask the cheatcode for
        // the broadcaster so the owner is always the signing account.
        (, address owner,) = vm.readCallers();
        token = new DemoOFT(name, symbol, LZ_ENDPOINT_V2, owner, supply);
        vm.stopBroadcast();

        console.log("DemoOFT deployed at:", address(token));
        console.log("Owner and delegate:", owner);
        console.log("Initial supply (wei):", supply);
    }

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
