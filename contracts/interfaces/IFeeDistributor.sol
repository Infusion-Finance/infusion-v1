// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

interface IFeeDistributor {
    function tokenLocker() external view returns (address);
}
