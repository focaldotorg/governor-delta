// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import "@interfaces/IBootstrappedVotingStrategy.sol";

abstract contract BootstrappedVotingStrategy is IBootstrappedVotingStrategy {

    uint constant public MAX_SEED_TIME = 365 days;

    /// @notice Tenure mapping for accounts, acting as a basis 
    mapping(address => Seed) public seeds;

    /**
      * @notice Get seeded effective time for an account  
      * @param owner The address to query for
      * @return Baseline effective time 
    **/
    function seededEffectiveTime(address owner) public view returns (uint) {
        Seed storage seed = seeds[owner];
        return seed.lifeTime > block.timestamp ? seed.basisTime : 0;
    }

    /**
      * @notice Returns the future projected voting power of a given account
      * @param owner The address to query for
      * @param timestamp The future time to query the voting power at
      * @return The future voting power of the account 
    **/
    function predict(address owner, uint timestamp) public view virtual returns (uint);

}
