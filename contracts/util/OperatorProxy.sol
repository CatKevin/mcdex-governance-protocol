// SPDX-License-Identifier: GPL
pragma solidity 0.7.4;

import "@openzeppelin/contracts-upgradeable/proxy/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/SafeERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/EnumerableSetUpgradeable.sol";

interface ILiquidityPool {
    function checkIn() external;

    function transferOperator(address newOperator) external;

    function claimOperator() external;

    function revokeOperator() external;

    function updatePerpetualRiskParameter(uint256 perpetualIndex, int256[8] calldata riskParams)
        external;

    function addAMMKeeper(uint256 perpetualIndex, address keeper) external;

    function removeAMMKeeper(uint256 perpetualIndex, address keeper) external;

    function createPerpetual(
        address oracle,
        int256[9] calldata baseParams,
        int256[8] calldata riskParams,
        int256[8] calldata minRiskParamValues,
        int256[8] calldata maxRiskParamValues
    ) external;

    function runLiquidityPool() external;
}

interface IAuthenticator {
    /**
     * @notice  Check if an account has the given role.
     * @param   role    A bytes32 value generated from keccak256("ROLE_NAME").
     * @param   account The account to be checked.
     * @return  True if the account has already granted permissions for the given role.
     */
    function hasRole(bytes32 role, address account) external view returns (bool);

    /**
     * @notice  This should be called from external contract, to test if a account has specified role.

     * @param   role    A bytes32 value generated from keccak256("ROLE_NAME").
     * @param   account The account to be checked.
     * @return  True if the account has already granted permissions for the given role.
     */
    function hasRoleOrAdmin(bytes32 role, address account) external view returns (bool);
}

/**
 * @notice  OperatorProxy is a proxy that can forward transaction with authentication.
 */
contract OperatorProxy is Initializable, OwnableUpgradeable {
    using AddressUpgradeable for address;
    using SafeERC20Upgradeable for IERC20Upgradeable;
    using EnumerableSetUpgradeable for EnumerableSetUpgradeable.AddressSet;

    EnumerableSetUpgradeable.AddressSet internal _maintainers;

    event AddMaintainer(address indexed newMaintainer);
    event RemoveMaintainer(address indexed maintainer);
    event WithdrawERC20(address indexed recipient, address indexed token, uint256 amount);

    receive() external payable {
        revert("do not send ether to me");
    }

    modifier onlyMaintainer() {
        require(_maintainers.contains(msg.sender), "caller is not authorized");
        _;
    }

    /**
     * @notice  Initialize vault contract.
     */
    function initialize() external initializer {
        __Ownable_init();
    }

    function listMaintainers() public view returns (address[] memory result) {
        uint256 length = _maintainers.length();
        result = new address[](length);
        for (uint256 i = 0; i < length; i++) {
            result[i] = _maintainers.at(i);
        }
        return result;
    }

    function addMaintainer(address newMaintainer) external onlyOwner {
        require(!_maintainers.contains(newMaintainer), "maintainer already exists");
        _maintainers.add(newMaintainer);
        emit AddMaintainer(newMaintainer);
    }

    function removeMaintainer(address maintainer) external onlyOwner {
        require(_maintainers.contains(maintainer), "maintainer not exists");
        _maintainers.remove(maintainer);
        emit RemoveMaintainer(maintainer);
    }

    function transferOperator(address liquidityPool, address newOperator) external onlyOwner {
        ILiquidityPool(liquidityPool).transferOperator(newOperator);
    }

    function checkIn(address liquidityPool) external onlyMaintainer {
        ILiquidityPool(liquidityPool).checkIn();
    }

    function claimOperator(address liquidityPool) external onlyMaintainer {
        ILiquidityPool(liquidityPool).claimOperator();
    }

    function revokeOperator(address liquidityPool) external onlyMaintainer {
        ILiquidityPool(liquidityPool).revokeOperator();
    }

    function updatePerpetualRiskParameter(
        address liquidityPool,
        uint256 perpetualIndex,
        int256[8] calldata riskParams
    ) external onlyMaintainer {
        ILiquidityPool(liquidityPool).updatePerpetualRiskParameter(perpetualIndex, riskParams);
    }

    function addAMMKeeper(
        address liquidityPool,
        uint256 perpetualIndex,
        address keeper
    ) external onlyMaintainer {
        ILiquidityPool(liquidityPool).addAMMKeeper(perpetualIndex, keeper);
    }

    function removeAMMKeeper(
        address liquidityPool,
        uint256 perpetualIndex,
        address keeper
    ) external onlyMaintainer {
        ILiquidityPool(liquidityPool).removeAMMKeeper(perpetualIndex, keeper);
    }

    function createPerpetual(
        address liquidityPool,
        address oracle,
        int256[9] calldata baseParams,
        int256[8] calldata riskParams,
        int256[8] calldata minRiskParamValues,
        int256[8] calldata maxRiskParamValues
    ) external onlyMaintainer {
        ILiquidityPool(liquidityPool).createPerpetual(
            oracle,
            baseParams,
            riskParams,
            minRiskParamValues,
            maxRiskParamValues
        );
    }

    function runLiquidityPool(address liquidityPool) external onlyMaintainer {
        ILiquidityPool(liquidityPool).runLiquidityPool();
    }

    function withdrawERC20(address token, uint256 amount) external onlyMaintainer {
        require(token != address(0), "token is zero address");
        require(amount != 0, "amount is zero");
        IERC20Upgradeable(token).safeTransfer(msg.sender, amount);
        emit WithdrawERC20(msg.sender, token, amount);
    }
}