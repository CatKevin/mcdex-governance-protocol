// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.7.4;

struct Checkpoint {
    uint256 fromBlock;
    uint256 value;
}

struct Snapshot {
    uint256 count;
    mapping(uint256 => Checkpoint) checkpoints;
}

library SnapshotOperation {
    function saveCheckpoint(Snapshot storage snapshot, uint256 newValue) internal {
        uint256 blockNumber = block.number;
        uint256 count = snapshot.count;
        if (count > 0 && snapshot.checkpoints[count - 1].fromBlock == blockNumber) {
            snapshot.checkpoints[count - 1].value = newValue;
        } else {
            snapshot.checkpoints[count].value = newValue;
            snapshot.count = count + 1;
        }
    }

    function findCheckpoint(Snapshot storage snapshot, uint256 blockNumber)
        internal
        view
        returns (uint256)
    {
        require(blockNumber < block.number, "not yet determined");
        uint256 count = snapshot.count;
        if (count == 0) {
            return 0;
        }

        // First check most recent balance
        if (snapshot.checkpoints[count - 1].fromBlock <= blockNumber) {
            return snapshot.checkpoints[count - 1].value;
        }
        // Next check implicit zero balance
        if (snapshot.checkpoints[0].fromBlock > blockNumber) {
            return 0;
        }
        uint256 lower = 0;
        uint256 upper = count - 1;
        while (upper > lower) {
            uint256 center = upper - (upper - lower) / 2; // ceil, avoiding overflow
            Checkpoint memory cp = snapshot.checkpoints[center];
            if (cp.fromBlock == blockNumber) {
                return cp.value;
            } else if (cp.fromBlock < blockNumber) {
                lower = center;
            } else {
                upper = center - 1;
            }
        }
        return snapshot.checkpoints[lower].value;
    }
}
