## Governor Delta
An EVM (Ethereum virtual machine) governance system, successor to [Governor Bravo](https://github.com/compound-finance/compound-protocol/blob/master/contracts/Governance/GovernorBravoDelegateG2.sol).

### Voting Modules
Implement and configure arbitrary vote weighting mechanisms allowing experimentation with diverse governance models without requiring restructuring system autonomy.

#### Strategies
* `WeightedVotingStrategy` - Traditional shareholder voting (one-share-one-vote)
* `TenureVotingStrategy`* - Linear time-weighted voting (super-voting)
* `PolycentricVotingStrategy`* - Time and commitment weighted voting [[paper](https://focal.org/polycentric-voting.)]

__* - Virtualised strategies ([learn more](./SPEC.md#voting-system))__

---

### Native Delegation
Governor Delta does not require `ERC20Votes` or a checkpoint system on the underlying token, delegation is supported natively by locking assets into the contract. Voting weight is allocated at the point of vote cast (or in the case of virtualized voting modules; is calculated for proposal resolution time) with the participant's balance locked for the duration of the proposal. This enables any token that follows the ERC20 standard to participate in governance without token migration or wrapping, **by default delegation is disabled in Delta and the activation of it is irreversible**. Additionally two new features are complimentary: 

**Revocability**: Delegators retain the right to revoke or redirect voting power at any time during an active proposal (only for virtualised voting modules), this provides a conflict resolution mechanism to deter adversarial capture.

**Expirations**: Delegations are configured with a maximum duration, after which authority returns to the delegator, preventing idle delegations from accruing significant voting power over time without the delegator's knowledge.

---

### Graduated Proposals
Delta introduces a tiered proposal framework, each tier configured with an independent quorum, quota and voting duration parameters. This mediates short term voting power advantages on critical decisions through extended voting periods, while enabling agile and broad decision-making for lower tiered proposals. An example proposal configuration given total supply equal to 100,000 shares:

| Tier | Severity | Quorum | Quota | Duration |
|------|----------|--------|-------|----------|
| 0 | Low | 5,000 | 500 | 7 days |
| 1 | Medium | 15,000 | 3,000 | 14 days |
| 2 | High | 33,000 | 10,00 | 38 days |
| 3 | Critical | 51,000 | 20,000 | 92 days |

At deployment all tiers are pre-configurable and adjustable through governance, it is advised **for organisations not interested in adopting the graduated proposal framework to assign all tiers equal parameters**. 

---

### Veto Mechanism
Delta addresses a critical flaw in Bravo, where proposals can only be cancelled by a) the proposer and b) if proposer's balance falls under the proposal threshold. This creates a critical issue for autonomous governance systems, where if a malicious proposal is submitted, succeeds and submitted to the queue **it is impossible to dispute**.

Delta introduces a pure veto function allowing stakeholders the collective power to cancel pending proposals subject to the timelock - without requiring a new proposal to be cast - creating a more balanced solution for fighting adversarial capture while retaining the original proposal lifecycle. Contesting a proposal can only be triggered when it is queued for execution, with the duration of exerting support or rejection in motion of only valid during the timelock delay.

---

### Guard System 

Delta provides an open framework for curating an organisation's policies, achieved through a module system for arbitrary execution invariants, checks use a preimage before proposal execution and a snapshot after. If a policy (guards) is failed to be met, the proposal will be reverted. This provides rigid and robust safeguards that was previously impossible in subsequent governance frameworks, such as restricting the amount of assets that can be transferred, contracts which can be called and even the functions permitted in any proposal. 

#### Modules
* `MaxTransferGuard` - Indexed by asset, restrict transfers that exceed thresholds  
* `WhitelistedCallGuard` - Indexed by address, restrict unauthorised external calls 
* `FunctionSelectorGuard` - Permit function types to be executed 

Guards work complimentary to the graduated proposal framework, where they are configurable by tier, with more strict safeguards assigned to lower tiers and more lenient for critical decisions. Consider that on deployment of Delta, **by default no guards are configured**.

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
3. Call the initialize function on Delta to migrate 
4. Configure delegation, voting strategy and proposal configurations (optional)

---

### Security
Report vulnerabilities via [research@focal.org](mailto:research@focal.org). Do not open public issues for security disclosures.

---

### Contributing
Open a well documented issue referencing the relevant areas of the architecture. Pull requests should include test coverage and a clear description of the intent and design tradeoffs.



