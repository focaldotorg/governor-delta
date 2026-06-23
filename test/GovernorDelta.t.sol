// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import { Test, console } from "forge-std/Test.sol";
import { GovernorDelta } from "@root/GovernorDelta.sol";
import { Timelock } from "@lib/Timelock.sol";

import { TestERC20 } from "./mock/TestERC20.sol";

contract GovernorDeltaTest is Test {

    GovernorDelta governor;
    TestERC20 governorToken;
    Timelock governorTimelock;

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

}
