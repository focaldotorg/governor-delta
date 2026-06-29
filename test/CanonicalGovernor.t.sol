pragma solidity ^0.8.13;

import { GovernorAdmin } from "./mock/GovernorAdmin.sol";
import { GovernorBaseTest } from "./GovernorBase.t.sol";

contract CanonicalGovernorTest is GovernorBaseTest {

    address public constant STAKEHOLDER_ALPHA = 0x67aA499679E75EdFbfb7719fB4795a9c389eC38c;
    address public constant STAKEHOLDER_BETA  = 0x4838B106FCe9647Bdf1E7877BF73cE8B0BAD5f97;
    address public constant STAKEHOLDER_THETA = 0x3011426bB63e7BE9b6b8AdF572874009569710b8;

    address public constant DELEGATOR_PRIMARY     = 0x8A1c5E88Ca465be1D01e4B437CE4E082fD14E25e;
    address public constant DELEGATOR_SECONDARY   = 0xE0D268481983B218e83DEe30da1c9f36B56Ffa0a;
    address public constant DELEGATEE_PRIMARY     = 0x557a4fC606ae646F585BC73aD2a4fc745a8CBcc8;
    address public constant DELEGATEE_SECONDARY   = 0xCbFD1745E492F6a555dF7A9B1E0B3Cd139e69504;

    function setUp() public override {
        super.setUp(); 

        governorToken.mint(STAKEHOLDER_ALPHA, STAKEHOLDER_MAJOR);
        governorToken.mint(STAKEHOLDER_BETA, STAKEHOLDER_MAJOR);
        governorToken.mint(STAKEHOLDER_THETA, STAKEHOLDER_MAJOR);
        governorToken.mint(STAKEHOLDER_ALPHA, STAKEHOLDER_MAJOR);
        governorToken.mint(STAKEHOLDER_BETA, STAKEHOLDER_MAJOR);
        governorToken.mint(DELEGATOR_PRIMARY, STAKEHOLDER_MINOR);
        governorToken.mint(DELEGATOR_SECONDARY, STAKEHOLDER_MINOR);
        governorToken.mint(DELEGATEE_PRIMARY, STAKEHOLDER_MINOR);
        governorToken.mint(DELEGATEE_SECONDARY, STAKEHOLDER_MINOR);

        /* --------TIMELOCK-------- */
        vm.startPrank(address(timelock));
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
        // Cant delegate past the max threshold
        vm.expectRevert();
        governor.delegate(DELEGATEE_PRIMARY, 366 days);
        //////////////////////////////////////
        governor.delegate(DELEGATEE_PRIMARY, 7 days);
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
        // Delegator cant withdraw with active vote 
        vm.expectRevert();
        governor.unlock(STAKEHOLDER_MINOR);
        //////////////////////////////////////
        vm.stopPrank();
        /* -------------------------------- */ 

        vm.warp(block.timestamp + DEFAULT_VOTING_PERIOD);

        (, uint forVotes,)= governor.getTally(proposalId);
        require(forVotes == STAKEHOLDER_MINOR * 2);

        /* ------PRIMARY-DELEGATOR------- */
        vm.startPrank(DELEGATOR_PRIMARY);
        // Delegator can now withdraw 
        governor.unlock(STAKEHOLDER_MINOR);
        vm.stopPrank();
        /* -------------------------------- */ 

        vm.warp(block.timestamp + 1 hours);

        /* ------PRIMARY-DELEGATEE------- */
        vm.startPrank(DELEGATEE_PRIMARY);
        pushMockProposal();

        vm.warp(block.timestamp + DEFAULT_VOTING_DELAY + 1);

        governor.castVote(proposalId + 1, 1, "");
        // Delegatee cant spend delegation that is no longer active
        vm.expectRevert();
        governor.castVirtualVote(proposalId + 1, 1, DELEGATOR_PRIMARY);
        //////////////////////////////////////
        vm.stopPrank();
        /* -------------------------------- */

        (, uint finalVotes,)= governor.getTally(proposalId + 1);
        require(finalVotes == STAKEHOLDER_MINOR);
    }

    function testRedelegate() public {}

    function testRevoke() public {}

    function testProxyVote() public {}

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

        /* ------ALPHA-STAKEHOLDER------- */
        vm.startPrank(STAKEHOLDER_ALPHA);
        approveAndLock(STAKEHOLDER_MAJOR);
        vm.stopPrank();
        /* -------------------------------- */ 

        /* ------BETA-STAKEHOLDER------- */
        vm.startPrank(STAKEHOLDER_BETA);
        approveAndLock(STAKEHOLDER_MAJOR);
        vm.stopPrank();
        /* -------------------------------- */

        /* ------THETA-STAKEHOLDER------- */
        vm.startPrank(STAKEHOLDER_THETA);
        approveAndLock(STAKEHOLDER_MAJOR);
        vm.stopPrank();
        /* -------------------------------- */ 
    }

}
