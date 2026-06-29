pragma solidity ^0.8.13;

import { GovernorAdmin } from "./mock/GovernorAdmin.sol";
import { GovernorBaseTest } from "./GovernorBase.t.sol";

contract CanonicalGovernorTest is GovernorBaseTest {

    address public constant STAKEHOLDER_ALPHA = 0x8A1c5E88Ca465be1D01e4B437CE4E082fD14E25e;
    address public constant STAKEHOLDER_BETA  = 0xE0D268481983B218e83DEe30da1c9f36B56Ffa0a;
    address public constant STAKEHOLDER_THETA = 0x3011426bB63e7BE9b6b8AdF572874009569710b8;

    address public constant DELEGATOR_PRIMARY     = 0x8A1c5E88Ca465be1D01e4B437CE4E082fD14E25e;
    address public constant DELEGATOR_SECONDARY   = 0xE0D268481983B218e83DEe30da1c9f36B56Ffa0a;
    address public constant DELEGATEE_PRIMARY     = 0x3011426bB63e7BE9b6b8AdF572874009569710b8;
    address public constant DELEGATEE_SECONDARY   = 0xCbFD1745E492F6a555dF7A9B1E0B3Cd139e69504;


    function setUp() public override {
        super.setUp(); 
    }

    function deployGovernor() internal override returns (GovernorAdmin) {
        return new GovernorAdmin();
    }

}
