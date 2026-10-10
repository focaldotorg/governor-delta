# Governor Delta

## Changelog

* **Vote Weighting**: Redacted the immutable weighting for arbitary, defined by [Voting Modules](#modules) enabling diverse voting models
* **Omit Whitelisting**: Redacted in place of the [Guard System](#guards), enabling arbitary permissions, constraints and checks 
* **Configuration Mutability**: 
Bravo predefined all parameters of governance at deployment time, which fundamentally fails to adapt for changing asset supply and stakeholder demographics [¹](#notes)
* **Omit Checkpoints**: Replaced by a lock-commit mechansim, where tokens are locked to signal conviction regressing the need for historic lookups with a checkpoint system [²](#notes)
* **Arbitary Call Context**: Bravo's timelock faced an issue in its prior proposal call flow, that caused native account balance stored in the timelock to become unspendable, this is addressed by the introduction of [Relay Actions](#relay-actions)
* **Deprecated Storage Slots**: Many of the prior storage domain objects and mappings, were labelled as redundant but are not overwritten to not void storage for existing instances
* **Native Delegation**: Opt-in delegation support, delegate by direct assignment with management via expiration and revocation
* **Vote Revision**: Prior votes were final given subject of a snapshot system, transient voting periods enabled by [Graduated Proposals](#graduated-proposals) need vote amendement to not inhibit stakeholders seeking to excercise additional inventory
* **Vote Accounting**: With the introduction arbitary vote weighting, the tally may need assortment in [Primary Votes]() and [Virtual Votes]()
* **Proxy Votes**: Delegated votes can be cast by proxy or keeper under when cast as [Virtual Votes][]
* **Vote Attestation**: Given if a module implementation is [Virtualised](), delegated votes must undergo [Vote Attestation]() to be marked as valid to be included in the [Tally]()  
## Modules

### Voting
--------
Defined as a standard interface under [`IVotingStrategy`]().

#### Virtualisation

A module or strategy is labelled as virtualised if it is time-weighted, clarifying that the tally should be seperated by [Primary Votes]() and [Virtual Votes]().

#### Extensions 

Extensions are standardised feature integrations for voting modules, that either add or modify underlying strategies. The [`EnduedTenureVotingStrategy`]() is a example of this, giving issuers the extensbility to set predefined time multiplier values for select addresses within a bounded period until expiration.

### Guards
--------
The guard system is a set of arbitary conditions before and after proposal execution, following the standard interface of [`IProposalGuard`](), 

<p align="center">
  <img width="700" alt="Screenshot 2026-10-05 at 14 49 37" src="https://github.com/user-attachments/assets/757cb347-9a4d-4ed6-bae3-ca4c479727ed" /> 
  <br />
  <em>Figure 1: Guard Process</em>
</p>

A state preimage or general constraints occur in `record()` with then further conditionals or invariant checks proceeding in `compare()`. Given the module structure, guards can access proposal calldata, declare formal roles and even restrict asset flows as exhibited with [`TransferGuard`](). 

## Configuration

**Canonical Token**  
The definitive currency of authority, defined at deployment. It represents the default base voting weight or balance.

**Veto**
- **Quota:** Minimum canonical token weight required to initiate a veto vote
- **Quorum:** Minimum canonical token weight required of consensus to cancel a queued proposal

**Graduated Proposals**  
- **Tiers**: The assigned index n for proposal configuration n
- **Guards**: Proposal n guards, by default [`StakingGuard`]() is assigned to all tiers [³](#notes). 
- **Duration**: The assigned voting period for proposal tier n
- **Quota**: Minimum canonical token weight required to propose proposal rank n
- **Quorum**: Minimum canonical token weight required to reach consensus for proposal n

## Account

**Stake**  
The canonical token balanced locked under to a voting identity.

**lastUpdateTime**  
The last timestamp a [Lock](#locking) or [Unlock](#unlocking) was initiated.

**Delegate**  
A selected account of which voting influence is permitted to as apart of [Delegation](#delegation).

**deltaAmountTime**  
The stake-time accumulator associated with any account, defined under [Effective Time](#effective-time).

#### Locking 
Voters are free to deposit additional tokens without restrictions, even when a participant in an active ballot.

#### Unlocking
Voters are constraint if they are a participant in an active ballot, where `unlockTime` is constraint by proposal `endTime`

## Voting System

### Primary Votes 

Realised votes cast by stakeholders, where voting power is derived and excercised by an individual voter.

### Virtual Votes

Virtual power is defined as votes cast by delegation or by proxy. In the context of [Virtualised](#virtualisation) voting strategies, delegated votes are assorted as apart of the [Pretally](). Although in the case of non-virtualised modules they are classified as primary votes and are automatically submitted to the [Tally](). 

### Vote Prediction

Pre-determines the voting power for a participant at proposal execution rather than when casting, designed for for time-dependent strategies such as [`TenureVotingStrategy`](). Using `predict()` gives participants and client interfaces an accurate projection of influence at proposal `endTime` rather than at the moment of casting.

### Delegation
----------
**State**  
Delegation by default is disabled, and can be activated for any deployment through `activateDelegation`, although it is irreversible one way state change by design.

**Identifiers**  
Every delegation action produces a `abi.encode(delegator, delgatee, expiry)` bytehash for reference in validation of delegations after the voting period under [Vote Attestation]() and create provenance for delegation actions.

#### Management
**Expirations**  
All delegations are subject to the `MAX_DELEGATION_PERIOD` constraint. This to prevent idle allocation of voting power from delegators that may become unaware to amplified influence or standing of delegates.

**Revocability**  

Revocation by default is the means for delegators to relinquish arrangements and can be excercised as long as the delegate has not excercised that authority in an active proposal. 

In the case of virtualised [Voting Modules](), **revocation provides the ability to cancel delegation available at any time** - even when the underlying voting power has been commited to a proposal - acting as a mediation to secondary market risk presented by time-weighted voting implementations under delegation. 

## Proposal System

### Status
Qualified, Unqualified, Contested, Dropped, Resolved.

### States
Pending, Active, Succeeded, Defeated, Cancelled, Executed, Expired and Queued

### Delay

**Voting**  
The is the default period of which proposal voting is scheduled after submission.

**Timelock**  
This is the default delay required until the proposal can be queued after succeeding.

### Grace Period

The maximum time a proposal is deemed as valid for execution, Bravo's prior timelock implementation restricts this to 14 days.

### Veto Period

The is the period of which a proposal is pending for execution, and where it can be contested under a veto action, the voting period for the veto proposal only lasts as long as the veto period.

<p align="center">
  <img width="1263" height="268" alt="Screenshot 2026-10-05 at 12 54 41" src="https://github.com/user-attachments/assets/62d47f7e-f71c-47f3-899c-bbfd57951d79" />
  <br />
  <em>Figure 3: Proposal Stages</em>
</p>



### Veto Mechanism
A mechanism to contest a pending proposal approved for execution under discretion of the timelock. Any stakeholder can propose to oppose if they meet the veto quota and successfully cancel if securing quorum, if not the proposal follows the normal execution pattern.

<p align="center">
  <img width="700" alt="proposal-lifecycle" src="https://github.com/user-attachments/assets/fc53769a-9dfa-4a83-9af4-abcbd5d9feac" />
  <br />
  <em>Figure 2: Proposal Lifecycle</em>
</p>
The veto period is only active as long as the timelock's grace period, it does not extend the timelock duration.

### Vote Attestation

During the timelock delay and veto period, in order for [Virtual Votes]() to be included in the final tally and counted as [Primary Votes](). Delegated votes are indexed by identifiers to validate active arrangements over the course of the voting period not subject to revocation or expiration. After attestation delegations can be managed without infringence, as all attested votes are final.  

### Ballots

#### Pretally 

During the voting period for proposals submitted under a [Virtualised]() voting configuration, vote counts are seperated by [Virtual Votes]() and [Primary Votes](). Non-virtualised voting strategies tally all votes as [Primary Votes]().

#### Tally 

Under the act of [Vote Attesation]() and subject to [Virtualised]() voting strategies, [Virtual Votes]() are realised as [Primary Votes]() once validated. 

### Relay Actions
Relay proposals shift the target proposals call context origin (default timelock) to the governor, this is allow asset transfer of tokens and native balances [that could of previously been deemed as unspendable in Bravo](https://github.com/focaldotorg/governor-delta/issues/4). 

## Effective Time
A capital-time integral, known as "effective time" proposed by **Gosling (2026)** [³](#notes), provides a single metric to effectively balance capital contribution with time. The parameter `deltaAmountTime`  reflects a component of that integral $$\sum_i a_i \cdot t_i$$  

&nbsp;
```math
t_{\mathrm{effective}} = \frac{\sum_i a_i \cdot t_i}{\sum_i a_i}
```
&nbsp;

Each [Lock](#locking) and [Unlock](#unlocking) events reweighs the integral relative to the balance committed the duration specified through `lastUpdateTime`. 

```solidity
// settle the interval held at the prior balance
uint256 deltaTime = block.timestamp - s.lastUpdateTime;
s.lastUpdateTime = block.timestamp;
s.deltaAmountTime += s.amount * deltaTime;
```

### Depositing

The new amount is added to the balance after settling. It has been held for zero time, so the numerator is unchanged and the average is diluted. Adding 500 to a 1000 balance at 100 days brings it to roughly 66.7 days. Reference the paper for a full deposit example scenario [³](#notes) with included explicit formulas.

```solidity
s.deltaAmountTime += s.amount * deltaTime;
```

### Withdrawing

After settling, `deltaAmountTime` is scaled down by the fraction of balance retained, so the average is unchanged. Withdrawing 500 from a 1000 balance at 100 days leaves it at 100 days. Partial exits never cost a holder their standing. This holds while a balance remains, and the paper [³](#notes) covers the full-withdrawal case.

```solidity
s.deltaAmountTime = s.deltaAmountTime * (s.amount - amount) / s.amount;
```

## Notes 

**[1]** An organisation is never the same as it was last week, a rigid structure not only subjects deployments of Bravo to rigorous thresholds (quotas) and quorums to contest rogue capture but also erodes participation from barriers to entry. Failure to adequately calculate sufficient values, additionally leaves an organisation vulnerable to attack with little means for recourse.

**[2]** While designed to combat vote-buying, unironically creates the new issue of proposers exercising voting power they may not still retain. Which is a primary subject of the empty voting problem [⁴](#note-4), labelled as a record-date capture attack. An adversary can create a malicious proposal, vote and then continue to relinquish the equivalent economic value on secondary markets, yet still have their weight meaningfully recorded in the [Ballot](#ballots). A problem that would be only be exacerbated if a group of actors colluded together, Delta is not subject to flaw given the omission of the checkpoint system.

**[3]** Gosling, _Polycentric Voting_ (2026), Focal Research Collective 

**[4]** Hu & Black, _Empty Voting and Hidden (Morphable) Ownership_ (2006), Southern California Law Review
