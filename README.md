## Governor Delta 

An on-chain governance mechanisim, successor to [Governor Bravo]().

### Voting modules 

Implement and configure arbitary voting power weighting mechanisims, to expirement with diverse governance models without fully compromising system autonomy.

#### Strategies 

* TokenWeightedVotingStrategy: plutocratic voting model (one-share-one-vote)
* QuadLinearVotingStrategy: a progressive plutocratic voting model [[paper]]()
* ConvictionVotingStrategy: time-weighted contextual voting model

### Veto timelock 

Governor Delta addresses a critical flaw in the Governor Bravo timelock mechanism. In Bravo, proposals are subject to a timelock before execution, but only the admin controller and the proposer can cancel transactions. This creates issues for permissionless governance systems:

1. Centralization of veto power in a single admin address
2. Inability to respond quickly to problematic proposals once queued
3. Difficulty in creating a responsive veto mechanism (a veto proposal would also be subject to timelock)

Governor Delta introduces a pure veto function allowing token holders to collectively cancel pending timelock proposals without requiring a new proposal process. This creates a more balanced solution for handling adversarial proposals while maintaining a democratic approach.

### Migrating
#### Alpha
Migrating from Governor Alpha to Governor Delta requires several steps:

1. Deploy Governor Delta: Set up the new contracts including a TokenWeightedStrategy to maintain the same voting model initially
1. Propose Migration: Use Governor Alpha to propose transferring authority to the new Governor Delta
1. Migrate Pending Proposals: Any active proposals in Alpha need to be recreated in Delta
1. Guardian Transfer: Move the Guardian role to the new contract
1. Timelock Control: Transfer timelock admin rights to the new Governor Delta
 
#### Bravo
Migrating from Governor Bravo is more straightforward:

1. Deploy Governor Delta: Set up the new contracts with appropriate strategies
1. Upgrade Implementation: Use Bravo's upgrade mechanism to point to the new Delta implementation
1. Initialize Parameters: Configure voting strategy and other parameters
1. Optional Parameter Migration: Adjust any governance parameters to match previous settings

Because Governor Delta is designed as an extension of Governor Bravo, many existing Governor Bravo contracts can be upgraded in-place to use the new implementation.

## Contributing

Open a well documented issue, referencing the relevant areas of the architecture.

