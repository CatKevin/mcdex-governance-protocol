// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.7.4;

import "@openzeppelin/contracts-upgradeable/math/SafeMathUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/AddressUpgradeable.sol";

interface IValueCapture {
    function totalCapturedUSD() external view returns (uint256);
}

interface IMCB is IERC20Upgradeable {
    function mint(address account, uint256 amount) external;
}

contract Minter {
    using AddressUpgradeable for address;
    using SafeMathUpgradeable for uint256;

    IMCB public mcbToken;

    address public valueCapture;

    address public devAccount;
    uint256 public devShareRate;

    uint256 public beginTime;
    uint256 public dailySupplyLimit;
    uint256 public totalSupplyLimit;
    uint256 public initialSupply;

    event MintMCB(
        address indexed recipient,
        uint256 amount,
        uint256 recipientReceivedAmount,
        uint256 devReceivedAmount
    );

    event SetDevAccount(address indexed devOld, address indexed devNew);

    constructor(
        address mcbToken_,
        address valueCapture_,
        address devAccount_,
        uint256 devShareRate_,
        uint256 totalSupplyLimit_,
        uint256 beginTime_,
        uint256 dailySupplyLimit_
    ) {
        require(mcbToken_.isContract(), "token must be contract");
        require(valueCapture_.isContract(), "value capture must be contract");
        mcbToken = IMCB(mcbToken_);
        valueCapture = valueCapture_;

        devAccount = devAccount_;
        devShareRate = devShareRate_;
        totalSupplyLimit = totalSupplyLimit_;
        beginTime = beginTime_;
        dailySupplyLimit = dailySupplyLimit_;

        initialSupply = mcbToken.totalSupply();
    }

    function setDevAccount(address devAccount_) external {
        require(msg.sender == devAccount, "caller must be dev account");
        require(devAccount_ != devAccount, "already dev account");
        emit SetDevAccount(devAccount, devAccount_);
        devAccount = devAccount_;
    }

    function mintableMCBToken() public view returns (uint256) {
        uint256 amountByTime = mintableMCBTokenByTime();
        uint256 amountByValue = mintableMCBTokenByValue();
        uint256 mintableAmount = amountByTime > amountByValue ? amountByTime : amountByValue;
        if (mintableAmount > mintedMCBToken()) {
            uint256 mintableAmount = mintableAmount.sub(mintedMCBToken());
            if (mintableAmount > totalSupplyLimit.sub(mcbToken.totalSupply())) {
                return totalSupplyLimit.sub(mcbToken.totalSupply());
            }
            return mintableAmount;
        }
        return 0;
    }

    function mintedMCBToken() public view returns (uint256) {
        return mcbToken.totalSupply().sub(initialSupply);
    }

    function mintableMCBTokenByTime() public view returns (uint256) {
        uint256 time = getBlockTimestamp();
        if (time <= beginTime) {
            return 0;
        }
        return time.sub(beginTime).mul(dailySupplyLimit).div(86400);
    }

    function mintableMCBTokenByValue() public view returns (uint256) {
        return IValueCapture(valueCapture).totalCapturedUSD();
    }

    function mintMCBToken(address recipient, uint256 amount) public {
        uint256 mintableAmount = mintableMCBToken();
        require(amount > 0, "zero amount");
        require(amount <= mintableAmount, "exceeds mintable amount");
        uint256 toDevAmount = amount.mul(devShareRate).div(1e18);
        uint256 toRecipientAmount = amount.sub(toDevAmount);
        mcbToken.mint(devAccount, toDevAmount);
        mcbToken.mint(recipient, toRecipientAmount);
        require(mcbToken.totalSupply() <= totalSupplyLimit, "exceeds supply limit");

        emit MintMCB(recipient, amount, toRecipientAmount, toDevAmount);
    }

    function getBlockTimestamp() internal view virtual returns (uint256) {
        return block.timestamp;
    }
}
