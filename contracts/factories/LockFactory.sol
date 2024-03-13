// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "contracts/interfaces/ILockFactory.sol";
import "contracts/FeeDistributor.sol";
import "contracts/TokenLocker.sol";

contract LockFactory is ILockFactory {
    address public lockManager;
    address public pendingLockManager;
    uint256 public maxLockDays;
    address public router;

    address internal _tempL;
    address internal _tempP;
    uint256 internal _tempS;
    uint256 internal _tempM;

    mapping(address => address) public feeDistributors;
    mapping(address => address) public tokenLockers;

    event LockCreated(
        address indexed pair,
        address indexed tokenLocker,
        address indexed feeDistributor,
        uint256 lockerFeesP
    );

    constructor(uint256 _maxLockDays) {
        maxLockDays = _maxLockDays;
        lockManager = msg.sender;
    }

    function initRouter(address _router) external {
        require(router == address(0), "router is set");
        router = _router;
    }

    function setLockManager(address _lockManager) external {
        require(msg.sender == lockManager, "NOT_LM");
        pendingLockManager = _lockManager;
    }

    function acceptLockManager() external {
        require(msg.sender == pendingLockManager, "NOT_PEN_LM");
        lockManager = pendingLockManager;
    }

    function setMaxLockDays(uint256 _maxLockDays) external {
        require(msg.sender == lockManager, "NOT_LM");
        require(_maxLockDays > 0, "ZERO_DAYS");
        maxLockDays = _maxLockDays;
    }

    function getInitFeeDistributor() external view returns (address) {
        return _tempL;
    }

    function getInitTokenLocker()
        external
        view
        returns (address, uint256, uint256)
    {
        return (_tempP, _tempS, _tempM);
    }

    // Creates lock contracts for a pair.
    function createLock(
        address pair,
        uint256 lockerFeesP
    ) external returns (address feeDistributor) {
        require(msg.sender == router, "NOT_ROUTER");
        require(lockerFeesP > 0, "NO_LOCK");

        // Create TokenLocker
        bytes32 salt = keccak256(abi.encodePacked(pair));
        (_tempP, _tempS, _tempM) = (
            pair,
            (block.timestamp / 1 days) * 1 days,
            maxLockDays
        );
        _tempL = address(new TokenLocker{salt: salt}());
        // Create FeeDistributor
        feeDistributor = address(new FeeDistributor{salt: salt}());

        feeDistributors[pair] = feeDistributor;
        tokenLockers[pair] = _tempL;
        emit LockCreated(pair, _tempL, feeDistributor, lockerFeesP);
    }
}
