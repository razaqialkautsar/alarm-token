// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {Script, console} from "forge-std/Script.sol";
import {OptionsBuilder} from "@layerzerolabs/oapp-evm/contracts/oapp/libs/OptionsBuilder.sol";
import {
    SendParam,
    MessagingFee,
    MessagingReceipt,
    OFTReceipt
} from "@layerzerolabs/oft-evm/contracts/interfaces/IOFT.sol";
import {DemoOFT} from "../src/demo/DemoOFT.sol";
import {TestnetGuard} from "./TestnetGuard.sol";

/// @title SendDemoOFT
/// @notice Sends `DemoOFT` tokens to the twin token on the other chain through LayerZero (gate G2, one direction per run).
/// @dev Testnet only. Run it on the source chain; run it again on the other chain for the opposite direction.
///      The signer pays the LayerZero fee in native token and must hold the tokens. Peers must already be wired
///      (`WireDemoOFT`). Delivery is asynchronous: track the printed GUID on LayerZero Scan (testnet) and record the
///      source and destination tx hashes in `docs/gates.md`.
///      Required env: LOCAL_OFT, DST_EID, AMOUNT_TOKENS (whole tokens, 18 decimals).
///      Optional env: TO (recipient on the destination chain, default the signer), LZ_RECEIVE_GAS (default 200000).
///
///      Usage (dry run, then add --broadcast):
///        LOCAL_OFT=0x.. DST_EID=40161 AMOUNT_TOKENS=100 \
///        forge script script/SendDemoOFT.s.sol --rpc-url $BASE_SEPOLIA_RPC_URL --private-key $PRIVATE_KEY
contract SendDemoOFT is Script, TestnetGuard {
    using OptionsBuilder for bytes;

    uint256 internal constant TOKEN_DECIMALS = 1e18;
    /// @dev Gas given to the destination `lzReceive`. A plain OFT credit needs far less; this leaves headroom.
    uint128 internal constant DEFAULT_LZ_RECEIVE_GAS = 200_000;

    error ZeroAmount();
    error LocalOftMissing(address oft);
    error WrongEndpointForChain(address tokenEndpoint, address expected);
    error DstEidNotAllowed(uint32 eid);
    error SameChainRoute(uint32 eid);
    error PeerNotSet(uint32 dstEid);
    error InsufficientTokens(uint256 have, uint256 need);
    error InsufficientNative(uint256 have, uint256 need);

    /// @notice Script entry point. Reads env, then sends.
    function run() external {
        send(
            vm.envAddress("LOCAL_OFT"),
            uint32(vm.envUint("DST_EID")),
            vm.envOr("TO", address(0)),
            vm.envUint("AMOUNT_TOKENS"),
            uint128(vm.envOr("LZ_RECEIVE_GAS", uint256(DEFAULT_LZ_RECEIVE_GAS)))
        );
    }

    /// @notice Quotes the fee, then sends `amountTokens` to `to` on `dstEid`.
    /// @param localOft DemoOFT on this chain. The signer must hold the tokens.
    /// @param dstEid LayerZero EID of the destination chain.
    /// @param to Recipient on the destination chain. The zero address means the signer.
    /// @param amountTokens Whole tokens to send.
    /// @param lzReceiveGas Gas for the destination `lzReceive`.
    function send(address localOft, uint32 dstEid, address to, uint256 amountTokens, uint128 lzReceiveGas) public {
        if (amountTokens == 0) revert ZeroAmount();
        DemoOFT oft = DemoOFT(localOft);
        _validateRoute(oft, dstEid);
        if (oft.peers(dstEid) == bytes32(0)) revert PeerNotSet(dstEid);

        uint256 amount = amountTokens * TOKEN_DECIMALS;

        vm.startBroadcast();
        (, address signer,) = vm.readCallers();
        if (oft.balanceOf(signer) < amount) revert InsufficientTokens(oft.balanceOf(signer), amount);

        SendParam memory param = SendParam({
            dstEid: dstEid,
            to: bytes32(uint256(uint160(to == address(0) ? signer : to))),
            amountLD: amount,
            minAmountLD: amount,
            extraOptions: OptionsBuilder.newOptions().addExecutorLzReceiveOption(lzReceiveGas, 0),
            composeMsg: "",
            oftCmd: ""
        });
        MessagingFee memory fee = oft.quoteSend(param, false);
        if (signer.balance < fee.nativeFee) revert InsufficientNative(signer.balance, fee.nativeFee);

        (MessagingReceipt memory receipt,) = oft.send{value: fee.nativeFee}(param, fee, payable(signer));
        vm.stopBroadcast();

        console.log("Chain ID:", block.chainid);
        console.log("From OFT:", localOft);
        console.log("Destination EID:", dstEid);
        console.log("Recipient:", address(uint160(uint256(param.to))));
        console.log("Amount (wei):", amount);
        console.log("LayerZero fee (wei):", fee.nativeFee);
        console.log("GUID:");
        console.logBytes32(receipt.guid);
    }

    /// @dev Route checks: testnet chain, the token uses this chain's endpoint, and the destination is another known
    ///      testnet. Virtual so tests that use mocked endpoints can replace it.
    function _validateRoute(DemoOFT oft, uint32 dstEid) internal view virtual {
        uint32 localEid = _expectedEid(block.chainid);
        if (address(oft).code.length == 0) revert LocalOftMissing(address(oft));
        address expected = _endpoint(block.chainid);
        if (address(oft.endpoint()) != expected) revert WrongEndpointForChain(address(oft.endpoint()), expected);
        if (dstEid == localEid) revert SameChainRoute(dstEid);
        if (dstEid != BASE_SEPOLIA_EID && dstEid != ETHEREUM_SEPOLIA_EID && dstEid != UNICHAIN_SEPOLIA_EID) {
            revert DstEidNotAllowed(dstEid);
        }
    }
}
