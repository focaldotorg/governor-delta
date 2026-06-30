pragma solidity ^0.8.10;

import "@interfaces/IGovernorDelta.sol";
import "@interfaces/IVotingStrategy.sol";

contract WeightedVotingStrategy is IVotingStrategy {

    IGovernorDelta public governor;

    constructor(address delta_) {
        governor = IGovernorDelta(delta_);
    }

    function virtualized() external returns (bool) {
        return false;
    }

    function power(address owner) external returns (uint) {
        (uint balance,) = governor.stake(owner);
        return balance;
    }

    function predict(address owner, uint timestamp) external returns (uint) {
        (uint balance,) = governor.stake(owner);
        return balance;
    }

    function weight(address owner) external returns (uint) {
        (uint balance,) = governor.stake(owner);
        return balance;
    }

}
