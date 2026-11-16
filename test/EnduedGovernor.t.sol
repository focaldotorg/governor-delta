pragma solidity ^0.8.13;

import { IEnduedVotingStrategy } from "@interfaces/IEnduedVotingStrategy.sol";
import { ITimeWeightedVotingStrategy } from "@interfaces/ITimeWeightedVotingStrategy.sol";
import { EnduedTenureVotingStrategy } from "@strategies/TenureVotingStrategy/derivatives/EnduedTenureVotingStrategy.sol";
import { GovernorAdmin } from "./mock/GovernorAdmin.sol";
import { BaseGovernorTest } from "./BaseGovernor.t.sol";

contract EnduedGovernorTest is BaseGovernorTest {

    EnduedTenureVotingStrategy strategy;

    address public constant STAKEHOLDER_TAU = 0x95222290DD7278Aa3Ddd389Cc1E1d165CC4BAfe5; 
    address public constant DELEGATOR_PRIMARY = 0x8A1c5E88Ca465be1D01e4B437CE4E082fD14E25e;
    address public constant DELEGATEE_PRIMARY = 0x557a4fC606ae646F585BC73aD2a4fc745a8CBcc8;
    
    function setUp() public override {
        super.setUp(); 

        // Issue extra share to tau to make proposal succeed
        governorToken.mint(STAKEHOLDER_TAU, STAKEHOLDER_MAJOR + 1);
        governorToken.mint(DELEGATOR_PRIMARY, STAKEHOLDER_MAJOR);
        governorToken.mint(DELEGATEE_PRIMARY, STAKEHOLDER_MAJOR);
  
        IEnduedVotingStrategy.Seed[] memory seeds = new IEnduedVotingStrategy.Seed[](2);
        ITimeWeightedVotingStrategy.Tranche[] memory tranches = new ITimeWeightedVotingStrategy.Tranche[](5);

        tranches[0] = ITimeWeightedVotingStrategy.Tranche(30 days, 1e6);
        tranches[1] = ITimeWeightedVotingStrategy.Tranche(60 days, 1.2e6);
        tranches[2] = ITimeWeightedVotingStrategy.Tranche(90 days, 1.5e6);
        tranches[3] = ITimeWeightedVotingStrategy.Tranche(180 days, 1.7e6);
        tranches[4] = ITimeWeightedVotingStrategy.Tranche(365 days, 2e6);

        seeds[0] = IEnduedVotingStrategy.Seed(STAKEHOLDER_TAU, 365 days, block.timestamp + 100 days);
        seeds[1] = IEnduedVotingStrategy.Seed(DELEGATOR_PRIMARY, 185 days, block.timestamp + 10 days);

        strategy = new EnduedTenureVotingStrategy(address(governor), tranches, seeds);

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

    function testSeeds() public {
        /* ------PRIMARY-DELEGATOR------- */
        vm.startPrank(DELEGATOR_PRIMARY);
        uint primaryTs = block.timestamp + 20 days;
        governor.delegate(DELEGATEE_PRIMARY, primaryTs);
        vm.stopPrank();
        /* -------------------------------- */ 

        // Let delegate endued (seeded) voting power expire 
        vm.warp(block.timestamp + 10 days);

        /* ------PRIMARY-DELEGATEE------- */
        vm.startPrank(DELEGATEE_PRIMARY);
        uint proposalId = pushMockProposal(1);

        vm.warp(block.timestamp + DEFAULT_VOTING_DELAY + 1);

        governor.castVote(proposalId, 0, "");
        governor.castVirtualVote(proposalId, 0, DELEGATOR_PRIMARY);
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
        votes[0] = abi.encode(DELEGATOR_PRIMARY, DELEGATEE_PRIMARY, primaryTs);
        governor.batchAttestVotes(proposalId, votes);

        (uint againstVotes, uint forVotes,) = governor.getTally(proposalId);

        // Deduct extra share voting power  
        require(againstVotes == forVotes - 2);
        require(againstVotes == 30000e18);
    }

    function setUpScenario() internal {
        /* ------PRIMARY-DELEGATOR------- */
        vm.startPrank(DELEGATOR_PRIMARY);
        approveAndLock(STAKEHOLDER_MAJOR);
        vm.stopPrank();
        /* -------------------------------- */

        /* ------PRIMARY-DELEGATEE------- */
        vm.startPrank(DELEGATEE_PRIMARY);
        approveAndLock(STAKEHOLDER_MAJOR);
        vm.stopPrank();
        /* -------------------------------- */

        /* ------TAU-STAKEHOLDER------- */
        vm.startPrank(STAKEHOLDER_TAU);
        // Account for extra share
        approveAndLock(STAKEHOLDER_MAJOR + 1);
        vm.stopPrank();
        /* -------------------------------- */ 
    }

}
