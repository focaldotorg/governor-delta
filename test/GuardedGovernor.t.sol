pragma solidity ^0.8.13;

import { TransferGuard, GuardStorage } from "@guards/TransferGuard.sol";
import { WhitelistGuard } from "@guards/WhitelistGuard.sol";
import { FunctionSelectorGuard } from "@guards/FunctionSelectorGuard.sol";
import { StakingGuard } from "@guards/StakingGuard.sol";
import { GovernorDelta } from "@root/GovernorDelta.sol";
import { BaseGovernorTest } from "./BaseGovernor.t.sol";
import { GovernorStorageV3 } from "@root/GovernorStorageV3.sol";

contract GuardedGovernorTest is BaseGovernorTest {

    address[] public guards;

    function setUp() public override {
        super.setUp(); 

        GovernorStorageV3.Graduated[3] memory config;
        guards.push(address(new StakingGuard(address(governor))));

        // Guard policy one configuration

        string[] memory selectorsOne = new string[](7);
        selectorsOne[0] = "_setProposalConfig(Graduated[3])";
        selectorsOne[1] = "_setVotingModule(address)";
        selectorsOne[2] = "_setVetoQuorum(uint256)";
        // Constraint can be bypassed if param uses alt uint declaration
        selectorsOne[3] = "_setVetoQuorum(uint)";
        selectorsOne[4] = "_setPendingAdmin(address)";
        selectorsOne[5] = "relay(uint256,address,uint256,bytes)";
        // Constraint can be bypassed if param uses alt uint declaration 
        selectorsOne[6] = "relay(uint,address,uint,bytes)";
        address[] memory contactsOne = new address[](1);
        contactsOne[0] = address(governor);
        address[] memory policyOne = new address[](3);
        policyOne[0] = guards[0];
        policyOne[1] = address(new WhitelistGuard(address(governor), contactsOne));
        policyOne[2] = address(new FunctionSelectorGuard(address(governor), selectorsOne));

        // Guard policy two configuration

        string[] memory selectorsTwo = new string[](5);
        selectorsTwo[0] = "_setProposalConfig(Graduated[3])";
        selectorsTwo[1] = "_setVotingModule(address)";
        selectorsTwo[2] = "_setVetoQuorum(uint256)";
        selectorsTwo[3] = "_setPendingAdmin(address)";
        selectorsTwo[4] = "approve(address,uint256)";
        address[] memory contactsTwo = new address[](4);
        contactsTwo[0] = address(governor);
        contactsTwo[1] = address(governorToken);
        contactsTwo[2] = address(0);
        contactsTwo[3] = address(treasuryToken);
        GuardStorage.Token[] memory budget = new GuardStorage.Token[](4); 
        budget[0] = GuardStorage.Token(0, 50 ether, 50 ether, address(0), address(timelock));
        budget[1] = GuardStorage.Token(0, 50 ether, 50 ether, address(0), address(governor));
        budget[2] = GuardStorage.Token(0, 500e18, 1000e18, address(treasuryToken), address(timelock));
        budget[3] = GuardStorage.Token(0, 100e18, 100e18, address(treasuryToken), address(governor));
        address[] memory policyTwo = new address[](4);
        policyTwo[0] = guards[0];
        policyTwo[1] = address(new TransferGuard(address(governor), budget));
        policyTwo[2] = address(new FunctionSelectorGuard(address(governor), selectorsTwo));
        policyTwo[3] = address(new WhitelistGuard(address(governor), contactsTwo));

        // Store transfer guard target for later
        guards.push(policyTwo[1]);

        // Guard policy three configuration
      
        address[] memory policyThree = new address[](1);
        policyThree[0] = guards[0];

        config[0] = GovernorStorageV3.Graduated(DEFAULT_PROPOSAL_QUOTA, DEFAULT_TIER_0_QUORUM, DEFAULT_VOTING_PERIOD, policyOne);
        config[1] = GovernorStorageV3.Graduated(DEFAULT_PROPOSAL_QUOTA, DEFAULT_TIER_1_QUORUM, DEFAULT_VOTING_PERIOD, policyTwo);
        config[2] = GovernorStorageV3.Graduated(DEFAULT_PROPOSAL_QUOTA, DEFAULT_TIER_2_QUORUM, DEFAULT_VOTING_PERIOD, policyThree);

        /* --------TIMELOCK-------- */
        vm.startPrank(address(timelock));
        governor._setProposalConfig(config);
        vm.stopPrank();
        /* -------------------------------- */
    }

    function testWhitelistAndSelectorGuards() public {
        address[] memory targets = new address[](1);
        string[] memory signatures = new string[](1);
        bytes[] memory calldatas = new bytes[](1);

        targets[0] = address(0);
        signatures[0] = "";
        calldatas[0] = ""; 

        /* --------STAKEHOLDER PRIMARY-------- */
        vm.startPrank(STAKEHOLDER_PRIMARY);
        approveAndLock(STAKEHOLDER_MAJOR);
        uint proposalId = makeProposal(0, targets[0], signatures[0], calldatas[0], 1); 

        vm.warp(block.timestamp + DEFAULT_VOTING_DELAY + 1);

        governor.castVote(proposalId, 1, "");
        vm.stopPrank();
        /* -------------------------------- */

        vm.warp(block.timestamp + DEFAULT_VOTING_PERIOD);

        governor.queue(proposalId);

        vm.warp(block.timestamp + DEFAULT_TIMELOCK_DELAY + DEFAULT_VETO_PERIOD + 1);

        // cant execute unpermitted target address
        vm.expectRevert();
        governor.execute(proposalId);
        //////////////////////////////////////////

        targets[0] = address(governor);

        // Test that alt uint declaration for restricted 
        
        signatures[0] = "_setVetoQuorum(uint)";
        calldatas[0] = abi.encode(10000e18);

        /* --------STAKEHOLDER PRIMARY-------- */
        vm.startPrank(STAKEHOLDER_PRIMARY);
        proposalId = makeProposal(0, targets[0], signatures[0], calldatas[0], 0); 

        vm.warp(block.timestamp + DEFAULT_VOTING_DELAY + 1);

        governor.castVote(proposalId, 1, "");
        vm.stopPrank();
        /* -------------------------------- */

        vm.warp(block.timestamp + DEFAULT_VOTING_PERIOD);

        governor.queue(proposalId);

        vm.warp(block.timestamp + DEFAULT_TIMELOCK_DELAY + DEFAULT_VETO_PERIOD + 1);

        // cant execute restricted selector
        vm.expectRevert();
        governor.execute(proposalId);
        /////////////////////////////////////////////

        targets[0] = address(governor);
        signatures[0] = "_setVetoPeriod(uint256)";
        calldatas[0] = abi.encode(2 days);

        /* --------STAKEHOLDER PRIMARY-------- */
        vm.startPrank(STAKEHOLDER_PRIMARY);
        proposalId = makeProposal(0, targets[0], signatures[0], calldatas[0], 0); 

        vm.warp(block.timestamp + DEFAULT_VOTING_DELAY + 1);

        governor.castVote(proposalId, 1, "");
        vm.stopPrank();
        /* -------------------------------- */

        vm.warp(block.timestamp + DEFAULT_VOTING_PERIOD);

        governor.queue(proposalId);

        vm.warp(block.timestamp + DEFAULT_TIMELOCK_DELAY + DEFAULT_VETO_PERIOD + 1);

        governor.execute(proposalId);
    }

    function testTransferGuard() public {
        vm.deal(address(governor), 50 ether);
        vm.deal(address(timelock), 100 ether);

        // Spending with sufficient allowance 
        
        address[] memory targets = new address[](2);
        string[] memory signatures = new string[](2);
        bytes[] memory calldatas = new bytes[](2);
        uint[] memory values = new uint[](2);
 
        values[0] = 50 ether;
        targets[0] = address(0);
        signatures[0] = "";
        calldatas[0] = "";

        values[1] = 0;
        targets[1] = address(governor);
        signatures[1] = "relay(uint256,address,uint256,bytes)";
        calldatas[1] = abi.encode(2, address(0), 50 ether, "");

        /* --------STAKEHOLDER PRIMARY-------- */
        vm.startPrank(STAKEHOLDER_PRIMARY);
        approveAndLock(STAKEHOLDER_MAJOR);
        uint proposalId = governor.propose(1, targets, values, signatures, calldatas, ""); 

        vm.warp(block.timestamp + DEFAULT_VOTING_DELAY + 1);

        governor.castVote(proposalId, 1, "");
        vm.stopPrank();
        /* -------------------------------- */

        vm.warp(block.timestamp + DEFAULT_VOTING_PERIOD);

        governor.queue(proposalId);

        vm.warp(block.timestamp + DEFAULT_TIMELOCK_DELAY + DEFAULT_VETO_PERIOD + 1);

        governor.execute(proposalId);

        // Spending with insufficient allowance 

        /* --------STAKEHOLDER PRIMARY-------- */
        vm.startPrank(STAKEHOLDER_PRIMARY);
        proposalId = makeProposal(1, address(0), "", "", 1); 

        vm.warp(block.timestamp + DEFAULT_VOTING_DELAY + 1);

        governor.castVote(proposalId, 1, "");
        vm.stopPrank();
        /* -------------------------------- */

        vm.warp(block.timestamp + DEFAULT_VOTING_PERIOD);

        governor.queue(proposalId);

        vm.warp(block.timestamp + DEFAULT_TIMELOCK_DELAY + DEFAULT_VETO_PERIOD + 1);

        // Cant spend with zero policy allowance
        vm.expectRevert();
        governor.execute(proposalId);
        //////////////////////////////////////

        // Normal spending and updated allowance 
        
        GuardStorage.Token[] memory budget = new GuardStorage.Token[](1); 
        budget[0] = GuardStorage.Token(0, 50 ether, 50 ether, address(0), address(timelock));
 
        /* --------GOVERNOR-------- */
        vm.startPrank(address(governor));
        TransferGuard(guards[1]).overwrite(budget);
        vm.stopPrank();
        /* -------------------------------- */

        targets = new address[](2);
        signatures = new string[](2);
        calldatas = new bytes[](2);
        values = new uint[](2);

        targets[0] = address(treasuryToken);
        signatures[0] = "transfer(address,uint256)";
        calldatas[0] = abi.encode(address(0xf), 500e18);
        values[0] = 0;

        targets[1] = address(0);
        signatures[1] = "";
        calldatas[1] = "";
        values[1] = 30 ether;

        /* --------STAKEHOLDER PRIMARY-------- */
        vm.startPrank(STAKEHOLDER_PRIMARY);
        proposalId = governor.propose(1, targets, values, signatures, calldatas, ""); 

        vm.warp(block.timestamp + DEFAULT_VOTING_DELAY + 1);

        governor.castVote(proposalId, 1, "");
        vm.stopPrank();
        /* -------------------------------- */

        vm.warp(block.timestamp + DEFAULT_VOTING_PERIOD);

        governor.queue(proposalId);

        vm.warp(block.timestamp + DEFAULT_TIMELOCK_DELAY + DEFAULT_VETO_PERIOD + 1);

        governor.execute(proposalId);

        // Spending with exceeding policy limit

        /* --------STAKEHOLDER PRIMARY-------- */
        vm.startPrank(STAKEHOLDER_PRIMARY);
        proposalId = makeProposal(1, address(treasuryToken), "transfer(address,uint256)",  abi.encode(address(this), 1000e18), 0); 

        vm.warp(block.timestamp + DEFAULT_VOTING_DELAY + 1);

        governor.castVote(proposalId, 1, "");
        vm.stopPrank();
        /* -------------------------------- */

        vm.warp(block.timestamp + DEFAULT_VOTING_PERIOD);

        governor.queue(proposalId);

        vm.warp(block.timestamp + DEFAULT_TIMELOCK_DELAY + DEFAULT_VETO_PERIOD + 1);

        // Cant spend exceeding policy limit
        vm.expectRevert();
        governor.execute(proposalId);
        //////////////////////////////////////
    }

    function testStakingGuard() public {
        address[] memory targets = new address[](1);
        string[] memory signatures = new string[](1);
        bytes[] memory calldatas = new bytes[](1);

        targets[0] = address(governor);
        signatures[0] = "relay(uint256,address,uint256,bytes)";
        calldatas[0] =
            abi.encode(2, address(governorToken), 0, abi.encodeWithSignature("transfer(address,uint256)", address(this), 1));

        /* --------STAKEHOLDER PRIMARY-------- */
        vm.startPrank(STAKEHOLDER_PRIMARY);
        approveAndLock(STAKEHOLDER_MAJOR);
        uint proposalId = makeProposal(2, targets[0], signatures[0], calldatas[0], 0); 

        vm.warp(block.timestamp + DEFAULT_VOTING_DELAY + 1);

        governor.castVote(proposalId, 1, "");
        vm.stopPrank();
        /* -------------------------------- */

        /* --------STAKEHOLDER SECONDARY-------- */
        vm.startPrank(STAKEHOLDER_SECONDARY);
        approveAndLock(STAKEHOLDER_MAJOR);
        governor.castVote(proposalId, 1, "");
        vm.stopPrank();
        /* -------------------------------- */

        /* --------STAKEHOLDER TERNARY-------- */
        vm.startPrank(STAKEHOLDER_TERNARY);
        approveAndLock(STAKEHOLDER_MINOR);
        governor.castVote(proposalId, 1, "");
        vm.stopPrank();
        /* -------------------------------- */

        vm.warp(block.timestamp + DEFAULT_VOTING_PERIOD);

        governor.queue(proposalId);

        vm.warp(block.timestamp + DEFAULT_TIMELOCK_DELAY + DEFAULT_VETO_PERIOD + 1);

        /// Cant expense govenror staking allocation
        vm.expectRevert();
        governor.execute(proposalId);
        ///////////////////////////////////////////
    }

    function makeProposal(uint8 tier, address target, string memory signature, bytes memory data, uint value) internal returns (uint) {
        address[] memory targets = new address[](1);
        string[] memory signatures = new string[](1);
        bytes[] memory calldatas = new bytes[](1);
        uint[] memory values = new uint[](1);

        values[0] = value;
        targets[0] = target;
        signatures[0] = signature;
        calldatas[0] = data;

        return governor.propose(tier, targets, values, signatures, calldatas, "");
    }
  
}
