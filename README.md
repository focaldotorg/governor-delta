## Governor Delta
An EVM (Ethereum virtual machine) governance system, successor to [Governor Bravo]().

### Voting Modules
Implement and configure arbitrary voting power weighting mechanisms, to experiment with diverse governance models without fully compromising system autonomy.

#### Strategies
* `TokenWeightedVotingStrategy` — plutocratic voting model (one-share-one-vote)
* `QuadLinearVotingStrategy` — a progressive plutocratic voting model [[paper]]()
* `ConvictionVotingStrategy` — time-weighted contextual voting model
* `PolycentricVotingStrategy` — time and commitment weighted voting model [[paper]]()

---

### Native Delegation
Governor Delta does not require ERC20Votes or checkpoint extensions on the underlying token. Vote weight is tallied at the point of vote cast, with the participant's balance locked for the duration of the proposal. This enables any ERC20 to participate in governance without token migration or wrapping.

Delegation is handled natively at the governor layer — participants may delegate their locked balance to any address at vote time, with full revocability retained by the delegator for the duration of the proposal.

---

### Vote Prediction
```solidity
function predictVotes(address participant, uint256 proposalId) external view returns (uint256);
```
Pre-calculates the final voting power for a participant at proposal execution time. For time-dependent strategies such as `PolycentricVotingStrategy`, VP compounds as `t_effective` accumulates between vote cast and execution. `predictVotes` gives participants and frontends an accurate projection of influence weight at the moment it matters rather than at the moment of casting.

---

### Graduated Proposals
Governor Delta supports tiered proposal severity, each tier configured with independent quorum and voting duration parameters. This mediates short term voting power advantages on critical decisions through extended voting periods, while enabling agile decision making for lower severity proposals.

| Tier | Severity | Quorum | Duration |
|------|----------|--------|----------|
| 0 | Low | 5% | 2 days |
| 1 | Medium | 15% | 5 days |
| 2 | High | 30% | 10 days |
| 3 | Critical | 51% | 14 days |

Tiers are configurable at deployment and adjustable through governance.

---

### Veto Timelock
Governor Delta addresses a critical flaw in the Governor Bravo timelock mechanism. In Bravo, proposals are subject to a timelock before execution, but only the admin controller and the proposer can cancel transactions. This creates issues for permissionless governance systems:

1. Centralisation of veto power in a single admin address
2. Inability to respond quickly to problematic proposals once queued
3. Difficulty in creating a responsive veto mechanism — a veto proposal would also be subject to timelock

Governor Delta introduces a pure veto function allowing token holders to collectively cancel pending timelock proposals without requiring a new proposal process. This creates a more balanced solution for handling adversarial proposals while maintaining a democratic approach.

---

### Migrating

#### From Alpha
1. Deploy Governor Delta with a `TokenWeightedStrategy` to maintain the same voting model initially
2. Propose migration via Governor Alpha, transferring authority to the new Governor Delta
3. Recreate any active proposals in Delta
4. Transfer the Guardian role to the new contract
5. Transfer timelock admin rights to Governor Delta

#### From Bravo
Because Governor Delta is designed as an extension of Governor Bravo, many existing contracts can be upgraded in-place:

1. Deploy Governor Delta with appropriate strategies
2. Use Bravo's upgrade mechanism to point to the new Delta implementation
3. Configure voting strategy and parameters
4. Optionally adjust governance parameters to match previous settings

---

### Security
Report vulnerabilities via [ops@focal.org](mailto:research@focal.org). Do not open public issues for security disclosures.

---

### Contributing
Open a well documented issue referencing the relevant areas of the architecture. Pull requests should include test coverage and a clear description of the motivation and design tradeoffs.
