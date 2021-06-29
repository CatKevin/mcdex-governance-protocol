// SPDX-License-Identifier: GPL
pragma solidity 0.7.4;

interface IValueCapture {
    function totalCapturedUSD() external view returns (uint256);

    function lastCapturedBlock() external view returns (uint256);

    function getCapturedValue()
        external
        view
        returns (uint256 totalCapturedUSD_, uint256 lastCapturedBlock_);

    /**
     * @notice Set receiver of value captured events.
     */
    function setCaptureNotifyRecipient(address newRecipient) external;

    /**
     * @notice  Return all addresses of USD tokens in whitelist as an array.
     */
    function listUSDTokens(uint256 begin, uint256 end)
        external
        view
        returns (address[] memory result);

    /**
     * @notice  Add a USD token to whitelist.
     *          Since not all the ERC20 has decimals interface, caller needs to specify the decimal of USD token.
     *          But the `decimals()` of token will be checked to match the parameter passed in if possible.
     *
     * @param   token       The address of usd token to be put into whitelist.
     * @param   decimals    The decimals of token.
     */
    function addUSDToken(address token, uint256 decimals) external;

    /**
     * @notice  Remove a USD token from whitelist.
     *
     * @param   token   The address of USD token to remove.
     */
    function removeUSDToken(address token) external;

    /**
     * @notice  Add a 'exchange' for some token.
     *          A exchange is known as a external contract who has an interface to accept some kind of token
     *          and return USD token in value capture's whitelist.
     *          That means the output token of exchange must be in th e whitelist.
     *          See contract/interfaces/IUSDConvertor.sol for interface spec of a exchange.
     *
     * @param   token               The address of any token accepted by exchange.
     * @param   exchange_          The address of exchange contract.
     */
    function setExternalExchange(address token, address exchange_) external;

    /**
     * @notice  Batch version of forwardAsset.
     *
     * @param   tokens      The array of address of token to forward to vault.
     * @param   amountsIn   The array of amounts to (exchange for USD and) forward to vault.
     */
    function forwardMultiAssets(address[] memory tokens, uint256[] memory amountsIn) external;

    /**
     * @notice  This method has the same usage as `forwardERC20Token`.
     *
     *          *Asset sent though this method to vault will not affect mintable amount of MCB.*
     */
    function forwardETH(uint256 amount) external;

    /**
     * @notice  This method is should not be called if there are any exchange available for given ERC20 token.
     *          But if there is really not, or the exchange is lack of enough liquidity,
     *          guardian will be able to send the asset to vault for other usage.
     *
     *          *Asset sent though this method to vault will not affect mintable amount of MCB.*
     */
    function forwardERC20Token(address token, uint256 amount) external;

    /**
     * @notice  This method has the same usage as `forwardERC20Token`.
     *
     *          *Asset sent though this method to vault will not affect mintable amount of MCB.*
     */
    function forwardERC721Token(address token, uint256 tokenID) external;
}
