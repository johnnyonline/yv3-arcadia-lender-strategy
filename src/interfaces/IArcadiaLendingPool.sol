// SPDX-License-Identifier: AGPL-3.0
pragma solidity 0.8.23;

interface IArcadiaLendingPool {

    /// @notice Returns the total amount of outstanding debt in the underlying asset.
    /// @return totalDebt The total debt in underlying assets.
    function totalAssets() external view returns (uint256);

    /// @notice Returns the total redeemable amount of liquidity in the underlying asset.
    /// @return totalLiquidity_ The total redeemable amount of liquidity in the underlying asset.
    function totalLiquidity() external view returns (uint256);

    /// @notice Flag indicating if the repay() function is paused.
    /// @return True if the repay() function is paused, false otherwise.
    function repayPaused() external view returns (bool);

    /// @notice Returns the configuration of the interest rate slopes.
    /// @return baseRatePerYear The base interest rate per year.
    /// @return lowSlopePerYear The slope of the interest rate per year when the utilization rate is below the utilization threshold.
    /// @return highSlopePerYear The slope of the interest rate per year when the utilization rate exceeds the utilization threshold.
    /// @return utilisationThreshold The utilization threshold for determining the interest rate slope change.
    function getInterestRateConfig() external view returns (uint72, uint72, uint72, uint16);

}
