// SPDX-License-Identifier: UNLICENSED
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
    address public constant ROLLUP_ADDRESS = 0xC0250Ed5Da98696386F13bE7DE31c1B54a854098;
    uint256 public constant CHAINID_MASK =
        0x0000000000000000000000000000000000000000000000000000FFFFFFFFFFFF;

    IAuthenticator public authenticator;

    mapping(bytes32 => address) public dataSources;
    mapping(bytes32 => bytes) public dataValues;
    mapping(bytes32 => uint256) public dataUpdateTimestamps;

    event UpdateDataSource(bytes32 key, address source);

    event PushDataToL2(bytes32 key, bytes data, address inbox, uint256 maxGas, uint256 gasPriceBid);
    event ReceiveDataFromL1(bytes32 key, bytes data);

    event PushDataToL1(bytes32 key, bytes data);
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
        require(!_isL2Net(), "method is only available on L2");
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
     * @notice  Retreive data in bytes format. Retreiver need to decode to get the raw data.
     *          For one key, old data will be overriden by newer data.
     */
    function getData(bytes32 key) public view returns (bytes memory, uint256 timestamp) {
        return (dataValues[key], dataUpdateTimestamps[key]);
    }

    /**
     * @notice  Set a authorized source for given key and the source will be synced to L1.
     *          That means the whitelist will be stored in both L1 & L2 storage.
     * @dev     L2 only.
     */
    function updateDataSource(bytes32 key, address source) public onlyL2 onlyAuthorized {
        require(dataSources[key] != source, "data source is already exist");
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
    function syncDataSourceFromL2(bytes32 key, address source) public onlyL1 {
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
    function pushDataFromL1(
        bytes32 key,
        bytes calldata data,
        address inbox,
        uint256 maxGas,
        uint256 gasPriceBid
    ) public onlyL1 {
        require(isValidSource(key, msg.sender), "data source is invalid");
        _pushDataFromL1(key, data, inbox, maxGas, gasPriceBid, true);
    }

    /**
     * @notice  Push data from L1 to L2 but will not revert if sender is not authorized.
     * @dev     L1 only.
     */
    function tryPushDataFromL1(
        bytes32 key,
        bytes calldata data,
        address inbox,
        uint256 maxGas,
        uint256 gasPriceBid
    ) public onlyL1 {
        if (!isValidSource(key, msg.sender)) {
            return;
        }
        _pushDataFromL1(key, data, inbox, maxGas, gasPriceBid, false);
    }

    function _pushDataFromL1(
        bytes32 key,
        bytes calldata data,
        address inbox,
        uint256 maxGas,
        uint256 gasPriceBid,
        bool revertOnFailure
    ) internal {
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
            emit PushDataToL2(key, data, inbox, maxGas, gasPriceBid);
        } catch Error(string memory reason) {
            if (revertOnFailure) {
                revert(reason);
            }
        } catch {
            if (revertOnFailure) {
                revert("fail to send transction to L2");
            }
        }
    }

    /**
     * @notice  This is the receiving method for `pushDataFromL1`.
     *          The key and data sent there will finally be passed in through arguments to this method.
     *          To avoid data rollback due to disorder, any data earlier than the timestamp of last update will be discard.
     */
    function receiveDataFromL1(
        bytes32 key,
        uint256 timestamp,
        bytes calldata data
    ) public onlyL2 {
        require(msg.sender == address(this), "data pusher is invalid");
        if (timestamp < dataUpdateTimestamps[key]) {
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
    function pushDataFromL2(bytes32 key, bytes calldata data) public onlyL2 {
        require(dataSources[key] == msg.sender, "data source is invalid");
        _pushDataFromL2(key, data, true);
    }

    /**
     * @notice  Push data from L2 to L1 but will not revert if sender is not authorized.
     * @notice  L2 only.
     */
    function tryPushDataFromL2(bytes32 key, bytes calldata data) public onlyL2 {
        if (!isValidSource(key, msg.sender)) {
            return;
        }
        _pushDataFromL2(key, data, false);
    }

    function _pushDataFromL2(
        bytes32 key,
        bytes calldata data,
        bool revertOnFailure
    ) internal {
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
            emit PushDataToL1(key, data);
        } catch Error(string memory reason) {
            if (revertOnFailure) {
                revert(reason);
            }
        } catch {
            if (revertOnFailure) {
                revert("fail to send transction to L1");
            }
        }
    }

    /**
     * @notice  This is the receiving method for `pushDataFromL2`.
     * @notice  L1 only.
     */
    function receiveDataFromL2(
        bytes32 key,
        uint256 timestamp,
        bytes calldata data
    ) public onlyL1 {
        require(_getL2Sender(msg.sender) == address(this), "data pusher is invalid");
        if (timestamp < dataUpdateTimestamps[key]) {
            return;
        }
        dataValues[key] = data;
        dataUpdateTimestamps[key] = timestamp;
        emit ReceiveDataFromL1(key, data);
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
}
