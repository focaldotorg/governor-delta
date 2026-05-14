# Governor Delta

## Omissions

### Configuration Immutability
Bravo predefined all parameters of governance at deployment time, which fundamentally fails to adapt for changing asset supply and stakeholder demographics. An organisation is never the same as it was last week, a rigid structure not only subjects deployments of Bravo to rigorous thresholds (quotas) and quorums to contest adverserial capture but also erodes participation from barriers to entry. Failure to adequcately calculate sufficient values, additionally leaves an organisation vulnerable to attack with little means for recourse.

### Checkpoints
Now redacted in Bravo from to the requirement of attesting balances, where stakeholders lock tokens to the contract to signal conviction regressing the need for historic lookups with a checkpoint system. Which while was designed to combat vote-buying, unironically creates the new issue of proposers excercising voting power they may not still retain. As an adversary can create a malicous proposal, vote and then continue to offload the equivalent tokens from the cast voting power on secondary markets, yet still have their weight meaningfully excercised in the ballot. A problem that would be only be exacerbated if a group of actors colluded together.

### Guardian
Replaced by the more broad timelock restructuring and possible to implement with the new guard system, it still was an unfavorable design choice of Bravo for more distributed organisations.

## Configuration

### Default Guards

By default there is no recommended default guards, except for contextual proposal constraints like `ExternalCallGuard` and `InternalCallGuard` by choice of the proposer. Although as a recommended policy, organisations should probably integrate `MaxTransferGuard` as a default guard for their own assurances and operations.

### Canonical token

The one definitive and immutable currency of authority, defined on deployment, this is the default or "base" voting weight represented as a coefficient.

### Subordinate tokens *

Can be one of or multiple currencies to translate to authority, configurable at any time, must be expressed as a proportion of the cannonical token (eg 0.4).

### Quota

#### Veto

Minimum cannoncial token weight to initiate a veto vote.

#### Root

Minimum cannoncial token weight to create a proposal.

### Quorum

#### Veto

Minimum cannoncial token weight to contest a queued proposal.

#### Graduated

Minimum cannoncial token weights for proposals by severity to deem consensus.

## Accounting

### Cooldown

When you lock assets into Delta there is a small cooldown period for withdrawing - similar to Bravo.

### Proposal lock

When you create a proposal there is a lock on the quota until the proposal resolves.

### Ballot locks

When you vote on a proposal your equivalent weight is locked until the proposal resolves.

## Modules

### IVotingStrategy

### IActionsReducer

### IProposalGuard

## Voting System

### Power prediction

Pre-calculates the final voting power for a participant at proposal execution time. For time-dependent strategies such as `PolycentricVotingStrategy`. Using `predictVotes` gives participants and frontends an accurate projection of influence weight at the moment it matters rather than at the moment of casting.

### Delegation

#### State

Delegation can be toggled on and off for any deployment.

#### Identifiers

Every delegation action produces a `keccak256(delegator, nonce, delgatee, amount, expiry)` bytehash for used for referenced in validation of coalitions post proposal voting period and create provenance for delegation actions.

#### Management

Delegations are revocable at any time even in when in a pending or active ballot.

## Proposal System

### States

Active, succeeded, defeated, canceled, executed, expired, queued and the new veto state contested.

### Graduated Proposals

Graduated proposals are configurable hierarchy of proposal labelling by severity, with equivalent quorums and durations to match.

### Preconditions (Guards)

Inline guards for proposal execution, what would be suitable for example is something like `InternalCallGuard` or `ExternalCallGuard`, that is contextually valid rather than generic system wide constraints.

### Ballots

#### Pretally (Active)

Prior to the proposal being deemed valid for execution, votes are decoupled by delegated "virtual" balances versus "pure" balances. Attestation is at preference of the voting strategy.

#### Tally (Timelock)

On execution we dismiss the prior results and compute a single value for the tally, since we can claim which virtual votes were attested during the timelock, for default weighted-voting strategies all delegated votes are attested by deafult.

## Timelock

### Reducer

A place for arbitary action interface inheritence, mostly suitable for voting strategies that involve a) delegation and b) time-weighting but can be configurable with any arbitary logic.

### Guards

The guard system is a set of modular conditions to predefine before proposal execution, think of them as preimage checks to make sure the intent of the proposal is met. A basic example is restricting calls to be external or internal, or something more rigorous and set system-wide being a max transfer guard for assets under organisational control.

### Veto Mechanism

A mechanism to contest a pending proposal approved for execution at the end of the timelock, here a stakeholder can propose to oppose this change, configurable through the veto quorum and quota options. If the veto reaches quorum, the proposal is dropped if it doesnt it continues to execute.

Veto voting period is only active as long as the timelock it does not extend the timelock duration.
