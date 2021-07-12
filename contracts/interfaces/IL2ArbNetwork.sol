// SPDX-License-Identifier: GPL
pragma solidity 0.7.4;

interface IArbSys {
    /**
     * @notice Get internal version number identifying an ArbOS build
     * @return version number as int
     */
    function arbOSVersion() external pure returns (uint256);

    /**
     * @notice Get Arbitrum block number (distinct from L1 block number; Arbitrum genesis block has block number 0)
     * @return block number as int
     */
    function arbBlockNumber() external view returns (uint256);

    /**
     * @notice Send a transaction to L1
     * @param destination recipient address on L1
     * @param calldataForL1 (optional) calldata for L1 contract call
     * @return a unique identifier for this L2-to-L1 transaction.
     */
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
    function bridge() external view returns (IBridge);

    function sendContractTransaction(
        uint256 maxGas,
        uint256 gasPriceBid,
        address destAddr,
        uint256 amount,
        bytes calldata data
    ) external returns (uint256);
}

interface IArbToken {
    function bridgeMint(address account, uint256 amount) external;

    function bridgeBurn(address account, uint256 amount) external;

    function l1Address() external view returns (address);
}

interface ITokenGateway {
    function router() external view returns (address);
}
