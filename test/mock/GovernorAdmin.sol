pragma solidity ^0.8.13;

import { IGovernorAlpha } from "@interfaces/IGovernorAlpha.sol";
import { GovernorDelta } from "@root/GovernorDelta.sol";

import { RelaxedTimelock } from "./RelaxedTimelock.sol";

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

    function initiate(address governor) external {
        require(msg.sender == admin, "GovernorDelta::_initiate: admin only");
        require(initialProposalId == 0, "GovernorDelta::_initiate: can only initiate once");
        proposalCount = 1;
        initialProposalId = 1;
        RelaxedTimelock(payable(address(timelock))).revokeAdmin();
    }

}
