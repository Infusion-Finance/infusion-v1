// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

interface ILockFactory {
    function getInitFeeDistributor() external view returns (address);
    function getInitTokenLocker()
        external
        view
        returns (address, uint256, uint256);
    function createLock(
        address pair,
        uint256 lockerFeesP
    ) external returns (address);
}
