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
    // Constants
    // ===============================================================

    /// @notice The address of the Arcadia lending pool
    address public immutable ARCADIA_LENDING_POOL;

    // ===============================================================
    // Constructor
    // ===============================================================

    /// @param _asset Underlying asset to use for this strategy
    /// @param _vault ERC4626 vault token to use. Arcadia Finance's share token, one recieves on borrowable deposits
    /// @param _name Name to use for this strategy. Ideally something human readable for a UI to use
    constructor(address _asset, address _vault, string memory _name) Base4626Compounder(_asset, _name, _vault) {
        ARCADIA_LENDING_POOL = IArcadiaTranche(_vault).LENDING_POOL();
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

    // ===============================================================
    // Mutated functions
    // ===============================================================

    function _deployFunds(
        uint256 _amount
    ) internal override {
        asset.forceApprove(ARCADIA_LENDING_POOL, _amount);
        vault.deposit(_amount, address(this));
    }

}
