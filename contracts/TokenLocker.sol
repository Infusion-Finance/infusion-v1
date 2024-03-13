// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "./interfaces/ILockFactory.sol";

contract TokenLocker {
    using SafeERC20 for IERC20;

    struct StreamData {
        uint256 start;
        uint256 amount;
        uint256 claimed;
    }

    struct LockData {
        uint128 weight;
        uint128 unlock;
    }

    // `dailyTotalWeight` and `dailyWeightOf` track the total lock weight for each day,
    // calculated as the sum of [number of tokens] * [days to unlock] for all active locks.
    // The array index corresponds to the number of the epoch day.
    uint128[65535] public dailyTotalWeight;

    // `dailyLockData` tracks the total lock weights and unlockable token balances for each user.
    mapping(address => LockData[65535]) dailyLockData;

    // `withdrawnUntil` tracks the most recent day for which each user has withdrawn their
    // expired token locks. Unlock values in `dailyLockData` with an index less than the related
    // value within `withdrawnUntil` have already been withdrawn.
    mapping(address => uint256) withdrawnUntil;

    // After a lock expires, a user calls to `initiateExitStream` and the withdrawable tokens
    // are streamed out linearly over the following day. This array is used to track data
    // related to the exit stream.
    mapping(address => StreamData) public exitStream;

    // when set to true, other accounts cannot call `lock` on behalf of an account
    mapping(address => bool) public blockThirdPartyActions;

    IERC20 public immutable stakingToken;

    uint256 public immutable startTime;
    uint256 public immutable MAX_LOCK_DAYS;

    event NewLock(address indexed user, uint256 amount, uint256 lockdays);
    event ExtendLock(
        address indexed user,
        uint256 amount,
        uint256 olddays,
        uint256 newdays
    );
    event NewExitStream(
        address indexed user,
        uint256 startTime,
        uint256 amount
    );
    event ExitStreamWithdrawal(
        address indexed user,
        uint256 claimed,
        uint256 remaining
    );

    constructor() {
        (
            address _stakingToken,
            uint256 _startTime,
            uint256 _maxLockDays
        ) = ILockFactory(msg.sender).getInitTokenLocker();
        MAX_LOCK_DAYS = _maxLockDays;
        stakingToken = IERC20(_stakingToken);
        // must start on the epoch day
        require((_startTime / 1 days) * 1 days == _startTime, "!epoch day");
        startTime = _startTime;
    }

    /**
        @notice Allow or block third-party calls to deposit, withdraw
                or claim rewards on behalf of the caller
     */
    function setBlockThirdPartyActions(bool _block) external {
        blockThirdPartyActions[msg.sender] = _block;
    }

    function getDay() public view returns (uint256) {
        return (block.timestamp - startTime) / 1 days;
    }

    /**
        @notice Get the current lock weight for a user
     */
    function userWeight(address _user) external view returns (uint256) {
        return dailyWeightOf(_user, getDay());
    }

    /**
        @notice Get the lock weight for a user in a given day
     */
    function dailyWeightOf(
        address _user,
        uint256 _day
    ) public view returns (uint256) {
        return uint256(dailyLockData[_user][_day].weight);
    }

    /**
        @notice Get the token balance that unlocks for a user in a given day
     */
    function dailyUnlocksOf(
        address _user,
        uint256 _day
    ) external view returns (uint256) {
        return uint256(dailyLockData[_user][_day].unlock);
    }

    /**
        @notice Get the total balance held in this contract for a user,
                including both active and expired locks
     */
    function userBalance(
        address _user
    ) external view returns (uint256 balance) {
        uint256 i = withdrawnUntil[_user] + 1;
        uint256 finish = getDay() + MAX_LOCK_DAYS + 1;
        while (i < finish) {
            balance += dailyLockData[_user][i].unlock;
            i++;
        }
        return balance;
    }

    /**
        @notice Get the current total lock weight
     */
    function totalWeight() external view returns (uint256) {
        return dailyTotalWeight[getDay()];
    }

    /**
        @notice Get the user lock weight and total lock weight for the given day
     */
    function dailyWeight(
        address _user,
        uint256 _day
    ) external view returns (uint256, uint256) {
        return (dailyWeightOf(_user, _day), dailyTotalWeight[_day]);
    }

    /**
        @notice Get data on a user's active token locks
        @param _user Address to query data for
        @return lockData dynamic array of [days until expiration, balance of lock]
     */
    function getActiveUserLocks(
        address _user
    ) external view returns (uint256[2][] memory lockData) {
        uint256 length = 0;
        uint256 day = getDay();
        uint256[] memory unlocks = new uint256[](MAX_LOCK_DAYS);
        for (uint256 i = 0; i < MAX_LOCK_DAYS; i++) {
            unlocks[i] = dailyLockData[_user][i + day + 1].unlock;
            if (unlocks[i] > 0) length++;
        }
        lockData = new uint256[2][](length);
        uint256 x = 0;
        for (uint256 i = 0; i < MAX_LOCK_DAYS; i++) {
            if (unlocks[i] > 0) {
                lockData[x] = [i + 1, unlocks[i]];
                x++;
            }
        }
        return lockData;
    }

    /**
        @notice Deposit tokens into the contract to create a new lock.
        @dev A lock is created for a given number of days. Minimum 1, maximum `MAX_LOCK_DAYS`.
             A user can have more than one lock active at a time. A user's total "lock weight"
             is calculated as the sum of [number of tokens] * [days until unlock] for all
             active locks. Fees are distributed porportionally according to a user's lock
             weight as a percentage of the total lock weight. At the start of each new day,
             each lock's days until unlock is reduced by 1. Locks that reach 0 day no longer
             receive any weight, and tokens may be withdrawn by calling `initiateExitStream`.
        @param _user Address to create a new lock for (does not have to be the caller)
        @param _amount Amount of tokens to lock. This balance transfered from the caller.
        @param _days The number of days for the lock.
     */
    function lock(
        address _user,
        uint256 _amount,
        uint256 _days
    ) external returns (bool) {
        if (msg.sender != _user) {
            require(
                !blockThirdPartyActions[_user],
                "Cannot lock on behalf of this account"
            );
        }
        require(_days > 0, "Min 1 day");
        require(_days <= MAX_LOCK_DAYS, "Exceeds MAX_LOCK_DAYS");
        require(_amount > 0, "Amount must be nonzero");

        stakingToken.safeTransferFrom(msg.sender, address(this), _amount);

        uint256 start = getDay();
        _increaseAmount(_user, start, _amount, _days, 0);

        uint256 end = start + _days;
        dailyLockData[_user][end].unlock += uint128(_amount);

        emit NewLock(_user, _amount, _days);
        return true;
    }

    /**
        @notice Extend the length of an existing lock.
        @param _amount Amount of tokens to extend the lock for. When the value given equals
                       the total size of the existing lock, the entire lock is moved.
                       If the amount is less, then the lock is effectively split into
                       two locks, with a portion of the balance extended to the new length
                       and the remaining balance at the old length.
        @param _days The number of days for the lock that is being extended.
        @param _newDays The number of days to extend the lock until.
     */
    function extendLock(
        uint256 _amount,
        uint256 _days,
        uint256 _newDays
    ) external returns (bool) {
        require(_days > 0, "Min 1 day");
        require(_newDays <= MAX_LOCK_DAYS, "Exceeds MAX_LOCK_DAYS");
        require(_days < _newDays, "newDays must be greater than days");
        require(_amount > 0, "Amount must be nonzero");

        LockData[65535] storage data = dailyLockData[msg.sender];
        uint256 start = getDay();
        uint256 end = start + _days;
        data[end].unlock -= uint128(_amount);
        end = start + _newDays;
        data[end].unlock += uint128(_amount);

        _increaseAmount(msg.sender, start, _amount, _newDays, _days);
        emit ExtendLock(msg.sender, _amount, _days, _newDays);
        return true;
    }

    /**
        @notice Create an exit stream, to withdraw tokens in expired locks over 1 day
     */
    function initiateExitStream() external returns (bool) {
        StreamData storage stream = exitStream[msg.sender];
        uint256 streamable = streamableBalance(msg.sender);
        require(streamable > 0, "No withdrawable balance");

        uint256 amount = stream.amount - stream.claimed + streamable;
        exitStream[msg.sender] = StreamData({
            start: block.timestamp,
            amount: amount,
            claimed: 0
        });
        withdrawnUntil[msg.sender] = getDay();

        emit NewExitStream(msg.sender, block.timestamp, amount);
        return true;
    }

    /**
        @notice Withdraw tokens from an active or completed exit stream
     */
    function withdrawExitStream() external returns (bool) {
        StreamData storage stream = exitStream[msg.sender];
        uint256 amount;
        if (stream.start > 0) {
            amount = claimableExitStreamBalance(msg.sender);
            if (stream.start + 1 days < block.timestamp) {
                delete exitStream[msg.sender];
            } else {
                stream.claimed = stream.claimed + amount;
            }
            stakingToken.safeTransfer(msg.sender, amount);
            emit ExitStreamWithdrawal(
                msg.sender,
                amount,
                stream.amount - stream.claimed
            );
        }
        return true;
    }

    /**
        @notice Get the amount of `stakingToken` in expired locks that is
                eligible to be released via an exit stream.
     */
    function streamableBalance(address _user) public view returns (uint256) {
        uint256 finishedDay = getDay();

        LockData[65535] storage data = dailyLockData[_user];
        uint256 amount;

        for (
            uint256 last = withdrawnUntil[_user] + 1;
            last <= finishedDay;
            last++
        ) {
            amount = amount + data[last].unlock;
        }
        return amount;
    }

    /**
        @notice Get the amount of tokens available to withdraw from the active exit stream.
     */
    function claimableExitStreamBalance(
        address _user
    ) public view returns (uint256) {
        StreamData storage stream = exitStream[_user];
        if (stream.start == 0) return 0;
        if (stream.start + 1 days < block.timestamp) {
            return stream.amount - stream.claimed;
        } else {
            uint256 claimable = (stream.amount *
                (block.timestamp - stream.start)) / 1 days;
            return claimable - stream.claimed;
        }
    }

    /**
        @dev Increase the amount within a lock weight array over a given time period
     */
    function _increaseAmount(
        address _user,
        uint256 _start,
        uint256 _amount,
        uint256 _rounds,
        uint256 _oldRounds
    ) internal {
        uint256 oldEnd = _start + _oldRounds;
        uint256 end = _start + _rounds;
        LockData[65535] storage data = dailyLockData[_user];
        for (uint256 i = _start; i < end; i++) {
            uint256 amount = _amount * (end - i);
            if (i < oldEnd) {
                amount -= _amount * (oldEnd - i);
            }
            dailyTotalWeight[i] += uint128(amount);
            data[i].weight += uint128(amount);
        }
    }
}
