// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import { Test, console } from "forge-std/Test.sol";

import { GovernorStorageV3, GovernorStorageV1 } from "@root/GovernorStorageV3.sol";

import { GovernorAdmin } from "./mock/GovernorAdmin.sol";
import { TestERC20 } from "./mock/TestERC20.sol";
import { RelaxedTimelock } from "./mock/RelaxedTimelock.sol";

contract BaseGovernorTest is Test {

    RelaxedTimelock timelock;
    GovernorAdmin governor;
    TestERC20 treasuryToken;
    TestERC20 governorToken;
  
    uint public constant STAKEHOLDER_MAJOR = 15000 ether;
    uint public constant STAKEHOLDER_MINOR = 5000 ether;
    uint public constant TREASURY_RESERVE = 20000 ether;
    uint public constant DEFAULT_PROPOSAL_QUOTA = 1000 ether;
    uint public constant DEFAULT_VOTING_PERIOD = 3 days;
    uint public constant DEFAULT_VOTING_DELAY = 2 days;
    uint public constant DEFAULT_TIMELOCK_DELAY = 1 days;
    uint public constant DEFAULT_VETO_PERIOD = 3 days;

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

    function setUp() public virtual {
        treasuryToken = new TestERC20();
        governorToken = new TestERC20();
        governor = deployGovernor();
        timelock = new RelaxedTimelock(msg.sender, DEFAULT_TIMELOCK_DELAY);

        // @notice Why is ether balances funded from governor, not timelock? 
        vm.deal(address(governor), 1 ether);
        // Distribute assets
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

    function deployGovernor() internal virtual returns (GovernorAdmin) {
        return new GovernorAdmin();
    }

    function testLockSystem() public {
        uint beforeTs = block.timestamp;
        uint balanceBefore = governorToken.balanceOf(STAKEHOLDER_PRIMARY);
        (uint stakeBefore,,) = governor.stake(STAKEHOLDER_PRIMARY);
        require(balanceBefore == STAKEHOLDER_MAJOR);
        require(stakeBefore == 0);

        /* ------PRIMARY-STAKEHOLDER------- */
        vm.startPrank(STAKEHOLDER_PRIMARY);
        approveAndLock(STAKEHOLDER_MAJOR);
        vm.stopPrank();
        /* -------------------------------- */

        // Fast forward 6 hours
        vm.warp(beforeTs + 6 hours);

        uint balanceAfter = governorToken.balanceOf(STAKEHOLDER_PRIMARY);
        (uint stakeAfter, uint deltaTime,) = governor.stake(STAKEHOLDER_PRIMARY);

        require(balanceAfter == 0);
        require(stakeAfter == STAKEHOLDER_MAJOR);
        require(deltaTime == 0);

        /* ------PRIMARY-STAKEHOLDER------- */
        vm.startPrank(STAKEHOLDER_PRIMARY);
        governor.unlock(500e18);
        vm.stopPrank();
        /* -------------------------------- */

        uint balanceLast = governorToken.balanceOf(STAKEHOLDER_PRIMARY);
        (uint stakeLast, uint deltaTimeLast,) = governor.stake(STAKEHOLDER_PRIMARY);

        require(balanceLast == 500e18);
        require(stakeLast == 14500e18);
        require(deltaTimeLast == (block.timestamp - beforeTs) * 14500e18);
    }

    function testInvalidProposal() public {
        /* ------TERNARY-STAKEHOLDER------- */
        vm.startPrank(STAKEHOLDER_TERNARY);
        approveAndLock(STAKEHOLDER_MINOR);
        uint proposalId = pushMockProposal();

        // Factor for voting delay
        vm.warp(block.timestamp + DEFAULT_VOTING_DELAY + 1);

        governor.castVote(proposalId, 1, "");

        GovernorStorageV3.ProposalStatus endStatus = governor.status(proposalId);
        require(endStatus == GovernorStorageV3.ProposalStatus.Unqualified);
        vm.stopPrank();
        /* -------------------------------- */
    }

    function testDefeatedProposal() public {
        /* ------TERNARY-STAKEHOLDER------- */
        vm.startPrank(STAKEHOLDER_TERNARY);
        approveAndLock(STAKEHOLDER_MINOR);
        uint proposalId = pushMockProposal();

        vm.warp(block.timestamp + DEFAULT_VOTING_DELAY + 1);

        governor.castVote(proposalId, 1, "");
        vm.stopPrank();
        /* -------------------------------- */

        /* ------SECONDARY-STAKEHOLDER------- */
        vm.startPrank(STAKEHOLDER_SECONDARY);
        approveAndLock(STAKEHOLDER_MAJOR);
        governor.castVote(proposalId, 0, "");
        vm.stopPrank();
        /* -------------------------------- */

       /* ------PRIMARY-STAKEHOLDER------- */
        vm.startPrank(STAKEHOLDER_PRIMARY);
        approveAndLock(STAKEHOLDER_MAJOR);
        governor.castVote(proposalId, 0, "");
        vm.stopPrank();
        /* -------------------------------- */

        vm.warp(block.timestamp + DEFAULT_VOTING_PERIOD + 1);
        
        // Proposal shouldnt queue when Defeated
        vm.expectRevert();
        governor.queue(proposalId);
        //////////////////////////////////////
        GovernorStorageV1.ProposalState endState = governor.state(proposalId); 
        GovernorStorageV3.ProposalStatus endStatus = governor.status(proposalId);
        require(endState == GovernorStorageV1.ProposalState.Defeated);
        require(endStatus == GovernorStorageV3.ProposalStatus.Resolved);
    }

    function testValidProposal() public {
        /* ------PRIMARY-STAKEHOLDER------- */
        vm.startPrank(STAKEHOLDER_PRIMARY);
        approveAndLock(STAKEHOLDER_MAJOR);
        uint proposalId = pushMockProposal();

        vm.warp(block.timestamp + DEFAULT_VOTING_DELAY + 1);

        governor.castVote(proposalId, 1, "");

        vm.warp(block.timestamp + DEFAULT_VOTING_PERIOD);

        governor.queue(proposalId);

        vm.warp(block.timestamp + DEFAULT_TIMELOCK_DELAY + DEFAULT_VETO_PERIOD + 1);

        governor.execute(proposalId);
        vm.stopPrank();
        /* -------------------------------- */
    }

    function testExpiredProposal() public {
        /* ------PRIMARY-STAKEHOLDER------- */
        vm.startPrank(STAKEHOLDER_PRIMARY);
        approveAndLock(STAKEHOLDER_MAJOR);
        uint proposalId = pushMockProposal();

        vm.warp(block.timestamp + DEFAULT_VOTING_DELAY + 1);

        governor.castVote(proposalId, 1, "");

        vm.warp(block.timestamp + DEFAULT_VOTING_PERIOD);

        governor.queue(proposalId);

        vm.warp(block.timestamp + DEFAULT_TIMELOCK_DELAY + timelock.GRACE_PERIOD() + 1);

        // Proposal shouldnt execute on expiration
        vm.expectRevert();
        governor.execute(proposalId);
        //////////////////////////////////////

        GovernorStorageV1.ProposalState endState = governor.state(proposalId); 
        require(endState == GovernorStorageV1.ProposalState.Expired);
        vm.stopPrank();
    }

    function testContestedProposal() public {
        /* ------PRIMARY-STAKEHOLDER------- */
        vm.startPrank(STAKEHOLDER_PRIMARY);
        approveAndLock(STAKEHOLDER_MAJOR);
        uint proposalId = pushMockProposal();

        vm.warp(block.timestamp + DEFAULT_VOTING_DELAY + 1);

        governor.castVote(proposalId, 1, "");

        vm.warp(block.timestamp + DEFAULT_VOTING_PERIOD);

        governor.queue(proposalId);
        vm.stopPrank();
        /* -------------------------------- */

        vm.warp(block.timestamp + DEFAULT_TIMELOCK_DELAY + 1);

        /* ------SECONDARY-STAKEHOLDER------- */
        vm.startPrank(STAKEHOLDER_SECONDARY);
        approveAndLock(STAKEHOLDER_MAJOR);
        governor.veto(proposalId);
        governor.castVetoVote(proposalId, 0, "");
        vm.stopPrank();
        /* -------------------------------- */

        GovernorStorageV3.ProposalStatus priorStatus = governor.status(proposalId); 
        require(priorStatus == GovernorStorageV3.ProposalStatus.Contested);

        /* ------TERNARY-STAKEHOLDER------- */
        vm.startPrank(STAKEHOLDER_TERNARY);
        approveAndLock(STAKEHOLDER_MINOR);
        governor.castVetoVote(proposalId, 1, "");
        vm.stopPrank();
        /* -------------------------------- */

        /* ------PRIMARY-STAKEHOLDER------- */
        vm.startPrank(STAKEHOLDER_PRIMARY);
        governor.castVetoVote(proposalId, 0, "");
        vm.stopPrank();
        /* -------------------------------- */

        vm.warp(block.timestamp + DEFAULT_TIMELOCK_DELAY + DEFAULT_VETO_PERIOD + 1);

        governor.execute(proposalId);

        GovernorStorageV1.ProposalState endState = governor.state(proposalId); 
        GovernorStorageV3.ProposalStatus endStatus = governor.status(proposalId); 
        require(endStatus == GovernorStorageV3.ProposalStatus.Resolved);
        require(endState == GovernorStorageV1.ProposalState.Executed);
    }

    function testVetoedProposal() public {
        /* ------PRIMARY-STAKEHOLDER------- */
        vm.startPrank(STAKEHOLDER_PRIMARY);
        approveAndLock(STAKEHOLDER_MAJOR);
        uint proposalId = pushMockProposal();

        vm.warp(block.timestamp + DEFAULT_VOTING_DELAY + 1);

        governor.castVote(proposalId, 1, "");

        vm.warp(block.timestamp + DEFAULT_VOTING_PERIOD);

        governor.queue(proposalId);
        vm.stopPrank();
        /* -------------------------------- */

        /* ------PRIMARY-STAKEHOLDER------- */
        vm.startPrank(STAKEHOLDER_SECONDARY);
        approveAndLock(STAKEHOLDER_MAJOR);
        governor.veto(proposalId);
        governor.castVetoVote(proposalId, 1, "");
        vm.stopPrank();
        /* -------------------------------- */

        GovernorStorageV3.ProposalStatus priorStatus = governor.status(proposalId); 
        require(priorStatus == GovernorStorageV3.ProposalStatus.Contested);

        /* ------PRIMARY-STAKEHOLDER------- */
        vm.startPrank(STAKEHOLDER_PRIMARY);
        governor.castVetoVote(proposalId, 1, "");
        vm.stopPrank();
        /* -------------------------------- */ 

        vm.warp(block.timestamp + DEFAULT_TIMELOCK_DELAY + DEFAULT_VETO_PERIOD + 1);

        GovernorStorageV3.ProposalStatus postStatus = governor.status(proposalId); 
        require(postStatus == GovernorStorageV3.ProposalStatus.Dropped);

        governor.resolve(proposalId);

        GovernorStorageV1.ProposalState endState = governor.state(proposalId);
        GovernorStorageV3.ProposalStatus endStatus = governor.status(proposalId);
        require(endStatus == GovernorStorageV3.ProposalStatus.Resolved);
        require(endState == GovernorStorageV1.ProposalState.Canceled);
    }

    function testCancelledProposal() public {
        /* ------PRIMARY-STAKEHOLDER------- */
        vm.startPrank(STAKEHOLDER_PRIMARY);
        approveAndLock(STAKEHOLDER_MAJOR);
        uint proposalId = pushMockProposal();

        vm.warp(block.timestamp + DEFAULT_VOTING_DELAY + 1);

        governor.cancel(proposalId);

        GovernorStorageV1.ProposalState endState = governor.state(proposalId);
        GovernorStorageV3.ProposalStatus endStatus = governor.status(proposalId);
        require(endStatus == GovernorStorageV3.ProposalStatus.Resolved);
        require(endState == GovernorStorageV1.ProposalState.Canceled);
    }

    function testCastVoteBySig() public {
        uint256 voterPk = 0xA11CE;
        address voter = vm.addr(voterPk);

        /* ------KEYHOLDER-STAKEHOLDER------- */
        vm.startPrank(voter);
        governorToken.mint(voter, STAKEHOLDER_MAJOR);
        approveAndLock(STAKEHOLDER_MAJOR);
        vm.stopPrank();
        /* -------------------------------- */

        /* ------PRIMARY-STAKEHOLDER------- */
        vm.startPrank(STAKEHOLDER_PRIMARY);
        approveAndLock(STAKEHOLDER_MAJOR);
        uint proposalId = pushMockProposal();

        vm.warp(block.timestamp + DEFAULT_VOTING_DELAY + 1);

        governor.castVote(proposalId, 1, "");
        /* -------------------------------- */

        // Attempt invalid signature
        vm.expectRevert();
        governor.castVoteBySig(proposalId, 1, 0, bytes32(0), bytes32(0));
        //////////////////////////////////////
        bytes32 domainHash = governor.DOMAIN_TYPEHASH();
        bytes32 domainSeparator = keccak256(abi.encode(domainHash, keccak256(bytes(governor.name())), block.chainid, address(governor)));
        bytes32 structHash = keccak256(abi.encode(governor.VOTE_TYPEHASH(), proposalId, 1));
        bytes32 digest = keccak256(abi.encodePacked("\x19\x01", domainSeparator, structHash));
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(voterPk, digest);
        governor.castVoteBySig(proposalId, 1, v, r, s);
    }

    function testVetoVoteBySig() public {
        uint256 voterPk = 0xF11AF;
        address voter = vm.addr(voterPk);

        /* ------KEYHOLDER-STAKEHOLDER------- */
        vm.startPrank(voter);
        governorToken.mint(voter, STAKEHOLDER_MAJOR);
        approveAndLock(STAKEHOLDER_MAJOR);
        vm.stopPrank();
        /* -------------------------------- */

        /* ------PRIMARY-STAKEHOLDER------- */
        vm.startPrank(STAKEHOLDER_PRIMARY);
        approveAndLock(STAKEHOLDER_MAJOR);
        uint proposalId = pushMockProposal();

        vm.warp(block.timestamp + DEFAULT_VOTING_DELAY + 1);

        governor.castVote(proposalId, 1, "");

        vm.warp(block.timestamp + DEFAULT_VOTING_PERIOD + 1);

        governor.queue(proposalId);
        governor.veto(proposalId);
        vm.stopPrank();
        /* -------------------------------- */

        // Attempt invalid signature
        vm.expectRevert();
        governor.castVetoVoteBySig(proposalId, 1, 0, bytes32(0), bytes32(0));
        //////////////////////////////////////
        bytes32 domainHash = governor.DOMAIN_TYPEHASH();
        bytes32 domainSeparator = keccak256(abi.encode(domainHash, keccak256(bytes(governor.name())), block.chainid, address(governor)));
        bytes32 structHash = keccak256(abi.encode(governor.VETO_TYPEHASH(), proposalId, 1));
        bytes32 digest = keccak256(abi.encodePacked("\x19\x01", domainSeparator, structHash));
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(voterPk, digest);
        governor.castVetoVoteBySig(proposalId, 1, v, r, s);
    }

    function testProposalConfig() public {
        GovernorStorageV3.Graduated[4] memory config;

        config[0] = GovernorStorageV3.Graduated({ quorum: STAKEHOLDER_MINOR, quota: DEFAULT_TIER_0_QUOTA, duration: DEFAULT_TIER_0_DURATION });
        config[1] = GovernorStorageV3.Graduated({ quorum: DEFAULT_TIER_1_QUORUM, quota: DEFAULT_TIER_1_QUOTA, duration: DEFAULT_TIER_1_DURATION });
        config[2] = GovernorStorageV3.Graduated({ quorum: DEFAULT_TIER_2_QUORUM, quota: DEFAULT_TIER_2_QUOTA, duration: DEFAULT_TIER_2_DURATION });
        config[3] = GovernorStorageV3.Graduated({ quorum: DEFAULT_TIER_3_QUORUM, quota: DEFAULT_TIER_3_QUOTA, duration: DEFAULT_TIER_3_DURATION });

        /* --------TIMELOCK-------- */
        vm.startPrank(address(timelock));
        governor._setProposalConfig(config);
        vm.stopPrank();
        /* -------------------------------- */

        /* ------TERNARY-STAKEHOLDER------- */
        vm.startPrank(STAKEHOLDER_TERNARY);
        approveAndLock(STAKEHOLDER_MINOR);
        uint proposalId = pushMockProposal();

        vm.warp(block.timestamp + DEFAULT_VOTING_DELAY + 1);

        governor.castVote(proposalId, 1, "");

        vm.warp(block.timestamp + DEFAULT_VOTING_PERIOD);

        // Proposal should not be ready with old duration 
        vm.expectRevert();
        governor.queue(proposalId);
        //////////////////////////////////////

        vm.warp(block.timestamp + (DEFAULT_TIER_0_DURATION - DEFAULT_VOTING_PERIOD));

        governor.queue(proposalId);
        vm.stopPrank();
        /* -------------------------------- */
    }

    function testSetVetoQuota() public {
        /* --------TIMELOCK-------- */
        vm.startPrank(address(timelock));
        governor._setVetoQuota(STAKEHOLDER_MINOR);
        vm.stopPrank();
        /* -------------------------------- */

        /* ------PRIMARY-STAKEHOLDER------- */
        vm.startPrank(STAKEHOLDER_PRIMARY);
        approveAndLock(STAKEHOLDER_MAJOR); 
        uint proposalId = pushMockProposal();

        vm.warp(block.timestamp + DEFAULT_VOTING_DELAY + 1);

        governor.castVote(proposalId, 1, "");

        vm.warp(block.timestamp + DEFAULT_VOTING_PERIOD);

        governor.queue(proposalId);
        vm.stopPrank();
        /* -------------------------------- */

        /* ------TERNARY-STAKEHOLDER------- */
        vm.startPrank(STAKEHOLDER_TERNARY);
        approveAndLock(STAKEHOLDER_MINOR);
        governor.veto(proposalId);
        governor.castVetoVote(proposalId, 1, "");
        vm.stopPrank();
        /* -------------------------------- */

        // @TODO Test final states
    }

    function testSetVetoQuorum() public {
        /* --------TIMELOCK-------- */
        vm.startPrank(address(timelock));
        governor._setVetoQuorum(STAKEHOLDER_MINOR);
        vm.stopPrank();
        /* -------------------------------- */

        /* ------PRIMARY-STAKEHOLDER------- */
        vm.startPrank(STAKEHOLDER_PRIMARY);
        approveAndLock(STAKEHOLDER_MAJOR);
        uint proposalId = pushMockProposal();

        vm.warp(block.timestamp + DEFAULT_VOTING_DELAY + 1);

        governor.castVote(proposalId, 1, "");

        vm.warp(block.timestamp + DEFAULT_VOTING_PERIOD);

        governor.queue(proposalId);
        governor.veto(proposalId);
        vm.stopPrank();
        /* -------------------------------- */

        /* ------TERNARY-STAKEHOLDER------- */
        vm.startPrank(STAKEHOLDER_TERNARY);
        approveAndLock(STAKEHOLDER_MINOR);
        governor.castVetoVote(proposalId, 1, "");
        vm.stopPrank();
        /* -------------------------------- */

        vm.warp(block.timestamp + DEFAULT_TIMELOCK_DELAY + DEFAULT_VETO_PERIOD + 1);

        governor.resolve(proposalId);

        GovernorStorageV1.ProposalState endState = governor.state(proposalId);
        require(endState == GovernorStorageV1.ProposalState.Canceled);
    }

    function testSetVetoPeriod() public {
        /* --------TIMELOCK-------- */
        vm.startPrank(address(timelock));
        governor._setVetoPeriod(DEFAULT_VETO_PERIOD + 3 days);
        vm.stopPrank();
        /* -------------------------------- */

        /* ------PRIMARY-STAKEHOLDER------- */
        vm.startPrank(STAKEHOLDER_PRIMARY);
        approveAndLock(STAKEHOLDER_MAJOR);
        uint proposalId = pushMockProposal();

        vm.warp(block.timestamp + DEFAULT_VOTING_DELAY + 1);

        governor.castVote(proposalId, 1, "");

        vm.warp(block.timestamp + DEFAULT_VOTING_PERIOD);

        governor.queue(proposalId);
        governor.veto(proposalId);
        governor.castVetoVote(proposalId, 1, "");
        vm.stopPrank();
        /* -------------------------------- */

        vm.warp(block.timestamp + DEFAULT_TIMELOCK_DELAY + DEFAULT_VETO_PERIOD + 1);

        // Proposal should not be ready with old period
        vm.expectRevert();
        governor.resolve(proposalId);
        //////////////////////////////////////

        vm.warp(block.timestamp + 3 days);

        governor.resolve(proposalId);
    }

    function approveAndLock(uint amount) internal {
        governorToken.approve(address(governor), amount);
        governor.lock(amount);
    }

    function pushMockProposal() internal returns (uint) {
        address[] memory targets = new address[](1);
        string[] memory signatures = new string[](1);
        bytes[] memory calldatas = new bytes[](1);
        uint[] memory values = new uint[](1);

        values[0] = 1 wei;
        targets[0] = address(0);
        signatures[0] = "";
        calldatas[0] = "";

        return governor.propose(0, targets, values, signatures, calldatas, "");
    }

}
