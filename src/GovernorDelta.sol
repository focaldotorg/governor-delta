pragma solidity ^0.8.10;

import "@interfaces/IGovernorDelta.sol";
import "GovernorStorageV3.sol";

contract GovernorDelta is GovernorStorageV3 {

    /// @notice The name of this contract
    string public constant name = "Governor Delta";

    /// @notice The minimum setable voting period
    uint public constant MIN_VOTING_PERIOD = 3 days;

    /// @notice The max setable voting period
    uint public constant MAX_VOTING_PERIOD = 100 days; 

    /// @notice The min setable voting delay 
    uint public constant MIN_VOTING_DELAY = 2 days;

    /// @notice The max setable voting delay
    uint public constant MAX_VOTING_DELAY = 2 weeks; 

    /// @notice The minimum number of votes of a proposal required for a proposal to be valid
    uint public constant MIN_QUORUM_VOTES = 400000e18; 

    /// @notice The maximum number of actions that can be included in a proposal
    uint public constant proposalMaxOperations = 10; 

    /// @notice Proposal tier 0 (low) minimum canonical weight
    uint public constant DEFAULT_TIER_0_QUORUM = 10000e18;

    /// @notice Proposal tier 0 (low) voting duration
    uint public constant DEFAULT_TIER_0_DURATION = 7 days;

    /// @notice Proposal tier 1 (medium) minimum canonical weight
    uint public constant DEFAULT_TIER_1_QUORUM = 15000e18;

    /// @notice Proposal tier 1 (medium) voting duration
    uint public constant DEFAULT_TIER_1_DURATION = 18 days;

    /// @notice Proposal tier 2 (high) minimum canonical weight
    uint public constant DEFAULT_TIER_2_QUORUM = 33000e18;

    /// @notice Proposal tier 2 (high) voting duration
    uint public constant DEFAULT_TIER_2_DURATION = 38 days;

    /// @notice Proposal tier 3 (critical) minimum canonical weight
    uint public constant DEFAULT_TIER_3_QUORUM = 51000e18;

    /// @notice Proposal tier 3 (critical) voting duration
    uint public constant DEFAULT_TIER_3_DURATION = 91 days;

    /// @notice The EIP-712 typehash for the contract's domain
    bytes32 public constant DOMAIN_TYPEHASH = keccak256("EIP712Domain(string name,uint256 chainId,address verifyingContract)");

    /// @notice The EIP-712 typehash for the ballot struct used by the contract
    bytes32 public constant BALLOT_TYPEHASH = keccak256("Ballot(uint256 proposalId,uint8 support)");

    /// @notice The EIP-712 typehash for the delegation struct used by the contract
    bytes32 public constant DELEGATION_TYPEHASH = keccak256("Delegation(address delegatee,uint256 nonce,uint256 expiry)");

    /**
      * @notice Used to initialize the contract during delegator constructor
      * @param timelock_ The address of the Timelock
      * @param token_ The address of the canonical token
      * @param votingPeriod_ The initial voting period
      * @param votingDelay_ The initial voting delay
      * @param proposalQuota_ The initial proposal threshold
    **/
    function initialize(address timelock_, address token_, uint votingPeriod_, uint votingDelay_, uint proposalQuota_) virtual public {
        require(address(timelock) == address(0), "GovernorDelta::initialize: can only initialize once");
        require(msg.sender == admin, "GovernorDelta::initialize: admin only");
        require(timelock_ != address(0), "GovernorDelta::initialize: invalid timelock address");
        require(token_ != address(0), "GovernorDelta::initialize: invalid canonical token address");

        timelock = ITimelock(timelock_);
        canonicalToken = IERC20(token_);
        votingModule = IVotingStrategy(address(new WeightedVotingStrategy(token_)));

        _setVotingPeriod(votingPeriod_);
        _setVotingDelay(votingDelay_);
        _setProposalQuota(proposalQuota_);
        _setProposalConfig([
            Graduated({ quorum: DEFAULT_TIER_0_QUORUM, duration: DEFAULT_TIER_0_DURATION }),
            Graduated({ quorum: DEFAULT_TIER_1_QUORUM, duration: DEFAULT_TIER_1_DURATION }),
            Graduated({ quorum: DEFAULT_TIER_2_QUORUM, duration: DEFAULT_TIER_2_DURATION }),
            Graduated({ quorum: DEFAULT_TIER_3_QUORUM, duration: DEFAULT_TIER_3_DURATION })
        ]);
    }

    /**
      * @notice Returns the stake of a given account
      * @param owner The address of the stakeholder
      * @return amount The total amount of tokens staked
      * @return deltaAmountTime Capital-weighted time coefficient
    **/
    function stake(address owner) public view returns (uint, uint) {
        Stake storage s = stakes[owner];
        return (s.amount, s.deltaAmountTime);
    }

    /**
      * @notice Locks canonical tokens into the governor to accrue voting weight
      * @param amount The amount of canonical tokens to lock
    **/
    function lock(uint amount) external {
        require(amount > 0, "GovernorDelta::lock: invalid amount");
        Stake storage s = stake[msg.sender];
        uint256 deltaTime = block.timestamp - s.lastUpdateTime;
        s.deltaAmountTime += s.amount * deltaTime;
        s.lastUpdateTime = block.timestamp;
        s.amount += amount;

        canonicalToken.transferFrom(msg.sender, address(this), amount);

        emit Locked(msg.sender, address(canonicalToken), amount);
    }

    /**
      * @notice Withdraws canonical tokens from the governor
      * @dev Settling prior period before mutating amount ensures deltaAmountTime is accurate
      * @param amount The amount of canonical tokens to withdraw
    **/
    function unlock(uint amount) external {
        Stake storage s = stake[msg.sender];
        require(amount > 0, "GovernorDelta::withdraw: invalid amount");
        require(amount <= s.amount, "GovernorDelta::withdraw: insufficient balance");
        require(block.timestamp > s.lastVoteTime, "GovernorDelta::withdraw: active vote");
        uint256 deltaTime = block.timestamp - s.lastUpdateTime;
        s.deltaAmountTime += s.amount * deltaTime;
        s.lastUpdateTime = block.timestamp;
        s.amount -= amount;

        canonicalToken.transfer(msg.sender, amount);

        emit Unlocked(msg.sender, address(canonicalToken), amount);
    }

    /**
      * @notice Admin function for setting the voting delay
      * @param newVotingDelay Wew voting delay as a timestamp 
    */
    function _setVotingDelay(uint newVotingDelay) external {
        require(msg.sender == admin, "GovernorDelta::_setVotingDelay: admin only");
        require(newVotingDelay >= MIN_VOTING_DELAY && newVotingDelay <= MAX_VOTING_DELAY, "GovernorBravo::_setVotingDelay: invalid voting delay");
        uint oldVotingDelay = votingDelay;
        votingDelay = newVotingDelay;

        emit VotingDelaySet(oldVotingDelay,votingDelay);
    }

    /**
      * @notice Admin function for setting the voting period
      * @param newVotingPeriod new voting period, in blocks
    */
    function _setVotingPeriod(uint newVotingPeriod) external {
        require(msg.sender == admin, "GovernorDelta::_setVotingPeriod: admin only");
        require(newVotingPeriod >= MIN_VOTING_PERIOD && newVotingPeriod <= MAX_VOTING_PERIOD, "GovernorBravo::_setVotingPeriod: invalid voting period");
        uint oldVotingPeriod = votingPeriod;
        votingPeriod = newVotingPeriod;

        emit VotingPeriodSet(oldVotingPeriod, votingPeriod);
    }

    /**
      * @notice Admin function for setting the proposal threshold
      * @dev newProposalThreshold must be greater than the hardcoded min
      * @param newProposalThreshold new proposal threshold
    */
    function _setProposalQuota(uint newProposalThreshold) external {
        require(msg.sender == admin, "GovernorDelta::_setProposalThreshold: admin only");
        uint oldProposalThreshold = proposalThreshold;
        proposalQuota = newProposalThreshold;

        emit ProposalQuotaSet(oldProposalThreshold, proposalQuota);
    }

    /**
     * @notice Sets the proposal configuration for all tiers
     * @dev Tier 0 (low) to tier 3 (critical), each with independent quorum and duration
     * @param configs Fixed array of four tier configurations, ordered by severity ascending
     */
    function _setProposalConfig(Graduated[4] memory configs) internal {
        for (uint8 i = 0; i < 4; i++) {
            require(configs[i].quorum >= MIN_QUORUM_VOTES, "GovernorDelta::_setProposalConfig: quorum below minimum");
            require(configs[i].duration >= MIN_VOTING_PERIOD && configs[i].duration <= MAX_VOTING_PERIOD, "GovernorDelta::_setProposalConfig: invalid duration");
            proposalConfig[i] = configs[i];
        }
    }

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

    /// @notice An event thats emitted when an account changes its delegate
    event DelegateChanged(address indexed delegator, address indexed fromDelegate, address indexed toDelegate);

    /// @notice An event thats emitted when a delegate account's vote balance changes
    event DelegateVotesChanged(address indexed delegate, uint previousBalance, uint newBalance);

}
