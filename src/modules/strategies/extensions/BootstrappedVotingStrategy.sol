// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import "@interfaces/IBootstrappedVotingStrategy.sol";

abstract contract BootstrappedVotingStrategy is IBootstrappedVotingStrategy {

    /// @notice Tenure mapping for accounts, acting as a basis 
    mapping(address => uint) public seeds;

    /**
      * @notice Get seeded effective time for an account  
      * @param owner The address to query for
      * @return Baseline effective time 
    **/
    function seededEffectiveTime(address owner) public view returns (uint) {
        return seeds[owner];
    }

    /**
      * @notice Returns the future projected voting power of a given account
      * @param owner The address to query for
      * @param timestamp The future time to query the voting power at
      * @return The future voting power of the account 
    **/
    function predict(address owner, uint timestamp) public view virtual returns (uint);

}
