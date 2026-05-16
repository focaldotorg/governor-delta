interface ^0.8.10;

interface IGovernor {
  
    /// @notice Emitted when a stakeholder locks canonical tokens into the governor
    event Locked(address indexed account, address indexed token, uint96 amount);

    /// @notice Emitted when a stakeholder unlocks canonical tokens from the governor
    event Unlocked(address indexed account, address indexed token, uint96 amount);

    /// @notice An event emitted when a new proposal is created
    event ProposalCreated(uint id, address proposer, address[] targets, uint[] values, string[] signatures, bytes[] calldatas, uint startBlock, uint endBlock, string description);

    /// @notice An event emitted when a vote has been cast on a proposal
    /// @param voter The address which casted a vote
    /// @param proposalId The proposal id which was voted on
    /// @param support Support value for the vote. 0=against, 1=for, 2=abstain
    /// @param votes Number of votes which were cast by the voter
    /// @param reason The reason given for the vote by the voter
    event VoteCast(address indexed voter, uint proposalId, uint8 support, uint votes, string reason);

    /// @notice An event emitted when a proposal has been canceled
    event ProposalCanceled(uint id);

    /// @notice An event emitted when a proposal has been queued in the Timelock
    event ProposalQueued(uint id, uint eta);

    /// @notice An event emitted when a proposal has been executed in the Timelock
    event ProposalExecuted(uint id);

    /// @notice An event emitted when a proposal has been vetoed in the Timelock
    event ProposalVetoed(uint id);

    /// @notice An event emitted when the voting delay is set
    event VotingDelaySet(uint oldVotingDelay, uint newVotingDelay);

    /// @notice An event emitted when the voting period is set
    event VotingPeriodSet(uint oldVotingPeriod, uint newVotingPeriod);

    /// @notice Emitted when implementation is changed
    event NewImplementation(address oldImplementation, address newImplementation);
    
    /// @notice Emitted when proposal threshold is set
    event ProposalQuorumSet(uint8 tier, uint oldProposalQuorum, uint newProposalQuorum);

    /// @notice Emitted when proposal threshold is set
    event ProposalQuotaSet(uint oldProposalQuota, uint newProposalQuota);

    /// @notice Emitted when veto threshold is set
    event VetoQuorumSet(uint oldVetoQuorum, uint newVetoQuorum);

    /// @notice Emitted when veto threshold is set
    event VetoQuotaSet(uint oldVetoQuota, uint newVetoQuota);

    /// @notice Emitted when pendingAdmin is changed
    event NewPendingAdmin(address oldPendingAdmin, address newPendingAdmin);

    /// @notice Emitted when pendingAdmin is accepted, which means admin is updated
    event NewAdmin(address oldAdmin, address newAdmin);

    /// @notice Emitted when an account changes a delegate
    event Delegate(address indexed delegator, address indexed delegate, bytes32 indexed id);

    /// @notice Emitted when an account revokes a delegate 
    event Revoke(address indexed delegator, address indexed delegate, bytes32 indexed id, uint timeUntilExpiry);

}
