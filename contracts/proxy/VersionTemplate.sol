// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Address} from "@openzeppelin/contracts/utils/Address.sol";
import {Initializable} from "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import {IVersionBeacon} from "./VersionBeacon.sol";

contract VersionTemplate is Initializable {
    bytes32 private constant _BEACON_SLOT = bytes32(uint256(keccak256("eip1967.proxy.beacon")) - 1);
    bytes32 private constant _VERSION_SLOT = bytes32(uint256(keccak256("eip1967.proxy.version")) - 1);

    bytes32 private constant _ADMIN_SLOT = bytes32(uint256(keccak256("eip1967.proxy.admin")) - 1);
    bytes32 internal constant _BEACON_AND_VERSION_SLOT =
        bytes32(uint256(keccak256("eip1967.proxy.beaconAndVersion")) - 1);

    event BeaconChanged(address previousBeacon, address newBeacon);
    event VersionChanged(uint96 previousVersion, uint96 newVersion);
    event AdminChanged(address previousAdmin, address newAdmin);

    error OnlyAdmin();
    error InvalidAddress();
    error UndefinedVersion();
    error BeaconIsNotAContract();

    function initialize(bytes memory data) external virtual initializer {}

    modifier onlyAdmin() {
        if (msg.sender != _admin()) {
            revert OnlyAdmin();
        }
        _;
    }

    // external functions

    function changeVersion(uint96 newVersion) external onlyAdmin {
        emit VersionChanged(_version(), newVersion);
        _setVersion(newVersion);
    }

    function changeVersionAndCall(uint96 newVersion, bytes calldata data) external onlyAdmin {
        emit VersionChanged(_version(), newVersion);
        _setVersion(newVersion);
        _delegateCall(data);
    }

    function changeAdmin(address newAdmin) external onlyAdmin {
        if (newAdmin == address(0)) {
            revert InvalidAddress();
        }
        emit AdminChanged(_admin(), newAdmin);
        _setAdmin(newAdmin);
    }

    // internal setters

    function _setBeacon(address beacon) private {
        if (!Address.isContract(beacon)) {
            revert BeaconIsNotAContract();
        }
        bytes32 slot = _BEACON_AND_VERSION_SLOT;

        // solhint-disable-next-line no-inline-assembly
        assembly {
            sstore(slot, or(shr(160, sload(slot)), beacon))
        }
    }

    function _setVersion(uint96 version) private {
        address beacon = _beacon();
        uint256 latest = IVersionBeacon(beacon).getLatestVersion();
        if (version > latest) {
            revert UndefinedVersion();
        }

        bytes32 slot = _BEACON_AND_VERSION_SLOT;
        // solhint-disable-next-line no-inline-assembly
        assembly {
            // sstore(slot, version)
            sstore(slot, or(shl(160, version), shr(96, shl(96, sload(slot)))))
        }
    }

    function _setAdmin(address newAdmin) private {
        bytes32 slot = _ADMIN_SLOT;
        // solhint-disable-next-line no-inline-assembly
        assembly {
            sstore(slot, newAdmin)
        }
    }

    function _delegateCall(bytes memory data) private {
        address implementation = _implementation();
        // solhint-disable-next-line avoid-low-level-calls
        (bool success,) = implementation.delegatecall(data);
        require(success);
    }

    // internal getters

    function _beacon() internal view virtual returns (address beacon) {
        bytes32 slot = _BEACON_AND_VERSION_SLOT;
        // solhint-disable-next-line no-inline-assembly
        assembly {
            // beacon := sload(slot)
            beacon := shr(96, shl(96, sload(slot)))
        }
    }

    function _version() internal view virtual returns (uint96 version) {
        bytes32 slot = _BEACON_AND_VERSION_SLOT;
        // solhint-disable-next-line no-inline-assembly
        assembly {
            // version := sload(slot)
            version := shr(160, sload(slot))
        }
    }

    function _beaconAndVersion() internal virtual returns (uint96 version, address beacon) {
        bytes32 slot = _BEACON_AND_VERSION_SLOT;
        // solhint-disable-next-line no-inline-assembly
        bytes32 value;
        assembly {
            value := sload(slot)
            beacon := shr(96, shl(96, value))
            version := shr(160, value)
        }
    }

    function _admin() internal view returns (address admin) {
        bytes32 slot = _ADMIN_SLOT;
        // solhint-disable-next-line no-inline-assembly
        assembly {
            admin := sload(slot)
        }
    }

    // internal overrides

    function _implementation() internal virtual returns (address implementation) {
        (uint96 version, address beacon) = _beaconAndVersion();
        return IVersionBeacon(beacon).getImplementation(version);
    }
}
