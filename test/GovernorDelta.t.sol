// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import { Test, console } from "forge-std/Test.sol";
import { GovernorDelta } from "@root/GovernorDelta.sol";
import { TestERC20 } from "./mock/TestERC20.sol";

contract GovernorDeltaTest is Test {

    GovernorDelta delta;
    TestERC20 governorToken;

    function setUp() public {}

}
