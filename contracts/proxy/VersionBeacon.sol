// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {Address} from "@openzeppelin/contracts/utils/Address.sol";

import "forge-std/console2.sol";

interface IVersionBeacon {
    error InvalidVersion();
    error InvalidImplementation();

    function getImplementation(uint256 version) external view returns (address implementation);

    function getLatestVersion() external view returns (uint256 latest);
}

contract VersionBeacon is IVersionBeacon, Ownable {
    // map version => implementation address
    mapping(uint256 => address) private _implementations;

    // version 0 always points to the latest implementation.
    uint256 private _latest;

    // map version => version description string
    mapping(uint256 => string) private _descriptions;

    constructor(address implementation) {
        _upgrade(implementation, "base version");
    }

    // external setters

    function upgrade(address newImplementation, string memory description) external onlyOwner {
        // TODO : check for duplicates?
        _upgrade(newImplementation, description);
    }

    // external getters

    function getImplementation(uint256 version) public view override returns (address implementation) {
        // version 0 is treated as default and points to latest
        if (version == 0) {
            return _implementations[_latest];
        } else {
            if (version > _latest) {
                revert InvalidVersion();
            }
            // TODO : should check if version exists before return it?
            return _implementations[version];
        }
    }

    function getLatestVersion() external view override returns (uint256 latest) {
        return _latest;
    }

    function getVersionDescription(uint256 version) external view returns (string memory) {
        return _descriptions[version];
    }

    // internal setters

    function _upgrade(address newImplementation, string memory description) private {
        console2.log(_descriptions[1]);
        if (!Address.isContract(newImplementation)) {
            revert InvalidImplementation();
        }
        _latest++;
        _implementations[_latest] = newImplementation;
        _descriptions[_latest] = description;
    }
}
