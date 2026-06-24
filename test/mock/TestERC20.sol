// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import { Test, console } from "forge-std/Test.sol";
import { GovernorDelta } from "@root/GovernorDelta.sol";
import { ERC20 } from "@openzeppelin/token/ERC20/ERC20.sol";

contract TestERC20 is ERC20 {

    constructor() ERC20("", "SHARE") {}

    function mint(address to, uint amount) public {
      _mint(to, amount);
    }

    function burn(address from, uint amount) public {
      _burn(from, amount);
    }

}
