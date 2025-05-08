// SPDX-License-Identifier: AGPL-3.0
pragma solidity 0.8.23;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

interface IAuction {

    function want() external view returns (ERC20);
    function receiver() external view returns (address);
    function kick(
        ERC20 _token
    ) external returns (uint256);

}
