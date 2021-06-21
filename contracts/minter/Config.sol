// SPDX-License-Identifier: GPL
pragma solidity 0.7.4;

import "@openzeppelin/contracts-upgradeable/proxy/Initializable.sol";

import { Context } from "./Context.sol";

abstract contract Config is Initializable, Context {
    uint256 public constant MCB_MAX_SUPPLY = 10_000_000 * 1e18;
    uint256 public constant DEVELOPER_COMMISSION_RATE = 25 * 1e16; // 25%
    uint256 public genesisBlock;

    function __Config_init(uint256 genesisBlock_) internal initializer {
        require(genesisBlock_ != 0, "genesisBlock is zero");
        genesisBlock = genesisBlock_;
    }

    modifier onlyAfterGenesis() {
        require(_blockNumber() >= genesisBlock, "genesis not reached");
        _;
    }

    /**
     * @notice Get block number beginning from genesis.
     */
    function _safeBlockNumber(uint256 blockNumber) internal view returns (uint256) {
        return blockNumber < genesisBlock ? genesisBlock : blockNumber;
    }

    bytes32[50] private __gap;
}
