pragma solidity ^0.8.10;

import "@interfaces/IProposalGuard.sol";
import "@interfaces/IERC20.sol";
import "@interfaces/IGovernorDelta.sol";

contract StakingGuard is IProposalGuard {

    address public governor;

    address public timelock;

    IERC20 public token;

    constructor(address governor_, address timelock_) {
        governor = governor_;
        timelock = timelock_;
        token = IGovernorDelta(governor_).canconicalToken();
    } 

    function record(address target, uint proposalId) public {
        require(msg.sender == governor || msg.sender == timelock, "TransferGuard::record: only admin");
    }
  
    function compare(address target, uint proposalId) public {
        require(msg.sender == governor || msg.sender == timelock, "TransferGuard::compare: only admin");
        uint balance = token.balanceOf(governor);
        uint staked = IGovernorDelta(governor).totalStaked();

        if (msg.sender == governor) {
          require(balance >= staked, "StakingGuard::compare: cannot expense staked balances");
        } 
    }

}

