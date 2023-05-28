//SPDX-License-Identifier: UNLICENSED
pragma solidity >0.5.0 <0.9.0;

//EPNS Comm Contract Interface
interface IEPNSCommInterface {
    function sendNotification(
        address _channel,
        address _recipient,
        bytes memory _identity
    ) external;

    function addDelegate(address _delegate) external;

    function subscribe(address _channel) external returns (bool);
}
