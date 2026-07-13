pragma solidity ^0.8.10;

interface IBootstrappedVotingStrategy {

    struct Seed {
        /// @notice The address to assign seed 
        address account;
        /// @notice Timestamp for seed expiration
        uint lifeTime; 
        /// @notice Baseline seed time value 
        uint basisTime;
    }

}

