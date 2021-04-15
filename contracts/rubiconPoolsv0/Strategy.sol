// contract that employs user Bath liquidity to market make and pass yield to users
/// @author Benjamin Hughes
/// @notice This represents a Stoikov market-making model designed for Rubicon...
pragma solidity ^0.5.16;

import "openzeppelin-solidity/contracts/token/ERC20/IERC20.sol";
import "./BathToken.sol";
import "../RubiconMarket.sol";
import "../peripheral_contracts/SafeMath.sol";
import "./BathHouse.sol";
import "./BathPair.sol";
import "../peripheral_contracts/ABDKMath64x64.sol";

contract Strategy {
    string public name;

    address public bathHouse;
    // address public underlyingAsset;
    // address public underlyingQuote;

    // address public bathAssetAddress;
    // address public bathQuoteAddress;

    address public RubiconMarketAddress;

    mapping(address => uint256[]) addressToHoldings;

    // security mapping to ensure only Pairs
    mapping(address => bool) approvedPairs;

    uint256[] public outstandingAskIDs;
    uint256[] public outstandingBidIDs;
    uint256[2][] public outstandingPairIDs;

    // TODO: make variable...
    int128 public maxAskSize = 1;
    int128 public maxBidSize = 1;

    event LogTrade(uint256, ERC20, uint256, ERC20);
    event LogNote(string, uint256);
    event LogAddress(string, ERC20);
    event LogNote128(string, int128);
    event BothFilled();

    struct order {
        uint256 pay_amt;
        ERC20 pay_gem;
        uint256 buy_amt;
        ERC20 buy_gem;
    }

    // order private newAsk;
    // order private newBid;

    constructor(
        string memory _name,
        address _bathHouse,
        address _rubiconMarket
    ) public {
        name = _name;
        bathHouse = _bathHouse;
        RubiconMarketAddress = _rubiconMarket;
    }

    modifier onlyPairs {
        require(
            BathHouse(bathHouse).isApprovedPair(msg.sender) == true,
            "not an approved pair"
        );
        _;
    }

    function placePairsTrade(
        // uint256 spread,
        address underlyingAsset,
        address bathAssetAddress,
        address underlyingQuote,
        address bathQuoteAddress,
        uint256 askNumerator,
        uint256 askDenomenator,
        uint256 bidNumerator,
        uint256 bidDenomenator
    ) internal {
        // 2. Calculate new bid and ask
        // (order memory bestAsk, order memory bestBid) =
        (order memory ask, order memory bid) =
            getNewOrders(
                underlyingAsset,
                underlyingQuote,
                askNumerator,
                askDenomenator,
                bidNumerator,
                bidDenomenator
            );

        // 3. place new bid and ask
        // emit LogTrade(ask.pay_amt, ask.pay_gem, ask.buy_amt, ask.buy_gem);
        // emit LogTrade(bid.pay_amt, bid.pay_gem, bid.buy_amt, bid.buy_gem);

        placeTrades(
            bathAssetAddress,
            bathQuoteAddress,
            ask,
            bid,
            underlyingAsset,
            underlyingQuote
        );
    }

    function getNewOrders(
        address underlyingAsset,
        address underlyingQuote,
        uint256 askNumerator,
        uint256 askDenominator,
        uint256 bidNumerator,
        uint256 bidDenominator
    ) internal pure returns (order memory, order memory) {
        ERC20 ERC20underlyingAsset = ERC20(underlyingAsset);
        ERC20 ERC20underlyingQuote = ERC20(underlyingQuote);

        order memory newAsk =
            order(
                askNumerator, // ...Asset amount...
                ERC20underlyingAsset,
                askDenominator, // (quote / asset ) * Asset amount
                ERC20underlyingQuote
            );
        order memory newBid =
            order(
                (bidNumerator),
                ERC20underlyingQuote,
                bidDenominator, // (asset / quote ) * Quote amount
                ERC20underlyingAsset
            );
        return (newAsk, newBid);
    }

    function placeTrades(
        address bathAssetAddress,
        address bathQuoteAddress,
        order memory ask,
        order memory bid,
        address asset,
        address quote
    ) internal returns (bool) {
        uint256 newAskID =
            BathToken(bathAssetAddress).placeOffer(
                ask.pay_amt,
                ask.pay_gem,
                ask.buy_amt,
                ask.buy_gem
            );
        emit LogTrade(ask.pay_amt, ask.pay_gem, ask.buy_amt, ask.buy_gem);

        uint256 newBidID =
            BathToken(bathQuoteAddress).placeOffer(
                bid.pay_amt,
                bid.pay_gem,
                bid.buy_amt,
                bid.buy_gem
            );
        emit LogTrade(bid.pay_amt, bid.pay_gem, bid.buy_amt, bid.buy_gem);

        address pair = BathHouse(bathHouse).getBathPair(asset, quote);
        BathPair(pair).addOutstandingPair([newAskID, newBidID, now]);
    }

    function execute(
        address underlyingAsset,
        address bathAssetAddress,
        address underlyingQuote,
        address bathQuoteAddress,
        uint256 askNumerator,
        uint256 askDenominator,
        uint256 bidNumerator,
        uint256 bidDenominator
    ) external onlyPairs returns (uint256, uint256) {
        // main function to chain the actions of a single strategic market making transaction
        require(askNumerator > 0);
        require(askDenominator > 0);
        require(bidNumerator > 0);
        require(bidDenominator > 0);

        // 2. Place pairs trade
        placePairsTrade(
            underlyingAsset,
            bathAssetAddress,
            underlyingQuote,
            bathQuoteAddress,
            askNumerator,
            askDenominator,
            bidNumerator,
            bidDenominator
        );
    }
}
