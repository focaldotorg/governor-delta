pragma solidity ^0.8.10;

import "@interfaces/IGovernorDelta.sol";

contract WeightedVotingStrategy is IVotingStrategy {

    IGovernorDelta governor;

    constructor(address delta_) {
        governor = IGovernorDelta(delta_);
    }

    function virtualization() public view returns (bool) {
        return false;
    }

    function power(address owner) public view returns (uint amount) {
        (amount,) = governor.stake(owner);
    }

    function weight(address owner) public view returns (uint amount) {
        (amount,) = governor.stake(owner);
    }

    function reduce(bytes32[] memory attestations) external returns (bool) { }

}
