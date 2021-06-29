// SPDX-License-Identifier: BSD
pragma solidity 0.7.4;

import "@openzeppelin/contracts-upgradeable/math/SafeMathUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/AddressUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/Initializable.sol";

import { ITimelock } from "./interfaces/ITimelock.sol";

contract Timelock is Initializable, ITimelock {
    using AddressUpgradeable for address;
    using SafeMathUpgradeable for uint256;

    event NewAdmin(address indexed newAdmin);
    event NewPendingAdmin(address indexed newPendingAdmin);
    event NewDelay(uint256 indexed newDelay);
    event CancelTransaction(
        bytes32 indexed txHash,
        address indexed target,
        uint256 value,
        string signature,
        bytes data,
        uint256 eta
    );
    event ExecuteTransaction(
        bytes32 indexed txHash,
        address indexed target,
        uint256 value,
        string signature,
        bytes data,
        uint256 eta
    );
    event QueueTransaction(
        bytes32 indexed txHash,
        address indexed target,
        uint256 value,
        string signature,
        bytes data,
        uint256 eta
    );

    uint256 public constant override GRACE_PERIOD = 3 days;
    uint256 public constant MINIMUM_DELAY = 0 days;
    uint256 public constant MAXIMUM_DELAY = 30 days;

    address public admin;
    address public pendingAdmin;
    uint256 public override delay;

    mapping(bytes32 => bool) public override queuedTransactions;

    function initialize(address admin_, uint256 delay_) external initializer {
        require(delay_ >= MINIMUM_DELAY, "Delay must exceed minimum delay.");
        require(delay_ <= MAXIMUM_DELAY, "Delay must not exceed maximum delay.");

        admin = admin_;
        delay = delay_;
    }

    receive() external payable {}

    function setDelay(uint256 delay_) public {
        require(msg.sender == address(this), "Call must come from Timelock.");
        require(delay_ >= MINIMUM_DELAY, "Delay must exceed minimum delay.");
        require(delay_ <= MAXIMUM_DELAY, "Delay must not exceed maximum delay.");
        delay = delay_;

        emit NewDelay(delay);
    }

    function acceptAdmin() public override {
        require(msg.sender == pendingAdmin, "Call must come from pendingAdmin.");
        admin = msg.sender;
        pendingAdmin = address(0);

        emit NewAdmin(admin);
    }

    function setPendingAdmin(address pendingAdmin_) public {
        require(msg.sender == address(this), "Call must come from Timelock.");
        pendingAdmin = pendingAdmin_;

        emit NewPendingAdmin(pendingAdmin);
    }

    function queueTransaction(
        address target,
        uint256 value,
        string memory signature,
        bytes memory data,
        uint256 eta
    ) public override returns (bytes32) {
        require(msg.sender == admin, "Call must come from admin.");
        require(
            eta >= getBlockTimestamp().add(delay),
            "Estimated execution block must satisfy delay."
        );

        bytes32 txHash = keccak256(abi.encode(target, value, signature, data, eta));
        queuedTransactions[txHash] = true;

        emit QueueTransaction(txHash, target, value, signature, data, eta);
        return txHash;
    }

    function cancelTransaction(
        address target,
        uint256 value,
        string memory signature,
        bytes memory data,
        uint256 eta
    ) public override {
        require(msg.sender == admin, "Call must come from admin.");

        bytes32 txHash = keccak256(abi.encode(target, value, signature, data, eta));
        queuedTransactions[txHash] = false;

        emit CancelTransaction(txHash, target, value, signature, data, eta);
    }

    function executeTransaction(
        address target,
        uint256 value,
        string memory signature,
        bytes memory data,
        uint256 eta
    ) public payable override returns (bytes memory) {
        require(msg.sender == admin, "Call must come from admin.");

        bytes32 txHash = keccak256(abi.encode(target, value, signature, data, eta));
        require(queuedTransactions[txHash], "Transaction hasn't been queued.");
        require(getBlockTimestamp() >= eta, "Transaction hasn't surpassed time lock.");
        require(getBlockTimestamp() <= eta.add(GRACE_PERIOD), "Transaction is stale.");

        queuedTransactions[txHash] = false;
        bytes memory callData;
        if (bytes(signature).length == 0) {
            callData = data;
        } else {
            callData = abi.encodePacked(bytes4(keccak256(bytes(signature))), data);
        }
        bytes memory returnData = target.functionCallWithValue(callData, value);
        emit ExecuteTransaction(txHash, target, value, signature, data, eta);
        return returnData;
    }

    function getBlockTimestamp() internal view virtual returns (uint256) {
        // solium-disable-next-line security/no-block-members
        return block.timestamp;
    }

    bytes32[50] private __gap;
}
