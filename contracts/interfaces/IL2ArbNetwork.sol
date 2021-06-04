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
}

interface IRollup {
    // Bridge is an IInbox and IOutbox
    function delayedBridge() external view returns (address);
}

interface IEthERC20Bridge {
    function deposit(
        address erc20,
        address destination,
        uint256 amount,
        uint256 maxSubmissionCost,
        uint256 maxGas,
        uint256 gasPriceBid,
        bytes calldata callHookData
    ) external payable returns (uint256 seqNum, uint256 depositCalldataLength);

    function inbox() external view returns (address);
}

interface IOutbox {
    function l2ToL1Sender() external view returns (address);
}

interface IInbox {
    function sendContractTransaction(
        uint256 maxGas,
        uint256 gasPriceBid,
        address destAddr,
        uint256 amount,
        bytes calldata data
    ) external returns (uint256);
}
