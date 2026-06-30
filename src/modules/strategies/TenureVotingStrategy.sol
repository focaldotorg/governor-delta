pragma solidity ^0.8.10;

import "@interfaces/IGovernorDelta.sol";
import "@interfaces/ITimeWeightedVotingStrategy.sol";
import "@interfaces/IVotingStrategy.sol";

contract TenureVotingStrategy is IVotingStrategy, ITimeWeightedVotingStrategy {

    IGovernorDelta public governor; 
    Tranche[] public tranches;

    constructor(address governor_) {
        governor = IGovernorDelta(governor_);
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

