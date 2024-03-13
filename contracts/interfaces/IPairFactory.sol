// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

interface IPairFactory {
    function allPairsLength() external view returns (uint);
    function isPair(address pair) external view returns (bool);
    function pairCodeHash() external pure returns (bytes32);
    function getPair(
        address tokenA,
        address token,
        bool stable
    ) external view returns (address);
    function createPair(
        address tokenA,
        address tokenB,
        bool stable,
        uint256 lockerFeesP,
        address feeDistributor
    ) external returns (address pair);
}
