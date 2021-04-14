// SPDX-License-Identifier: GPL
pragma solidity 0.7.4;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts-upgradeable/proxy/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/utils/AddressUpgradeable.sol";

import "./interfaces/IL2ArbNetwork.sol";
import "./interfaces/IAuthenticator.sol";

/**
 * @notice  DataExchange is a contract for data exchanging between L1 and L2 at the same address.
 */
contract DataExchange is Initializable {
    using AddressUpgradeable for address;

    bytes32 public constant DATA_EXCHANGE_ADMIN_ROLE = keccak256("DATA_EXCHANGE_ADMIN_ROLE");
    address public constant ARB_SYS_ADDRESS = 0x0000000000000000000000000000000000000064;
    address public constant ROLLUP_ADDRESS = 0x19914a2873136aE17E25E4eff6088BF17f3ea3a3;
    uint256 public constant CHAINID_MASK =
        0x0000000000000000000000000000000000000000000000000000FFFFFFFFFFFF;

    IAuthenticator public authenticator;

    mapping(bytes32 => address) public dataSources;
    mapping(bytes32 => bytes) public dataValues;
    mapping(bytes32 => uint256) public dataUpdateTimestamps;

    event UpdateDataSource(bytes32 key, address source);

    event FeedDataToL2(bytes32 key, bytes data, address inbox, uint256 maxGas, uint256 gasPriceBid);
    event ReceiveDataFromL1(bytes32 key, bytes data);

    event FeedDataToL1(bytes32 key, bytes data);
    event ReceiveDataFromL2(bytes32 key, bytes data);

    receive() external payable {}

    modifier onlyAuthorized() {
        require(
            authenticator.hasRoleOrAdmin(DATA_EXCHANGE_ADMIN_ROLE, msg.sender),
            "caller is not authorized"
        );
        _;
    }

    modifier onlyL1() {
        require(!_isL2Net(), "method is only available on L1");
        _;
    }

    modifier onlyL2() {
        require(_isL2Net(), "method is only available on L2");
        _;
    }

    /**
     * @notice  Initialzie vault contract.
     *
     * @param   authenticator_  The address of authentication controller that can determine who is able to call
     *                          admin interfaces.
     */
    function initialize(address authenticator_) external initializer {
        require(authenticator_ != address(0), "authenticator is the zero address");
        authenticator = IAuthenticator(authenticator_);
    }

    /**
     * @notice  Check if is a account is authorized to push data for given key.
     */
    function isValidSource(bytes32 key, address account) public view returns (bool) {
        return account == dataSources[key];
    }

    /**
     * @notice  Retreive data in bytes format for given key. Retreiver need to decode to get the raw data.
     *          For one key, old data will be overriden by newer data.
     */
    function getData(bytes32 key) public view returns (bytes memory, bool) {
        return (dataValues[key], dataUpdateTimestamps[key] > 0);
    }

    /**
     * @notice  Retreive the last updated timestamp for given key.
     */
    function getDataLastUpdateTimestamp(bytes32 key) public view returns (uint256) {
        return dataUpdateTimestamps[key];
    }

    /**
     * @notice  Set a authorized source for given key and the source will be synced to L1.
     *          That means the whitelist will be stored in both L1 & L2 storage.
     * @dev     L2 only.
     */
    function updateDataSource(bytes32 key, address source) external onlyL2 onlyAuthorized {
        // require(dataSources[key] != source, "data source is already exist");
        dataSources[key] = source;
        IArbSys(ARB_SYS_ADDRESS).sendTxToL1(
            address(this),
            abi.encodeWithSignature("syncDataSourceFromL2(bytes32,address)", key, source)
        );
        emit UpdateDataSource(key, source);
    }

    /**
     * @notice  Sync the authorized source from L2.
     *          When the source is set in L2, a sync message will be sent to L1 at the same time.
     * @dev     L1 only.
     */
    function syncDataSourceFromL2(bytes32 key, address source) external onlyL1 {
        require(_getL2Sender(msg.sender) == address(this), "sender is invalid");
        require(dataSources[key] != source, "data source is already exist");
        dataSources[key] = source;
        emit UpdateDataSource(key, source);
    }

    /**
     * @notice  Push data from L1 to L2. the inbox, maxGas and gasPriceBid is required by Arb L2 network.
     *
     * @dev     L1 only.
     */
    function feedDataFromL1(
        bytes32 key,
        bytes memory data,
        address inbox,
        uint256 maxGas,
        uint256 gasPriceBid
    ) external onlyL1 {
        require(isValidSource(key, msg.sender), "data source is invalid");
        _feedDataFromL1(key, data, inbox, maxGas, gasPriceBid, true);
    }

    /**
     * @notice  Push data from L1 to L2 but will not revert if sender is not authorized.
     * @dev     L1 only.
     */
    function tryFeedDataFromL1(
        bytes32 key,
        bytes memory data,
        address inbox,
        uint256 maxGas,
        uint256 gasPriceBid
    ) external onlyL1 returns (bool) {
        if (!isValidSource(key, msg.sender)) {
            return false;
        }
        return _feedDataFromL1(key, data, inbox, maxGas, gasPriceBid, false);
    }

    /**
     * @notice  This is the receiving method for `feedDataFromL1`.
     *          The key and data sent there will finally be passed in through arguments to this method.
     *          To avoid data rollback due to disorder, any data earlier than the timestamp of last update will be discard.
     */
    function receiveDataFromL1(
        bytes32 key,
        uint256 timestamp,
        bytes memory data
    ) external onlyL2 {
        require(msg.sender == address(this), "data pusher is invalid");
        if (timestamp <= dataUpdateTimestamps[key]) {
            return;
        }
        dataValues[key] = data;
        dataUpdateTimestamps[key] = timestamp;
        emit ReceiveDataFromL1(key, data);
    }

    /**
     * @notice  Push data from L2 to L1.
     * @dev     L2 only.
     */
    function feedDataFromL2(bytes32 key, bytes memory data) external onlyL2 {
        require(dataSources[key] == msg.sender, "data source is invalid");
        _feedDataFromL2(key, data, true);
    }

    /**
     * @notice  Push data from L2 to L1 but will not revert if sender is not authorized.
     * @notice  L2 only.
     */
    function tryFeedDataFromL2(bytes32 key, bytes memory data) external onlyL2 returns (bool) {
        if (!isValidSource(key, msg.sender)) {
            return false;
        }
        return _feedDataFromL2(key, data, false);
    }

    /**
     * @notice  This is the receiving method for `feedDataFromL2`.
     * @notice  L1 only.
     */
    function receiveDataFromL2(
        bytes32 key,
        uint256 timestamp,
        bytes memory data
    ) external onlyL1 {
        require(_getL2Sender(msg.sender) == address(this), "data pusher is invalid");
        if (timestamp <= dataUpdateTimestamps[key]) {
            return;
        }
        dataValues[key] = data;
        dataUpdateTimestamps[key] = timestamp;
        emit ReceiveDataFromL1(key, data);
    }

    function _feedDataFromL1(
        bytes32 key,
        bytes memory data,
        address inbox,
        uint256 maxGas,
        uint256 gasPriceBid,
        bool revertOnFailure
    ) internal returns (bool) {
        require(_isValidInbox(inbox), "inbox is invalid");
        try
            IInbox(inbox).sendContractTransaction(
                maxGas,
                gasPriceBid,
                address(this),
                0,
                abi.encodeWithSignature(
                    "receiveDataFromL1(bytes32,uint256,bytes)",
                    key,
                    _getBlockTimestamp(),
                    data
                )
            )
        {
            emit FeedDataToL2(key, data, inbox, maxGas, gasPriceBid);
            return true;
        } catch Error(string memory reason) {
            if (revertOnFailure) {
                revert(reason);
            }
            return false;
        } catch {
            if (revertOnFailure) {
                revert("fail to send transction to L2");
            }
            return false;
        }
    }

    function _feedDataFromL2(
        bytes32 key,
        bytes memory data,
        bool revertOnFailure
    ) internal returns (bool) {
        try
            IArbSys(ARB_SYS_ADDRESS).sendTxToL1(
                address(this),
                abi.encodeWithSignature(
                    "receiveDataFromL2(bytes32,uint256,bytes)",
                    key,
                    _getBlockTimestamp(),
                    data
                )
            )
        {
            emit FeedDataToL1(key, data);
            return true;
        } catch Error(string memory reason) {
            if (revertOnFailure) {
                revert(reason);
            }
            return false;
        } catch {
            if (revertOnFailure) {
                revert("fail to send transction to L1");
            }
            return false;
        }
    }

    function _isValidInbox(address inbox) internal view returns (bool) {
        try IRollup(ROLLUP_ADDRESS).bridge() returns (address trustedBridge) {
            return IBridge(trustedBridge).allowedInboxes(inbox);
        } catch {
            return false;
        }
    }

    function _getL2Sender(address bridge) internal view returns (address) {
        address trustedBridge = IRollup(ROLLUP_ADDRESS).bridge();
        require(trustedBridge == bridge, "not a valid l2 outbox");
        IOutbox outbox = IOutbox(IBridge(trustedBridge).activeOutbox());
        return outbox.l2ToL1Sender();
    }

    function _isL2Net() internal view returns (bool) {
        uint256 id;
        assembly {
            id := chainid()
        }
        return id == (uint256(ROLLUP_ADDRESS) & CHAINID_MASK);
    }

    function _getBlockTimestamp() internal view virtual returns (uint256) {
        return block.timestamp;
    }

    bytes32[50] private __gap;
}
