// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.4;

contract TradeGuideStorage {
    // This example swaps DAI/WETH9 for single path swaps and DAI/WMATIC/WETH9 for multi path swaps.

    address public constant WETH = 0xA6FA4fB5f76172d178d61B04b0ecd319C5d1C0aa;
    address public constant WMATIC = 0x9c3C9283D3e44854697Cd22D3Faa240Cfb032889;
    address public constant USDC = 0xe9DcE89B076BA6107Bb64EF30678efec11939234;
    address public channel;

    // For this example, we will set the pool fee to 0.3%.
    uint24 public constant poolFee = 3000;
    uint256 public totalOfTrades = 0;
    uint256 public users;

    enum TradeState {
        ONGOING,
        COMPLETED
    }

    struct TradeLog {
        address trader;
        address tokenBought;
        uint256 timeStamp;
        int256 buyPrice;
        TradeState _tradeState;
        uint256 upkeepID;
        int256 sl;
        int256 tp;
    }

    TradeLog[] public trades;

    mapping(address => address[]) public subscribers;
    mapping(address => string[]) public posts;
    mapping(address => uint256) public noOfSubscribers;
    mapping(address => uint256) public noOfTrades;
    mapping(address => string) public userProfile;
    mapping(address => uint) subscribersFee;
    mapping(address => mapping(address => uint256)) public balances;

    event Swapped(address _tokenIn, uint256 _price);
    event UpkeepID(uint256 indexed upkeedId);
    event Subscribed(address to, uint amount);

    // Helper function to convert address to string
    function addressToString(
        address _address
    ) public pure returns (string memory) {
        bytes32 value = bytes32(uint256(uint160(_address)));
        bytes memory alphabet = "0123456789abcdef";

        bytes memory str = new bytes(42);
        str[0] = "0";
        str[1] = "x";
        for (uint256 i = 0; i < 20; i++) {
            str[2 + i * 2] = alphabet[uint8(value[i + 12] >> 4)];
            str[3 + i * 2] = alphabet[uint8(value[i + 12] & 0x0f)];
        }
        return string(str);
    }

    function numberToString(
        uint256 _number
    ) public pure returns (string memory) {
        if (_number == 0) {
            return "0";
        }
        uint256 temp = _number;
        uint256 digits;
        while (temp != 0) {
            digits++;
            temp /= 10;
        }
        bytes memory buffer = new bytes(digits);
        while (_number != 0) {
            digits -= 1;
            buffer[digits] = bytes1(uint8(48 + (_number % 10)));
            _number /= 10;
        }
        return string(buffer);
    }
}
