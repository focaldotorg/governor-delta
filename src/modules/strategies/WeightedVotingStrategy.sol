pragma solidity ^0.8.10;

import "@interfaces/IERC20.sol";
import "@interfaces/IVotingStrategy.sol";

contract WeightedVotingStrategy is IVotingStrategy {

    IERC20 public votingToken;

    constructor(address token_) {
        votingToken = IERC20(token_);
    }

    function virtualization() public view returns (bool) {
        return false;
    }

    function power(address owner) public view returns (uint) {
        return votingToken.balanceOf(owner);
    }

    function weight(address owner_) public view returns (uint) {
        return votingToken.balanceOf(owner);
    }

    function reduce(bytes32[] memory attestations) external returns (bool) { }

}
