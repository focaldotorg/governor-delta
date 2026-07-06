pragma solidity ^0.8.13;

import { ITimeWeightedVotingStrategy } from "@interfaces/ITimeWeightedVotingStrategy.sol";
import { TenureVotingStrategy } from "@strategies/TenureVotingStrategy.sol";
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
        uint proposalId = pushMockProposal();

        vm.warp(block.timestamp + DEFAULT_VOTING_DELAY + 1);

        governor.castVote(proposalId, 0, "");
        governor.castVirtualVote(proposalId, 0, DELEGATOR_PRIMARY);
        vm.stopPrank();
        /* -------------------------------- */

        /* ------SECONDARY-DELEGATEE------- */
        vm.startPrank(DELEGATEE_SECONDARY);
        governor.castVote(proposalId, 0, "");
        // Try cast expired virtual weight
        vm.expectRevert();
        governor.castVirtualVote(proposalId, 0, DELEGATOR_SECONDARY);
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
        uint proposalId = pushMockProposal();

        vm.warp(block.timestamp + DEFAULT_VOTING_DELAY + 1);

        governor.castVote(proposalId, 1, "");
        governor.castVirtualVote(proposalId, 1, DELEGATOR_PRIMARY);
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
        uint proposalId = pushMockProposal();

        vm.warp(block.timestamp + DEFAULT_VOTING_DELAY + 1);

        governor.castVote(proposalId, 1, "");
        governor.castVirtualVote(proposalId, 1, DELEGATOR_PRIMARY);
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
