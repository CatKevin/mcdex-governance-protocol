pragma solidity 0.7.4;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/math/SafeMathUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/AddressUpgradeable.sol";

interface ArbSys {
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
     * @notice Send given amount of Eth to dest from sender.
     * This is a convenience function, which is equivalent to calling sendTxToL1 with empty calldataForL1.
     * @param destination recipient address on L1
     * @return unique identifier for this L2-to-L1 transaction.
     */
    function withdrawEth(address destination)
        external
        payable
        returns (uint256);

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

abstract contract L2ArbitrumMessenger {
    address internal constant arbsysAddr = address(100);

    event TxToL1(
        address indexed _from,
        address indexed _to,
        uint256 indexed _id,
        bytes _data
    );

    function sendTxToL1(
        uint256 _l1CallValue,
        address _from,
        address _to,
        bytes memory _data
    ) internal virtual returns (uint256) {
        uint256 _id =
            ArbSys(arbsysAddr).sendTxToL1{value: _l1CallValue}(_to, _data);
        emit TxToL1(_from, _to, _id, _data);
        return _id;
    }
}

contract L2MCBv2 is ERC20Upgradeable, OwnableUpgradeable, L2ArbitrumMessenger {
    using AddressUpgradeable for address;
    using SafeMathUpgradeable for uint256;

    address public l1Token;
    address public l2Token;
    address public gateway;
    uint256 public l1TotalSupply;
    uint256 public l2Minted;

    function initialize(
        string memory name_,
        string memory symbol_,
        address gateway_,
        address l1Token_,
        uint256 l1TotalSupply_
    ) external initializer {
        require(gateway_.isContract(), "gateway must be contract");

        __Ownable_init();
        __ERC20_init(name_, symbol_);
        gateway = gateway_;
        l1Token = l1Token_;
        l1TotalSupply = l1TotalSupply_;
    }

    modifier onlyGateway {
        require(msg.sender == gateway, "ONLY_GATEWAY");
        _;
    }

    function totalSupply() public view virtual override returns (uint256) {
        return l2Minted;
    }

    function bridgeMint(address account, uint256 amount)
        external
        virtual
        onlyGateway
    {
        _mint(account, amount);
        l2Minted = l2Minted.add(amount);
    }

    function bridgeBurn(address account, uint256 amount)
        external
        virtual
        onlyGateway
    {
        _burn(account, amount);
        l2Minted = l2Minted.sub(amount);
    }

    function mint(address to, uint256 amount) external virtual onlyOwner {
        _mint(to, amount);
        // mint to gateway on L1
        sendTxToL1(0, address(this), l1Token, getOutboundCalldata(amount));
        l2Minted = l2Minted.add(amount);
    }

    function getOutboundCalldata(uint256 amount)
        public
        view
        virtual
        returns (bytes memory)
    {
        return abi.encodeWithSignature("escrowMint(uint256)", amount);
    }
}
