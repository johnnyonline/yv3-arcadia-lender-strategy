// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.18;

import {AprOracleBase} from "@periphery/AprOracle/AprOracleBase.sol";

import {IStrategyInterface} from "../interfaces/IStrategyInterface.sol";
import {IArcadiaLendingPool} from "../interfaces/IArcadiaLendingPool.sol";

contract StrategyAprOracle is AprOracleBase {

    // ===============================================================
    // Constants
    // ===============================================================

    /// @notice The unit for fixed point numbers with 4 decimals precision. Forked from Arcadia's codebase.
    uint256 private constant ONE_4 = 10_000;

    // ===============================================================
    // Constructor
    // ===============================================================

    constructor() AprOracleBase("Arcadia Lender Strategy APR Oracle", msg.sender) {}

    // ===============================================================
    // View functions
    // ===============================================================

    /**
     * @notice Will return the expected Apr of a strategy post a debt change.
     * @dev _delta is a signed integer so that it can also represent a debt
     * decrease.
     *
     * This should return the annual expected return at the current timestamp
     * represented as 1e18.
     *
     *      ie. 10% == 1e17
     *
     * _delta will be == 0 to get the current apr.
     *
     * This will potentially be called during non-view functions so gas
     * efficiency should be taken into account.
     *
     * @param _strategy The token to get the apr for.
     * @param _delta The difference in debt.
     * @return . The expected apr for the strategy represented as 1e18.
     */
    function aprAfterDebtChange(address _strategy, int256 _delta) external view override returns (uint256) {
        IArcadiaLendingPool _pool = IArcadiaLendingPool(IStrategyInterface(_strategy).ARCADIA_LENDING_POOL());
        uint256 _utilisation = _calcUtilisation(_delta, _pool);
        return _calcInterestRate(_utilisation, _pool) * _utilisation / ONE_4 / 10;
    }

    // ===============================================================
    // Internal functions
    // ===============================================================

    function _calcUtilisation(int256 _delta, IArcadiaLendingPool _pool) internal view returns (uint256) {
        uint256 _totalDebt = _pool.totalAssets();
        uint256 _totalAssets = _pool.totalLiquidity();
        if (_totalAssets == 0) return 0;
        if (_delta < 0) require(uint256(_delta * -1) < _totalAssets, "!delta");
        uint256 _totalAssetsAfterDelta = uint256(int256(_totalAssets) + _delta);
        uint256 _utilisation = _totalDebt * ONE_4 / _totalAssetsAfterDelta;
        return _utilisation <= ONE_4 ? _utilisation : ONE_4;
    }

    function _calcInterestRate(uint256 _utilisation, IArcadiaLendingPool _pool) internal view returns (uint256) {
        if (_pool.repayPaused()) return 0;
        (uint256 _baseRatePerYear, uint256 _lowSlopePerYear, uint256 _highSlopePerYear, uint256 _utilisationThreshold) =
            _pool.getInterestRateConfig();
        if (_utilisation >= _utilisationThreshold) {
            uint256 _lowSlopeInterest = _utilisationThreshold * _lowSlopePerYear;
            uint256 _highSlopeInterest = _utilisation - _utilisationThreshold * _highSlopePerYear;
            return (_lowSlopeInterest + _highSlopeInterest) / ONE_4 + _baseRatePerYear;
        } else {
            return _utilisation * _lowSlopePerYear / ONE_4 + _baseRatePerYear;
        }
    }

}
