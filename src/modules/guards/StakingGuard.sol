pragma solidity ^0.8.10;

import "@interfaces/IProposalGuard.sol";
import "@interfaces/IERC20.sol";
import "@interfaces/IGovernorDelta.sol";

contract StakingGuard is IProposalGuard {

    address public governor;

    IERC20 public token;

    constructor(address governor_) {
        governor = governor_;
        token = IGovernorDelta(governor_).canonicalToken();
    } 

    function record(address target, uint proposalId) public {
        require(msg.sender == governor, "TransferGuard::record: only admin");
    }
  
    function compare(address target, uint proposalId) public {
        require(msg.sender == governor, "TransferGuard::compare: only admin");

        if (target == governor) {
          uint balance = token.balanceOf(governor);
          uint staked = IGovernorDelta(governor).totalStaked();
          require(balance >= staked, "StakingGuard::compare: cannot expense staked balances");
        } 
    }

}

