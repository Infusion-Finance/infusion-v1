// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "./interfaces/ITokenLocker.sol";
import "./interfaces/IPair.sol";
import "./interfaces/ILockFactory.sol";

contract FeeDistributor {
    using SafeERC20 for IERC20;

    struct StreamData {
        uint256 start;
        uint256 amount;
        uint256 claimed;
    }

    // Fees are transferred into this contract as they are collected, and in the same tokens
    // that they are collected in. The total amount collected each day is recorded in
    // `dailyFeeAmounts`. At the end of a day, the fee amounts are streamed out over
    // the following day based on each user's lock weight at the end of that day. Data
    // about the active stream for each token is tracked in `activeUserStream`

    // fee token -> day -> total amount received that day
    mapping(address => mapping(uint256 => uint256)) public dailyFeeAmounts;
    // user -> fee token -> data about the active stream
    mapping(address => mapping(address => StreamData)) activeUserStream;

    // account earning rewards => receiver of rewards for this account
    // if receiver is set to address(0), rewards are paid to the earner
    // this is used to aid 3rd party contract integrations
    mapping(address => address) public claimReceiver;

    // when set to true, other accounts cannot call `claim` on behalf of an account
    mapping(address => bool) public blockThirdPartyActions;

    uint256 public immutable startTime;
    ITokenLocker public immutable tokenLocker;
    IPair public immutable pool;

    event FeesReceived(
        address caller,
        address indexed token0,
        address indexed token1,
        uint256 indexed day,
        uint256 amount0,
        uint256 amount1
    );
    event FeesClaimed(
        address caller,
        address indexed account,
        address indexed receiver,
        address indexed token,
        uint256 amount
    );

    constructor() {
        ITokenLocker _tokenLocker = ITokenLocker(
            ILockFactory(msg.sender).getInitFeeDistributor()
        );
        tokenLocker = _tokenLocker;
        startTime = _tokenLocker.startTime();
        pool = IPair(_tokenLocker.stakingToken());
    }

    function setClaimReceiver(address _receiver) external {
        claimReceiver[msg.sender] = _receiver;
    }

    function setBlockThirdPartyActions(bool _block) external {
        blockThirdPartyActions[msg.sender] = _block;
    }

    function getDay() public view returns (uint256) {
        if (startTime == 0) return 0;
        return (block.timestamp - startTime) / 1 days;
    }

    /**
        @notice Deposit pool fees into the contract, to be distributed to LP lockers
     */
    function depositFees() external returns (bool) {
        (uint256 amount0, uint256 amount1) = pool.claimFees();
        require(amount0 != 0 || amount1 != 0, "No fees to claim from a pair");

        (address token0, address token1) = pool.tokens();
        uint256 day = getDay();

        dailyFeeAmounts[token0][day] += amount0;
        dailyFeeAmounts[token1][day] += amount1;

        emit FeesReceived(msg.sender, token0, token1, day, amount0, amount1);
        return true;
    }

    /**
        @notice Get an array of claimable amounts of accrued pool tokens fees
        @param _user Address to query claimable amounts for
     */
    function claimable(
        address _user
    ) external view returns (uint256 amount0, uint256 amount1) {
        (address token0, address token1) = pool.tokens();
        (amount0, ) = _getClaimable(_user, token0);
        (amount1, ) = _getClaimable(_user, token1);
    }

    /**
        @notice Claim accrued protocol fees according to a locked balance in `TokenLocker`.
        @dev Fees are claimable up to the end of the previous day. Claimable fees from more
             than one day ago are released immediately, fees from the previous day are streamed.
        @param _user Address to claim for. Any account can trigger a claim for any other account.
        @param _tokens Array of tokens to claim for.
        @return claimedAmounts Array of amounts claimed.
     */
    function claim(
        address _user,
        address[] calldata _tokens
    ) external returns (uint256[] memory claimedAmounts) {
        if (msg.sender != _user) {
            require(
                !blockThirdPartyActions[_user],
                "Cannot claim on behalf of this account"
            );
        }
        address receiver = claimReceiver[_user];
        if (receiver == address(0)) receiver = _user;
        claimedAmounts = new uint256[](_tokens.length);
        StreamData memory stream;
        for (uint256 i = 0; i < _tokens.length; i++) {
            address token = _tokens[i];
            (claimedAmounts[i], stream) = _getClaimable(_user, token);
            activeUserStream[_user][token] = stream;
            IERC20(token).safeTransfer(receiver, claimedAmounts[i]);
            emit FeesClaimed(
                msg.sender,
                _user,
                receiver,
                token,
                claimedAmounts[i]
            );
        }
        return claimedAmounts;
    }

    function _getClaimable(
        address _user,
        address _token
    ) internal view returns (uint256, StreamData memory) {
        uint256 claimableday = getDay();

        if (claimableday == 0) {
            // the first full day hasn't completed yet
            return (0, StreamData({start: startTime, amount: 0, claimed: 0}));
        }

        // the previous day is the claimable one
        claimableday -= 1;
        StreamData memory stream = activeUserStream[_user][_token];
        uint256 lastClaimday;
        if (stream.start == 0) {
            lastClaimday = 0;
        } else {
            lastClaimday = (stream.start - startTime) / 1 days;
        }

        uint256 amount;
        if (claimableday == lastClaimday) {
            // special case: claim is happening in the same day as a previous claim
            uint256 previouslyClaimed = stream.claimed;
            stream = _buildStreamData(_user, _token, claimableday);
            amount = stream.claimed - previouslyClaimed;
            return (amount, stream);
        }

        if (stream.start > 0) {
            // if there is a partially claimed day, get the unclaimed amount and increment
            // `lastClaimWeeek` so we begin iteration on the following day
            amount = stream.amount - stream.claimed;
            lastClaimday += 1;
        }

        // iterate over days that have passed fully without any claims
        for (uint256 i = lastClaimday; i < claimableday; i++) {
            (uint256 userWeight, uint256 totalWeight) = tokenLocker.dailyWeight(
                _user,
                i
            );
            if (userWeight == 0) continue;
            amount += (dailyFeeAmounts[_token][i] * userWeight) / totalWeight;
        }

        // add a partial amount for the active day
        stream = _buildStreamData(_user, _token, claimableday);

        return (amount + stream.claimed, stream);
    }

    function _buildStreamData(
        address _user,
        address _token,
        uint256 _day
    ) internal view returns (StreamData memory) {
        uint256 start = startTime + _day * 1 days;
        (uint256 userWeight, uint256 totalWeight) = tokenLocker.dailyWeight(
            _user,
            _day
        );
        uint256 amount;
        uint256 claimed;
        if (userWeight > 0) {
            amount = (dailyFeeAmounts[_token][_day] * userWeight) / totalWeight;
            claimed = (amount * (block.timestamp - 1 days - start)) / 1 days;
        }
        return StreamData({start: start, amount: amount, claimed: claimed});
    }
}
