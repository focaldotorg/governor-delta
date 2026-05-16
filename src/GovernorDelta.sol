pragma solidity ^0.8.10;

import "@interfaces/IGovernor.sol";
import "GovernorStorageV3.sol";

contract GovernorDelta is IGovernor, GovernorStorageV3 {

    /// @notice The name of this contract
    string public constant name = "Governor Delta";

    /// @notice The minimum setable voting period
    uint public constant MIN_VOTING_PERIOD = 3 days;

    /// @notice The max setable voting period
    uint public constant MAX_VOTING_PERIOD = 100 days;

    /// @notice The max delegation period
    uint public constant MAX_DELEGATION_PERIOD = 1 year;

    /// @notice The min setable voting delay 
    uint public constant MIN_VOTING_DELAY = 2 days;

    /// @notice The max setable voting delay
    uint public constant MAX_VOTING_DELAY = 2 weeks; 

    /// @notice The minimum number of votes of a proposal required for a proposal to be valid
    uint public constant MIN_QUORUM_VOTES = 400000e18; 

    /// @notice The maximum number of actions that can be included in a proposal
    uint public constant MAX_PROPOSAL_OPERATIONS = 10; 

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
        require(votingDelay_ >= MIN_VOTING_DELAY && votingDelay_ <= MAX_VOTING_DELAY, "GovernorDelta:: invalid voting delay");

        timelock = ITimelock(timelock_);
        canonicalToken = IERC20(token_);
        votingModule = IVotingStrategy(address(new WeightedVotingStrategy(address(this))));
        proposalConfig[0] = Graduated({ quorum: DEFAULT_TIER_0_QUORUM, duration: DEFAULT_TIER_0_DURATION });
        proposalConfig[1] = Graduated({ quorum: DEFAULT_TIER_1_QUORUM, duration: DEFAULT_TIER_1_DURATION });
        proposalConfig[2] = Graduated({ quorum: DEFAULT_TIER_2_QUORUM, duration: DEFAULT_TIER_2_DURATION });
        proposalConfig[3] = Graduated({ quorum: DEFAULT_TIER_3_QUORUM, duration: DEFAULT_TIER_3_DURATION });

        votingDelay = votingDelay_;
        proposalQuota = proposalQuota_;
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
        Stake storage s = stakes[msg.sender];
        uint256 deltaTime = block.timestamp - s.lastUpdateTime;
        s.deltaAmountTime += s.amount * deltaTime;
        s.lastUpdateTime = block.timestamp;
        s.amount += amount;

        canonicalToken.transferFrom(msg.sender, address(this), amount);

        emit Locked(msg.sender, address(canonicalToken), amount);
    }

    /**
      * @notice Withdraws canonical tokens from the governor
      * @param amount The amount of canonical tokens to withdraw
    **/
    function unlock(uint amount) external {
        Stake storage s = stakes[msg.sender];
        require(amount > 0, "GovernorDelta::withdraw: invalid amount");
        require(amount <= s.amount, "GovernorDelta::withdraw: insufficient balance");
        require(s.unlockTime < block.timestamp, "GovernorDelta::withdraw: active vote or delegation");
        uint256 deltaTime = block.timestamp - s.lastUpdateTime;
        s.deltaAmountTime += s.amount * deltaTime;
        s.lastUpdateTime = block.timestamp;
        s.amount -= amount;

        canonicalToken.transfer(msg.sender, amount);

        emit Unlocked(msg.sender, address(canonicalToken), amount);
    }

    /**
      * @notice Delegates voting power to another account
      * @param delegatee The address to delegate voting power to
      * @param expiry The timestamp at which the delegation expires
      * @return id The delegation identifier 
    **/
    function delegate(address delegatee, uint256 expiry) external returns (bytes32 id) {
        Stake storage s = stakes[msg.sender];
        require(delegatee != address(0), "GovernorDelta::delegate: invalid delegatee");
        require(expiry > block.timestamp, "GovernorDelta::delegate: insufficient expiry");
        require(expiry - block.timestamp <= MAX_DELEGATION_PERIOD, "GovernorDelta::delegate: invalid expiry");
        require(delegations[msg.sender].target == address(0), "GovernorDelta::delegate: active delegation");
        require(s.unlockTime < block.timestamp, "GovernorDelta::delegate: vote already assigned");
        require(s.amount > 0, "GovernorDelta::delegate: no stake");
        id = keccak256(abi.encode(msg.sender, delegatee, expiry));

        _moveDelegates(msg.sender, delegatee, expiry);
        emit Delegate(msg.sender, delegatee, id);
    }

    /**
      * @notice Redelegates voting power after an expired delegation
      * @param delegatee The address to delegate voting power to, pass msg.sender to reclaim
      * @param expiry The timestamp at which the delegation expires
      * @return id The delegation identifier
    **/
    function redelegate(address delegatee, uint256 expiry) external returns (bytes32 id) {
        require(delegatee != address(0), "GovernorDelta::redelegate: invalid delegatee");
        require(expiry > block.timestamp, "GovernorDelta::delegate: insufficient expiry");
        require(expiry - block.timestamp <= MAX_DELEGATION_PERIOD, "GovernorDelta::delegate: invalid expiry");
        require(delegations[msg.sender].expiry <= block.timestamp, "GovernorDelta::redelegate: active delegation");
        id = keccak256(abi.encode(msg.sender, delegatee, expiry));

        _moveDelegates(msg.sender, delegatee, expiry);
        emit Delegate(msg.sender, delegatee, id);
    }

    /**
      * @notice Revokes an active delegation
      * @dev Delegation identifier is recomputed from stored parameters 
    **/
    function revoke() external {
        Delegate storage d = delegations[msg.sender];
        require(d.target != address(0), "GovernorDelta::revoke: no active delegation");
        require(d.expiry > block.timestamp, "GovernorDelta::revoke: delegation already expired");
        bytes32 id = keccak256(abi.encode(msg.sender, d.target, d.expiry));
        uint256 timeRemaining = d.expiry - block.timestamp;
        address delegatee = d.target;

        _moveDelegates(msg.sender, msg.sender, block.timestamp);
        emit Revoke(msg.sender, delegatee, id, timeRemaining);
    }

    function _moveDelegates(address delegator, address delegatee, uint256 expiry) internal {
        if (delegator != delegatee) {
          delegations[delegator] = Delegate({ target: delegatee, expiry: expiry });
          stakes[delegator].unlockTime = expiry;
        } else {
          delete delegations[delegator];

          stakes[delegator].unlockTime = block.timestamp;
        }
    } 

    /**
      * @notice Admin function for setting the voting delay
      * @param newVotingDelay Wew voting delay as a timestamp 
    */
    function _setVotingDelay(uint newVotingDelay) external {
        require(msg.sender == admin, "GovernorDelta::_setVotingDelay: admin only");
        require(newVotingDelay >= MIN_VOTING_DELAY && newVotingDelay <= MAX_VOTING_DELAY, "GovernorDelta::_setVotingDelay: invalid voting delay");
        uint oldVotingDelay = votingDelay;
        votingDelay = newVotingDelay;

        emit VotingDelaySet(oldVotingDelay,votingDelay);
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
    function _setProposalConfig(Graduated[4] memory configs) external {
        require(msg.sender == admin, "GovernorDelta::_setProposalConfig: admin only");

        for (uint8 i = 0; i < 4; i++) {
            require(configs[i].quorum >= MIN_QUORUM_VOTES, "GovernorDelta::_setProposalConfig: quorum below minimum");
            require(configs[i].duration >= MIN_VOTING_PERIOD && configs[i].duration <= MAX_VOTING_PERIOD, "GovernorDelta::_setProposalConfig: invalid duration");
            proposalConfig[i] = configs[i];
        }
    }

}
