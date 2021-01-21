pragma solidity 0.7.4;
// SPDX-License-Identifier: UNLICENSED

import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface IValueCapture {
    function getCapturedUSD() external view returns (uint256);
}

interface IMCBToken {
    function mint(address to, uint256 amount) external;
}

contract Vault {
    using SafeMath for uint256;

    address internal _valueCapture;
    address internal _mcbToken;
    address internal _dev;

    uint256 internal _phase1BeginTime;
    uint256 internal _phase1DailySupplyLimit;
    uint256 internal _phase2BeginTime;
    uint256 internal _phase2DailySupplyLimit;

    uint256 internal _mintedMCB;
    uint256 internal _devShareRate;
    uint256 internal _lastMintTime;

    event MintMCB(
        address indexed recipient,
        uint256 amount,
        uint256 recipientReceivedAmount,
        uint256 devReceivedAmount
    );

    // constructor(uint256 startTime) public {
    //     _startTime = startTime;
    //     _mintedMCB = _mcbToken.totalSupply();
    // }

    function setDev(address dev) public {
        require(msg.sender == dev, "caller must be dev");
    }

    function mintMCB(address recipient, uint256 amount) public {
        uint256 maxMintableAmount = _getMintableAmount();
        require(amount <= maxMintableAmount, "exceed max mintable amount");

        uint256 toDevAmount = amount.mul(_phase2DailySupplyLimit).div(1e18);
        uint256 toRecipientAmount = amount.sub(toDevAmount);
        IMCBToken(_mcbToken).mint(recipient, toRecipientAmount);
        IMCBToken(_mcbToken).mint(_dev, toDevAmount);
        _mintedMCB = _mintedMCB.add(amount);

        emit MintMCB(recipient, amount, toRecipientAmount, toDevAmount);
    }

    function execute(address to, bytes memory data) public {}

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
        mintableAmount = IValueCapture(_valueCapture).getCapturedUSD();
    }

    function _getMintableAmountByTime(uint256 time) internal view returns (uint256 mintableAmount) {
        if (time <= _phase1BeginTime) {
            mintableAmount = 0;
            return mintableAmount;
        }
        if (time > _phase1BeginTime) {
            uint256 mintable =
                time.sub(_phase1BeginTime).mul(1e18).div(86400).mul(_phase1DailySupplyLimit);
            mintableAmount = mintableAmount.add(mintable);
        }
        if (time > _phase2BeginTime) {
            uint256 mintable =
                time.sub(_phase2BeginTime).mul(1e18).div(86400).mul(_phase2BeginTime);
            mintableAmount = mintableAmount.add(mintable);
        }
    }
}
