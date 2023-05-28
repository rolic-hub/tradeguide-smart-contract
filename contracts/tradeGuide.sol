// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.4;
pragma abicoder v2;


import "./tradeGuideStorage.sol";
import "./interfaces/IPriceOracle.sol";
import "./interfaces/IEPNSCommInterface.sol";
import "@uniswap/v3-periphery/contracts/interfaces/ISwapRouter.sol";
import {AutomationRegistryInterface, State, Config} from "@chainlink/contracts/src/v0.8/interfaces/AutomationRegistryInterface1_2.sol";
import {LinkTokenInterface} from "@chainlink/contracts/src/v0.8/interfaces/LinkTokenInterface.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

interface KeeperRegistrarInterface {
    function register(
        string memory name,
        bytes calldata encryptedEmail,
        address upkeepContract,
        uint32 gasLimit,
        address adminAddress,
        bytes calldata checkData,
        uint96 amount,
        uint8 source,
        address sender
    ) external;
}

contract TradeGuide is TradeGuideStorage {
    using SafeERC20 for IERC20;

    ISwapRouter public immutable swapRouter;
    LinkTokenInterface public immutable i_link;
    IPriceOracle public immutable oracleAdress;
    address public immutable registrar;
    IEPNSCommInterface public immutable _epnsComms;
    AutomationRegistryInterface public immutable i_registry;
    bytes4 registerSig = KeeperRegistrarInterface.register.selector;

    constructor(
        ISwapRouter _swapRouter,
        LinkTokenInterface _link,
        address _registrar,
        IPriceOracle _oracleAddress,
        AutomationRegistryInterface _registry,
        IEPNSCommInterface epnsComms
    ) {
        swapRouter = _swapRouter;
        i_link = _link;
        registrar = _registrar;
        oracleAdress = _oracleAddress;
        i_registry = _registry;
        _epnsComms = epnsComms;
    }

    function useTPandSL(
        int256 tp,
        int256 sl,
        uint96 _amount,
        uint256 amountIn,
        address _tokenIn,
        address _tokenOut
    ) public {
        int256 currentPrice = int256(oracleAdress.getAssetPrice(_tokenOut));
        require(tp > currentPrice, "tp has to be greater than current price");
        require(sl < currentPrice, "sl has to be less than current price");

        TradeLog memory _tradeLog = trades.push();
        _tradeLog.trader = msg.sender;
        _tradeLog.tokenBought = _tokenOut;
        _tradeLog.timeStamp = block.timestamp;
        _tradeLog.buyPrice = currentPrice;
        _tradeLog._tradeState = TradeState.ONGOING;
        _tradeLog.sl = sl;
        _tradeLog.tp = tp;

        address[] memory _subscribers = subscribers[msg.sender];
        for (uint i = 0; i < _subscribers.length; i++) {
            sendNotif(_subscribers[i], _tradeLog, channel);
        }

        uint256 amountOut = swapExactInputSingle(
            _tokenIn,
            amountIn,
            _tokenOut,
            address(this)
        );

        registerAndPredictID(
            _amount,
            amountOut,
            sl,
            tp,
            currentPrice,
            _tokenOut,
            _tradeLog
        );
    }

    function registerAndPredictID(
        uint96 amount,
        uint256 _amountOut,
        int256 _sl,
        int256 _tp,
        int256 _currentprice,
        address _tokenOut,
        TradeLog memory _tradeLog
    ) public {
        bytes memory checkData = abi.encode(
            _amountOut,
            _sl,
            _tp,
            _currentprice,
            _tokenOut,
            _tradeLog
        );
        (State memory state, , ) = i_registry.getState();
        uint256 oldNonce = state.nonce;
        bytes memory payload = abi.encode(
            "tradeGuide Automate",
            "0x",
            address(this),
            9999,
            msg.sender,
            checkData,
            amount,
            0,
            address(this)
        );

        i_link.transferAndCall(
            registrar,
            amount,
            bytes.concat(registerSig, payload)
        );
        (state, , ) = i_registry.getState();
        uint256 newNonce = state.nonce;
        if (newNonce == oldNonce + 1) {
            uint256 upkeepID = uint256(
                keccak256(
                    abi.encodePacked(
                        blockhash(block.number - 1),
                        address(i_registry),
                        uint32(oldNonce)
                    )
                )
            );
            _tradeLog.upkeepID = upkeepID;
            addressToUpkeepId[msg.sender] = upkeepID;
            emit UpkeepID(upkeepID);
        } else {
            revert("auto-approve disabled");
        }
    }

    function checkUpkeep(
        bytes calldata checkData
    ) external view returns (bool upkeepNeeded, bytes memory performData) {
        (
            uint256 _tp,
            uint256 _sl,
            ,
            int256 _currentPrice,
            ,
            TradeLog memory _tradeLog
        ) = abi.decode(
                checkData,
                (uint256, uint256, uint256, int256, address, TradeLog)
            );

        bool checkSLTP = (int256(_tp) <= _currentPrice ||
            int256(_sl) >= _currentPrice);
        upkeepNeeded = (checkSLTP &&
            _tradeLog._tradeState == TradeState.ONGOING);

        performData = checkData;
    }

    function performUpkeep(bytes calldata performData) external {
        (
            uint256 _tp,
            uint256 _sl,
            uint256 amountIn,
            int256 _currentPrice,
            address _tokenIn,
            TradeLog memory _tradeLog
        ) = abi.decode(
                performData,
                (uint256, uint256, uint256, int256, address, TradeLog)
            );

        bool checkSLTP = (int256(_tp) <= _currentPrice ||
            int256(_sl) >= _currentPrice);
        if (checkSLTP && _tradeLog._tradeState == TradeState.ONGOING) {
            swapExactInputSingle(_tokenIn, amountIn, USDC, msg.sender);
            _tradeLog._tradeState = TradeState.COMPLETED;
        } else {
            cancelUpkeepById(_tradeLog.upkeepID);
        }
    }

    function subscribe(address _to) public {
        require(
            IERC20(USDC).balanceOf(msg.sender) >= subscribersFee[_to],
            "Insufficient balance to subscribe"
        );
        IERC20(USDC).transfer(_to, subscribersFee[_to]);
        subscribers[_to].push(msg.sender);
        _epnsComms.subscribe(channel);
    }

    function swapExactInputSingle(
        address _tokenIn,
        uint256 amountIn,
        address _tokenOut,
        address reciepient
    ) public returns (uint256 amountOut) {
        // msg.sender must approve this contract

        // // transfer tokens
        // IERC20(_tokenIn).safeTransferFrom(msg.sender, address(this), amountIn);

        // Approve the router to spend DAI.
        IERC20(_tokenIn).safeApprove(address(swapRouter), amountIn);

        uint256 currentPriceOut = oracleAdress.getAssetPrice(_tokenOut);
        uint256 currentPriceIn = oracleAdress.getAssetPrice(_tokenOut);

        uint _amountOutMin = currentPriceIn / currentPriceOut;

        // Naively set amountOutMinimum to 0. In production, use an oracle or other data source to choose a safer value for amountOutMinimum.
        // We also set the sqrtPriceLimitx96 to be 0 to ensure we swap our exact input amount.
        ISwapRouter.ExactInputSingleParams memory params = ISwapRouter
            .ExactInputSingleParams({
                tokenIn: _tokenIn,
                tokenOut: _tokenOut,
                fee: poolFee,
                recipient: reciepient,
                deadline: block.timestamp,
                amountIn: amountIn,
                amountOutMinimum: _amountOutMin,
                sqrtPriceLimitX96: 0
            });

        // The call to `exactInputSingle` executes the swap.
        amountOut = swapRouter.exactInputSingle(params);
        balances[msg.sender][_tokenOut] = amountOut;
        noOfTrades[msg.sender] += 1;
        totalOfTrades++;

        IERC20(_tokenOut).safeApprove(address(swapRouter), amountOut);
    }

    function swapExactInputSingleAlone(
        address _tokenIn,
        uint256 amountIn,
        address _tokenOut
    ) external returns (uint256 amountOut) {
        IERC20(_tokenIn).safeTransferFrom(msg.sender, address(this), amountIn);

        // Approve the router to spend DAI.
        IERC20(_tokenIn).approve(address(swapRouter), amountIn);
        // Naively set amountOutMinimum to 0. In production, use an oracle or other data source to choose a safer value for amountOutMinimum.
        // We also set the sqrtPriceLimitx96 to be 0 to ensure we swap our exact input amount.

        uint256 currentPriceOut = oracleAdress.getAssetPrice(_tokenOut);
        uint256 currentPriceIn = oracleAdress.getAssetPrice(_tokenOut);

        uint _amountOutMin = currentPriceIn / currentPriceOut;

        int256 sl = 0;
        int256 tp = 0;

        TradeLog storage _tradeLog = trades.push();
        _tradeLog.trader = msg.sender;
        _tradeLog.tokenBought = _tokenOut;
        _tradeLog.timeStamp = block.timestamp;
        _tradeLog.buyPrice = int256(currentPriceOut);
        _tradeLog._tradeState = TradeState.ONGOING;
        _tradeLog.sl = sl;
        _tradeLog.tp = tp;

        ISwapRouter.ExactInputSingleParams memory params = ISwapRouter
            .ExactInputSingleParams({
                tokenIn: _tokenIn,
                tokenOut: _tokenOut,
                fee: poolFee,
                recipient: msg.sender,
                deadline: block.timestamp,
                amountIn: amountIn,
                amountOutMinimum: _amountOutMin,
                sqrtPriceLimitX96: 0
            });

        // The call to `exactInputSingle` executes the swap.
        amountOut = swapRouter.exactInputSingle(params);

        _tradeLog._tradeState = TradeState.COMPLETED;

        noOfTrades[msg.sender] += 1;
        totalOfTrades++;
    }

    function cancelUpkeepById(uint256 id) public {
        i_registry.cancelUpkeep(id);
    }

    function addFundsByID(address user, uint96 amount) external {
        uint256 id = addressToUpkeepId[user];
        i_registry.addFunds(id, amount);
    }

    function sendNotif(
        address _to,
        TradeLog memory _tradeLog,
        address _channel
    ) public returns (bool) {
        _epnsComms.sendNotification(
            _channel,
            _to,
            bytes(
                string(
                    abi.encodePacked(
                        "0",
                        "+",
                        "3",
                        "+",
                        "Swap Alert",
                        numberToString(_tradeLog.timeStamp),
                        ":",
                        addressToString(_tradeLog.trader),
                        "bought",
                        addressToString(_tradeLog.tokenBought),
                        "at",
                        numberToString(uint(_tradeLog.buyPrice)),
                        "with",
                        numberToString(uint(_tradeLog.sl)),
                        numberToString(uint(_tradeLog.tp))
                    )
                )
            )
        );
        return true;
    }

    function addAdelegate(address _delegate) external {
        _epnsComms.addDelegate(_delegate);
    }

    function setSubscribersFee(uint256 fee, address user) public {
        subscribersFee[user] = fee;
    }

    function setUserProfile(
        address user,
        string memory _image,
        string memory _name
    ) public {
        userProfile[user] = User(user, _image, _name);
    }

    //view Functions

    function getTrades() public view returns (TradeLog[] memory) {
        return trades;
    }

    function getSubcribers(
        address user
    ) public view returns (address[] memory) {
        return subscribers[user];
    }

    function getProfile(address user) public view returns (User memory) {
        return userProfile[user];
    }

    function getSubscribersFee(address user) public view returns (uint256) {
        return subscribersFee[user];
    }

    function getNoSubscribers(address user) public view returns (uint256) {
        return noOfSubscribers[user];
    }

    function getNoTrades(address user) public view returns (uint256) {
        return noOfTrades[user];
    }

    function getTotalTrades() public view returns (uint256) {
        return totalOfTrades;
    }

    // recieve() external {};
}
