// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import { Test, console } from "forge-std/Test.sol";
import { GovernorDelta } from "@root/GovernorDelta.sol";
import { Timelock } from "@lib/Timelock.sol";

import { TestERC20 } from "./mock/TestERC20.sol";

contract GovernorBaseTest is Test {

    Timelock timelock;
    GovernorDelta governor;
    TestERC20 treasuryToken;
    TestERC20 governorToken;
    
    uint public constant DEFAULT_VOTING_PERIOD = 3 days;
    uint public constant DEFAULT_VOTING_DELAY = 1 days; 
    uint public constant DEFAULT_TIER_0_QUORUM = 10000e18;
    uint public constant DEFAULT_TIER_0_DURATION = 7 days;
    uint public constant DEFAULT_TIER_1_QUORUM = 15000e18;
    uint public constant DEFAULT_TIER_1_DURATION = 18 days;
    uint public constant DEFAULT_TIER_2_QUORUM = 33000e18;
    uint public constant DEFAULT_TIER_2_DURATION = 38 days;
    uint public constant DEFAULT_TIER_3_QUORUM = 51000e18;
    uint public constant DEFAULT_TIER_3_DURATION = 91 days;

    function setUp() public {}

    function testLockSystem() public {}

    function testStakeTimeCoeff() public {}

    function testSetVetoQuota() public {}

    function testSetVetoQuorum() public {}

    function testChangeAdmin() public {}

    function testSetProposalConfig() public {}

    function testValidProposal() public {}

    function testDefeatedProposal public {}

    function testExpiredProposal() public {}

    function testContestedProposal() public {}

    function testVetoedProposal() public {}

    function testCancelledProposal() public {}

    function testVoteBySig() public {}

    function testVetoVoteBySig() public {}

    function testProxyVote() public {}

    function testDelegationActivation() public {}

}
