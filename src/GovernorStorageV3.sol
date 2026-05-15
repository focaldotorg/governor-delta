// SPDX-License-Identifier: BSD-3-Clause
pragma solidity ^0.8.10;

import "@interfaces/ITimelock.sol";
import "@interfaces/IERC20.sol";
import "@interfaces/IVotingStrategy.sol";

contract GovernorProxyStorage {
    /// @notice Administrator for this contract
    address public admin;

    /// @notice Pending administrator for this contract
    address public pendingAdmin;

    /// @notice Active brains of Governor
    address public implementation;
}

/**
 * @title Storage for Governor Bravo Delegate
 * @notice For future upgrades, do not change GovernorBravoDelegateStorageV1. Create a new
 * contract which implements GovernorBravoDelegateStorageV1 and following the naming convention
 * GovernorBravoDelegateStorageVX.
 */
contract GovernorStorageV1 is GovernorProxyStorage {

    /// @notice The delay before voting on a proposal may take place, once proposed, in blocks
    uint public votingDelay;

    /// @notice The duration of voting on a proposal, in blocks
    uint public votingPeriod;

    /// @notice ------- DEPRECATED -----------
    /// @dev REASON: Proxy storage compatibility
    /// @dev NOTE: Superseded by `proposalQuota`
    /// @dev DO NOT REMOVE, REORDER, OR REUSE
    IGovernorToken internal _proposalThreshold;
    /// @notice ------------------------------

    /// @notice Initial proposal id set at become
    uint public initialProposalId;

    /// @notice The total number of proposals
    uint public proposalCount;

    /// @notice The address of the Compound Protocol Timelock
    ITimelock public timelock;

    /// @notice ------- DEPRECATED -----------
    /// @dev REASON: Proxy storage compatibility
    /// @dev NOTE: Superseded by `canonicalToken`
    /// @dev DO NOT REMOVE, REORDER, OR REUSE
    IGovernorToken internal _comp;
    /// @notice ------------------------------

    /// @notice ------- DEPRECATED -----------
    /// @dev REASON: Proxy storage compatibility
    /// @dev NOTE: Superseded by `proposals`
    /// @dev DO NOT REMOVE, REORDER, OR REUSE
    mapping (uint => Proposal) internal _proposals;
    /// @notice ------------------------------

    /// @notice The latest proposal for each proposer
    mapping (address => uint) public latestProposalIds;

    struct Proposal {
        /// @notice Unique id for looking up a proposal
        uint id;

        /// @notice Creator of the proposal
        address proposer;

        /// @notice The timestamp that the proposal will be available for execution, set once the vote succeeds
        uint eta;

        /// @notice the ordered list of target addresses for calls to be made
        address[] targets;

        /// @notice The ordered list of values (i.e. msg.value) to be passed to the calls to be made
        uint[] values;

        /// @notice The ordered list of function signatures to be called
        string[] signatures;

        /// @notice The ordered list of calldata to be passed to each call
        bytes[] calldatas;

        /// @notice The block at which voting begins: holders must delegate their votes prior to this block
        uint startBlock;

        /// @notice The block at which voting ends: votes must be cast prior to this block
        uint endBlock;

        /// @notice Current number of votes in favor of this proposal
        uint forVotes;

        /// @notice Current number of votes in opposition to this proposal
        uint againstVotes;

        /// @notice Current number of votes for abstaining for this proposal
        uint abstainVotes;

        /// @notice Flag marking whether the proposal has been canceled
        bool canceled;

        /// @notice Flag marking whether the proposal has been executed
        bool executed;

        /// @notice Receipts of ballots for the entire set of voters
        mapping (address => Receipt) receipts;
    }

    /// @notice Ballot receipt record for a voter
    struct Receipt {
        /// @notice Whether or not a vote has been cast
        bool hasVoted;

        /// @notice Whether or not the voter supports the proposal or abstains
        uint8 support;

        /// @notice The number of votes the voter had, which were cast
        uint96 votes;
    }

    /// @notice Possible states that a proposal may be in
    enum ProposalState {
        Pending,
        Active,
        Canceled,
        Defeated,
        Succeeded,
        Queued,
        Expired,
        Executed
    }

}

