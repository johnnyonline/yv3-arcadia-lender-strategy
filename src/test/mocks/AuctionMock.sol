// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.18;

contract AuctionMock {

    address private _want;
    address private _receiver;

    constructor(
        address want_
    ) {
        _want = want_;
    }

    function setReceiver(
        address receiver_
    ) external {
        _receiver = receiver_;
    }

    function setWant(
        address want_
    ) external {
        _want = want_;
    }

    function kick(
        address
    ) external pure returns (uint256) {
        return 0;
    }

    function receiver() external view returns (address) {
        return _receiver == address(0) ? msg.sender : _receiver;
    }

    function want() external view returns (address) {
        return _want;
    }

}
