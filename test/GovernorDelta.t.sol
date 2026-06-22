// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import { Test, console } from "forge-std/Test.sol";
import { GovernorDelta } from "@root/GovernorDelta.sol";
import { IERC20 } from "@openzeppelin/token/ERC20/IERC20.sol";

contract GovernorDeltaTest is Test {

    IERC20 governorToken;
    GovernorDelta delta;

    function setUp() public {}

}
