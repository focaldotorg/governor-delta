// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import { Test, console } from "forge-std/Test.sol";
import { GovernorDelta } from "@root/GovernorDelta.sol";
import { ERC20 } from "@openzeppelin/token/ERC20/ERC20.sol";

contract GovernorDeltaTest is Test {

    ERC20 governorToken;
    GovernorDelta delta;

    function setUp() public {
      governorToken = new ERC20("", "SHARE", 18);
      delta = new GovernorDelta();
    }

}
