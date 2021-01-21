// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.7.4;

import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/GSN/ContextUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/Initializable.sol";

contract ShareToken is
    Initializable,
    ContextUpgradeable,
    AccessControlUpgradeable,
    ERC20Upgradeable
{
    struct Checkpoint {
        uint256 fromBlock;
        uint256 value;
    }

    struct Snapshot {
        uint256 count;
        mapping(uint256 => Checkpoint) checkpoints;
    }

    Snapshot internal _totalSupplySnapshot;
    mapping(address => Snapshot) internal _balanceSnapshot;

    event SaveBalanceCheckpoint(address indexed account, uint256 balance);
    event SaveTotalSupplyCheckpoint(uint256 totalSupply);

    function initialize(
        string memory name,
        string memory symbol,
        address admin
    ) public virtual initializer {
        __ShareToken_init(name, symbol, admin);
    }

    function __ShareToken_init(
        string memory name,
        string memory symbol,
        address admin
    ) internal initializer {
        __Context_init_unchained();
        __AccessControl_init_unchained();
        __ERC20_init_unchained(name, symbol);
        __ShareToken_init_unchained(admin);
    }

    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");

    function __ShareToken_init_unchained(address admin) internal initializer {
        _setupRole(ADMIN_ROLE, admin);
    }

    function getBalanceCheckpointCount(address account) public view returns (uint256) {
        return _balanceSnapshot[account].count;
    }

    function getBalanceCheckpointAt(address account, uint256 checkpointIndex)
        public
        view
        returns (uint256, uint256)
    {
        Checkpoint storage checkpoint = _balanceSnapshot[account].checkpoints[checkpointIndex];
        return (checkpoint.fromBlock, checkpoint.value);
    }

    function getTotalSupplyCheckpointCount() public view returns (uint256) {
        return _totalSupplySnapshot.count;
    }

    function getTotalSupplyCheckpointAt(uint256 checkpointIndex)
        public
        view
        returns (uint256, uint256)
    {
        Checkpoint storage checkpoint = _totalSupplySnapshot.checkpoints[checkpointIndex];
        return (checkpoint.fromBlock, checkpoint.value);
    }

    function getTotalSupplyAt(uint256 blockNumber) public view virtual returns (uint256) {
        return _findCheckpoint(_totalSupplySnapshot, blockNumber);
    }

    /**
     * @notice Determine the prior number of votes for an account as of a block number
     * @dev Block number must be a finalized block or else this function will revert to prevent misinformation.
     * @param account The address of the account to check
     * @param blockNumber The block number to get the vote balance at
     * @return The number of votes the account had as of the given block
     */
    function getBalanceAt(address account, uint256 blockNumber)
        public
        view
        virtual
        returns (uint256)
    {
        return _findCheckpoint(_balanceSnapshot[account], blockNumber);
    }

    function mint(address account, uint256 amount) public virtual {
        require(hasRole(ADMIN_ROLE, _msgSender()), "must have admin role to mint");
        _mint(account, amount);
        _saveBalanceCheckpoint(account);
        _saveTotalSupplyCheckpoint();
    }

    function burn(address account, uint256 amount) public virtual {
        require(hasRole(ADMIN_ROLE, _msgSender()), "must have admin role to burn");
        _burn(account, amount);
        _saveBalanceCheckpoint(account);
        _saveTotalSupplyCheckpoint();
    }

    function _transfer(
        address sender,
        address recipient,
        uint256 amount
    ) internal virtual override {
        super._transfer(sender, recipient, amount);

        _saveBalanceCheckpoint(sender);
        _saveBalanceCheckpoint(recipient);
    }

    function _saveBalanceCheckpoint(address account) internal {
        if (account == address(0)) {
            return;
        }
        uint256 balance = balanceOf(account);
        _saveCheckpoint(_balanceSnapshot[account], balance);
        emit SaveBalanceCheckpoint(account, balance);
    }

    function _saveTotalSupplyCheckpoint() internal {
        uint256 totalSupply_ = totalSupply();
        _saveCheckpoint(_totalSupplySnapshot, totalSupply_);
        emit SaveTotalSupplyCheckpoint(totalSupply_);
    }

    function _saveCheckpoint(Snapshot storage snapshot, uint256 newValue) internal {
        uint256 blockNumber = block.number;
        uint256 count = snapshot.count;
        if (count > 0 && snapshot.checkpoints[count - 1].fromBlock == blockNumber) {
            snapshot.checkpoints[count - 1].value = newValue;
        } else {
            snapshot.checkpoints[count].value = newValue;
            snapshot.count = count + 1;
        }
    }

    function _findCheckpoint(Snapshot storage snapshot, uint256 blockNumber)
        internal
        view
        returns (uint256)
    {
        require(blockNumber < block.number, "not yet determined");
        uint256 count = snapshot.count;
        if (count == 0) {
            return 0;
        }

        // First check most recent balance
        if (snapshot.checkpoints[count - 1].fromBlock <= blockNumber) {
            return snapshot.checkpoints[count - 1].value;
        }
        // Next check implicit zero balance
        if (snapshot.checkpoints[0].fromBlock > blockNumber) {
            return 0;
        }
        uint256 lower = 0;
        uint256 upper = count - 1;
        while (upper > lower) {
            uint256 center = upper - (upper - lower) / 2; // ceil, avoiding overflow
            Checkpoint memory cp = snapshot.checkpoints[center];
            if (cp.fromBlock == blockNumber) {
                return cp.value;
            } else if (cp.fromBlock < blockNumber) {
                lower = center;
            } else {
                upper = center - 1;
            }
        }
        return snapshot.checkpoints[lower].value;
    }

    uint256[50] private __gap;
}
