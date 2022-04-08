// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.4;

import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import {ERC721Enumerable} from "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";

import {IFactory} from "../factory/IFactory.sol";
import {IInstanceRegistry} from "../factory/InstanceRegistry.sol";
import {ProxyFactory} from "../factory/ProxyFactory.sol";

import {IUniversalVault} from "./Crucible.sol";

/// @title CrucibleFactory
contract CrucibleFactory is IFactory, IInstanceRegistry, ERC721Enumerable  {
    address private immutable _template;

    constructor(address template) ERC721("Alchemist Crucible v1", "CRUCIBLE-V1") {
        require(template != address(0), "CrucibleFactory: invalid template");
        _template = template;
    }

    /* registry functions */

    function isInstance(address instance) external view override returns (bool validity) {
        return ERC721._exists(uint256(uint160(instance)));
    }

    function instanceCount() external view override returns (uint256 count) {
        return ERC721Enumerable.totalSupply();
    }

    function instanceAt(uint256 index) external view override returns (address instance) {
        return address(uint160(ERC721Enumerable.tokenByIndex(index)));
    }

    /* factory functions */

    function create(bytes calldata) external override returns (address vault) {
        return create();
    }

    function create2(bytes calldata, bytes32 salt) external override returns (address vault) {
        return create2(salt);
    }

    function create() public returns (address vault) {
        // create clone and initialize
        vault = ProxyFactory._create(
            _template,
            abi.encodeWithSelector(IUniversalVault.initialize.selector)
        );

        // mint nft to caller
        ERC721._safeMint(msg.sender, uint256(uint160(vault)));

        // emit event
        emit InstanceAdded(vault);

        // explicit return
        return vault;
    }

    function create2(bytes32 salt) public returns (address vault) {
        // create clone and initialize
        vault = ProxyFactory._create2(
            _template,
            abi.encodeWithSelector(IUniversalVault.initialize.selector),
            salt
        );

        // mint nft to caller
        ERC721._safeMint(msg.sender, uint256(uint160(vault)));

        // emit event
        emit InstanceAdded(vault);

        // explicit return
        return vault;
    }

    /* getter functions */

    function getTemplate() external view returns (address template) {
        return _template;
    }
}
