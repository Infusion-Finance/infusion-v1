// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "contracts/interfaces/IPairFactory.sol";
import "contracts/Pair.sol";

contract PairFactory is IPairFactory {
    bool public isPaused;
    address public pauser;
    address public pendingPauser;

    uint256 public stableFee;
    uint256 public volatileFee;
    uint256 public constant MAX_FEE = 5; // 0.05%
    address public feeManager;
    address public pendingFeeManager;
    address public router;

    mapping(address => mapping(address => mapping(bool => address)))
        public getPair;
    address[] public allPairs;
    mapping(address => bool) public isPair; // simplified check if its a pair, given that `stable` flag might not be available in peripherals

    address internal _temp0;
    address internal _temp1;
    bool internal _temp;
    uint256 internal _tempP;
    address internal _tempF;

    event PairCreated(
        address indexed token0,
        address indexed token1,
        bool stable,
        address pair,
        uint
    );

    constructor() {
        pauser = msg.sender;
        isPaused = false;
        feeManager = msg.sender;
        stableFee = 2; // 0.02%
        volatileFee = 2;
    }

    function allPairsLength() external view returns (uint) {
        return allPairs.length;
    }

    function getPairs(
        uint256 rangeA,
        uint256 rangeB
    ) external view returns (address[] memory pairs) {
        require(rangeB <= allPairs.length && rangeA < rangeB, "INVALID_RANGE");
        pairs = new address[](rangeB - rangeA);
        for (uint256 i = rangeA; i < rangeB; ++i) {
            pairs[i - rangeA] = allPairs[i];
        }
    }

    function initRouter(address _router) external {
        require(router == address(0), "router is set");
        router = _router;
    }

    function setPauser(address _pauser) external {
        require(msg.sender == pauser);
        pendingPauser = _pauser;
    }

    function acceptPauser() external {
        require(msg.sender == pendingPauser);
        pauser = pendingPauser;
    }

    function setPause(bool _state) external {
        require(msg.sender == pauser);
        isPaused = _state;
    }

    function setFeeManager(address _feeManager) external {
        require(msg.sender == feeManager, "not fee manager");
        pendingFeeManager = _feeManager;
    }

    function acceptFeeManager() external {
        require(msg.sender == pendingFeeManager, "not pending fee manager");
        feeManager = pendingFeeManager;
    }

    function setFee(bool _stable, uint256 _fee) external {
        require(msg.sender == feeManager, "not fee manager");
        require(_fee <= MAX_FEE, "fee too high");
        require(_fee != 0, "fee must be nonzero");
        if (_stable) {
            stableFee = _fee;
        } else {
            volatileFee = _fee;
        }
    }

    function getFee(bool _stable) public view returns (uint256) {
        return _stable ? stableFee : volatileFee;
    }

    function pairCodeHash() external pure returns (bytes32) {
        return keccak256(type(Pair).creationCode);
    }

    function getInitializable()
        external
        view
        returns (address, address, bool, uint256, address)
    {
        return (_temp0, _temp1, _temp, _tempP, _tempF);
    }

    // Creates pair, if lockerFeesP != 0, then lockerFeesP percentage of LP fees will go to a feeDistributor contract.
    function createPair(
        address tokenA,
        address tokenB,
        bool stable,
        uint256 lockerFeesP,
        address feeDistributor
    ) external returns (address pair) {
        require(msg.sender == router, "NR");
        require(tokenA != tokenB, "IA"); // Pair: IDENTICAL_ADDRESSES
        (address token0, address token1) = tokenA < tokenB
            ? (tokenA, tokenB)
            : (tokenB, tokenA);
        require(token0 != address(0), "ZA"); // Pair: ZERO_ADDRESS
        require(getPair[token0][token1][stable] == address(0), "PE"); // Pair: PAIR_EXISTS - single check is sufficient
        bytes32 salt = keccak256(abi.encodePacked(token0, token1, stable)); // notice salt includes stable as well, 3 parameters
        (_temp0, _temp1, _temp, _tempP, _tempF) = (
            token0,
            token1,
            stable,
            lockerFeesP,
            feeDistributor
        );
        pair = address(new Pair{salt: salt}());
        getPair[token0][token1][stable] = pair;
        getPair[token1][token0][stable] = pair; // populate mapping in the reverse direction
        allPairs.push(pair);
        isPair[pair] = true;
        emit PairCreated(token0, token1, stable, pair, allPairs.length);
    }
}
