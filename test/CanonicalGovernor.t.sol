pragma solidity ^0.8.13;

import { GovernorAdmin } from "./mock/GovernorAdmin.sol";
import { GovernorBaseTest } from "./mock/GovernorBase.t.sol";

contract CanonicalGovernorTest is GovernorBaseTest {

    function setUp() public override {
        super.setUp(); 
    }

    function deployGovernor() internal override returns (GovernorAdmin) {
        return new GovernorAdmin();
    }

}
