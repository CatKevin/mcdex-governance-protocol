pragma solidity 0.7.4;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/AddressUpgradeable.sol";

interface IBridge {
    function activeOutbox() external view returns (address);
}

interface IInbox {
    function bridge() external view returns (IBridge);
}

interface IOutbox {
    function l2ToL1Sender() external view returns (address);
}

interface ITokenGateway {
    function router() external view returns (address);
}

contract L1MCBv2 is ERC20Upgradeable, OwnableUpgradeable {
    using AddressUpgradeable for address;

    address public l2Token;
    address public inbox;
    address public gateway;

    function initialize(
        string memory name_,
        string memory symbol_,
        address gateway_,
        address inbox_,
        address l2Token_
    ) external initializer {
        require(gateway_.isContract(), "gateway must be contract");

        __Ownable_init();
        __ERC20_init(name_, symbol_);
        gateway = gateway_;
        inbox = inbox_;
        l2Token = l2Token_;

        _mint(msg.sender, 1000 * 1e18);
    }

    function escrowMint(uint256 amount) external virtual {
        // require(isSenderL2Token(), "sender must be l2Token");
        _mint(gateway, amount);
    }

    function registerTokenOnL2(
        uint256 maxSubmissionCost,
        uint256 maxGas,
        uint256 gasPriceBid
    ) external payable {
        (bool ok, bytes memory result) =
            gateway.call{ value: msg.value }(
                abi.encodeWithSignature(
                    "registerTokenToL2(address,uint256,uint256,uint256)",
                    l2Token,
                    maxGas,
                    gasPriceBid,
                    maxSubmissionCost
                )
            );
        require(ok, result.length > 0 ? string(result) : "fail to register token");
    }

    function setGateway(
        uint256 maxSubmissionCost,
        uint256 maxGas,
        uint256 gasPriceBid
    ) external payable {
        (bool ok, bytes memory result) =
            ITokenGateway(gateway).router().call{ value: msg.value }(
                abi.encodeWithSignature(
                    "setGateway(address,uint256,uint256,uint256)",
                    gateway,
                    maxGas,
                    gasPriceBid,
                    maxSubmissionCost
                )
            );
        require(ok, result.length > 0 ? string(result) : "fail to register token");
    }

    function isSenderL2Token() internal view virtual returns (bool) {
        IOutbox outbox = IOutbox(IInbox(inbox).bridge().activeOutbox());
        return l2Token == outbox.l2ToL1Sender();
    }
}
