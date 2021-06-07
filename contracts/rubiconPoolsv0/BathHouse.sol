/// @author Benjamin Hughes - Rubicon
/// @notice This contract acts as the admin for the Rubicon Pools system
/// @notice The BathHouse approves strategist contracts and initializes bathPairs

pragma solidity =0.5.16;

import "./BathPair.sol";

contract BathHouse {
    string public name = "Rubicon Bath House";

    address[] public allBathPairs;
    mapping(address => mapping(address => address)) public getPair;

    address public admin;
    address public RubiconMarketAddress;

    // List of approved strategies
    mapping(address => bool) approvedStrategies;
    mapping(address => bool) approvedBathTokens;
    mapping(address => bool) approvedPairs;
    mapping(address => bool) bathQuoteExists;
    mapping(address => bool) bathAssetExists;
    mapping(address => address) quoteToBathQuote;
    mapping(address => address) assetToBathAsset;

    bool public initialized;

    // Key, system-wide risk parameters for Pools
    uint256 public reserveRatio; // proportion of the pool that must remain present in the pair

    // The delay after which unfilled orders are cancelled
    uint256 public timeDelay;

    // Constraint variable for the max amount of outstanding market making pairs at a time
    uint256 public maxOutstandingPairCount;

    function initialize(address market, uint _reserveRatio, uint _timeDelay, uint mopc) public {
        require(!initialized);
        admin = msg.sender;
        
        timeDelay = _timeDelay;
        require(_reserveRatio <= 100);
        require(_reserveRatio > 0);
        reserveRatio = _reserveRatio;

        maxOutstandingPairCount = mopc;

        RubiconMarketAddress = market;
        initialized = true;
    }

    modifier onlyAdmin {
        require(msg.sender == admin);
        _;
    }

    function setCancelTimeDelay(uint256 value) public onlyAdmin {
        timeDelay = value;
    }

    function setMaxOutstandingPairCount(uint256 value) public onlyAdmin {
        maxOutstandingPairCount = value;
    }

    function getMarket() public view returns(address) {
        return RubiconMarketAddress;
    }

    function initBathPair(
        address asset,
        // string calldata assetName,
        address quote,
        // string calldata quoteName,
        // uint256 _reserveRatio,
        // uint256 _timeDelay,
        // uint256 _maxOutstandingPairCount
        address pair
    ) external onlyAdmin returns (address newPair) {
        //calls initialize on two Bath Tokens and spins them up
        require(asset != quote);
        require(asset != address(0));
        require(quote != address(0));
        require(getPair[asset][quote] == address(0));
        allBathPairs.push(address(pair));

        getPair[asset][quote] = address(pair);

        approvePair(address(pair));
        addQuote(quote, BathPair(pair).getThisBathQuote());
        return address(pair);
    }

    function getBathPair(address asset, address quote)
        public
        view
        returns (address pair)
    {
        return getPair[asset][quote];
    }

    function isApprovedStrat(address strategy) external view returns (bool) {
        if (approvedStrategies[strategy] == true) {
            return true;
        } else {
            return false;
        }
    }

    function approveStrategy(address strategy)
        external
        onlyAdmin
        returns (bool)
    {
        approvedStrategies[strategy] = true;
    }

    function isApprovedBathToken(address bathToken) external view returns (bool) {
        if (approvedBathTokens[bathToken] == true) {
            return true;
        } else {
            return false;
        }
    }

    function approveBathToken(address bathToken)
        external
        onlyAdmin
        returns (bool)
    {
        approvedBathTokens[bathToken] = true;
    }

    function isApprovedPair(address pair) external view returns (bool) {
        if (approvedPairs[pair] == true) {
            return true;
        } else {
            return false;
        }
    }

    function approvePair(address pair) internal {
        approvedPairs[pair] = true;
    }

    function addQuote(address quote, address bathQuote) internal {
        if (bathQuoteExists[quote]) {
            return;
        } else {
            bathQuoteExists[quote] = true;
            quoteToBathQuote[quote] = bathQuote;
        }
    }

    function addAsset(address asset, address bathAsset) internal {
        if (bathAssetExists[asset]) {
            return;
        } else {
            bathAssetExists[asset] = true;
            assetToBathAsset[asset] = bathAsset;
        }
    }

    function doesQuoteExist(address quote) public view returns (bool) {
        return bathQuoteExists[quote];
    }

    function doesAssetExist(address asset) public view returns (bool) {
        return bathAssetExists[asset];
    }

    function quoteToBathQuoteCheck(address quote)
        public
        view
        returns (address)
    {
        return quoteToBathQuote[quote];
    }
}
