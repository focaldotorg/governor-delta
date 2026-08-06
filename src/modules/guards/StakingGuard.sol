pragma solidity ^0.8.10;

import "@interfaces/IProposalGuard.sol";
import "@interfaces/IERC20.sol";
import "@interfaces/IGovernorDelta.sol";

contract StakingGuard is IProposalGuard {

    /// @notice Governor target context address
    address public governor;

    /// @notice Governing token target context
    IERC20 public token;

    /**
      * @notice Initialisation 
      * @param governor_ Target governor context address
    **/
    constructor(address governor_) {
        governor = governor_;
        token = IGovernorDelta(governor_).canonicalToken();
    } 

    /**
      * @notice Post execution state diff
      * @param context Target guard context address 
      * @param proposalId Associated proposal identifier 
    **/
    function record(address context, uint proposalId) public {
        require(msg.sender == governor, "TransferGuard::record: only admin");
    }
  
    /**
      * @notice Post execution state diff
      * @param context Target guard context address 
      * @param proposalId Associated proposal identifier 
    **/
    function compare(address context, uint proposalId) public {
        require(msg.sender == governor, "TransferGuard::compare: only admin");

        if (context == governor) {
          uint balance = token.balanceOf(governor);
          uint staked = IGovernorDelta(governor).totalStaked();
          require(balance >= staked, "StakingGuard::compare: cannot expense staked balances");
        } 
    }

}

