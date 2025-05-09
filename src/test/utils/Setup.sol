// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.18;

import {IERC4626} from "@openzeppelin/contracts/interfaces/IERC4626.sol";

import "forge-std/console2.sol";
import {ExtendedTest} from "./ExtendedTest.sol";

import {ArcadiaLenderStrategy as Strategy, ERC20} from "../../Strategy.sol";
import {StrategyFactory} from "../../StrategyFactory.sol";
import {IStrategyInterface} from "../../interfaces/IStrategyInterface.sol";

import {AuctionMock} from "../mocks/AuctionMock.sol";

// Inherit the events so they can be checked if desired.
import {IEvents} from "@tokenized-strategy/interfaces/IEvents.sol";

interface IFactory {

    function governance() external view returns (address);

    function set_protocol_fee_bps(
        uint16
    ) external;

    function set_protocol_fee_recipient(
        address
    ) external;

}

contract Setup is ExtendedTest, IEvents {

    // Addresses for different contracts we will use repeatedly.
    IERC4626 public vault = IERC4626(0x393893caeB06B5C16728bb1E354b6c36942b1382); // arcadia weth lender vault
    address public shitcoin = address(0x568eb42245121219cCf12D2b6458123A8303356D); // BODEN

    // Contract instances that we will use repeatedly.
    ERC20 public asset;
    IStrategyInterface public strategy;
    AuctionMock public auction;

    StrategyFactory public strategyFactory;

    mapping(string => address) public tokenAddrs;

    // Addresses for different roles we will use repeatedly.
    address public user = address(10);
    address public keeper = address(4);
    address public management = address(1);
    address public performanceFeeRecipient = address(3);
    address public emergencyAdmin = address(5);

    // Address of the real deployed Factory
    address public factory;

    // Integer variables that will be used repeatedly.
    uint256 public decimals;
    uint256 public MAX_BPS = 10_000;

    // Fuzz from $1 of 1e6 stable coins up to 1 trillion of a 1e18 coin
    uint256 public maxFuzzAmount = 1e30;
    uint256 public minFuzzAmount = 1_000_000;

    // Default profit max unlock time is set for 10 days
    uint256 public profitMaxUnlockTime = 10 days;

    function setUp() public virtual {
        _setTokenAddrs();

        // Set asset
        asset = ERC20(vault.asset());

        // Set decimals
        decimals = asset.decimals();

        strategyFactory = new StrategyFactory(management, performanceFeeRecipient, keeper, emergencyAdmin);

        // Deploy strategy and set variables
        strategy = IStrategyInterface(setUpStrategy());
        auction = new AuctionMock(vault.asset());

        factory = strategy.FACTORY();

        // label all the used addresses for traces
        vm.label(keeper, "keeper");
        vm.label(factory, "factory");
        vm.label(address(asset), "asset");
        vm.label(management, "management");
        vm.label(address(strategy), "strategy");
        vm.label(performanceFeeRecipient, "performanceFeeRecipient");
    }

    function setUpStrategy() public returns (address) {
        // we save the strategy as a IStrategyInterface to give it the needed interface
        IStrategyInterface _strategy =
            IStrategyInterface(address(strategyFactory.newStrategy(address(vault), "Tokenized Strategy")));

        vm.prank(management);
        _strategy.acceptManagement();

        return address(_strategy);
    }

    function depositIntoStrategy(IStrategyInterface _strategy, address _user, uint256 _amount) public {
        vm.prank(_user);
        asset.approve(address(_strategy), _amount);

        vm.prank(_user);
        _strategy.deposit(_amount, _user);
    }

    function mintAndDepositIntoStrategy(IStrategyInterface _strategy, address _user, uint256 _amount) public {
        airdrop(asset, _user, _amount);
        depositIntoStrategy(_strategy, _user, _amount);
    }

    // For checking the amounts in the strategy
    function checkStrategyTotals(
        IStrategyInterface _strategy,
        uint256 _totalAssets,
        uint256 _totalDebt,
        uint256 _totalIdle
    ) public {
        uint256 _assets = _strategy.totalAssets();
        uint256 _balance = ERC20(_strategy.asset()).balanceOf(address(_strategy));
        uint256 _idle = _balance > _assets ? _assets : _balance;
        uint256 _debt = _assets - _idle;
        assertEq(_assets, _totalAssets, "!totalAssets");
        assertEq(_debt, _totalDebt, "!totalDebt");
        assertEq(_idle, _totalIdle, "!totalIdle");
        assertEq(_totalAssets, _totalDebt + _totalIdle, "!Added");
    }

    function airdrop(ERC20 _asset, address _to, uint256 _amount) public {
        uint256 balanceBefore = _asset.balanceOf(_to);
        deal(address(_asset), _to, balanceBefore + _amount);
    }

    function setFees(uint16 _protocolFee, uint16 _performanceFee) public {
        address gov = IFactory(factory).governance();

        // Need to make sure there is a protocol fee recipient to set the fee.
        vm.prank(gov);
        IFactory(factory).set_protocol_fee_recipient(gov);

        vm.prank(gov);
        IFactory(factory).set_protocol_fee_bps(_protocolFee);

        vm.prank(management);
        strategy.setPerformanceFee(_performanceFee);
    }

    // function simulateMaxBorrow() public {
    //     ISilo _silo1 = ISilo(siloLendToken); // borrow from
    //     ISilo _silo0 = ISilo(siloCollateralToken); // deposit to

    //     address _usefulWhale = address(420);
    //     vm.startPrank(_usefulWhale);

    //     // Deposit collateral
    //     uint256 _collateralAmount = 1e30; // 1 trillion S
    //     airdrop(ERC20(_silo0.asset()), _usefulWhale, _collateralAmount);
    //     ERC20(_silo0.asset()).approve(address(_silo0), _collateralAmount);
    //     _silo0.deposit(_collateralAmount, _usefulWhale);

    //     // Borrow
    //     uint256 _borrowAmount = _silo1.getLiquidity();
    //     _silo1.borrow(_borrowAmount, _usefulWhale, _usefulWhale);
    //     vm.stopPrank();

    //     // make sure utilization is 100%
    //     assertEq(_silo1.getLiquidity(), 0, "!getLiquidity");
    // }

    // function unwindSimulateMaxBorrow() public {
    //     ISilo _silo1 = ISilo(siloLendToken); // borrow from

    //     address _usefulWhale = address(420);
    //     vm.startPrank(_usefulWhale);

    //     // Repay
    //     uint256 _sharesToRepay = _silo1.maxRepayShares(_usefulWhale);
    //     uint256 _assetsToRepay = _silo1.previewRepayShares(_sharesToRepay);
    //     airdrop(asset, _usefulWhale, _assetsToRepay);
    //     asset.approve(address(_silo1), _assetsToRepay);
    //     _silo1.repayShares(_assetsToRepay, _usefulWhale);

    //     vm.stopPrank();
    // }

    function _setTokenAddrs() internal {
        tokenAddrs["WBTC"] = 0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599;
        tokenAddrs["YFI"] = 0x0bc529c00C6401aEF6D220BE8C6Ea1667F6Ad93e;
        tokenAddrs["WETH"] = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
        tokenAddrs["LINK"] = 0x514910771AF9Ca656af840dff83E8264EcF986CA;
        tokenAddrs["USDT"] = 0xdAC17F958D2ee523a2206206994597C13D831ec7;
        tokenAddrs["DAI"] = 0x6B175474E89094C44Da98b954EedeAC495271d0F;
        tokenAddrs["USDC"] = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    }

}
