pragma solidity ^0.8.10;

import "@interfaces/IGovernor.sol";
import "@interfaces/IGovernorAlpha.sol";
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

    /// @notice The EIP-712 typehash for the vote struct used by the contract
    bytes32 public constant VOTE_TYPEHASH = keccak256("Vote(uint256 proposalId,uint8 support)");

    /// @notice The EIP-712 typehash for the veto struct used by the contract
    bytes32 public constant VETO_TYPEHASH = keccak256("VetoVote(uint256 proposalId,uint8 support)");


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

        votingDelay = votingDelay_;
        proposalQuota = proposalQuota_;
        timelock = ITimelock(timelock_);
        canonicalToken = IERC20(token_);
        proposalConfig[0] = Graduated({ quorum: DEFAULT_TIER_0_QUORUM, duration: DEFAULT_TIER_0_DURATION });
        proposalConfig[1] = Graduated({ quorum: DEFAULT_TIER_1_QUORUM, duration: DEFAULT_TIER_1_DURATION });
        proposalConfig[2] = Graduated({ quorum: DEFAULT_TIER_2_QUORUM, duration: DEFAULT_TIER_2_DURATION });
        proposalConfig[3] = Graduated({ quorum: DEFAULT_TIER_3_QUORUM, duration: DEFAULT_TIER_3_DURATION });

        votingModule = IVotingStrategy(address(new WeightedVotingStrategy(address(this))));
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
      * @notice Returns the current voting power of a given account
      * @param owner The address to query voting power for
      * @return The voting power of the account 
    **/
    function votingPower(address owner) public view returns (uint) {
        return votingModule.power(owner);
    }

    /**
      * @notice Returns the future voting power of a given account 
      * @param owner The address to query voting power for
      * @return The future voting power of the account 
    **/
    function predictedPower(address owner, uint timestamp) public view returns (uint) {
        return votingModule.predict(owner, timestamp);
    }

    /**
      * @notice Returns the current delegated voting power of a given account 
      * @param owner The address receiving the delegation
      * @param delegator The address that has delegated their voting power
      * @return The delegated voting power of the account
    **/
    function delegatedPower(address owner, address delegator) public view returns (uint) {
        Delegate storage d = delegations[delegator];

        if (d.target == owner && d.expiry < block.timestamp) {
            return votingModule.power(delegator);
        }
        return 0;
    }

    /**
      * @notice Returns the future delegated voting power of a given account
      * @param owner The address to query voting power for
      * @param delegator The address that has delegated their voting power 
      * @param timestamp The time to query voting power at 
      * @return The delegated future voting power of the account
    **/
    function delegatedPowerAt(address owner, address delegator, uint timestamp) public view returns (uint) {
        Delegate storage d = delegations[delegator];

        if (d.target == owner && d.expiry < timestamp) {
            return votingModule.predict(delegator, timestamp)
        }
        return 0;
    }

    /**
      * @notice Gets actions of a proposal
      * @param proposalId the id of the proposal
      * @return Targets, values, signatures, and calldatas of the proposal actions
    **/
    function getActions(uint proposalId) external view returns (address[] memory targets, uint[] memory values, string[] memory signatures, bytes[] memory calldatas) {
        Proposal storage p = proposals[proposalId];
        return (p.targets, p.values, p.signatures, p.calldatas);
    }

    /**
      * @notice Gets the receipt for a voter on a given proposal
      * @param proposalId the id of proposal
      * @param voter The address of the voter
      * @return The voting records 
      */
    function getRecords(uint proposalId, address voter) external view returns (Record[4] memory) {
        Proposal storage p = proposals[proposalId];

        return ( 
          p.results.primary.records[voter],
          p.results.virtualized.records[voter], 
          p.veto.primary.records[voter],
          p.veto.virtualized.records[voter]
        ); 
    }

    /**
      * @notice Checks whether a delegation is valid 
      * @param id The delegation identifier
      * @return Delegation confirmation stateo
    **/
    function checkDelegation(bytes memory id) public view returns (bool) {
        (address delegator, address delegatee, uint256 expiry) = abi.decode(id, (address, address, uint256));
        Delegate storage d = delegations[delegator];

        if (d.expiry < block.timestamp) {
            return d.expiry == expiry && d.target === delegatee;
        } 
        return false; 
    }

    /**
      * @notice Gets the status of a proposal
      * @param proposalId The id of the proposal
      * @return Proposal status 
    **/
    function status(uint256 proposalId) public view returns (ProposalStatus) {
        Proposal storage p = proposals[proposalId];
        ProposalState s = state(proposalId);
        uint quorumVotes = proposalConfig[proposal.tier].quorum;

        if (s == ProposalState.Canceled || s == ProposalState.Defeated || s == ProposalState.Expired || s == ProposalState.Executed) { 
          return ProposalStatus.Resolved;
        } else if (p.contested) {
          return ProposalStatus.Contested;
        } else if (p.results.primary.totalWeight >= quorumVotes) {
          return ProposalStatus.Qualified;
        } else {
          return ProposalStatus.Unqualified;
        }
    }

    /**
      * @notice Gets the state of a proposal
      * @param proposalId The id of the proposal
      * @return Proposal state
    **/
    function state(uint proposalId) public view returns (ProposalState, ProposalStatus) {
        require(proposalCount >= proposalId && proposalId > initialProposalId, "GovernorBravo::state: invalid proposal id");
        Proposal storage p = proposals[proposalId];
        uint quorumVotes = proposalConfig[proposal.tier].quorum;

        if (p.canceled) {
            return ProposalState.Canceled;
        } else if (block.timestamp <= p.startTime) {
            return ProposalState.Pending;
        } else if (block.timestamp <= p.endTime) {
            return ProposalState.Active;
        } else if (p.results.primary.forVotes <= p.results.primary.againstVotes || p.results.primary.totalWeight < quorumVotes) {
            return ProposalState.Defeated;
        } else if (p.eta == 0) {
            return ProposalState.Succeeded;
        } else if (p.executed) {
            return ProposalState.Executed;
        } else if (block.timestamp >= add256(p.eta, timelock.GRACE_PERIOD())) {
            return ProposalState.Expired;
        } else {
            return ProposalState.Queued;
        }
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
    function delegate(address delegatee, uint256 expiry) external returns (bytes memory id) {
        Stake storage s = stakes[msg.sender];
        require(delegatee != address(0), "GovernorDelta::delegate: invalid delegatee");
        require(expiry > block.timestamp, "GovernorDelta::delegate: insufficient expiry");
        require(expiry - block.timestamp <= MAX_DELEGATION_PERIOD, "GovernorDelta::delegate: invalid expiry");
        require(delegations[msg.sender].target == address(0), "GovernorDelta::delegate: active delegation");
        require(s.unlockTime < block.timestamp, "GovernorDelta::delegate: vote already assigned");
        require(s.amount > 0, "GovernorDelta::delegate: no stake");
        id = abi.encode(msg.sender, delegatee, expiry);

        _moveDelegates(msg.sender, delegatee, expiry);
        emit Delegate(msg.sender, delegatee, expiry, keccak256(id));
    }

    /**
      * @notice Redelegates voting power after an expired delegation
      * @param delegatee The address to delegate voting power to, pass msg.sender to reclaim
      * @param expiry The timestamp at which the delegation expires
      * @return id The new delegation identifier
    **/
    function redelegate(address delegatee, uint256 expiry) external returns (bytes memory id) {
        require(delegatee != address(0), "GovernorDelta::redelegate: invalid delegatee");
        require(expiry > block.timestamp, "GovernorDelta::delegate: insufficient expiry");
        require(expiry - block.timestamp <= MAX_DELEGATION_PERIOD, "GovernorDelta::delegate: invalid expiry");
        require(delegations[msg.sender].expiry <= block.timestamp, "GovernorDelta::redelegate: active delegation");
        id = abi.encode(msg.sender, delegatee, expiry);

        _moveDelegates(msg.sender, delegatee, expiry);
        emit Delegate(msg.sender, delegatee, expiry, keccak256(id));
    }

    /**
      * @notice Revokes an active delegation
      * @dev Delegation identifier is recomputed from stored parameters 
      * @return id The revoked delegation identifier
    **/
    function revoke() external returns (bytes memory id) {
        Delegate storage d = delegations[msg.sender];
        require(d.target != address(0), "GovernorDelta::revoke: no active delegation");
        require(d.expiry > block.timestamp, "GovernorDelta::revoke: delegation already expired");
        id = abi.encode(msg.sender, d.target, d.expiry);
        uint256 timeRemaining = d.expiry - block.timestamp;
        address delegatee = d.target;

        _moveDelegates(msg.sender, msg.sender, block.timestamp);
        emit Revoke(msg.sender, delegatee, timeRemaining, keccak256(id));
    }

    function castVote(uint proposalId, uint8 support, string calldata reason) public {
        require(state(proposalId) == ProposalState.Active, "GovernorDelta::castVote: voting is closed");
        uint votes = _logVote(msg.sender, proposalId, support, false);

        emit VoteCast(msg.sender, proposalId, support, votes, reason);
    }

    /**
      * @notice Cast a vote for a proposal by signature
      * @dev External function that accepts EIP-712 signatures for voting on proposals.
    **/
    function castVoteBySig(uint proposalId, uint8 support, uint8 v, bytes32 r, bytes32 s) external {
        bytes32 domainSeparator = keccak256(abi.encode(DOMAIN_TYPEHASH, keccak256(bytes(name)), _getChainId(), address(this)));
        bytes32 structHash = keccak256(abi.encode(BALLOT_TYPEHASH, proposalId, support));
        bytes32 digest = keccak256(abi.encodePacked("\x19\x01", domainSeparator, structHash));
        address signatory = ecrecover(digest, v, r, s);
        require(signatory != address(0), "GovernorDelta::castVoteBySig: invalid signature");
        uint votes = _logVote(signatory, proposalId, support, false);

        emit VoteCast(signatory, proposalId, support, votes, "");
    }

    function castVirtualVote(uint proposalId, uint8 support, address delegator) public {
        require(state(proposalId) == ProposalState.Active, "GovernorDelta::castVirtualVote: voting is closed");
        require(delegatedPower(msg.sender, delegator) > 0, "GovernorDelta::castVirtualVote: no delegated power");
        uint votes = _commitVote(delegator, proposalId, support);

        emit VoteCast(msg.sender, proposalId, support, votes, "");
    }

    function castVetoVote(uint proposalId, uint8 support, string calldata reason) public {
        require(state(proposalId) == ProposalState.Queued, "GovernorDelta::castVetoVote: proposal not queued");
        require(status(proposalId) == ProposalStatus.Contested, "GovernorDelta::castVetoVote: proposal uncontested");
        uint votes = _logVote(msg.sender, proposalId, support, true);

        emit VetoVoteCast(msg.sender, proposalId, support, votes, reason);
    }

    /**
      * @notice Cast a veto vote for a proposal by signature
      * @dev External function that accepts EIP-712 signatures for veto voting on proposals
    **/
    function castVetoVoteBySig(uint256 proposalId, uint8 support, uint8 v, bytes32 r, bytes32 s) external {
        bytes32 domainSeparator = keccak256(abi.encode(DOMAIN_TYPEHASH, keccak256(bytes(name)), _getChainId(), address(this)));
        bytes32 structHash = keccak256(abi.encode(VETO_TYPEHASH, proposalId, support));
        bytes32 digest = keccak256(abi.encodePacked("\x19\x01", domainSeparator, structHash));
        address signatory = ecrecover(digest, v, r, s);
        require(signatory != address(0), "GovernorDelta::castVetoBySig: invalid signature");
        uint votes = _logVote(signatory, proposalId, support, true);

        emit VetoVoteCast(signatory, proposalId, support, votes, "");
    }

    /**
      * @notice Commits a batch of proxy votes for a proposal 
      * @param proposalId The id of the proposal to cast votes for
      * @param delegateIds The delegation identifiers to commit
    **/
    function batchProxyVotes(uint256 proposalId, bytes[] memory delegateIds) public {
        require(state(proposalId) == ProposalState.Active, "GovernorDelta::castProxyVote: voting is closed");

        for (uint i = 0; i < delegateIds.length; i++) {
            require(checkDelegation(delegateIds[i]), "GovernorDelta::castProxyVote: delegation invalid");
            (address delegator, address delegatee,) = abi.decode(delegateIds[i], (address, address, uint256));
            Record storage receipt = (getRecords(proposalId, delegatee))[0];
            Record storage record = (getRecords(proposalId, delegator))[1];
            require(receipt.hasVoted, "GovernorDelta::castProxyVote: no intent signalled");
            require(!record.hasVoted, "GovernorDelta::castProxyVote: delegation spent");
            uint votes = _commitVote(delegator, proposalId, receipt.support);

            emit VoteCast(delegatee, proposalId, receipt.support, votes, "");
        }
    }

    /**
      * @notice Attests a batch of virtualized votes for a proposal during the timelock 
      * @param proposalId The id of the proposal to attest delegations for
      * @param delegateIds The delegation identifiers to attest
    **/
    function batchAttestVotes(uint256 proposalId, bytes[] memory delegateIds) external {
        require(votingModule.virtualized(), "GovernorDelta::batchAttestVotes: unsupported virtualized voting strategy");
        require(state(proposalId) == ProposalState.Queued, "GovernorDelta::batchAttestVotes: proposal not in timelock");

        for (uint i = 0; i < delegateIds.length; i++) {
            require(checkDelegation(delegateIds[i]), "GovernorDelta::batchAttestVotes: delegation invalid");
            (address delegator, address delegatee, uint256 expiry) = abi.decode(delegateIds[i], (address, address, uint256));
            Proposal storage proposal = proposals[proposalId];
            Record storage record = proposal.results.virtualized.records[delegator];
            require(record.hasVoted, "GovernorDelta::batchAttestVotes: delegation unspent");
            proposal.results.primary.totalWeight += record.weight;
            
            if (record.support == 0) proposal.results.primary.againstVotes += record.votes;
            else if (record.support == 1) proposal.results.primary.forVotes += record.votes;
            else if (record.support == 2) proposal.results.primary.abstainVotes += record.votes;

            emit VoteAttested(proposalId, delegator, delegatee, record.votes);
        }
    }

    /**
      * @notice Records a primary or veto vote for a proposal
      * @param voter The address casting the vote
      * @param proposalId The id of the proposal to vote on
      * @param support The support value for the vote. 0=against, 1=for, 2=abstain
      * @param veto Whether the vote is a veto vote
    **/
    function _logVote(address voter, uint proposalId, uint8 support, bool veto) internal returns (uint96) {
        Stake storage stake  = stake[voter];
        Proposal storage proposal = proposals[proposalId];
        Tally storage tally = !veto ? proposal.results : proposal.veto;
        Ballot storage ballot = tally.primary;
        uint weight = stakes[voter].amount; 
        uint votes = !veto ? votingPower(voter) : weight;
        stake.unlockTime = proposal.endTime;

        _recordVote(voter, support, ballot, votes, weight);
        return votes;
    }

    /**
      * @notice Records a virtual delegated vote for a proposal
      * @param voter The address casting the virtual vote on behalf of their delegatee
      * @param proposalId The id of the proposal to vote on
      * @param support The support value for the vote. 0=against, 1=for, 2=abstain
    **/
    function _commitVote(address voter, uint proposalId, uint8 support) internal returns (uint96) {
        Stake storage stake  = stake[voter];
        Proposal storage proposal = proposals[proposalId];
        Tally storage tally = proposal.results;
        Ballot storage ballot = tally.virtualized;
        uint weight = stakes[voter].amount; 
        uint votes = votingPower(voter);
        stake.unlockTime = proposal.eta;

        // @TODO factor for virtualized strategies

        _recordVote(voter, support, ballot, votes, weight);
        return votes;
    }

    /**
      * @notice Core vote recording primitive, writes vote to ballot and updates tally
      * @param voter The address casting the vote
      * @param support The support value for the vote. 0=against, 1=for, 2=abstain
      * @param ballot The ballot storage to record the vote in
      * @param votes The voting power to record
      * @param weight The canonical weight of the voter
    **/
    function _recordVote(address voter, uint8 support, Ballot storage ballot, uint votes, uint weight) internal {
        Record storage record = ballot.records[voter]; 
        require(support <= 2, "GovernorDelta::_recordVote: invalid vote type");
        require(!record.hasVoted, "GovernorDelta::_recordVote: voter already voted");

        if (support == 0) ballot.againstVotes += votes;
        else if (support == 1) ballot.forVotes += votes;
        else if (support == 2) ballot.abstainVotes += votes;

        ballot.totalWeight += weight;
        record.hasVoted = true;
        record.support = support;
        record.weight = weight;
        record.votes = votes;
    }

    /**
      * @notice Admin function for setting the voting delay
      * @param newVotingDelay Wew voting delay as a timestamp 
    **/
    function _setVotingDelay(uint newVotingDelay) external {
        require(msg.sender == admin, "GovernorDelta::_setVotingDelay: admin only");
        require(newVotingDelay >= MIN_VOTING_DELAY && newVotingDelay <= MAX_VOTING_DELAY, "GovernorDelta::_setVotingDelay: invalid voting delay");
        uint oldVotingDelay = votingDelay;
        votingDelay = newVotingDelay;

        emit VotingDelaySet(oldVotingDelay,votingDelay);
    }

    /**
      * @notice Admin function for setting the proposal threshold
      * @param newProposalThreshold new proposal threshold
    **/
    function _setProposalQuota(uint newProposalQuota) external {
        require(msg.sender == admin, "GovernorDelta::_setProposalThreshold: admin only");
        uint oldProposalQuota = proposalQuota;
        proposalQuota = newProposalQuota;

        emit ProposalQuotaSet(oldProposalQuota, proposalQuota);
    }

    /**
     * @notice Sets the proposal configuration for all tiers
     * @dev Tier 0 (low) to tier 3 (critical), each with independent quorum and duration
     * @param configs Fixed array of four tier configurations, ordered by severity ascending
    **/
    function _setProposalConfig(Graduated[4] memory configs) external {
        require(msg.sender == admin, "GovernorDelta::_setProposalConfig: admin only");

        for (uint8 i = 0; i < 4; i++) {
            require(configs[i].quorum >= MIN_QUORUM_VOTES, "GovernorDelta::_setProposalConfig: quorum below minimum");
            require(configs[i].duration >= MIN_VOTING_PERIOD && configs[i].duration <= MAX_VOTING_PERIOD, "GovernorDelta::_setProposalConfig: invalid duration");
            uint oldProposalQuorum = proposalConfig[i].quorum;
            proposalConfig[i] = configs[i];

            emit ProposalQuorumSet(i, oldProposalQuorum, configs[i].quorum);
        }
    }

    /**
      * @notice Admin function for setting the veto quota
      * @param newVetoQuota new proposal threshold
    **/
    function _setVetoQuota(uint newVetoQuota) external {
        require(msg.sender == admin, "GovernorDelta::_setVetoQuota: admin only");
        uint oldVetoQuota = vetoQuota;
        vetoQuota = newVetoQuota;

        emit VetoQuotaSet(oldVetoQuota, vetoQuota);
    }

    /**
      * @notice Admin function for setting the veto quorum
      * @param newVetoQuorum new veto quorum
    **/
    function _setVetoQuorum(uint newVetoQuorum) external {
        require(msg.sender == admin, "GovernorDelta::_setVetoQuorum: admin only");
        require(newVetoQuorum >= MIN_QUORUM_VOTES, "GovernorDelta::_setVetoQuorum: quorum below minimum");
        uint oldVetoQuorum = vetoQuorum;
        proposalQuota = newVetoQuorum;

        emit VetoQuorumSet(oldVetoQuorum, vetoQuorum);
    }

    function _setVotingModule(address strategy) external {
        require(msg.sender == admin, "GovernorDelta::_setVotingModule: admin only");
        address previousModule = address(votingModule)
        votingModule = IVotingStrategy(strategy);

        emit NewVotingModule(previousModule, votingModule);
    }

    /**
      * @notice Initiate the GovernorDelta contract
      * @dev Admin only. Sets initial proposal id which initiates the contract, ensuring a continuous proposal id count
      * @param governorAlpha The address for the Governor to continue the proposal id count from
    **/
    function _initiate(address governor) external {
        require(msg.sender == admin, "GovernorDelta::_initiate: admin only");
        require(initialProposalId == 0, "GovernorDelta::_initiate: can only initiate once");
        proposalCount = GovernorAlpha(governor).proposalCount();
        initialProposalId = proposalCount;
        timelock.acceptAdmin();
    }

    /**
      * @notice Begins transfer of admin rights. The newPendingAdmin must call `_acceptAdmin` to finalize the transfer.
      * @dev Admin function to begin change of admin. The newPendingAdmin must call `_acceptAdmin` to finalize the transfer.
      * @param newPendingAdmin New pending admin.
    **/
    function _setPendingAdmin(address newPendingAdmin) external {
        require(msg.sender == admin, "GovernorDelta:_setPendingAdmin: admin only");
        address oldPendingAdmin = pendingAdmin;
        pendingAdmin = newPendingAdmin;

        emit NewPendingAdmin(oldPendingAdmin, newPendingAdmin);
    }

    /**
      * @notice Accepts transfer of admin rights. msg.sender must be pendingAdmin
      * @dev Admin function for pending admin to accept role and update admin
    **/
    function _acceptAdmin() external {
        require(msg.sender == pendingAdmin && msg.sender != address(0), "GovernorDelta:_acceptAdmin: pending admin only");
        address oldAdmin = admin;
        address oldPendingAdmin = pendingAdmin;
        admin = pendingAdmin;
        pendingAdmin = address(0);

        emit NewAdmin(oldAdmin, admin);
        emit NewPendingAdmin(oldPendingAdmin, pendingAdmin);
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

    function _getChainId() internal pure returns (uint) {
        uint chainId;
        assembly { chainId := chainid() }
        return chainId;
    }

}
