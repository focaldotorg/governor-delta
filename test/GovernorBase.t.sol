// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import { Test, console } from "forge-std/Test.sol";
import { Timelock } from "@lib/Timelock.sol";

import { GovernorAdmin } from "./mock/GovernorAdmin.sol";
import { TestERC20 } from "./mock/TestERC20.sol";

contract GovernorBaseTest is Test {

    Timelock timelock;
    GovernorAdmin governor;
    TestERC20 treasuryToken;
    TestERC20 governorToken;
  
    uint public constant STAKEHOLDER_MINOR = 100 ether;
    uint public constant STAKEHOLDER_LARGER = 1500 ether;
    uint public constant TREASURY_RESERVE = 20000 ether;
    uint public constant DEFAULT_PROPOSAL_QUOTA = 100 ether;
    uint public constant DEFAULT_VOTING_PERIOD = 3 days;
    uint public constant DEFAULT_VOTING_DELAY = 2 days;
    uint public constant DEFAULT_TIMELOCK_DELAY = 2 days;
    uint public constant DEFAULT_TIER_0_QUORUM = 10000e18;
    uint public constant DEFAULT_TIER_0_DURATION = 7 days;
    uint public constant DEFAULT_TIER_1_QUORUM = 15000e18;
    uint public constant DEFAULT_TIER_1_DURATION = 18 days;
    uint public constant DEFAULT_TIER_2_QUORUM = 33000e18;
    uint public constant DEFAULT_TIER_2_DURATION = 38 days;
    uint public constant DEFAULT_TIER_3_QUORUM = 51000e18;
    uint public constant DEFAULT_TIER_3_DURATION = 91 days;

    function setUp() public {
        treasuryToken = new TestERC20();
        governorToken = new TestERC20();
        governor = new GovernorAdmin();
        timelock = new Timelock(msg.sender, DEFAULT_TIMELOCK_DELAY);

        governorToken.mint(msg.sender, STAKEHOLDER_LARGER);
        treasuryToken.mint(address(timelock), TREASURY_RESERVE);
    }

    function testChangeAdmin() public {
        address beforeAdmin = governor.admin();

        require(msg.sender == beforeAdmin);

        governor.initialize(address(timelock), address(governorToken), DEFAULT_VOTING_PERIOD, DEFAULT_VOTING_DELAY, DEFAULT_PROPOSAL_QUOTA);
        governor._setPendingAdmin(address(governor));
        governor.acceptAdmin();

        address afterAdmin = governor.admin();

        require(beforeAdmin != afterAdmin);
        require(address(governor) == afterAdmin);
    }

    function testLockSystem() public {}

    function testStakeTimeCoeff() public {}

    function testSetVetoQuota() public {}

    function testSetVetoQuorum() public {}

    function testProposalConfig() public {}

    function testValidProposal() public {}

    function testDefeatedProposal() public {}

    function testExpiredProposal() public {}

    function testContestedProposal() public {}

    function testVetoedProposal() public {}

    function testCancelledProposal() public {}

    function testVoteBySig() public {}

    function testVetoVoteBySig() public {}

    function testProxyVote() public {}

    function testStaleWeightVote() public {}

    function testDelegationActivation() public {}

}
