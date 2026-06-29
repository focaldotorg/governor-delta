pragma solidity ^0.8.10;

import "@interfaces/IGovernorDelta.sol";
import "@interfaces/ITimeWeightedVotingStrategy.sol";
import "@interfaces/IVotingStrategy.sol";

contract TenureVotingStrategy is IVotingStrategy, ITimeWeightedVotingStrategy {

    IGovernorDelta governor;

    constructor(address delta_) {
        governor = IGovernorDelta(delta_);
    }

    function virtualized() external returns (bool) {
        return true;
    }

    function power(address owner) external returns (uint) {
        return 0;
    }

    function predict(address owner, uint timestamp) external returns (uint) {
        return 0;
    }

    function weight(address owner) external returns (uint) {
        return 0;
    }

}

