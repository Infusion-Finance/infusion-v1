// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

interface ITokenLocker {
    function getDay() external view returns (uint256);
    function dailyWeight(
        address user,
        uint256 day
    ) external view returns (uint256, uint256);
    function startTime() external view returns (uint256);
    function stakingToken() external view returns (address);
}
