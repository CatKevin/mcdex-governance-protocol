// SPDX-License-Identifier: GPL
pragma solidity 0.7.4;

interface IComponent {
    /**
     * @notice  The address of base token.
     */
    function baseToken() external view returns (address);

    /**
     * @notice  A hook which is call when user deposits MCB into XMCB.
     */
    function beforeMintingToken(
        address account,
        uint256 amount,
        uint256 totalSupply
    ) external;

    /**
     * @notice  A hook which is call when user withdraws MCB from XMCB.
     */
    function beforeBurningToken(
        address account,
        uint256 amount,
        uint256 totalSupply
    ) external;
}
