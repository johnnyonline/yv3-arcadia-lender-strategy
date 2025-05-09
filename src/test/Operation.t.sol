// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.18;

import "forge-std/console2.sol";
import {Setup, ERC20, IStrategyInterface} from "./utils/Setup.sol";

contract OperationTest is Setup {

    function setUp() public virtual override {
        super.setUp();
    }

    function test_setupStrategyOK() public {
        console2.log("address of strategy", address(strategy));
        assertTrue(address(0) != address(strategy));
        assertEq(strategy.asset(), address(asset));
        assertEq(strategy.management(), management);
        assertEq(strategy.performanceFeeRecipient(), performanceFeeRecipient);
        assertEq(strategy.keeper(), keeper);
        assertEq(strategy.vault(), address(vault));
        assertEq(strategy.balanceOfAsset(), 0);
        assertEq(strategy.balanceOfVault(), 0);
        assertEq(strategy.balanceOfStake(), 0);
        assertEq(strategy.valueOfVault(), 0);
        assertEq(strategy.vaultsMaxWithdraw(), 0);
        assertEq(strategy.auction(), address(0));
        assertEq(strategy.ARCADIA_LENDING_POOL(), lendingPool);
    }

    function test_operation(
        uint256 _amount
    ) public {
        vm.assume(_amount > minFuzzAmount && _amount < maxFuzzAmount);

        // Deposit into strategy
        mintAndDepositIntoStrategy(strategy, user, _amount);

        assertEq(strategy.totalAssets(), _amount, "!totalAssets");

        // Earn Interest
        skip(1 days);

        // Report profit
        vm.prank(keeper);
        (uint256 profit, uint256 loss) = strategy.report();

        // Check return Values
        assertGe(profit, 0, "!profit");
        assertEq(loss, 0, "!loss");

        skip(strategy.profitMaxUnlockTime());

        uint256 balanceBefore = asset.balanceOf(user);

        // Withdraw all funds
        vm.prank(user);
        strategy.redeem(_amount, user, user);

        assertGe(asset.balanceOf(user), balanceBefore + _amount, "!final balance");
    }

    function test_profitableReport(uint256 _amount, uint16 _profitFactor) public {
        vm.assume(_amount > minFuzzAmount && _amount < maxFuzzAmount);
        _profitFactor = uint16(bound(uint256(_profitFactor), 10, MAX_BPS / 10));

        // Deposit into strategy
        mintAndDepositIntoStrategy(strategy, user, _amount);

        assertEq(strategy.totalAssets(), _amount, "!totalAssets");

        // Earn Interest
        skip(1 days);

        uint256 toAirdrop = (_amount * _profitFactor) / MAX_BPS;
        airdrop(asset, address(strategy), toAirdrop);

        // Report profit
        vm.prank(keeper);
        (uint256 profit, uint256 loss) = strategy.report();

        // Check return Values
        assertGe(profit, toAirdrop, "!profit");
        assertEq(loss, 0, "!loss");

        skip(strategy.profitMaxUnlockTime());

        uint256 balanceBefore = asset.balanceOf(user);

        // Withdraw all funds
        vm.prank(user);
        strategy.redeem(_amount, user, user);

        assertGe(asset.balanceOf(user), balanceBefore + _amount, "!final balance");
    }

    function test_profitableReport_withFees(uint256 _amount, uint16 _profitFactor) public {
        vm.assume(_amount > minFuzzAmount && _amount < maxFuzzAmount);
        _profitFactor = uint16(bound(uint256(_profitFactor), 10, MAX_BPS / 10));

        // Set protocol fee to 0 and perf fee to 10%
        setFees(0, 1000);

        // Deposit into strategy
        mintAndDepositIntoStrategy(strategy, user, _amount);

        assertEq(strategy.totalAssets(), _amount, "!totalAssets");

        // Earn Interest
        skip(1 days);

        uint256 toAirdrop = (_amount * _profitFactor) / MAX_BPS;
        airdrop(asset, address(strategy), toAirdrop);

        // Report profit
        vm.prank(keeper);
        (uint256 profit, uint256 loss) = strategy.report();

        // Check return Values
        assertGe(profit, toAirdrop, "!profit");
        assertEq(loss, 0, "!loss");

        skip(strategy.profitMaxUnlockTime());

        // Get the expected fee
        uint256 expectedShares = (profit * 1000) / MAX_BPS;

        assertEq(strategy.balanceOf(performanceFeeRecipient), expectedShares);

        uint256 balanceBefore = asset.balanceOf(user);

        // Withdraw all funds
        vm.prank(user);
        strategy.redeem(_amount, user, user);

        assertGe(asset.balanceOf(user), balanceBefore + _amount, "!final balance");

        vm.prank(performanceFeeRecipient);
        strategy.redeem(expectedShares, performanceFeeRecipient, performanceFeeRecipient);

        checkStrategyTotals(strategy, 0, 0, 0);

        assertGe(asset.balanceOf(performanceFeeRecipient), expectedShares, "!perf fee out");
    }

    function test_tendTrigger(
        uint256 _amount
    ) public {
        vm.assume(_amount > minFuzzAmount && _amount < maxFuzzAmount);

        (bool trigger,) = strategy.tendTrigger();
        assertTrue(!trigger);

        // Deposit into strategy
        mintAndDepositIntoStrategy(strategy, user, _amount);

        (trigger,) = strategy.tendTrigger();
        assertTrue(!trigger);

        // Skip some time
        skip(1 days);

        (trigger,) = strategy.tendTrigger();
        assertTrue(!trigger);

        vm.prank(keeper);
        strategy.report();

        (trigger,) = strategy.tendTrigger();
        assertTrue(!trigger);

        // Unlock Profits
        skip(strategy.profitMaxUnlockTime());

        (trigger,) = strategy.tendTrigger();
        assertTrue(!trigger);

        vm.prank(user);
        strategy.redeem(_amount, user, user);

        (trigger,) = strategy.tendTrigger();
        assertTrue(!trigger);
    }

    function test_auction(
        uint256 _amount
    ) public {
        vm.assume(_amount > minFuzzAmount && _amount < maxFuzzAmount);

        vm.expectRevert("!keeper");
        strategy.kickAuction(address(asset));

        vm.startPrank(management);
        strategy.setAuction(address(auction));
        assertEq(address(strategy.auction()), address(auction));

        auction.setReceiver(management);
        vm.expectRevert("!receiver");
        strategy.setAuction(address(auction));
        auction.setReceiver(address(0));

        auction.setWant(address(vault));
        vm.expectRevert("!want");
        strategy.setAuction(address(auction));
        vm.stopPrank();

        vm.expectRevert("!keeper");
        strategy.kickAuction(shitcoin);

        vm.startPrank(keeper);
        vm.expectRevert("!_toAuction");
        strategy.kickAuction(shitcoin);

        airdrop(ERC20(shitcoin), address(strategy), _amount);
        strategy.kickAuction(shitcoin);
        assertEq(ERC20(shitcoin).balanceOf(address(strategy)), 0);
        assertEq(ERC20(shitcoin).balanceOf(address(auction)), _amount);
    }

    // function test_operation_maxUtilization(
    //     uint256 _amount
    // ) public {
    //     vm.assume(_amount > minFuzzAmount && _amount < maxFuzzAmount);

    //     // Deposit into strategy
    //     mintAndDepositIntoStrategy(strategy, user, _amount);

    //     assertEq(strategy.totalAssets(), _amount, "!totalAssets");
    //     assertEq(strategy.maxRedeem(user), _amount, "!maxRedeem");

    //     // Simulate max borrow so utilization is 100%
    //     simulateMaxBorrow();

    //     assertEq(strategy.maxRedeem(user), 0, "!maxRedeem==0");

    //     // Revert on redeem
    //     vm.prank(user);
    //     vm.expectRevert("ERC4626: redeem more than max");
    //     strategy.redeem(_amount, user, user);

    //     // Unwind borrow position
    //     unwindSimulateMaxBorrow();

    //     // Earn Interest
    //     skip(1 days);

    //     // Report profit
    //     vm.prank(keeper);
    //     (uint256 profit, uint256 loss) = strategy.report();

    //     // Check return Values
    //     assertGt(profit, 0, "!profit");
    //     assertEq(loss, 0, "!loss");

    //     uint256 balanceBefore = asset.balanceOf(user);

    //     // Withdraw all funds
    //     vm.prank(user);
    //     strategy.redeem(_amount, user, user);

    //     assertGe(asset.balanceOf(user), balanceBefore + _amount, "!final balance");
    // }

}
