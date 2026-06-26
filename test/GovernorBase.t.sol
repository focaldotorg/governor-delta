// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import { Test, console } from "forge-std/Test.sol";

import { GovernorStorageV3, GovernorStorageV1 } from "@root/GovernorStorageV3.sol";

import { GovernorAdmin } from "./mock/GovernorAdmin.sol";
import { TestERC20 } from "./mock/TestERC20.sol";
import { RelaxedTimelock } from "./mock/RelaxedTimelock.sol";

contract GovernorBaseTest is Test {

    RelaxedTimelock timelock;
    GovernorAdmin governor;
    TestERC20 treasuryToken;
    TestERC20 governorToken;
  
    uint public constant STAKEHOLDER_MAJOR = 45000 ether;
    uint public constant STAKEHOLDER_MINOR = 5000 ether;
    uint public constant TREASURY_RESERVE = 20000 ether;
    uint public constant DEFAULT_PROPOSAL_QUOTA = 1000 ether;
    uint public constant DEFAULT_VOTING_PERIOD = 3 days;
    uint public constant DEFAULT_VOTING_DELAY = 2 days;
    uint public constant DEFAULT_TIMELOCK_DELAY = 1 days;

    uint public constant DEFAULT_TIER_0_QUORUM = 10000e18;
    uint public constant DEFAULT_TIER_0_QUOTA = 500e18;
    uint public constant DEFAULT_TIER_0_DURATION = 7 days;
    uint public constant DEFAULT_TIER_1_QUORUM = 15000e18;
    uint public constant DEFAULT_TIER_1_QUOTA =1000e18;
    uint public constant DEFAULT_TIER_1_DURATION = 18 days;
    uint public constant DEFAULT_TIER_2_QUORUM = 33000e18;
    uint public constant DEFAULT_TIER_2_QUOTA = 5000e18;
    uint public constant DEFAULT_TIER_2_DURATION = 38 days;
    uint public constant DEFAULT_TIER_3_QUORUM = 51000e18;
    uint public constant DEFAULT_TIER_3_QUOTA = 10000e18;
    uint public constant DEFAULT_TIER_3_DURATION = 91 days;

    address public constant STAKEHOLDER_PRIMARY   = 0x742d35Cc6634C0532925a3b844Bc454e4438f44e;
    address public constant STAKEHOLDER_SECONDARY = 0xd8dA6BF26964aF9D7eEd9e03E53415D37aA96045;
    address public constant STAKEHOLDER_TERNARY   = 0x66f820a414680B5bcda5eECA5dea238543F42054;

    function setUp() public {
        treasuryToken = new TestERC20();
        governorToken = new TestERC20();
        governor = new GovernorAdmin();
        timelock = new RelaxedTimelock(msg.sender, DEFAULT_TIMELOCK_DELAY);

        vm.deal(STAKEHOLDER_PRIMARY, 1 ether);
        vm.deal(STAKEHOLDER_SECONDARY, 1 ether);
        vm.deal(STAKEHOLDER_TERNARY, 1 ether);
        treasuryToken.mint(address(timelock), TREASURY_RESERVE);
        governorToken.mint(STAKEHOLDER_PRIMARY, STAKEHOLDER_MAJOR);
        governorToken.mint(STAKEHOLDER_SECONDARY, STAKEHOLDER_MAJOR);
        governorToken.mint(STAKEHOLDER_TERNARY, STAKEHOLDER_MINOR);
        // Initialise governor
        governor.initialize(address(timelock), address(governorToken), DEFAULT_VOTING_PERIOD, DEFAULT_VOTING_DELAY, DEFAULT_PROPOSAL_QUOTA);
        governor._setPendingAdmin(address(governor));
        governor.initiate(address(governor));
        governor.acceptAdmin(address(timelock));
    }

    function testLockSystem() public {
        uint beforeTs = block.timestamp;
        uint balanceBefore = governorToken.balanceOf(STAKEHOLDER_PRIMARY);
        (uint stakeBefore,) = governor.stake(STAKEHOLDER_PRIMARY);
        require(balanceBefore == STAKEHOLDER_MAJOR);
        require(stakeBefore == 0);

        /* ------PRIMARY-STAKEHOLDER------- */
        vm.startPrank(STAKEHOLDER_PRIMARY);
        governorToken.approve(address(governor), STAKEHOLDER_MAJOR);
        governor.lock(STAKEHOLDER_MAJOR);
        vm.stopPrank();
        /* -------------------------------- */

        // Fast forward 6 hours
        vm.warp(beforeTs + 6 hours);

        uint balanceAfter = governorToken.balanceOf(STAKEHOLDER_PRIMARY);
        (uint stakeAfter, uint deltaTime) = governor.stake(STAKEHOLDER_PRIMARY);

        require(balanceAfter == 0);
        require(stakeAfter == STAKEHOLDER_MAJOR);
        require(deltaTime == 0);

        /* ------PRIMARY-STAKEHOLDER------- */
        vm.startPrank(STAKEHOLDER_PRIMARY);
        governor.unlock(500e18);
        vm.stopPrank();
        /* -------------------------------- */

        uint balanceLast = governorToken.balanceOf(STAKEHOLDER_PRIMARY);
        (uint stakeLast, uint deltaTimeLast) = governor.stake(STAKEHOLDER_PRIMARY);

        require(balanceLast == 500e18);
        require(stakeLast == 44500e18);
        require(deltaTimeLast == (block.timestamp - beforeTs) * STAKEHOLDER_MAJOR);
    }

    function testInvalidProposal() public {
        address[] memory targets = new address[](1);
        string[] memory signatures = new string[](1);
        bytes[] memory calldatas = new bytes[](1);
        uint[] memory values = new uint[](1);

        values[0] = 0;
        targets[0] = address(governor);
        signatures[0] = "_activateDelegation()";
        calldatas[0] = "";

        /* ------TERNARY-STAKEHOLDER------- */
        vm.startPrank(STAKEHOLDER_TERNARY);
        governorToken.approve(address(governor), STAKEHOLDER_MINOR);
        governor.lock(STAKEHOLDER_MINOR);
        governor.propose(0, targets, values, signatures, calldatas, "");

        // Factor for voting delay
        vm.warp(block.timestamp + DEFAULT_VOTING_DELAY + 1);

        governor.castVote(2, 1, "");

        // Let proposal finalise
        vm.warp(block.timestamp + DEFAULT_VOTING_PERIOD + DEFAULT_TIMELOCK_DELAY);

        GovernorStorageV1.ProposalState endState = governor.state(2); 
        GovernorStorageV3.ProposalStatus endStatus = governor.status(2);
        require(endState == GovernorStorageV1.ProposalState.Defeated);
        require(endStatus == GovernorStorageV3.ProposalStatus.Unqualified);
        vm.expectRevert();
        governor.queue(2);
        vm.stopPrank();
        /* -------------------------------- */
    }

    function testDefeatedProposal() public {
        address[] memory targets = new address[](1);
        string[] memory signatures = new string[](1);
        bytes[] memory calldatas = new bytes[](1);
        uint[] memory values = new uint[](1);

        values[0] = 0;
        targets[0] = address(governor);
        signatures[0] = "_activateDelegation()";
        calldatas[0] = "";

        /* ------TERNARY-STAKEHOLDER------- */
        vm.startPrank(STAKEHOLDER_TERNARY);
        governorToken.approve(address(governor), STAKEHOLDER_MINOR);
        governor.lock(STAKEHOLDER_MINOR);
        governor.propose(0, targets, values, signatures, calldatas, "");

        // Factor for voting delay
        vm.warp(block.timestamp + DEFAULT_VOTING_DELAY + 1);

        governor.castVote(2, 1, "");
        /* -------------------------------- */

        /* ------SECONDARY-STAKEHOLDER------- */
        vm.startPrank(STAKEHOLDER_SECONDARY);
        governorToken.approve(address(governor), STAKEHOLDER_MAJOR);
        governor.lock(STAKEHOLDER_MAJOR);
        governor.castVote(2, 0, "");
        vm.stopPrank();
        /* -------------------------------- */


       /* ------PRIMARY-STAKEHOLDER------- */
        vm.startPrank(STAKEHOLDER_PRIMARY);
        governorToken.approve(address(governor), STAKEHOLDER_MAJOR);
        governor.lock(STAKEHOLDER_MAJOR);
        governor.castVote(2, 0, "");
        vm.stopPrank();
        /* -------------------------------- */

        // Let proposal finalise
        vm.warp(block.timestamp + DEFAULT_VOTING_PERIOD + DEFAULT_TIMELOCK_DELAY);

        vm.expectRevert();
        governor.queue(2);

        GovernorStorageV1.ProposalState endState = governor.state(2); 
        GovernorStorageV3.ProposalStatus endStatus = governor.status(2);
        require(endState == GovernorStorageV1.ProposalState.Defeated);
        require(endStatus == GovernorStorageV3.ProposalStatus.Qualified);
        vm.stopPrank();
    }

    function testValidProposal() public {
        address[] memory targets = new address[](1);
        string[] memory signatures = new string[](1);
        bytes[] memory calldatas = new bytes[](1);
        uint[] memory values = new uint[](1);

        values[0] = 0;
        targets[0] = address(governor);
        signatures[0] = "_activateDelegation()";
        calldatas[0] = "";

        /* ------PRIMARY-STAKEHOLDER------- */
        vm.startPrank(STAKEHOLDER_PRIMARY);
        governorToken.approve(address(governor), STAKEHOLDER_MAJOR);
        governor.lock(STAKEHOLDER_MAJOR);
        governor.propose(0, targets, values, signatures, calldatas, "");

        // Factor for voting delay
        vm.warp(block.timestamp + DEFAULT_VOTING_DELAY + 1);

        governor.castVote(2, 1, "");

        // Let proposal finalise
        vm.warp(block.timestamp + DEFAULT_VOTING_PERIOD);

        governor.queue(2);

        // Let proposal finalise
        vm.warp(block.timestamp + DEFAULT_TIMELOCK_DELAY);

        governor.execute(2);
        vm.stopPrank();
        /* -------------------------------- */
    }

    function testExpiredProposal() public {
        address[] memory targets = new address[](1);
        string[] memory signatures = new string[](1);
        bytes[] memory calldatas = new bytes[](1);
        uint[] memory values = new uint[](1);

        values[0] = 0;
        targets[0] = address(governor);
        signatures[0] = "_activateDelegation()";
        calldatas[0] = "";

        /* ------PRIMARY-STAKEHOLDER------- */
        vm.startPrank(STAKEHOLDER_PRIMARY);
        governorToken.approve(address(governor), STAKEHOLDER_MAJOR);
        governor.lock(STAKEHOLDER_MAJOR);
        governor.propose(0, targets, values, signatures, calldatas, "");

        // Factor for voting delay
        vm.warp(block.timestamp + DEFAULT_VOTING_DELAY + 1);

        governor.castVote(2, 1, "");

        // Let proposal finalise
        vm.warp(block.timestamp + DEFAULT_VOTING_PERIOD);

        governor.queue(2);

        // Let proposal finalise
        vm.warp(block.timestamp + DEFAULT_TIMELOCK_DELAY + timelock.GRACE_PERIOD());
        vm.expectRevert();
        governor.execute(2);

        GovernorStorageV1.ProposalState endState = governor.state(2); 
        require(endState == GovernorStorageV1.ProposalState.Expired);
        vm.stopPrank();
    }

    function testContestedProposal() public {
        address[] memory targets = new address[](1);
        string[] memory signatures = new string[](1);
        bytes[] memory calldatas = new bytes[](1);
        uint[] memory values = new uint[](1);

        values[0] = 0;
        targets[0] = address(governor);
        signatures[0] = "_activateDelegation()";
        calldatas[0] = "";

        /* ------PRIMARY-STAKEHOLDER------- */
        vm.startPrank(STAKEHOLDER_PRIMARY);
        governorToken.approve(address(governor), STAKEHOLDER_MAJOR);
        governor.lock(STAKEHOLDER_MAJOR);
        governor.propose(0, targets, values, signatures, calldatas, "");

        // Factor for voting delay
        vm.warp(block.timestamp + DEFAULT_VOTING_DELAY + 1);

        governor.castVote(2, 1, "");

        // Let proposal finalise
        vm.warp(block.timestamp + DEFAULT_VOTING_PERIOD);

        governor.queue(2);
        vm.stopPrank();
        /* -------------------------------- */

        // Let proposal finalise
        vm.warp(block.timestamp + DEFAULT_TIMELOCK_DELAY + 1 hours);

        /* ------TERNARY-STAKEHOLDER------- */
        vm.startPrank(STAKEHOLDER_TERNARY);
        governorToken.approve(address(governor), STAKEHOLDER_MINOR);
        governor.lock(STAKEHOLDER_MINOR);

        governor.veto(2);
        governor.castVetoVote(2, 0, "");

        GovernorStorageV3.ProposalStatus priorStatus = governor.status(2); 
        require(priorStatus == GovernorStorageV3.ProposalStatus.Contested);

        vm.warp(block.timestamp + timelock.GRACE_PERIOD());
        vm.expectRevert();
        governor.execute(2);

        GovernorStorageV1.ProposalState endState = governor.state(2); 
        GovernorStorageV3.ProposalStatus endStatus = governor.status(2); 
        require(endStatus == GovernorStorageV3.ProposalStatus.Resolved);
        require(endState == GovernorStorageV1.ProposalState.Succeeded);
        vm.stopPrank();
        /* -------------------------------- */
    }

    function testVetoedProposal() public {
        address[] memory targets = new address[](1);
        string[] memory signatures = new string[](1);
        bytes[] memory calldatas = new bytes[](1);
        uint[] memory values = new uint[](1);

        values[0] = 0;
        targets[0] = address(governor);
        signatures[0] = "_activateDelegation()";
        calldatas[0] = "";

        /* ------PRIMARY-STAKEHOLDER------- */
        vm.startPrank(STAKEHOLDER_PRIMARY);
        governorToken.approve(address(governor), STAKEHOLDER_MAJOR);
        governor.lock(STAKEHOLDER_MAJOR);
        governor.propose(0, targets, values, signatures, calldatas, "");

        // Factor for voting delay
        vm.warp(block.timestamp + DEFAULT_VOTING_DELAY + 1);

        governor.castVote(2, 1, "");

        // Let proposal finalise
        vm.warp(block.timestamp + DEFAULT_VOTING_PERIOD);

        governor.queue(2);
        vm.stopPrank();
        /* -------------------------------- */

        // Let proposal finalise
        vm.warp(block.timestamp + DEFAULT_TIMELOCK_DELAY + 1 hours);

        /* ------TERNARY-STAKEHOLDER------- */
        vm.startPrank(STAKEHOLDER_TERNARY);
        governorToken.approve(address(governor), STAKEHOLDER_MINOR);
        governor.lock(STAKEHOLDER_MINOR);

        governor.veto(2);
        governor.castVetoVote(2, 1, "");
        vm.stopPrank();
        /* -------------------------------- */

        /* ------PRIMARY-STAKEHOLDER------- */
        vm.startPrank(STAKEHOLDER_SECONDARY);
        governorToken.approve(address(governor), STAKEHOLDER_MAJOR);
        governor.lock(STAKEHOLDER_MAJOR);
        governor.castVetoVote(2, 1, "");
        vm.stopPrank();
        /* -------------------------------- */
        
        GovernorStorageV3.ProposalStatus priorStatus = governor.status(2); 
        require(priorStatus == GovernorStorageV3.ProposalStatus.Contested);

        governor.resolve(2);

        GovernorStorageV1.ProposalState endState = governor.state(2);
        GovernorStorageV3.ProposalStatus endStatus = governor.status(2);
        require(endStatus == GovernorStorageV3.ProposalStatus.Resolved);
        require(endState == GovernorStorageV1.ProposalState.Canceled);
    }

    function testCancelledProposal() public {
        address[] memory targets = new address[](1);
        string[] memory signatures = new string[](1);
        bytes[] memory calldatas = new bytes[](1);
        uint[] memory values = new uint[](1);

        values[0] = 0;
        targets[0] = address(governor);
        signatures[0] = "_activateDelegation()";
        calldatas[0] = "";

        /* ------PRIMARY-STAKEHOLDER------- */
        vm.startPrank(STAKEHOLDER_PRIMARY);
        governorToken.approve(address(governor), STAKEHOLDER_MAJOR);
        governor.lock(STAKEHOLDER_MAJOR);
        governor.propose(0, targets, values, signatures, calldatas, "");

        // Factor for voting delay
        vm.warp(block.timestamp + DEFAULT_VOTING_DELAY + 1);

        governor.cancel(2);
        
        GovernorStorageV1.ProposalState endState = governor.state(2);
        GovernorStorageV3.ProposalStatus endStatus = governor.status(2);
        require(endStatus == GovernorStorageV3.ProposalStatus.Resolved);
        require(endState == GovernorStorageV1.ProposalState.Canceled);
    }

    function testVoteBySig() public {}

    function testVetoVoteBySig() public {}

    function testProxyVote() public {}

    function testStaleWeightVote() public {}

    function testDelegationActivation() public {}

    function testProposalConfig() public {}

    function testSetVetoQuota() public {}

    function testSetVetoQuorum() public {}

}
