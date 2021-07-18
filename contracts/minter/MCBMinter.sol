// SPDX-License-Identifier: GPL
pragma solidity 0.7.4;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts-upgradeable/utils/AddressUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/math/SafeMathUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";

import { IAuthenticator } from "../interfaces/IAuthenticator.sol";
import { ICaptureNotifyRecipient } from "../interfaces/ICaptureNotifyRecipient.sol";
import { Config } from "./Config.sol";
import { Context } from "./Context.sol";
import { Distribution } from "./Distribution.sol";
import { Minter } from "./Minter.sol";

contract MCBMinter is
    Initializable,
    Context,
    Config,
    Distribution,
    Minter,
    ReentrancyGuardUpgradeable,
    ICaptureNotifyRecipient
{
    using AddressUpgradeable for address;
    using SafeMathUpgradeable for uint256;

    bytes32 public constant MINTER_ADMIN_ROLE = keccak256("MINTER_ADMIN_ROLE");
    bytes32 public constant VALUE_CAPTURE_ROLE = keccak256("VALUE_CAPTURE_ROLE");

    IAuthenticator public authenticator;
W
    event BaseMint(address indexed recipient, uint256 amount);
    event RoundMint(uint256 index, address indexed recipient, uint256 amount);
    event OnValueCaptured(uint256 totalCapturedUSD, uint256 lastCapturedBlock);

    function initialize(
        address authenticator_,
        address mcbToken_,
        address developer_,
        uint256 genesisBlock_,
        uint128 baseInitialSupply_,
        uint128 baseMinReleaseRate_
    ) external initializer {
        require(authenticator_.isContract(), "authenticator must be contract");

        __ReentrancyGuard_init();
        __Config_init(genesisBlock_);
        __Distribution_init(baseInitialSupply_, baseMinReleaseRate_);
        __Minter_init(mcbToken_, developer_);

        authenticator = IAuthenticator(authenticator_);
    }

    modifier onlyAuthorized() {
        require(
            authenticator.hasRoleOrAdmin(MINTER_ADMIN_ROLE, msg.sender),
            "caller is not authorized"
        );
        _;
    }

    /**
     * @notice  Get the mintable amounts of base and rounds.
     * @return  baseMintableAmount      The mintable amount from base.
     * @return  roundMintableAmounts    The mintable amounts from all rounds.
     */
    function getMintableAmounts()
        public
        returns (uint256 baseMintableAmount, uint256[] memory roundMintableAmounts)
    {
        _updateMintableAmount();
        baseMintableAmount = _baseMintableAmount();
        uint256 count = roundMintStates.length;
        if (count > 0) {
            roundMintableAmounts = new uint256[](count);
            for (uint256 i = 0; i < count; i++) {
                roundMintableAmounts[i] = _roundMintableAmount(i);
            }
        }
    }

    /**
     * @notice  Set the dev account who is the beneficiary of shares from minted MCB token.
     *          Only can be called by current developer.
     */
    function setDeveloper(address newDeveloper) external {
        require(msg.sender == developer, "sender must be developer");
        _setDeveloper(newDeveloper);
    }

    /**
     * @notice  Create a new round for vesting.
     */
    function newRound(
        address recipient,
        uint128 maxSupply,
        uint128 rateLimitPerBlock,
        uint128 startBlock
    ) external onlyAuthorized {
        require(recipient != address(0), "recipient is zero address");
        _newRound(recipient, maxSupply, rateLimitPerBlock, startBlock);
    }

    /**
     * @notice  Update mintable amount. There are two types of minting, with different destination: base and series-A.
     *          The base mintable amount is composed of a constant releasing rate and the fee catpure from liqudity pool;
     *          The series-A part is mainly from the captured part of base mintable amount.
     *          This method updates both the base part and the series-A part. To see the rule, check ... for details.
     */
    function updateMintableAmount() public {
        _updateMintableAmount();
    }

    /**
     * @notice  Mint token from the part of baseMintableAmount.
     */
    function mintFromBase(address recipient, uint256 amount) external onlyAuthorized {
        updateMintableAmount();
        _releaseFromBase(amount);
        _mint(recipient, amount);
        emit BaseMint(recipient, amount);
    }

    /**
     * @notice  Mint token from the part of a round.
     *          This method need no authentication to be called.
     *          So the beneficiary is able to call at any time to release the vesting tokens.
     */
    function mintFromRound(uint256 index) external {
        _updateMintableAmount();
        address recipient = _roundRecipient(index);
        uint256 amount = _roundMintableAmount(index);
        _releaseFromRound(index, amount);
        _mint(recipient, amount);
        emit RoundMint(index, recipient, amount);
    }

    /**
     * @notice  Update captured USD value. Only can be called by the sender who is granted
     *          VALUE_CAPTURE_ROLE role by authenticator.
     *          Calls in the same block will be ignored.
     * @param   totalCapturedUSD    CapturedUSD value, represented with a fix-float of decimals 18.
     * @param   lastCapturedBlock   The blockNumber captured last time.
     */
    function onValueCaptured(uint256 totalCapturedUSD, uint256 lastCapturedBlock)
        external
        override
    {
        require(
            authenticator.hasRole(VALUE_CAPTURE_ROLE, msg.sender),
            "caller is not valueCapture"
        );
        _updateExtraMintableAmount(totalCapturedUSD, lastCapturedBlock);
        emit OnValueCaptured(totalCapturedUSD, lastCapturedBlock);
    }

    bytes32[50] private __gap;
}
