pragma solidity ^0.8.10;

interface IProposalGuard {

    /// @notice Pre execution state snapshot 
    function record(address context, uint proposalId) external;

    /// @notice Post execution state diff
    function compare(address context, uint proposalId) external;

}




