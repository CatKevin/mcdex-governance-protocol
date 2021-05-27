// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.7.4;

interface IArbSys {
    function sendTxToL1(address destination, bytes calldata calldataForL1)
        external
        payable
        returns (uint256);
}

interface IBridge {
    function activeOutbox() external view returns (address);

    function allowedInboxes(address inbox) external view returns (bool);

    function allowedOutboxes(address outbox) external view returns (bool);

    function allowedInboxList(uint256 index) external view returns (address);

    function allowedOutboxList(uint256 index) external view returns (address);

    function inboxAccs(uint256 index) external view returns (bytes32);

    function messageCount() external view returns (uint256);
}

interface IRollup {
    // Bridge is an IInbox and IOutbox
    function delayedBridge() external view returns (address);

    function outbox() external view returns (address);
}

interface IL2ERC20Bridge {
    function deposit(
        address erc20,
        address destination,
        uint256 amount,
        uint256 maxSubmissionCost,
        uint256 maxGas,
        uint256 gasPriceBid,
        bytes calldata callHookData
    ) external payable returns (uint256);

    function inbox() external view returns (address);
}

interface IOutbox {
    function l2ToL1Sender() external view returns (address);

    function processOutgoingMessages(bytes calldata sendsData, uint256[] calldata sendLengths)
        external;
}

interface IInbox {
    function sendL1FundedContractTransaction(
        uint256 maxGas,
        uint256 gasPriceBid,
        address destAddr,
        bytes calldata data
    ) external payable returns (uint256);

    function sendContractTransaction(
        uint256 maxGas,
        uint256 gasPriceBid,
        address destAddr,
        uint256 amount,
        bytes calldata data
    ) external returns (uint256);
}
