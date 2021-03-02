// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.7.4;

interface IComponent {
    function owner() external view returns (address);

    function baseToken() external view returns (address);

    function beforeMintingToken(
        address account,
        uint256 amount,
        uint256 totalSupply
    ) external;

    function beforeBurningToken(
        address account,
        uint256 amount,
        uint256 totalSupply
    ) external;
}
