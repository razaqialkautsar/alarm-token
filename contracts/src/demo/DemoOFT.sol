// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {OFT} from "@layerzerolabs/oft-evm/contracts/OFT.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

/// @title DemoOFT
/// @notice Standard LayerZero V2 OFT used for Alarm Token drills on testnet. No custom mint, peer, or delegate logic:
///         peers and delegate are managed only through the inherited, owner-gated OApp functions.
/// @dev Minimal version for dependency and compiler checks. Drill-specific needs (PRD.md section 8.4) are added later.
contract DemoOFT is OFT {
    /// @param name_ Token name.
    /// @param symbol_ Token symbol.
    /// @param lzEndpoint_ LayerZero EndpointV2 on this chain.
    /// @param owner_ Owner and initial LayerZero delegate.
    /// @param initialSupply_ Amount minted to `owner_` at deployment (may be zero).
    constructor(string memory name_, string memory symbol_, address lzEndpoint_, address owner_, uint256 initialSupply_)
        OFT(name_, symbol_, lzEndpoint_, owner_)
        Ownable(owner_)
    {
        if (initialSupply_ > 0) _mint(owner_, initialSupply_);
    }
}
