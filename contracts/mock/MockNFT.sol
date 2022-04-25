// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.0;

import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";

contract MockNFT is ERC721 {

    constructor() ERC721("MockNFT", "MockNFT") {   
    }
    function mint(address recipient, uint256 tokenId) external {
        ERC721._mint(recipient, tokenId);
    }
}
