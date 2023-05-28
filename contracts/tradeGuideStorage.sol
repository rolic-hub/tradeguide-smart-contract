// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.4;

contract TradeGuideStorage {
    // This example swaps DAI/WETH9 for single path swaps and DAI/WMATIC/WETH9 for multi path swaps.

    address public constant WETH = 0xA6FA4fB5f76172d178d61B04b0ecd319C5d1C0aa;
    address public constant WMATIC = 0x9c3C9283D3e44854697Cd22D3Faa240Cfb032889;
    address public constant USDC = 0xe9DcE89B076BA6107Bb64EF30678efec11939234;

    // For this example, we will set the pool fee to 0.3%.
    uint24 public constant poolFee = 3000;
    uint256 public totalOfTrades = 0;
    uint256 public users;

    enum TradeState {
        ONGOING,
        COMPLETED
    }

    struct User {
        address user;
        string image;
        string name;
    }

    struct TradeLog {
        address trader;
        uint256 timeStamp;
        int256 buyPrice;
        TradeState _tradeState;
        uint256 upkeepID;
        int256 sl;
        int256 tp;
    }

    TradeLog[] public trades;

    mapping(address => address[]) public subscribers;
    mapping(address => uint256) public noOfSubscribers;
    mapping(address => uint256) public noOfTrades;
    mapping(address => uint) public addressToUpkeepId;
    mapping(address => User) public userProfile;
    mapping (address => uint) subscribersFee;
    mapping(address => mapping(address => uint256)) public balances;

    event Swapped(address _tokenIn, uint256 _price);
    event UpkeepID(uint256 indexed upkeedId);
}
