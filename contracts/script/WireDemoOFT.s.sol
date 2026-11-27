// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {Script, console} from "forge-std/Script.sol";
import {DemoOFT} from "../src/demo/DemoOFT.sol";
import {TestnetGuard} from "./TestnetGuard.sol";

/// @title WireDemoOFT
/// @notice Points a local `DemoOFT` at its twin on the other chain by calling `setPeer`. Testnet only.
/// @dev Run once per chain (Base Sepolia, then chain X), each time with the other chain's token as the remote.
///      Required env: LOCAL_OFT, REMOTE_EID, REMOTE_OFT. The signer must be the owner of LOCAL_OFT.
///
///      Usage (dry run, then add --broadcast):
///        LOCAL_OFT=0x.. REMOTE_EID=40161 REMOTE_OFT=0x.. \
///        forge script script/WireDemoOFT.s.sol --rpc-url $BASE_SEPOLIA_RPC_URL --private-key $PRIVATE_KEY
///      On Ethereum Sepolia, broadcast with --skip-simulation (README, "Ethereum Sepolia gas").
contract WireDemoOFT is Script, TestnetGuard {
    error RemoteEidNotAllowed(uint32 eid);
    error SameChainPeer(uint32 eid);
    error ZeroAddress();
    error LocalOftMissing(address oft);
    error NotOwner(address signer, address owner);

    /// @notice Script entry point. Reads env, then wires. Env is read only here so tests can call `wire` directly.
    function run() external {
        wire(vm.envAddress("LOCAL_OFT"), uint32(vm.envUint("REMOTE_EID")), vm.envAddress("REMOTE_OFT"));
    }

    /// @notice Checks chain and ownership, sets the peer if it differs, and logs the result.
    /// @param localOft DemoOFT on this chain. The signer must own it.
    /// @param remoteEid LayerZero EID of the other chain.
    /// @param remoteOft DemoOFT on the other chain.
    function wire(address localOft, uint32 remoteEid, address remoteOft) public {
        uint32 localEid = _expectedEid(block.chainid);
        _checkEndpoint(localEid);
        _checkRemote(localEid, remoteEid, localOft, remoteOft);

        console.log("Chain ID:", block.chainid);
        console.log("Local EID:", localEid);
        console.log("Local OFT:", localOft);
        console.log("Remote EID:", remoteEid);
        console.log("Remote OFT:", remoteOft);

        _wire(DemoOFT(localOft), remoteEid, remoteOft);
    }

    /// @dev Pure input checks. The remote must be a known testnet EID on a different chain and a non-zero address.
    function _checkRemote(uint32 localEid, uint32 remoteEid, address localOft, address remoteOft) internal view {
        if (localOft == address(0) || remoteOft == address(0)) revert ZeroAddress();
        if (localOft.code.length == 0) revert LocalOftMissing(localOft);
        if (remoteEid == localEid) revert SameChainPeer(remoteEid);
        if (remoteEid != BASE_SEPOLIA_EID && remoteEid != ETHEREUM_SEPOLIA_EID && remoteEid != UNICHAIN_SEPOLIA_EID) {
            revert RemoteEidNotAllowed(remoteEid);
        }
    }

    /// @dev Sets the peer only when it differs: `PeerSet` is emitted on every call, even for the same value.
    function _wire(DemoOFT localOft, uint32 remoteEid, address remoteOft) internal {
        bytes32 peer = bytes32(uint256(uint160(remoteOft)));
        if (localOft.peers(remoteEid) == peer) {
            console.log("Peer already set, nothing to do.");
            return;
        }

        vm.startBroadcast();
        (, address signer,) = vm.readCallers();
        if (localOft.owner() != signer) revert NotOwner(signer, localOft.owner());
        localOft.setPeer(remoteEid, peer);
        vm.stopBroadcast();

        console.log("Peer set. Signer:", signer);
    }
}
