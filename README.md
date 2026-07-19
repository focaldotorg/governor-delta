## Governor Delta
An EVM (Ethereum virtual machine) modular governance system, successor to [Governor Bravo](https://github.com/compound-finance/compound-protocol/blob/master/contracts/Governance/GovernorBravoDelegateG2.sol).

### Voting Modules
Implement and configure arbitrary vote weighting mechanisms allowing experimentation with governance models without the need for restructuring.

#### Strategies
* `WeightedVotingStrategy`: Traditional shareholder voting (one share, one vote)
* `TenureVotingStrategy*`: Linear time-weighted voting (French loyalty shares)
* `PolycentricVotingStrategy*`: Time and commitment voting ([paper](https://focal.org/polycentric-voting.pdf))

_`*` Virtualised strategies ([learn more](./SPEC.md#virtualisation))_

#### Extensions

Voting strategy extensions are feature enhancements that strategy standards can integrate, for example being [the "bootstrapped" extension](https://github.com/focaldotorg/governor-delta/blob/main/src/modules/strategies/derivatives/BootstrappedTenureVotingStrategy.sol). Which enables issuers to specify preconfigured time weights for set addresses with apprioriate expiration dates, allowing to specifically architect power dynamics predictably and explicitly for virtualised strategies.

---

### Native Delegation
Delta does not require `ERC20Votes` or a checkpoint system on the underlying governor token, delegation stil facilitated through the introduction of a lock and attest model. Any token that follows the ERC20 standard to participate in governance without token migration or wrapping, **by default delegation is disabled in Delta and the activation of it is irreversible**. Additionally two new dynamics are introduced: 

**Expirations**: Delegations are configured under a maximum duration, after which authority returns to the delegator, preventing idle delegations from accruing significant voting power over time that they may become unaccustomed with.

**Revocability**: Delegators retain the right to revoke or redirect voting power except when it is actively being utilised in an active ballot. On the contrary to virtualised voting strategies where revocation can happen without restriction, provding a conflict resolution mechanism in response to delegated voting power concentration.

---

### Veto Mechanism
Delta addresses a critical flaw in Bravo, where proposals can only be cancelled by **a) the proposer** and **b) if proposer's balance falls under the proposal threshold**. This creates a critical issue for autonomous governance systems, where if a malicious proposal is submitted, succeeds and submitted to the queue **makes it impossible to dispute**.

The introduction of a veto mechanism enables stakeholders the collective power to cancel queued proposals subject to the timelock - all without requiring a new proposal to be cast - creating a more balanced solution for fighting adversarial capture while retaining the original proposal lifecycle. Contesting a proposal can only be done within a select time window of the timelock's process cycle until it is marked as valid for execution.

---

### Graduated Proposals
Delta introduces a gradual proposal framework, each tier configured with an independent quorum, quota and voting duration parameters. This mediates short term voting power advantages on critical decisions through extended voting periods, while enabling agile and broad decision-making for lower tiered proposals. An example proposal configuration given total supply equal to 100,000 shares:

| Tier | Rank | Quorum | Quota | Duration |
|------|----------|--------|-------|----------|
| 0 | Low | 5,000 | 500 | 7 days |
| 1 | Medium | 15,000 | 3,000 | 14 days |
| 2 | High | 33,000 | 10,00 | 38 days |
| 3 | Critical | 51,000 | 20,000 | 92 days |

At deployment all tiers are configurable and adjustable through governance, it is advised **for organisations not interested in adopting the graduated proposal framework to assign all tiers equal parameters** as being the default option.

---

### Guard System 

Delta provides an open framework for curating an organisation's policies, achieved through a module system for arbitrary execution invariant checks, using a preimage before proposal execution and a snapshot after. If a guard or policy so to say, is failed to be met, the proposal will be reverted. This provides robust and explict safeguards that was previously lackluster in subsequent governance frameworks. Some examples being; restricting the amount of assets that can be transferred, contracts which can be called and even the functions permitted in any proposal. 

#### Modules
* `MaxTransferGuard`: Indexed by asset, restrict transfers that exceed thresholds  
* `WhitelistedCallGuard`: Indexed by address, restrict unauthorised external calls 
* `FunctionSelectorGuard`: Permit function types to be executed 

Guards work complimentary to the graduated proposal framework, where they are configurable by tier, with more strict safeguards assigned to lower tiers and more lenient as the tier value follows an acsending order. Consider that on deployment of Delta, **by default no guards are configured**.

---

### Migrating

#### From Alpha
1. Deploy Governor Delta
2. Transfer the guardian role to Delta 
3. Transfer timelock admin rights to Delta 
4. Depreciate and transfer all prior Alpha peripheral contract permissions to Delta 
5. Configure delegation, voting strategy and proposal configurations (optional)

#### From Bravo

Given that Delta is designed as an extension of Bravo, many existing deployment can be upgraded using its proxy pattern without reconfiguring permissions to external perhipheral contracts as the target address does not change:

1. Deploy Governor Delta 
2. Propose migration by assigning Delta as the new implementation 
3. Call the `initialize` function on Delta to migrate 
4. Configure delegation, voting strategy and proposal configurations (optional)

---

### Security
Report vulnerabilities via [research@focal.org](mailto:research@focal.org). Do not open public issues for security disclosures.

---

### Contributing
Open a well documented issue referencing the relevant areas of the architecture of any problem statement. Pull requests (PR) should include test coverage and a clear description of the intent and design tradeoffs. Issues and PRs should follow title capitalisiation when labeling and commit messages should always be lowercase. 


