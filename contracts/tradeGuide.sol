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
error InsufficientFunds();
error InvalidTPOrSL();

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
        IEPNSCommInterface epnsComms,
        address _channel
    ) {
        swapRouter = _swapRouter;
        i_link = _link;
        registrar = _registrar;
        oracleAdress = _oracleAddress;
        i_registry = _registry;
        _epnsComms = epnsComms;
        channel = _channel;
    }

    function useTPandSL(
        int256 tp,
        int256 sl,
        uint256 amountIn,
        address _tokenIn,
        address _tokenOut
    ) public {
        int256 currentPriceTokenOut = int256(
            oracleAdress.getAssetPrice(_tokenOut)
        );
        int256 currentPriceTokenIn = int256(
            oracleAdress.getAssetPrice(_tokenIn)
        );
        int256 currentPriceLink = int256(
            oracleAdress.getAssetPrice(address(i_link))
        );
        int minAmount = ((currentPriceLink / currentPriceTokenIn) * 5) / 10;
        uint totalMin = amountIn + uint(minAmount);
        if (tp < currentPriceTokenOut) {
            revert InvalidTPOrSL();
        }
        if (sl > currentPriceTokenOut) {
            revert InvalidTPOrSL();
        }
        if (IERC20(_tokenIn).balanceOf(msg.sender) < totalMin) {
            revert InsufficientFunds();
        }

        TradeLog memory _tradeLog = getATrade[totalOfTrades + 1]; // = trades.push();
        _tradeLog.index = uint8(totalOfTrades + 1);
        _tradeLog.trader = msg.sender;
        _tradeLog.tokenBought = _tokenOut;
        _tradeLog.timeStamp = block.timestamp;
        _tradeLog.buyPrice = currentPriceTokenOut;
        _tradeLog.amount = amountIn;
        _tradeLog._tradeState = TradeState.ONGOING;
        _tradeLog.sl = sl;
        _tradeLog.tp = tp;

        address[] memory _subscribers = subscribers[msg.sender];
        if (_subscribers.length > 0) {
            sendNotif(_subscribers, _tradeLog);
        }

        IERC20(_tokenIn).safeTransferFrom(msg.sender, address(this), totalMin);

        uint256 amountOut = swapExactInputSingle(
            _tokenIn,
            amountIn,
            _tokenOut,
            address(this)
        );

        int amountOutMinLink = (currentPriceTokenIn / currentPriceLink) *
            minAmount;

        ISwapRouter.ExactInputSingleParams memory params = ISwapRouter
            .ExactInputSingleParams({
                tokenIn: _tokenIn,
                tokenOut: address(i_link),
                fee: poolFee,
                recipient: address(this),
                deadline: block.timestamp,
                amountIn: uint(minAmount),
                amountOutMinimum: uint(amountOutMinLink),
                sqrtPriceLimitX96: 0
            });

        // The call to `exactInputSingle` executes the swap.
        uint amountOutLink = swapRouter.exactInputSingle(params);

        registerAndPredictID(uint96(amountOutLink), amountOut, _tradeLog);
    }

    function registerAndPredictID(
        uint96 amount,
        uint256 _amountOut,
        TradeLog memory _tradeLog
    ) public {
        bytes memory checkData = abi.encode(_amountOut, _tradeLog);
        (State memory state, , ) = i_registry.getState();
        uint256 oldNonce = state.nonce;
        bytes memory payload = abi.encode(
            "TradeGuide Automate",
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
            emit UpkeepID(upkeepID);
        } else {
            revert("auto-approve disabled");
        }
    }

    function checkUpkeep(
        bytes calldata checkData
    ) external view returns (bool upkeepNeeded, bytes memory performData) {
        (, TradeLog memory _tradeLog) = abi.decode(
            checkData,
            (uint256, TradeLog)
        );

        bool checkSLTP = (int256(_tradeLog.tp) <= _tradeLog.buyPrice ||
            int256(_tradeLog.sl) >= _tradeLog.buyPrice);
        upkeepNeeded = (checkSLTP &&
            _tradeLog._tradeState == TradeState.ONGOING);

        performData = checkData;
    }

    function performUpkeep(bytes calldata performData) external {
        (uint256 amountIn, TradeLog memory _tradeLog) = abi.decode(
            performData,
            (uint256, TradeLog)
        );

        bool checkSLTP = (int256(_tradeLog.tp) <= _tradeLog.buyPrice ||
            int256(_tradeLog.sl) >= _tradeLog.buyPrice);
        if (checkSLTP && _tradeLog._tradeState == TradeState.ONGOING) {
            swapExactInputSingle(
                _tradeLog.tokenBought,
                amountIn,
                USDC,
                msg.sender
            );
            _tradeLog._tradeState = TradeState.COMPLETED;
        } else {
            cancelUpkeepById(_tradeLog);
        }
    }

    function subscribe(address _to) public {
        if (IERC20(USDC).balanceOf(msg.sender) < subscribersFee[_to]) {
            revert InsufficientFunds();
        }
        IERC20(USDC).transfer(_to, subscribersFee[_to]);

        subscribers[_to].push(msg.sender);
        emit Subscribed(_to, subscribersFee[_to]);
    }

    function swapExactInputSingle(
        address _tokenIn,
        uint256 amountIn,
        address _tokenOut,
        address reciepient
    ) internal returns (uint256 amountOut) {
        // msg.sender must approve this contract

        // // transfer tokens
        // IERC20(_tokenIn).safeTransferFrom(msg.sender, address(this), amountIn);

        // Approve the router to spend DAI.
        IERC20(_tokenIn).safeApprove(address(swapRouter), amountIn);

        uint256 currentPriceOut = oracleAdress.getAssetPrice(_tokenOut);
        uint256 currentPriceIn = oracleAdress.getAssetPrice(_tokenIn);

        uint _amountOutMin = (currentPriceIn / currentPriceOut) * amountIn;

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
        noOfTrades[msg.sender] += 1;
        totalOfTrades++;
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
        uint256 currentPriceIn = oracleAdress.getAssetPrice(_tokenIn);

        uint _amountOutMin = (currentPriceIn / currentPriceOut) * amountIn;

        int256 sl = 0;
        int256 tp = 0;

        TradeLog storage _tradeLog = getATrade[totalOfTrades + 1];
        _tradeLog.index = uint8(totalOfTrades + 1);
        _tradeLog.trader = msg.sender;
        _tradeLog.tokenBought = _tokenOut;
        _tradeLog.timeStamp = block.timestamp;
        _tradeLog.amount = amountIn;
        _tradeLog.buyPrice = int256(currentPriceOut);
        _tradeLog._tradeState = TradeState.ONGOING;
        _tradeLog.sl = sl;
        _tradeLog.tp = tp;

        address[] memory _subscribers = subscribers[msg.sender];
        if (_subscribers.length > 0) {
            sendNotif(_subscribers, _tradeLog);
        }

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

    function cancelUpkeepById(TradeLog memory _tradeLog) public {
        uint256 id = _tradeLog.upkeepID;
        i_registry.cancelUpkeep(id);
    }

    function addFundsByID(TradeLog memory _tradeLog, uint96 amount) external {
        if (IERC20(address(i_link)).balanceOf(msg.sender) < amount) {
            revert InsufficientFunds();
        }
        IERC20(address(i_link)).safeTransferFrom(
            msg.sender,
            address(this),
            amount
        );
        uint256 id = _tradeLog.upkeepID;
        i_registry.addFunds(id, amount);
    }

    function sendNotif(
        address[] memory _to,
        TradeLog memory _tradeLog
    ) public returns (bool) {
        for (uint i = 0; i < _to.length; i++) {
            _epnsComms.sendNotification(
                channel,
                _to[i],
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
        }
        return true;
    }

    function addAdelegate(address _delegate) external {
        _epnsComms.addDelegate(_delegate);
    }

    function addAPost(string memory link) public {
        posts[msg.sender].push(link);
    }

    function setSubscribersFee(uint256 fee) public {
        subscribersFee[msg.sender] = fee;
    }

    function setUserProfile(string memory userLink) public {
        userProfile[msg.sender] = userLink;
    }

    //view Functions

    function getTrades() public view returns (TradeLog[] memory) {
        uint aTrade = totalOfTrades;
        TradeLog[] memory _tradeLog = new TradeLog[](aTrade);
        for (uint i = 0; i < aTrade; i++) {
            _tradeLog[i] = getATrade[i + 1];
        }
        return _tradeLog;
    }

    function getSubcribers(
        address user
    ) public view returns (address[] memory) {
        return subscribers[user];
    }

    function getPosts(address user) public view returns (string[] memory) {
        return posts[user];
    }

    function getProfile(address user) public view returns (string memory) {
        return userProfile[user];
    }

    function getUpkeepInfo(
        TradeLog memory _tradeLog
    ) public view returns (uint96 balance) {
        (, , , balance, , , , ) = i_registry.getUpkeep(_tradeLog.upkeepID);
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

    function getPrice(address _token) public view returns (uint256) {
        uint _getPrice = oracleAdress.getAssetPrice(_token);
        return _getPrice;
    }

    receive() external payable {}
}
