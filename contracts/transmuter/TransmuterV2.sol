// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.7.6;
pragma abicoder v2;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {IERC20Permit} from "@openzeppelin/contracts/drafts/IERC20Permit.sol";
import {TransferHelper} from "@uniswap/lib/contracts/libraries/TransferHelper.sol";
import {Clones} from "@openzeppelin/contracts/proxy/Clones.sol";

import {IAludel} from "../aludel/Aludel.sol";
import {IUniversalVault} from "../crucible/Crucible.sol";
import {IFactory} from "../factory/IFactory.sol";

/// @title TransmuterV2
contract TransmuterV2 {
    function mintCrucibleAndStake(
        address aludel,
        address crucibleFactory,
        uint256 amount,
        bytes32 salt,
        bytes calldata permission
    ) external returns (address vault) {

        // create vault using delegatecall
        vault = _createVault(crucibleFactory, salt);
        // get staking token
        address stakingToken = IAludel(aludel).getAludelData().stakingToken;
        // transfer tokens
        TransferHelper.safeTransferFrom(stakingToken, msg.sender, vault, amount);
        // stake
        IAludel(aludel).stake(vault, amount, permission);
    }

    struct Permit {
        address owner;
        address spender;
        uint256 value;
        uint256 deadline;
        uint8 v;
        bytes32 r;
        bytes32 s;
    }

    /// @notice Delegatecall the crucible factory to mint the crucible directly to msg.sender
    function _createVault(address crucibleFactory, bytes32 salt) internal returns (address) {
        // create vault through delegate call
        (bool success, bytes memory data) = crucibleFactory.delegatecall(
            abi.encodeWithSelector(IFactory.create2.selector, "", salt)
        );
        require(success);
        return abi.decode(data, (address)); 
    }

    function mintCruciblePermitAndStake(
        address aludel,
        address crucibleFactory,
        bytes32 salt,
        Permit calldata permit,
        bytes calldata permission
    ) external returns (address vault) {
        // create vault using delegatecall
        vault = _createVault(crucibleFactory, salt);
        // permit and stake
        permitAndStake(aludel, vault, permit, permission);
        // return vault
        return vault;
    }

    function permitAndStake(
        address aludel,
        address vault,
        Permit calldata permit,
        bytes calldata permission
    ) public {
        // get staking token
        address stakingToken = IAludel(aludel).getAludelData().stakingToken;
        // permit transfer
        IERC20Permit(stakingToken).permit(
            permit.owner,
            permit.spender,
            permit.value,
            permit.deadline,
            permit.v,
            permit.r,
            permit.s
        );
        // transfer tokens
        TransferHelper.safeTransferFrom(stakingToken, msg.sender, vault, permit.value);
        // stake
        IAludel(aludel).stake(vault, permit.value, permission);
    }

    struct StakeRequest {
        address aludel;
        address vault;
        uint256 amount;
        bytes permission;
    }

    function stakeMulti(StakeRequest[] calldata requests) external {
        for (uint256 index = 0; index < requests.length; index++) {
            StakeRequest calldata request = requests[index];
            IAludel(request.aludel).stake(request.vault, request.amount, request.permission);
        }
    }

    struct UnstakeRequest {
        address aludel;
        address vault;
        uint256 amount;
        bytes permission;
    }

    function unstakeMulti(UnstakeRequest[] calldata requests) external {
        for (uint256 index = 0; index < requests.length; index++) {
            UnstakeRequest calldata request = requests[index];
            IAludel(request.aludel).unstakeAndClaim(
                request.vault,
                request.amount,
                request.permission
            );
        }
    }

    function predictDeterministicAddress(
        address master,
        bytes32 salt,
        address deployer
    ) external pure returns (address instance) {
        return Clones.predictDeterministicAddress(master, salt, deployer);
    }
}