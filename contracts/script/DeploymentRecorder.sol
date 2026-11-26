// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {Script, console} from "forge-std/Script.sol";
import {VmSafe} from "forge-std/Vm.sol";

/// @title DeploymentRecorder
/// @notice Writes deployed addresses to `deployments/<chain>.json` (schema in `deployments/README.md`), so scripts and
///         the dashboard read addresses from one place (CLAUDE.md sections 6.2 and 6.5).
/// @dev Writes only when the script runs with `--broadcast`. Dry runs and tests leave the files untouched. The write
///      happens during the script's simulation, before the transaction is mined, so check the address with
///      `cast code` after a broadcast. Tx hashes are in `contracts/broadcast/`.
abstract contract DeploymentRecorder is Script {
    uint256 internal constant LASNA_CHAIN_ID = 5318007;
    uint256 internal constant BASE_SEPOLIA_ID = 84532;
    uint256 internal constant ETHEREUM_SEPOLIA_ID = 11155111;
    uint256 internal constant UNICHAIN_SEPOLIA_ID = 1301;

    error NoDeploymentFileForChain(uint256 chainId);

    /// @dev Records `addr` under `contracts.<name>` for the current chain, only during a broadcast.
    function _record(string memory name, address addr) internal {
        if (!_isBroadcast()) {
            console.log("Dry run: deployments file not written for", name);
            return;
        }
        _write(block.chainid, name, addr);
    }

    /// @dev Creates the chain file if needed, then sets `contracts.<name>.address`. Overwrites an earlier entry.
    function _write(uint256 chainId, string memory name, address addr) internal {
        string memory path = _path(chainId);
        if (!vm.exists(path)) {
            vm.writeJson(string.concat('{"chainId":', vm.toString(chainId), ',"contracts":{}}'), path);
        }
        string memory entry = vm.serializeAddress(name, "address", addr);
        vm.writeJson(entry, path, string.concat(".contracts.", name));
        console.log("Recorded in", path);
    }

    /// @dev File path for a chain. Virtual so tests can write to a scratch directory instead of `deployments/`.
    function _path(uint256 chainId) internal view virtual returns (string memory) {
        return string.concat(vm.projectRoot(), "/../deployments/", _chainName(chainId), ".json");
    }

    /// @dev File name per testnet. No mainnet chain has a file.
    function _chainName(uint256 chainId) internal pure returns (string memory) {
        if (chainId == BASE_SEPOLIA_ID) return "base-sepolia";
        if (chainId == ETHEREUM_SEPOLIA_ID) return "ethereum-sepolia";
        if (chainId == UNICHAIN_SEPOLIA_ID) return "unichain-sepolia";
        if (chainId == LASNA_CHAIN_ID) return "reactive-lasna";
        revert NoDeploymentFileForChain(chainId);
    }

    function _isBroadcast() internal view returns (bool) {
        return vm.isContext(VmSafe.ForgeContext.ScriptBroadcast) || vm.isContext(VmSafe.ForgeContext.ScriptResume);
    }
}
