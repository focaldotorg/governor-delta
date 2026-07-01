pragma solidity ^0.8.13;

import { ITimeWeightedVotingStrategy } from "@interfaces/ITimeWeightedVotingStrategy.sol";
import { TenureVotingStrategy } from "@strategies/TenureVotingStrategy.sol";
import { GovernorAdmin } from "./mock/GovernorAdmin.sol";
import { BaseGovernorTest } from "./BaseGovernor.t.sol";

contract VirtualGovernorTest is BaseGovernorTest {

    TenureVotingStrategy strategy;

    address public constant DELEGATOR_PRIMARY = 0x8A1c5E88Ca465be1D01e4B437CE4E082fD14E25e;
    address public constant DELEGATOR_SECONDARY = 0xE0D268481983B218e83DEe30da1c9f36B56Ffa0a;
    address public constant DELEGATEE_PRIMARY = 0x557a4fC606ae646F585BC73aD2a4fc745a8CBcc8;
    address public constant DELEGATEE_SECONDARY = 0xCbFD1745E492F6a555dF7A9B1E0B3Cd139e69504;

    function setUp() public override {
        super.setUp(); 
      
        governorToken.mint(DELEGATOR_PRIMARY, STAKEHOLDER_MINOR);
        governorToken.mint(DELEGATOR_SECONDARY, STAKEHOLDER_MINOR);
        governorToken.mint(DELEGATEE_PRIMARY, STAKEHOLDER_MINOR);
        governorToken.mint(DELEGATEE_SECONDARY, STAKEHOLDER_MINOR);

        ITimeWeightedVotingStrategy.Tranche[] memory tranches = new ITimeWeightedVotingStrategy.Tranche[](5);

        tranches[0] = ITimeWeightedVotingStrategy.Tranche(30 days, 10e6);
        tranches[1] = ITimeWeightedVotingStrategy.Tranche(60 days, 12e6);
        tranches[2] = ITimeWeightedVotingStrategy.Tranche(90 days, 15e6);
        tranches[3] = ITimeWeightedVotingStrategy.Tranche(180 days, 17e6);
        tranches[4] = ITimeWeightedVotingStrategy.Tranche(365 days, 20e6);

        strategy = new TenureVotingStrategy(address(governor), tranches);

        /* --------TIMELOCK-------- */
        vm.startPrank(address(timelock));
        governor._setVotingModule(address(strategy));
        governor._activateDelegation();
        vm.stopPrank();
        /* -------------------------------- */

        setUpScenario();
    }

    function deployGovernor() internal override returns (GovernorAdmin) {
        return new GovernorAdmin();
    }

    function testDelegate() public {}

    function testRedelegate() public {}

    function testRevoke() public {}

    function testProxyVote() public {}

    function setUpScenario() internal {
        /* ------PRIMARY-DELEGATOR------- */
        vm.startPrank(DELEGATOR_PRIMARY);
        approveAndLock(STAKEHOLDER_MINOR);
        vm.stopPrank();
        /* -------------------------------- */

        /* ------SECONDARY-DELEGATOR------- */
        vm.startPrank(DELEGATOR_SECONDARY);
        approveAndLock(STAKEHOLDER_MINOR);
        vm.stopPrank();
        /* -------------------------------- */ 

        /* ------PRIMARY-DELEGATEE------- */
        vm.startPrank(DELEGATEE_PRIMARY);
        approveAndLock(STAKEHOLDER_MINOR);
        vm.stopPrank();
        /* -------------------------------- */

        /* ------SECONDARY-DELEGATEE------- */
        vm.startPrank(DELEGATEE_SECONDARY);
        approveAndLock(STAKEHOLDER_MINOR);
        vm.stopPrank();
        /* -------------------------------- */ 
    }

}
