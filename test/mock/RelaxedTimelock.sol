// SPDX-License-Identifier: BSD-3-Clause
pragma solidity ^0.8.10;

import { Timelock } from "@lib/Timelock.sol";

contract RelaxedTimelock is Timelock {

    constructor(address admin, uint delay) Timelock(admin, delay) {}

    function revokeAdmin(address governor) public {
        admin = governor;

        emit NewAdmin(admin);
    } 

}
