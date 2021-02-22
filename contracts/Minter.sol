// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.7.4;

import "@openzeppelin/contracts-upgradeable/math/SafeMathUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/AddressUpgradeable.sol";

interface IValueCapture {
    function getCapturedUSD() external view returns (uint256);
}

interface IMCB is IERC20Upgradeable {
    function mint(address account, uint256 amount) external;
}

contract MCBMinter {
    using AddressUpgradeable for address;
    using SafeMathUpgradeable for uint256;

    IMCB public mcbToken;

    address internal _dev;
    address public valueCapture;

    uint256 public phase1BeginTime;
    uint256 public phase1DailySupplyLimit;
    uint256 public phase2BeginTime;
    uint256 public phase2DailySupplyLimit;
    uint256 public totalSupplyLimitation;

    uint256 internal _mintedMCB;
    uint256 internal _devShareRate;
    uint256 internal _lastMintTime;

    event MintMCB(
        address indexed recipient,
        uint256 amount,
        uint256 recipientReceivedAmount,
        uint256 devReceivedAmount
    );

    event SetDev(address indexed devOld, address indexed devNew);

    constructor(address mcbToken_) {
        require(mcbToken_.isContract(), "token must be contract");

        mcbToken = IMCB(mcbToken_);
        // require(
        //     supplyLimitation_ >= mcbToken.totalSupply(),
        //     "supply limitation exceeds total supply"
        // );
    }

    function setDev(address dev) public {
        require(msg.sender == dev, "caller must be dev");
        emit SetDev(_dev, dev);
        _dev = dev;
    }

    function mintMCB(address recipient, uint256 amount) public {
        uint256 maxMintableAmount = _getMintableAmount();
        require(amount <= maxMintableAmount, "exceed mintable amount");
        require(
            mcbToken.totalSupply().add(amount) <= totalSupplyLimitation,
            "exceeds total supply limitation"
        );

        uint256 toDevAmount = amount.mul(phase2DailySupplyLimit).div(1e18);
        uint256 toRecipientAmount = amount.sub(toDevAmount);
        mcbToken.mint(recipient, toRecipientAmount);
        mcbToken.mint(_dev, toDevAmount);
        _mintedMCB = _mintedMCB.add(amount);

        emit MintMCB(recipient, amount, toRecipientAmount, toDevAmount);
    }

    function _getMintableAmount() internal view returns (uint256 mintableAmount) {
        uint256 amountByTime = _getMintableAmountByTime(block.timestamp);
        uint256 amountByValue = _getMintableAmountByValue();
        // max between 2 limits
        mintableAmount = amountByTime > amountByValue ? amountByTime : amountByValue;
        mintableAmount = mintableAmount > _mintedMCB
            ? mintableAmount = mintableAmount.sub(_mintedMCB)
            : 0;
    }

    function _getMintableAmountByValue() internal view returns (uint256 mintableAmount) {
        mintableAmount = IValueCapture(valueCapture).getCapturedUSD();
    }

    function _getMintableAmountByTime(uint256 time) internal view returns (uint256 mintableAmount) {
        if (time <= phase1BeginTime) {
            mintableAmount = 0;
            return mintableAmount;
        }
        if (time > phase1BeginTime) {
            uint256 mintable =
                time.sub(phase1BeginTime).mul(1e18).div(86400).mul(phase1DailySupplyLimit);
            mintableAmount = mintableAmount.add(mintable);
        }
        if (time > phase2BeginTime) {
            uint256 mintable = time.sub(phase2BeginTime).mul(1e18).div(86400).mul(phase2BeginTime);
            mintableAmount = mintableAmount.add(mintable);
        }
    }
}
