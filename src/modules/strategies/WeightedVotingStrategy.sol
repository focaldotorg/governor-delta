pragma solidity ^0.8.10;

import "@interfaces/IGovernorDelta.sol";
import "@interfaces/IVotingStrategy.sol";

contract WeightedVotingStrategy is IVotingStrategy {

    IGovernorDelta public governor;

    constructor(address delta_) {
        governor = IGovernorDelta(delta_);
    }

    /**
      * @notice Returns the modules configuration type 
      * @return A boolean value to indicate whether the module has virtual weighting
    **/
    function virtualized() external pure returns (bool) {
        return false;
    }

    /**
      * @notice Returns the current voting power of a given account
      * @param owner The address to query for
      * @return The voting power of the account 
    **/
    function power(address owner) external view returns (uint) {
        (uint balance,,) = governor.stake(owner);
        return balance;
    }

    /**
      * @notice Returns the future projected voting power of a given account
      * @param owner The address to query for
      * @param timestamp The future time to query the voting power at
      * @return The future voting power of the account 
    **/
    function predict(address owner, uint timestamp) external view returns (uint) {
        (uint balance,,) = governor.stake(owner);
        return balance;
    }

    /**
      * @notice Returns the current voting weight of a given account
      * @param owner The address to query for
      * @return The voting weight of the account 
    **/
    function weight(address owner) external view returns (uint) {
        (uint balance,,) = governor.stake(owner);
        return balance;
    }

}
