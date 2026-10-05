pragma solidity ^0.8.13;

import { ITimeWeightedVotingStrategy } from "@interfaces/ITimeWeightedVotingStrategy.sol";
import { TenureVotingStrategy } from "@strategies/TenureVotingStrategy.sol";
import { GovernorStorageV3 } from "@root/GovernorStorageV3.sol";
import { GovernorAdmin } from "./mock/GovernorAdmin.sol";
import { BaseGovernorTest } from "./BaseGovernor.t.sol";

contract VirtualGovernorTest is BaseGovernorTest {

    TenureVotingStrategy strategy;

    address public constant STAKEHOLDER_TAU = 0x95222290DD7278Aa3Ddd389Cc1E1d165CC4BAfe5; 
    address public constant STAKEHOLDER_OMEGA = 0x396343362be2A4dA1cE0C1C210945346fb82Aa49; 
    address public constant STAKEHOLDER_ALPHA = 0x67aA499679E75EdFbfb7719fB4795a9c389eC38c;
    address public constant STAKEHOLDER_BETA  = 0x4838B106FCe9647Bdf1E7877BF73cE8B0BAD5f97;
    address public constant STAKEHOLDER_THETA = 0x3011426bB63e7BE9b6b8AdF572874009569710b8;
    address public constant DELEGATOR_PRIMARY = 0x8A1c5E88Ca465be1D01e4B437CE4E082fD14E25e;
    address public constant DELEGATOR_SECONDARY = 0xE0D268481983B218e83DEe30da1c9f36B56Ffa0a;
    address public constant DELEGATEE_PRIMARY = 0x557a4fC606ae646F585BC73aD2a4fc745a8CBcc8;
    address public constant DELEGATEE_SECONDARY = 0xCbFD1745E492F6a555dF7A9B1E0B3Cd139e69504;
    
    function setUp() public override {
        super.setUp(); 

        governorToken.mint(STAKEHOLDER_TAU, STAKEHOLDER_MINOR);
        governorToken.mint(STAKEHOLDER_OMEGA, STAKEHOLDER_MINOR);
        governorToken.mint(STAKEHOLDER_ALPHA, STAKEHOLDER_MINOR);
        governorToken.mint(STAKEHOLDER_BETA, STAKEHOLDER_MINOR);
        governorToken.mint(STAKEHOLDER_THETA, STAKEHOLDER_MINOR);
        governorToken.mint(DELEGATEE_SECONDARY, STAKEHOLDER_MINOR);
        governorToken.mint(DELEGATOR_PRIMARY, STAKEHOLDER_MINOR);
        governorToken.mint(DELEGATOR_SECONDARY, STAKEHOLDER_MINOR);
        governorToken.mint(DELEGATEE_PRIMARY, STAKEHOLDER_MINOR);
        governorToken.mint(DELEGATEE_SECONDARY, STAKEHOLDER_MINOR);

        ITimeWeightedVotingStrategy.Tranche[] memory tranches = new ITimeWeightedVotingStrategy.Tranche[](5);

        tranches[0] = ITimeWeightedVotingStrategy.Tranche(30 days, 10e6);
        tranches[1] = ITimeWeightedVotingStrategy.Tranche(60 days, 12e6);
        tranches[2] = ITimeWeightedVotingStrategy.Tranche(90 days, 15e6);
        tranches[3] = ITimeWeightedVotingStrategy.Tranche(180 days, 17e6);
        tranches[4] = ITimeWeightedVotingStrategy.Tranche(365 days, 20e6);

        strategy = new TenureVotingStrategy(address(governor), tranches);

        /* --------TIMELOCK-------- */
        vm.startPrank(address(timelock));
        governor._setVotingModule(address(strategy));
        governor._activateDelegation();
        vm.stopPrank();
        /* -------------------------------- */

        setUpScenario();
    }

    function deployGovernor() internal override returns (GovernorAdmin) {
        return new GovernorAdmin();
    }

    function testVirtualDelegatedVoteRevision() public {
        uint delegationExpiry = block.timestamp + 7 days;

        /* ------PRIMARY-DELEGATOR------- */
        vm.startPrank(DELEGATOR_PRIMARY);
        governor.delegate(DELEGATEE_PRIMARY, delegationExpiry);
        vm.stopPrank();
        /* -------------------------------- */

        /* ------PRIMARY-DELEGATEE------- */
        vm.startPrank(DELEGATEE_PRIMARY);
        uint proposalId = pushMockProposal(0);
        vm.warp(block.timestamp + DEFAULT_VOTING_DELAY + 1);
        vm.stopPrank();
        /* -------------------------------- */

        commitDelegation(proposalId, DELEGATOR_PRIMARY, DELEGATEE_PRIMARY, delegationExpiry);
        (uint committedAgainstVotes, uint committedForVotes,) = governor.getTally(proposalId);
        require(committedAgainstVotes == 0);
        require(committedForVotes == 0);
        GovernorStorageV3.Record[3] memory firstCommitRecords = governor.getRecords(proposalId, DELEGATOR_PRIMARY);
        require(firstCommitRecords[1].commitVersion == 1);

        /* ------PRIMARY-DELEGATEE------- */
        vm.prank(DELEGATEE_PRIMARY);
        governor.castVote(proposalId, 1, "");
        /* -------------------------------- */
        (uint firstAgainstVotes, uint firstForVotes,) = governor.getTally(proposalId);
        require(firstAgainstVotes == 0);
        require(firstForVotes > 0);
        (uint firstVirtualAgainstVotes, uint firstVirtualForVotes,) = governor.getVirtualTally(proposalId);
        require(firstVirtualAgainstVotes == 0);
        require(firstVirtualForVotes > 0);

        vm.prank(DELEGATEE_PRIMARY);
        governor.castVote(proposalId, 1, "");

        (uint revisedVirtualAgainstVotes, uint revisedVirtualForVotes,) = governor.getVirtualTally(proposalId);
        require(revisedVirtualAgainstVotes == 0);
        require(revisedVirtualForVotes == firstVirtualForVotes);

        // Unchanged voting power cannot be recommitted
        vm.expectRevert();
        commitDelegation(proposalId, DELEGATOR_PRIMARY, DELEGATEE_PRIMARY, delegationExpiry);

        /* ------PRIMARY-DELEGATOR------- */
        vm.startPrank(DELEGATOR_PRIMARY);
        governorToken.mint(DELEGATOR_PRIMARY, STAKEHOLDER_MINOR);
        approveAndLock(STAKEHOLDER_MINOR);
        vm.stopPrank();
        /* -------------------------------- */

        commitDelegation(proposalId, DELEGATOR_PRIMARY, DELEGATEE_PRIMARY, delegationExpiry);
        GovernorStorageV3.Record[3] memory secondCommitRecords = governor.getRecords(proposalId, DELEGATOR_PRIMARY);
        require(secondCommitRecords[1].commitVersion == 2);

        (, uint updatedVirtualForVotes,) = governor.getVirtualTally(proposalId);
        require(updatedVirtualForVotes > firstVirtualForVotes);

        /* ------PRIMARY-DELEGATEE------- */
        vm.prank(DELEGATEE_PRIMARY);
        governor.castVote(proposalId, 0, "");
        /* -------------------------------- */
        (uint secondAgainstVotes, uint secondForVotes,) = governor.getTally(proposalId);
        require(secondAgainstVotes > 0);
        require(secondForVotes == 0);
        (uint secondVirtualAgainstVotes, uint secondVirtualForVotes,) = governor.getVirtualTally(proposalId);
        require(secondVirtualAgainstVotes == updatedVirtualForVotes);
        require(secondVirtualForVotes == 0);

        /* ------ALPHA-STAKEHOLDER------- */
        vm.startPrank(STAKEHOLDER_ALPHA);
        governor.castVote(proposalId, 1, "");
        vm.stopPrank();
        /* -------------------------------- */

        /* ------BETA-STAKEHOLDER------- */
        vm.startPrank(STAKEHOLDER_BETA);
        governor.castVote(proposalId, 1, "");
        vm.stopPrank();
        /* -------------------------------- */

        vm.warp(block.timestamp + DEFAULT_VOTING_PERIOD + 1);
        governor.queue(proposalId);
        vm.warp(block.timestamp + DEFAULT_TIMELOCK_DELAY + 1);

        bytes[] memory delegateIds = new bytes[](1);
        delegateIds[0] = abi.encode(DELEGATOR_PRIMARY, DELEGATEE_PRIMARY, delegationExpiry);
        governor.batchAttestVotes(proposalId, delegateIds);

        GovernorStorageV3.Record[3] memory delegatorRecords = governor.getRecords(proposalId, DELEGATOR_PRIMARY);
        (uint finalAgainstVotes,,) = governor.getTally(proposalId);
        require(finalAgainstVotes == secondAgainstVotes + delegatorRecords[1].votes);
    }

    function testVirtualDelegationToUnstakedDelegatee() public {
        address delegatee = address(0xBEEF);
        uint delegationExpiry = block.timestamp + 7 days;

        /* ------PRIMARY-DELEGATOR------- */
        vm.prank(DELEGATOR_PRIMARY);
        governor.delegate(delegatee, delegationExpiry);
        /* -------------------------------- */

        /* ------ALPHA-STAKEHOLDER------- */
        vm.prank(STAKEHOLDER_ALPHA);
        uint proposalId = pushMockProposal(0);
        /* -------------------------------- */

        vm.warp(block.timestamp + DEFAULT_VOTING_DELAY + 1);

        /* ------UNSTAKED-DELEGATEE------- */
        vm.prank(delegatee);
        governor.castVote(proposalId, 1, "");
        /* -------------------------------- */

        GovernorStorageV3.Record[3] memory delegateeRecords = governor.getRecords(proposalId, delegatee);
        require(delegateeRecords[0].hasVoted);
        require(delegateeRecords[0].votes == 0);
        require(delegateeRecords[0].weight == 0);

        commitDelegation(proposalId, DELEGATOR_PRIMARY, delegatee, delegationExpiry);
        (, uint committedVirtualForVotes,) = governor.getVirtualTally(proposalId);
        require(committedVirtualForVotes > 0);

        /* ------ALPHA-STAKEHOLDER------- */
        vm.prank(STAKEHOLDER_ALPHA);
        governor.castVote(proposalId, 1, "");
        /* -------------------------------- */

        /* ------BETA-STAKEHOLDER------- */
        vm.prank(STAKEHOLDER_BETA);
        governor.castVote(proposalId, 1, "");
        /* -------------------------------- */

        vm.warp(block.timestamp + DEFAULT_VOTING_PERIOD + 1);
        governor.queue(proposalId);
        vm.warp(block.timestamp + DEFAULT_TIMELOCK_DELAY + 1);

        GovernorStorageV3.Record[3] memory delegatorRecords = governor.getRecords(proposalId, DELEGATOR_PRIMARY);
        (, uint priorForVotes,) = governor.getTally(proposalId);

        bytes[] memory delegateIds = new bytes[](1);
        delegateIds[0] = abi.encode(DELEGATOR_PRIMARY, delegatee, delegationExpiry);
        governor.batchAttestVotes(proposalId, delegateIds);

        (, uint finalForVotes,) = governor.getTally(proposalId);
        require(finalForVotes == priorForVotes + delegatorRecords[1].votes);
    }

    function testAttestationRequiresDirectDelegateeVote() public {
        uint delegationExpiry = block.timestamp + 7 days;

        vm.prank(DELEGATOR_PRIMARY);
        governor.delegate(DELEGATEE_PRIMARY, delegationExpiry);

        vm.prank(DELEGATOR_SECONDARY);
        governor.delegate(DELEGATOR_PRIMARY, delegationExpiry);

        vm.prank(DELEGATEE_PRIMARY);
        uint proposalId = pushMockProposal(0);
        vm.warp(block.timestamp + DEFAULT_VOTING_DELAY + 1);

        commitDelegation(proposalId, DELEGATOR_PRIMARY, DELEGATEE_PRIMARY, delegationExpiry);
        commitDelegation(proposalId, DELEGATOR_SECONDARY, DELEGATOR_PRIMARY, delegationExpiry);

        vm.prank(DELEGATEE_PRIMARY);
        governor.castVote(proposalId, 1, "");
        vm.prank(STAKEHOLDER_ALPHA);
        governor.castVote(proposalId, 1, "");
        vm.prank(STAKEHOLDER_BETA);
        governor.castVote(proposalId, 1, "");

        vm.warp(block.timestamp + DEFAULT_VOTING_PERIOD + 1);
        governor.queue(proposalId);
        vm.warp(block.timestamp + DEFAULT_TIMELOCK_DELAY + 1);

        bytes[] memory delegateIds = new bytes[](1);
        delegateIds[0] = abi.encode(DELEGATOR_PRIMARY, DELEGATEE_PRIMARY, delegationExpiry);
        governor.batchAttestVotes(proposalId, delegateIds);

        GovernorStorageV3.Record[3] memory records = governor.getRecords(proposalId, DELEGATOR_PRIMARY);
        require(records[0].delegatee == DELEGATEE_PRIMARY);

        delegateIds[0] = abi.encode(DELEGATOR_SECONDARY, DELEGATOR_PRIMARY, delegationExpiry);
        vm.expectRevert();
        governor.batchAttestVotes(proposalId, delegateIds);
    }

    function testVirtualDelegationRedirect() public {
        uint primaryExpiry = block.timestamp + 7 days;

        /* ------PRIMARY-DELEGATOR------- */
        vm.prank(DELEGATOR_PRIMARY);
        governor.delegate(DELEGATEE_PRIMARY, primaryExpiry);
        /* -------------------------------- */

        /* ------PRIMARY-DELEGATEE------- */
        vm.startPrank(DELEGATEE_PRIMARY);
        uint proposalId = pushMockProposal(0);
        vm.warp(block.timestamp + DEFAULT_VOTING_DELAY + 1);
        vm.stopPrank();
        /* -------------------------------- */

        commitDelegation(proposalId, DELEGATOR_PRIMARY, DELEGATEE_PRIMARY, primaryExpiry);

        /* ------PRIMARY-DELEGATEE------- */
        vm.prank(DELEGATEE_PRIMARY);
        governor.castVote(proposalId, 1, "");
        /* -------------------------------- */

        (, uint primaryVirtualForVotes,) = governor.getVirtualTally(proposalId);
        require(primaryVirtualForVotes > 0);

        /* ------PRIMARY-DELEGATOR------- */
        vm.prank(DELEGATOR_PRIMARY);
        governor.revoke();
        /* -------------------------------- */

        vm.warp(block.timestamp + 1);
        uint secondaryExpiry = block.timestamp + 7 days;

        /* ------PRIMARY-DELEGATOR------- */
        vm.prank(DELEGATOR_PRIMARY);
        governor.delegate(DELEGATEE_SECONDARY, secondaryExpiry);
        /* -------------------------------- */

        commitDelegation(proposalId, DELEGATOR_PRIMARY, DELEGATEE_SECONDARY, secondaryExpiry);
        GovernorStorageV3.Record[3] memory redirectedRecords = governor.getRecords(proposalId, DELEGATOR_PRIMARY);
        require(redirectedRecords[1].delegatee == DELEGATEE_SECONDARY);
        require(redirectedRecords[1].commitVersion == 2);

        (uint redirectedVirtualAgainstVotes, uint redirectedVirtualForVotes,) = governor.getVirtualTally(proposalId);
        require(redirectedVirtualAgainstVotes == 0);
        require(redirectedVirtualForVotes == 0);

        /* ------SECONDARY-DELEGATEE------- */
        vm.prank(DELEGATEE_SECONDARY);
        governor.castVote(proposalId, 0, "");
        /* -------------------------------- */

        (uint secondaryVirtualAgainstVotes, uint secondaryVirtualForVotes,) = governor.getVirtualTally(proposalId);
        require(secondaryVirtualAgainstVotes == primaryVirtualForVotes);
        require(secondaryVirtualForVotes == 0);

        /* ------ALPHA-STAKEHOLDER------- */
        vm.prank(STAKEHOLDER_ALPHA);
        governor.castVote(proposalId, 1, "");
        /* -------------------------------- */

        /* ------BETA-STAKEHOLDER------- */
        vm.prank(STAKEHOLDER_BETA);
        governor.castVote(proposalId, 1, "");
        /* -------------------------------- */

        vm.warp(block.timestamp + DEFAULT_VOTING_PERIOD + 1);
        governor.queue(proposalId);
        vm.warp(block.timestamp + DEFAULT_TIMELOCK_DELAY + 1);

        bytes[] memory delegateIds = new bytes[](1);
        delegateIds[0] = abi.encode(DELEGATOR_PRIMARY, DELEGATEE_PRIMARY, primaryExpiry);
        // Prior delegation cannot be attested after redirect
        vm.expectRevert();
        governor.batchAttestVotes(proposalId, delegateIds);

        GovernorStorageV3.Record[3] memory delegatorRecords = governor.getRecords(proposalId, DELEGATOR_PRIMARY);
        (uint priorAgainstVotes, uint priorForVotes,) = governor.getTally(proposalId);

        delegateIds[0] = abi.encode(DELEGATOR_PRIMARY, DELEGATEE_SECONDARY, secondaryExpiry);
        governor.batchAttestVotes(proposalId, delegateIds);

        (uint finalAgainstVotes, uint finalForVotes,) = governor.getTally(proposalId);
        require(finalAgainstVotes == priorAgainstVotes + delegatorRecords[1].votes);
        require(finalForVotes == priorForVotes);
    }

    function testDelegate() public {
        /* ------PRIMARY-DELEGATOR------- */
        vm.startPrank(DELEGATOR_PRIMARY);
        uint primaryTs = block.timestamp + 7 days;
        governor.delegate(DELEGATEE_PRIMARY, primaryTs);
        vm.stopPrank();
        /* -------------------------------- */ 

        /* ------SECONDARY-DELEGATOR------- */
        vm.startPrank(DELEGATOR_SECONDARY);
        uint secondaryTs = block.timestamp + 1 days;
        governor.delegate(DELEGATEE_SECONDARY, secondaryTs);
        vm.stopPrank();
        /* -------------------------------- */ 

        /* ------PRIMARY-DELEGATEE------- */
        vm.startPrank(DELEGATEE_PRIMARY);
        uint proposalId = pushMockProposal(1);

        vm.warp(block.timestamp + DEFAULT_VOTING_DELAY + 1);

        commitDelegation(proposalId, DELEGATOR_PRIMARY, DELEGATEE_PRIMARY);
        governor.castVote(proposalId, 0, "");
        vm.stopPrank();
        /* -------------------------------- */

        /* ------SECONDARY-DELEGATEE------- */
        vm.startPrank(DELEGATEE_SECONDARY);
        governor.castVote(proposalId, 0, "");
        // Try cast expired virtual weight
        vm.expectRevert();
        commitDelegation(proposalId, DELEGATOR_SECONDARY, DELEGATEE_SECONDARY, secondaryTs);
        //////////////////////////////////////
        vm.stopPrank();
        /* -------------------------------- */

        /* ------ALPHA-STAKEHOLDER------- */
        vm.startPrank(STAKEHOLDER_ALPHA);
        governor.castVote(proposalId, 1, "");
        vm.stopPrank();
        /* -------------------------------- */  
      
        /* ------BETA-STAKEHOLDER------- */
        vm.startPrank(STAKEHOLDER_BETA);
        governor.castVote(proposalId, 1, "");
        vm.stopPrank();
        /* -------------------------------- */  

        /* ------THETA-STAKEHOLDER------- */
        vm.startPrank(STAKEHOLDER_THETA);
        governor.castVote(proposalId, 1, "");
        vm.stopPrank();
        /* -------------------------------- */  

        /* ------OMEGA-STAKEHOLDER------- */
        vm.startPrank(STAKEHOLDER_OMEGA);
        governor.castVote(proposalId, 1, "");
        vm.stopPrank();
        /* -------------------------------- */  

        /* ------TAU-STAKEHOLDER------- */
        vm.startPrank(STAKEHOLDER_TAU);
        governor.castVote(proposalId, 1, "");
        vm.stopPrank();
        /* -------------------------------- */  

        vm.warp(block.timestamp + DEFAULT_VOTING_PERIOD + 1);

        governor.queue(proposalId);

        vm.warp(block.timestamp + DEFAULT_TIMELOCK_DELAY + 1);

        bytes[] memory votes = new bytes[](1);
        votes[0] = abi.encode(DELEGATOR_SECONDARY, DELEGATEE_SECONDARY, secondaryTs);
        // Try attest expired delegation
        vm.expectRevert();
        governor.batchAttestVotes(proposalId, votes);
        //////////////////////////////////////
        votes[0] = abi.encode(DELEGATOR_PRIMARY, DELEGATEE_PRIMARY, primaryTs);
        governor.batchAttestVotes(proposalId, votes);
        // Attempt reattesting 
        vm.expectRevert();
        governor.batchAttestVotes(proposalId, votes);
        //////////////////////////////////////
        (uint againstVotes, uint forVotes,) = governor.getTally(proposalId);
    
        require(forVotes == 28500e18);
        require(againstVotes == 25500e18);
    }

    function testRedelegate() public {
        /* ------PRIMARY-DELEGATOR------- */
        vm.startPrank(DELEGATOR_PRIMARY);
        uint primaryTs = block.timestamp + 7 days;
        governor.delegate(DELEGATEE_PRIMARY, primaryTs);
        vm.stopPrank();
        /* -------------------------------- */ 

        /* ------SECONDARY-DELEGATOR------- */
        vm.startPrank(DELEGATOR_SECONDARY);
        uint secondaryTs = block.timestamp + 1 days;
        governor.delegate(DELEGATEE_SECONDARY, secondaryTs);
        vm.stopPrank();
        /* -------------------------------- */ 

        /* ------PRIMARY-DELEGATEE------- */
        vm.startPrank(DELEGATEE_PRIMARY);
        uint proposalId = pushMockProposal(1);

        vm.warp(block.timestamp + DEFAULT_VOTING_DELAY + 1);

        commitDelegation(proposalId, DELEGATOR_PRIMARY, DELEGATEE_PRIMARY);
        governor.castVote(proposalId, 1, "");
        vm.stopPrank();
        /* -------------------------------- */

        /* ------PRIMARY-DELEGATOR------- */
        vm.startPrank(DELEGATOR_PRIMARY);
        // Cant redelegate an active delegation without revoking
        vm.expectRevert();
        governor.delegate(DELEGATEE_PRIMARY, block.timestamp + 7 days);
        //////////////////////////////////////
        vm.stopPrank();
        /* -------------------------------- */ 

        /* ------SECONDARY-DELEGATOR------- */
        vm.startPrank(DELEGATOR_SECONDARY);
        governor.delegate(DELEGATOR_SECONDARY, block.timestamp + 7 days);
        governor.castVote(proposalId, 1, "");
        vm.stopPrank();
        /* -------------------------------- */ 

        /* ------SECONDARY-DELEGATEE------- */
        vm.startPrank(DELEGATEE_SECONDARY);
        governor.castVote(proposalId, 1, "");
        vm.stopPrank();
        /* -------------------------------- */

        vm.warp(block.timestamp + DEFAULT_VOTING_PERIOD + 1);

        governor.queue(proposalId);

        vm.warp(block.timestamp + DEFAULT_TIMELOCK_DELAY + 1);

        bytes[] memory votes = new bytes[](1);
        votes[0] = abi.encode(DELEGATOR_PRIMARY, DELEGATEE_PRIMARY, primaryTs);
        governor.batchAttestVotes(proposalId, votes);

        (, uint forVotes,) = governor.getTally(proposalId);
    
        require(forVotes == 34000e18);  
    }

    function testRevoke() public {
        /* ------PRIMARY-DELEGATOR------- */
        vm.startPrank(DELEGATOR_PRIMARY);
        uint primaryTs = block.timestamp + 7 days;
        governor.delegate(DELEGATEE_PRIMARY, primaryTs);
        vm.stopPrank();
        /* -------------------------------- */ 

        /* ------SECONDARY-DELEGATOR------- */
        vm.startPrank(DELEGATOR_SECONDARY);
        uint secondaryTs = block.timestamp + 1 days;
        governor.delegate(DELEGATEE_SECONDARY, secondaryTs);
        vm.stopPrank();
        /* -------------------------------- */ 

        /* ------PRIMARY-DELEGATEE------- */
        vm.startPrank(DELEGATEE_PRIMARY);
        uint proposalId = pushMockProposal(0);

        vm.warp(block.timestamp + DEFAULT_VOTING_DELAY + 1);

        commitDelegation(proposalId, DELEGATOR_PRIMARY, DELEGATEE_PRIMARY);
        governor.castVote(proposalId, 1, "");
        vm.stopPrank();
        /* -------------------------------- */

        /* ------PRIMARY-DELEGATOR------- */
        vm.startPrank(DELEGATOR_PRIMARY);
        governor.revoke();
        vm.stopPrank();
        /* -------------------------------- */ 

        /* ------SECONDARY-DELEGATOR------- */
        vm.startPrank(DELEGATOR_SECONDARY);
        // Cant revoke an already expired delegation
        vm.expectRevert();
        governor.revoke();
        //////////////////////////////////////
        vm.stopPrank();
        /* -------------------------------- */ 

        /* ------SECONDARY-DELEGATEE------- */
        vm.startPrank(DELEGATEE_SECONDARY);
        governor.castVote(proposalId, 1, "");
        vm.stopPrank();
        /* -------------------------------- */

        vm.warp(block.timestamp + DEFAULT_VOTING_PERIOD + 1);

        governor.queue(proposalId);

        vm.warp(block.timestamp + DEFAULT_TIMELOCK_DELAY + 1);

        bytes[] memory votes = new bytes[](1);
        votes[0] = abi.encode(DELEGATOR_PRIMARY, DELEGATEE_PRIMARY, primaryTs);
        // Try attest revoked delegation
        vm.expectRevert();
        governor.batchAttestVotes(proposalId, votes);
        //////////////////////////////////////

        (, uint forVotes,) = governor.getTally(proposalId);
    
        require(forVotes == 17000e18);
    }

    function testRevokeBySig() public {
        uint256 delegatorPk = 0xD31163B01;
        address delegator = vm.addr(delegatorPk);
        uint delegationExpiry = block.timestamp + 7 days;
        uint sigExpiry = block.timestamp + 7 days;

        /* ------DELEGATOR------- */
        vm.startPrank(delegator);
        governorToken.mint(delegator, STAKEHOLDER_MINOR);
        approveAndLock(STAKEHOLDER_MINOR);
        governor.delegate(DELEGATEE_PRIMARY, delegationExpiry);
        vm.stopPrank();
        /* -------------------------------- */ 

        /* ------PRIMARY-DELEGATEE------- */
        vm.startPrank(DELEGATEE_PRIMARY);
        uint proposalId = pushMockProposal(1);

        vm.warp(block.timestamp + DEFAULT_VOTING_DELAY + 1);

        commitDelegation(proposalId, delegator, DELEGATEE_PRIMARY);
        governor.castVote(proposalId, 1, "");
        vm.stopPrank();
        /* -------------------------------- */ 

        bytes32 digest = revocationDigest(DELEGATEE_PRIMARY, delegationExpiry, 0, sigExpiry);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(delegatorPk, digest);
        governor.revokeBySig(DELEGATEE_PRIMARY, delegationExpiry, 0, sigExpiry, v, r, s);

        /* ------STAKEHOLDER_ALPHA------- */
        vm.startPrank(STAKEHOLDER_ALPHA);
        governor.castVote(proposalId, 1, "");
        vm.stopPrank();
        /* -------------------------------- */ 

        /* ------STAKEHOLDER_BETA------- */
        vm.startPrank(STAKEHOLDER_BETA);
        governor.castVote(proposalId, 1, "");
        vm.stopPrank();
        /* -------------------------------- */ 

        /* ------STAKEHOLDER_THETA------- */
        vm.startPrank(STAKEHOLDER_THETA);
        governor.castVote(proposalId, 1, "");
        vm.stopPrank();
        /* -------------------------------- */ 

        /* ------STAKEHOLDER_OMEGA------- */
        vm.startPrank(STAKEHOLDER_OMEGA);
        governor.castVote(proposalId, 1, "");
        vm.stopPrank();
        /* -------------------------------- */ 

        /* ------STAKEHOLDER_TAU------- */
        vm.startPrank(STAKEHOLDER_TAU);
        governor.castVote(proposalId, 1, "");
        vm.stopPrank();
        /* -------------------------------- */ 

        vm.warp(block.timestamp + DEFAULT_VOTING_PERIOD + 1);

        governor.queue(proposalId);

        vm.warp(block.timestamp + DEFAULT_TIMELOCK_DELAY + 1);

        bytes[] memory votes = new bytes[](1);
        votes[0] = abi.encode(delegator, DELEGATEE_PRIMARY, delegationExpiry);

        // Cant attest votes that have been revoked
        vm.expectRevert();
        governor.batchAttestVotes(proposalId, votes);
        ////////////////////////////////////////
    }

    function setUpScenario() internal {
        /* ------PRIMARY-DELEGATOR------- */
        vm.startPrank(DELEGATOR_PRIMARY);
        approveAndLock(STAKEHOLDER_MINOR);
        vm.stopPrank();
        /* -------------------------------- */

        /* ------SECONDARY-DELEGATOR------- */
        vm.startPrank(DELEGATOR_SECONDARY);
        approveAndLock(STAKEHOLDER_MINOR);
        vm.stopPrank();
        /* -------------------------------- */ 

        /* ------PRIMARY-DELEGATEE------- */
        vm.startPrank(DELEGATEE_PRIMARY);
        approveAndLock(STAKEHOLDER_MINOR);
        vm.stopPrank();
        /* -------------------------------- */

        /* ------SECONDARY-DELEGATEE------- */
        vm.startPrank(DELEGATEE_SECONDARY);
        approveAndLock(STAKEHOLDER_MINOR);
        vm.stopPrank();
        /* -------------------------------- */

        // Let delegate voting power accrue 
        vm.warp(block.timestamp + 90 days);

        /* ------ALPHA-STAKEHOLDER------- */
        vm.startPrank(STAKEHOLDER_ALPHA);
        approveAndLock(STAKEHOLDER_MINOR);
        vm.stopPrank();
        /* -------------------------------- */  

        // Give alpha stakeholder fourth level multiplier
        vm.warp(block.timestamp + 30 days);

        /* ------BETA-STAKEHOLDER------- */
        vm.startPrank(STAKEHOLDER_BETA);
        approveAndLock(STAKEHOLDER_MINOR);
        vm.stopPrank();
        /* -------------------------------- */  

        // Give beta stakeholder third level multiplier
        vm.warp(block.timestamp + 30 days);

        /* ------THETA-STAKEHOLDER------- */
        vm.startPrank(STAKEHOLDER_THETA);
        approveAndLock(STAKEHOLDER_MINOR);
        vm.stopPrank();
        /* -------------------------------- */  

        // Give theta stakeholder second level multiplier
        vm.warp(block.timestamp + 30 days);

        /* ------OMEGA-STAKEHOLDER------- */
        vm.startPrank(STAKEHOLDER_OMEGA);
        approveAndLock(STAKEHOLDER_MINOR);
        vm.stopPrank();
        /* -------------------------------- */  

        /* ------TAU-STAKEHOLDER------- */
        vm.startPrank(STAKEHOLDER_TAU);
        approveAndLock(STAKEHOLDER_MINOR);
        vm.stopPrank();
        /* -------------------------------- */ 
    }

}
