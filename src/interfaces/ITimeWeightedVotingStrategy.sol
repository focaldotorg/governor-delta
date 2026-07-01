pragma solidity ^0.8.10;

interface ITimeWeightedVotingStrategy {

    struct Tranche {
        /// @notice Duration or time range (eg. 90 days)
        uint64  size; 
         /// @notice Fixed multiplier for voting weight must be gte than the multiplier unit 
        uint192 multiplier;
    }

    /// @notice Event emitted when a new tranche configuration is set 
    event NewTranches(Tranche[] oldTranches, Tranche[] newTranches);

}
