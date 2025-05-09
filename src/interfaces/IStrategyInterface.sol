// SPDX-License-Identifier: AGPL-3.0
pragma solidity 0.8.23;

import {IBase4626Compounder} from "@periphery/Bases/4626Compounder/IBase4626Compounder.sol";
// import {IStrategy} from "@tokenized-strategy/interfaces/IStrategy.sol";

interface IStrategyInterface is IBase4626Compounder {

    function auction() external view returns (address);
    function setAuction(
        address _auction
    ) external;
    function kickAuction(
        address _token
    ) external returns (uint256);

}
