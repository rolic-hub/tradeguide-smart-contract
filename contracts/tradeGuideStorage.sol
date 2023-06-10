// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.4;

contract TradeGuideStorage {
    // This example swaps DAI/WETH9 for single path swaps and DAI/WMATIC/WETH9 for multi path swaps.

    address public USDC;
    address public channel;

    // For this example, we will set the pool fee to 0.3%.
    uint24 public constant poolFee = 3000;
    uint256 public totalOfTrades = 0;
    uint256 public users = 0;

    enum TradeState {
        ONGOING,
        COMPLETED
    }

    struct TradeLog {
        uint8 index;
        address trader;
        address tokenBought;
        uint256 timeStamp;
        int256 buyPrice;
        uint256 amount;
        TradeState _tradeState;
        uint256 upkeepID;
        int256 sl;
        int256 tp;
    }

    mapping(address => address[]) public subscribers;
    mapping(address => string[]) public posts;
    mapping(address => uint256) public noOfSubscribers;
    mapping(address => uint256) public noOfTrades;
    mapping(address => string) public userProfile;
    mapping(address => uint) subscribersFee;
    mapping(uint => TradeLog) getATrade;

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
