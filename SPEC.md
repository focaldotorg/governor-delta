# Governor Delta

## Omissions

### Whitelisting 
Replaced by the more broad [Timelock](#timelock) restructuring and possible to implement with the new [Guard System](#guards), it still was an unfavorable design choice of Bravo for more distributed organisations.

### Configuration Immutability
Bravo predefined all parameters of governance at deployment time, which fundamentally fails to adapt for changing asset supply and stakeholder demographics. An organisation is never the same as it was last week, a rigid structure not only subjects deployments of Bravo to rigorous thresholds (quotas) and quorums to contest adverserial capture but also erodes participation from barriers to entry. Failure to adequcately calculate sufficient values, additionally leaves an organisation vulnerable to attack with little means for recourse.

### Checkpoints
Now redacted in Bravo from to the requirement of attesting balances, where stakeholders lock tokens to the contract to signal conviction regressing the need for historic lookups with a checkpoint system. Which while was designed to combat vote-buying, unironically creates the new issue of proposers excercising voting power they may not still retain. As an adversary can create a malicous proposal, vote and then continue to offload the equivalent tokens from the cast voting power on secondary markets, yet still have their weight meaningfully excercised in the [Ballot](#ballots). A problem that would be only be exacerbated if a group of actors colluded together.

### Monotonic Call Authority 

In Bravo the timelock faced an issue of the prior call structure, that caused native account balance stored in the timelock to be unspendable, this is addressed by the introduction of [Relay Proposals](#relay-proposals).

## Configuration

**Canonical token**  
The definitive and immutable currency of authority, defined at deployment. It represents the default ("base") voting weight as a coefficient.

**Quota**
- **Veto:** Minimum canonical token weight required to initiate a veto vote.
- **Root:** Minimum canonical token weight required to create a proposal.

**Quorum**
- **Veto:** Minimum canonical token weight required to contest a queued proposal.
- **Graduated:** Minimum canonical token weights by proposal severity required to reach consensus.

**Guards**  
Organisations inherit `StakedTransferGuard` by default for relay proposals. This guard prevents stakeholder deposits from being transferred when a proposal is processed and is a default immutable policy, that is not recommended to omit.

## Modules

### IVotingStrategy

#### Virtualisation

A voting module is intended to be labelled as "virtual" if it is time-weighted, this is to ensure [Delegations](#delegation) can be recorded within a window as valid.

#### Extensions 

Extensions are standardised feature integrations for voting modules, that either add or modify underlying strategies. The `BootstrappedTenureVotingStrategy` is a example of this, giving deployers the extensbility to set predefined or "seeded" basis voting multiplier values with even expiration control.

### IProposalGuard

#### Precheck

Arbitary check that happens before proposal execution.

#### Postcheck

Arbitary check that happens after proposal execution.

## Voting System

### Primary Votes 

Realised votes cast by stakeholders, where voting power is derived from a single indexed account.

### Virtual Votes

Virtual power or votes are defined as votes cast by delegation or proxy, under a [Virtualised](#virtualisation) voting module. To factor for time-weighting a snapshot of the delegated power must be valid at proposal `endTime`. To prove that the delegation was valid during the proposal voting period, if the voting module is non-virtualised delegations bare to distinction to "virtual" but conform to [Primary Votes](#primary-votes). Virtual votes must be attested to be included in the [Final Tally](#final-tally).

### Proxy Votes

If a stakeholder has voted their primary voting power to a proposal, they're intent of the proposal is recorded, if a stakeholder has active delegations which have not been cast, proxy votes allows a relayer to cast the votes indexed by delegation [Identifier](#identifiers). Once the stakeholder casts their support, it is final, only way to void that is through contesting the proposal to its [Veto Mechanisim](#veto-mechanism).

### Power prediction

Pre-calculates the final voting power for a participant at proposal execution time. For time-dependent strategies such as `PolycentricVotingStrategy`. Using `projectedPower` gives participants and frontends an accurate projection of influence weight at the moment it matters rather than at the moment of casting.

### Delegation

#### State

Delegation by default is disabled, and can be activated for any deployment through `activateDelegation`, although it is irreversible one way state change by design.

#### Identifiers

Every delegation action produces a `keccak256(delegator, nonce, delgatee, amount, expiry)` bytehash for used for referenced in validation of coalitions post proposal voting period and create provenance for delegation actions.

#### Management

##### Expirations

All delegations are subject to the `MAX_DELEGATION_PERIOD` constraint, this is not allow idle allocation of voting power from delegates.

##### Revocability

In the case of virtualised voting modules, revoacability is available at any time - even admist a proposal where that delegated power has already been cast - this is to factor for the potential inclusion of delegation leasing and enforcing such arrangements on a continous bilateral price model. **If you do not wish to be exposed to delegation market risk, do not activate delegation**. When dealing with no virtualised strategies, you can only revoke an active delegation when it is not cast to an active proposal and it is not expired.


## Proposal System

### Status

Qualified, unqualified, contested, resolved.

### States

Active, succeeded, defeated, canceled, executed, expired, queued and the new veto state contested.

### Graduated Proposals

Graduated proposals are configurable hierarchy of proposal labelling by severity, with equivalent quorums and durations to match.

#### Guards

The guard system is a set of modular conditions to predefine before proposal execution, think of them as preimage checks to make sure the intent of the proposal is met. A basic example is restricting calls to be external or internal, or something more rigorous and set system-wide being a max transfer guard for assets under organisational control.

### Relay Proposals

Relay proposals shift the target proposals origin to the governor, this is allow asset transfer of tokens and native balances [that could of previously been deemed as unspendable in Bravo](https://github.com/focaldotorg/governor-delta/issues/4). 

### Ballots

#### Pretally 

Prior to the proposal being deemed valid for execution, votes are decoupled by delegated "virtual" balances versus "pure" balances. Attestation is at preference of the voting strategy.

#### Final Tally 

On execution we dismiss the prior results and compute a single value for the tally, since we can claim which [Virtual Votes](#virtual-votes) were attested during the timelock, for default weighted-voting strategies all delegated votes are attested by deafult.

### Veto Mechanism

A mechanism to contest a pending proposal approved for execution at the end of the timelock, here a stakeholder can propose to oppose this change, configurable through the veto quorum and quota options. If the veto reaches quorum, the proposal is dropped if it doesnt it continues to execute.

Veto voting period is only active as long as the timelock it does not extend the timelock duration.

## Timelock

### Delay

This is the default delay required until the proposal can be queued if it is succeeded.

### Veto Period

The is the period of which a proposal is pending for execution, and where it can be contested to trigger a veto action, the voting period for the veto proposal only lasts as long as the veto period.

### Grace Period

The maximum time a proposal is deemed as valid for execution.

### Vote Attestation

During the [Delay](#delay) and [Veto Periods](#veto-period), virtual votes need to be attested to be included in the final tally as realised "primary" votes. The delegation must be still be active to attest, once attested delegations no longer need to be active if of preference, the attestation counts the virtual votes cast over the course of the proposal voting period as finalised.
