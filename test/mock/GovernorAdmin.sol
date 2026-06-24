pragma solidity ^0.8.13;

import { GovernorDelta } from "@root/GovernorDelta.sol";

contract GovernorAdmin is GovernorDelta {

    constructor() {
        admin = msg.sender;
    }

    function acceptAdmin() external {
        address oldAdmin = admin;
        address oldPendingAdmin = pendingAdmin;
        admin = pendingAdmin;
        pendingAdmin = address(0);

        emit NewAdmin(oldAdmin, admin);
        emit NewPendingAdmin(oldPendingAdmin, pendingAdmin);
    }

}
