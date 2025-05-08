// SPDX-License-Identifier: AGPL-3.0
pragma solidity 0.8.23;

import {Base4626Compounder, ERC20, SafeERC20} from "@periphery/Bases/4626Compounder/Base4626Compounder.sol";

import {IAuction} from "./interfaces/IAuction.sol";
import {IArcadiaTranche} from "./interfaces/IArcadiaTranche.sol";

contract ArcadiaLenderStrategy is Base4626Compounder {

    using SafeERC20 for ERC20;

    // ===============================================================
    // Storage
    // ===============================================================

    /// @notice Address for the auction contract
    IAuction public auction;

    // ===============================================================
    // Constructor
    // ===============================================================

    constructor(address _asset, address _vault, string memory _name) Base4626Compounder(_asset, _name, _vault) {
        asset.forceApprove(IArcadiaTranche(_vault).LENDING_POOL(), type(uint256).max);
    }

    // ===============================================================
    // Management functions
    // ===============================================================

    /// @notice Set the auction contract
    /// @param _auction The new auction contract
    function setAuction(
        IAuction _auction
    ) external onlyManagement {
        require(_auction.receiver() == address(this), "!receiver");
        require(_auction.want() == asset, "!want");
        auction = _auction;
    }

    // ===============================================================
    // Keeper functions
    // ===============================================================

    /// @notice Kicks off an auction
    /// @param _token The address of the token to be auctioned
    /// @return The available amount for bidding on in the auction
    function kickAuction(
        ERC20 _token
    ) external onlyKeepers returns (uint256) {
        require(_token != asset && address(_token) != address(vault), "!_token");

        uint256 _toAuction = _token.balanceOf(address(this));
        require(_toAuction > 0, "!_toAuction");

        IAuction _auction = auction;
        _token.safeTransfer(address(_auction), _toAuction);
        return _auction.kick(_token);
    }

}