contract GovernorStorageV2 is GovernorStorageV1 {

    /// @notice ------- DEPRECATED -----------
    /// @dev REASON: Proxy storage compatibility
    /// @dev DO NOT REMOVE, REORDER, OR REUSE
    mapping (address => uint) internal _whitelistExpirations;
    /// @notice ------------------------------

    /// @notice ------- DEPRECATED -----------
    /// @dev REASON: Proxy storage compatibility
    /// @dev DO NOT REMOVE, REORDER, OR REUSE
    address internal _whitelistGuardian;
    /// @notice ------------------------------

}

contract GovernorStorageV3 is GovernorStorageV2 {

    /// @notice The basis token or currency of authority 
    IERC20 public canonicalToken;

    /// @notice The basis token or currency of authority 
    IVotingStrategy public votingModule;

    /// @notice Flag to toggle delegation functionality
    bool public delegationEnabled;

    /// @notice The number of votes required in order for a voter to become a proposer
    uint public proposalQuota;

    /// @notice The number of votes required in order for a voter to initiate a veto proposal 
    uint public vetoQuota;

    /// @notice The number of votes cast required for a veto proposal to be considered valid
    uint public vetoQuorum; 

    /// @notice The official record of all proposals ever proposed
    mapping (uint => ProposalV2) internal proposals;

    /// @notice Graduated proposal parameters 
    mapping(uint8 => Graduated) public proposalConfig;

    struct ProposalV2 {
        /// @notice Unique id for looking up a proposal
        uint id;

        /// @notice Proposal severity (0,1,2,3)
        uint8 tier;

        /// @notice Creator of the proposal
        address proposer;

        /// @notice The timestamp that the proposal will be available for execution, set once the vote succeeds
        uint eta;

        /// @notice the ordered list of target addresses for calls to be made
        address[] targets;

        /// @notice The ordered list of values (i.e. msg.value) to be passed to the calls to be made
        uint[] values;

        /// @notice The ordered list of function signatures to be called
        string[] signatures;

        /// @notice The ordered list of calldata to be passed to each call
        bytes[] calldatas;

        /// @notice The timestamp at which voting begins
        uint startTime;

        /// @notice The timestamp at which voting end
        uint endTime;

        /// @notice The proposal voting results
        Tally results;

        /// @notice The veto proposal voting results 
        Tally veto;

        /// @notice Flag marking whether the proposal has been canceled
        bool canceled;

        /// @notice Flag marking whether the proposal has been executed
        bool executed;

        /// @notice Flag marking whether the proposal has been vetoed
        bool contested;

    }

    /// @notice Proposal configuration 
    struct Tally {
        /// @notice Pure votes cast
        Ballot primary;

        /// @notice Virtual votes cast
        Ballot virtualized;

        /// @notice Records of ballots for the entire set of voters
        mapping (address => Record) records;
    }

    /// @notice Proposal vote record
    struct Ballot {
        /// @notice Current number of votes in favor of this proposal
        uint forVotes;

        /// @notice Current number of votes in opposition to this proposal
        uint againstVotes;

        /// @notice Current number of votes for abstaining for this proposal
        uint abstainVotes;
    }

    /// @notice Proposal voter record
    struct Record {
        /// @notice Whether or not a vote has been cast
        bool hasVoted;

        /// @notice Whether or not the voter supports the proposal or abstains
        uint8 decision;

        /// @notice The number of votes the voter had, which were cast
        uint96 power;

        /// @notice The number of tokens the voter had, which were cast 
        uint96 weight;
    }

    /// @notice Proposal configuration 
    struct Graduated {
        /// @notice The minimum number of votes of a proposal required for a proposal to be valid
        uint256 quorum;
        /// @notice The duration of which a proposal will be active for voting
        uint256 duration;
    }

}

