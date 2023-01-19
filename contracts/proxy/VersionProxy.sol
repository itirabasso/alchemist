// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Proxy} from "@openzeppelin/contracts/proxy/Proxy.sol";
import {IVersionBeacon} from "./VersionBeacon.sol";
import {Initializable} from "@openzeppelin/contracts/proxy/utils/Initializable.sol";

/// @dev using EIP-1822 and EIP-1967 patterns
/// https://eips.ethereum.org/EIPS/eip-1822
/// https://eips.ethereum.org/EIPS/eip-1967
contract VersionProxy is Initializable, Proxy {
    bytes32 internal constant _BEACON_SLOT = bytes32(uint256(keccak256("eip1967.proxy.beacon")) - 1);
    bytes32 internal constant _VERSION_SLOT = bytes32(uint256(keccak256("eip1967.proxy.version")) - 1);

    bytes32 internal constant _BEACON_AND_VERSION_SLOT =
        bytes32(uint256(keccak256("eip1967.proxy.beaconAndVersion")) - 1);
    bytes32 internal constant _ADMIN_SLOT = bytes32(uint256(keccak256("eip1967.proxy.admin")) - 1);

    // todo : check for func selector clash
    function initializeProxy(address beacon, uint96 version, address owner, bytes memory data) public initializer {
        bytes32 beaconAndVersionSlot = _BEACON_AND_VERSION_SLOT;
        bytes32 adminSlot = _ADMIN_SLOT;

        bytes32 value;
        // solhint-disable-next-line no-inline-assembly
        assembly {
            value := or(shl(160, version), beacon)
            sstore(beaconAndVersionSlot, value)
            sstore(adminSlot, owner)
        }

        (bool success, bytes memory ret) = _implementation().delegatecall(data);
        require(success);
    }

    // internal getters

    function _beacon() internal view virtual returns (address beacon) {
        // bytes32 slot = _BEACON_AND_VERSION_SLOT;
        bytes32 slot = _BEACON_SLOT;
        // solhint-disable-next-line no-inline-assembly
        // assembly {
        //     // beacon := and(sload(slot), 0xffffffffffffffffffffffffffffffffffffffff)
        //     // beacon := shr(shl(sload(slot), 96), 160)
        //     beacon := sload(slot)
        // }
        assembly {
            // beacon := sload(slot)
            beacon := shr(96, shl(96, sload(slot)))
        }
    }

    function _version() internal view virtual returns (uint96 version) {
        // bytes32 slot = _BEACON_AND_VERSION_SLOT;
        bytes32 slot = _VERSION_SLOT;
        // solhint-disable-next-line no-inline-assembly
        // assembly {
        //     // version := shr(sload(slot), 160)
        //     version := sload(slot)
        // }
        assembly {
            // version := sload(slot)
            version := shr(160, sload(slot))
        }
    }

    function _beaconAndVersion() internal view virtual returns (uint96 version, address beacon) {
        bytes32 slot = _BEACON_AND_VERSION_SLOT;
        // solhint-disable-next-line no-inline-assembly
        bytes32 value;
        // bytes32 v2;
        assembly {
            value := sload(slot)
            beacon := shr(96, shl(96, value))
            version := shr(160, value)
        }
    }

    // internal overrides

    function _implementation() internal view virtual override returns (address implementation) {
        (uint96 version, address beacon) = _beaconAndVersion();
        return IVersionBeacon(beacon).getImplementation(version);
    }
}
