pragma solidity ^0.8.13;

import { GovernorAdmin } from "./mock/GovernorAdmin.sol";
import { BaseGovernorTest } from "./BaseGovernor.t.sol";

contract CanonicalGovernorTest is BaseGovernorTest {

    address public constant DELEGATOR_PRIMARY = 0x8A1c5E88Ca465be1D01e4B437CE4E082fD14E25e;
    address public constant DELEGATOR_SECONDARY = 0xE0D268481983B218e83DEe30da1c9f36B56Ffa0a;
    address public constant DELEGATEE_PRIMARY = 0x557a4fC606ae646F585BC73aD2a4fc745a8CBcc8;
    address public constant DELEGATEE_SECONDARY = 0xCbFD1745E492F6a555dF7A9B1E0B3Cd139e69504;
    address public constant RELAYER = 0x1D63a0F23A0B41bc4Cee4DB6E58Fc67A4a5b3d19;

    function setUp() public override {
        super.setUp(); 
      
        governorToken.mint(DELEGATOR_PRIMARY, STAKEHOLDER_MINOR);
        governorToken.mint(DELEGATOR_SECONDARY, STAKEHOLDER_MINOR);
        governorToken.mint(DELEGATEE_PRIMARY, STAKEHOLDER_MINOR);
        governorToken.mint(DELEGATEE_SECONDARY, STAKEHOLDER_MINOR);

        /* --------TIMELOCK-------- */
        vm.startPrank(address(timelock));
        governor._activateDelegation();
        vm.stopPrank();
        /* -------------------------------- */    
        
        setUpScenario();
    }

    function deployGovernor() internal override returns (GovernorAdmin) {
        return new GovernorAdmin();
    }

    function testDelegate() public {
        /* ------PRIMARY-DELEGATOR------- */
        vm.startPrank(DELEGATOR_PRIMARY);
        // Cant delegate past the max threshold
        vm.expectRevert();
        governor.delegate(DELEGATEE_PRIMARY, block.timestamp + 366 days);
        //////////////////////////////////////
        governor.delegate(DELEGATEE_PRIMARY, block.timestamp + 7 days);
        vm.stopPrank();
        /* -------------------------------- */ 

        /* ------PRIMARY-DELEGATEE------- */
        vm.startPrank(DELEGATEE_PRIMARY);
        uint proposalId = pushMockProposal();

        vm.warp(block.timestamp + DEFAULT_VOTING_DELAY + 1);

        governor.castVote(proposalId, 1, "");
        governor.castVirtualVote(proposalId, 1, DELEGATOR_PRIMARY);
        vm.stopPrank();
        /* -------------------------------- */

        /* ------PRIMARY-DELEGATOR------- */
        vm.startPrank(DELEGATOR_PRIMARY);
        // Delegator cant withdraw with active vote 
        vm.expectRevert();
        governor.unlock(STAKEHOLDER_MINOR);
        //////////////////////////////////////
        vm.stopPrank();
        /* -------------------------------- */ 

        vm.warp(block.timestamp + DEFAULT_VOTING_PERIOD);

        (, uint forVotes,)= governor.getTally(proposalId);
        require(forVotes == STAKEHOLDER_MINOR * 2);

        /* ------PRIMARY-DELEGATOR------- */
        vm.startPrank(DELEGATOR_PRIMARY);
        // Delegator can now withdraw 
        governor.unlock(STAKEHOLDER_MINOR);
        vm.stopPrank();
        /* -------------------------------- */ 

        vm.warp(block.timestamp + 1 hours);

        /* ------PRIMARY-DELEGATEE------- */
        vm.startPrank(DELEGATEE_PRIMARY);
        pushMockProposal();

        vm.warp(block.timestamp + DEFAULT_VOTING_DELAY + 1);

        governor.castVote(proposalId + 1, 1, "");
        // Delegatee cant spend delegation that is no longer active
        vm.expectRevert();
        governor.castVirtualVote(proposalId + 1, 1, DELEGATOR_PRIMARY);
        //////////////////////////////////////
        vm.stopPrank();
        /* -------------------------------- */

        (, uint finalVotes,)= governor.getTally(proposalId + 1);
        require(finalVotes == STAKEHOLDER_MINOR);
    }

    function testRedelegate() public {
        /* ------PRIMARY-DELEGATOR------- */
        vm.startPrank(DELEGATOR_PRIMARY);
        governor.delegate(DELEGATEE_PRIMARY, block.timestamp + 1 days);
        vm.stopPrank();
        /* -------------------------------- */ 

        /* ------SECONDARY-DELEGATOR------- */
        vm.startPrank(DELEGATOR_SECONDARY);
        governor.delegate(DELEGATEE_SECONDARY, block.timestamp + 7 days);
        vm.stopPrank();
        /* -------------------------------- */ 

        /* ------PRIMARY-DELEGATEE------- */
        vm.startPrank(DELEGATEE_PRIMARY);
        uint proposalId = pushMockProposal();

        vm.warp(block.timestamp + DEFAULT_VOTING_DELAY + 1);

        governor.castVote(proposalId, 1, "");
        // Cant use expired delegation 
        vm.expectRevert();
        governor.castVirtualVote(proposalId, 1, DELEGATOR_PRIMARY);
        /* -------------------------------- */ 

        /* ------PRIMARY-DELEGATOR------- */
        vm.startPrank(DELEGATOR_PRIMARY);
        // Delegator can redelegate because of expiry
        governor.delegate(DELEGATEE_SECONDARY, block.timestamp + 1 days);
        vm.stopPrank();
        /* -------------------------------- */ 

        /* ------PRIMARY-DELEGATEE------- */
        vm.startPrank(DELEGATEE_PRIMARY);
        // Cant use expired delegation 
        vm.expectRevert();
        governor.castVirtualVote(proposalId, 1, DELEGATOR_PRIMARY);
        /* -------------------------------- */

        /* ------SEOCNDARY-DELEGATEE------- */
        vm.startPrank(DELEGATEE_SECONDARY);
        governor.castVote(proposalId, 1, "");
        governor.castVirtualVote(proposalId, 1, DELEGATOR_PRIMARY);
        governor.castVirtualVote(proposalId, 1, DELEGATOR_SECONDARY);
        /* -------------------------------- */ 

        vm.warp(block.timestamp + DEFAULT_VOTING_PERIOD);

        (, uint finalVotes,)= governor.getTally(proposalId);
        require(finalVotes == STAKEHOLDER_MINOR * 4); 
    }

    function testRevoke() public {
        /* ------PRIMARY-DELEGATOR------- */
        vm.startPrank(DELEGATOR_PRIMARY);
        governor.delegate(DELEGATEE_PRIMARY, block.timestamp + 7 days);
        vm.stopPrank();
        /* -------------------------------- */ 

        /* ------PRIMARY-DELEGATEE------- */
        vm.startPrank(DELEGATEE_PRIMARY);
        uint proposalId = pushMockProposal();

        vm.warp(block.timestamp + DEFAULT_VOTING_DELAY + 1);

        governor.castVote(proposalId, 1, "");
        governor.castVirtualVote(proposalId, 1, DELEGATOR_PRIMARY);
        vm.stopPrank();
        /* -------------------------------- */

        /* ------PRIMARY-DELEGATOR------- */
        vm.startPrank(DELEGATOR_PRIMARY);
        // Delegator cant revoke with active vote 
        vm.expectRevert();
        governor.revoke();
        //////////////////////////////////////
        vm.stopPrank();
        /* -------------------------------- */ 

        vm.warp(block.timestamp + DEFAULT_VOTING_PERIOD);

        /* ------PRIMARY-DELEGATOR------- */
        vm.startPrank(DELEGATOR_PRIMARY);
        // Delegator can now revoke 
        governor.revoke();
        vm.stopPrank();
        /* -------------------------------- */     
    }

    function testDelegateBySig() public {
        uint256 delegatorPk = 0xD31163A73;
        address delegator = vm.addr(delegatorPk);
        uint delegationExpiry = block.timestamp + 7 days;
        uint sigExpiry = block.timestamp + 1 days;
        uint expiredSigExpiry = block.timestamp - 1;

        /* ------DELEGATOR------- */
        vm.startPrank(delegator);
        governorToken.mint(delegator, STAKEHOLDER_MINOR);
        approveAndLock(STAKEHOLDER_MINOR);
        vm.stopPrank();
        /* -------------------------------- */

        // Attempt invalid signature
        vm.expectRevert();
        governor.delegateBySig(DELEGATEE_PRIMARY, delegationExpiry, 0, sigExpiry, 0, bytes32(0), bytes32(0));

        // Attempt expired signature
        bytes32 expiredDigest = delegationDigest(DELEGATEE_PRIMARY, delegationExpiry, 0, expiredSigExpiry);
        (uint8 expiredV, bytes32 expiredR, bytes32 expiredS) = vm.sign(delegatorPk, expiredDigest);
        vm.expectRevert();
        governor.delegateBySig(DELEGATEE_PRIMARY, delegationExpiry, 0, expiredSigExpiry, expiredV, expiredR, expiredS);

        bytes32 digest = delegationDigest(DELEGATEE_PRIMARY, delegationExpiry, 0, sigExpiry);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(delegatorPk, digest);

        /* ------RELAYER------- */
        vm.prank(RELAYER);
        bytes memory id = governor.delegateBySig(DELEGATEE_PRIMARY, delegationExpiry, 0, sigExpiry, v, r, s);
        /* -------------------------------- */

        (address target, uint expiry) = governor.delegations(delegator);

        require(governor.checkDelegation(id));
        require(target == DELEGATEE_PRIMARY);
        require(expiry == delegationExpiry);
        require(governor.nonces(delegator) == 1);

        // Attempt signature replay
        vm.expectRevert();
        governor.delegateBySig(DELEGATEE_PRIMARY, delegationExpiry, 0, sigExpiry, v, r, s);
    }

    function testDelegateBySigInvalidNonce() public {
        uint256 delegatorPk = 0xD31163A74;
        address delegator = vm.addr(delegatorPk);
        uint delegationExpiry = block.timestamp + 7 days;
        uint sigExpiry = block.timestamp + 1 days;

        /* ------DELEGATOR------- */
        vm.startPrank(delegator);
        governorToken.mint(delegator, STAKEHOLDER_MINOR);
        approveAndLock(STAKEHOLDER_MINOR);
        vm.stopPrank();
        /* -------------------------------- */

        bytes32 digest = delegationDigest(DELEGATEE_PRIMARY, delegationExpiry, 1, sigExpiry);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(delegatorPk, digest);

        // Attempt signature with unexpected nonce
        vm.expectRevert();
        governor.delegateBySig(DELEGATEE_PRIMARY, delegationExpiry, 1, sigExpiry, v, r, s);
    }

    function testDelegateBySigAfterExpiry() public {
        uint256 delegatorPk = 0xD31163A79;
        address delegator = vm.addr(delegatorPk);
        uint initialExpiry = block.timestamp + 1 days;
        uint nextExpiry = block.timestamp + 7 days;
        uint sigExpiry = block.timestamp + 2 days;

        /* ------DELEGATOR------- */
        vm.startPrank(delegator);
        governorToken.mint(delegator, STAKEHOLDER_MINOR);
        approveAndLock(STAKEHOLDER_MINOR);
        governor.delegate(DELEGATEE_PRIMARY, initialExpiry);
        vm.stopPrank();
        /* -------------------------------- */

        vm.warp(block.timestamp + 1 days + 1);

        bytes32 digest = delegationDigest(DELEGATEE_SECONDARY, nextExpiry, 0, sigExpiry);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(delegatorPk, digest);

        governor.delegateBySig(DELEGATEE_SECONDARY, nextExpiry, 0, sigExpiry, v, r, s);

        (address target, uint expiry) = governor.delegations(delegator);
        require(target == DELEGATEE_SECONDARY);
        require(expiry == nextExpiry);
        require(governor.nonces(delegator) == 1);
    }

    function testRevokeBySigInvalidNonce() public {
        uint256 delegatorPk = 0xD31163A76;
        address delegator = vm.addr(delegatorPk);
        uint delegationExpiry = block.timestamp + 7 days;
        uint sigExpiry = block.timestamp + 1 days;

        /* ------DELEGATOR------- */
        vm.startPrank(delegator);
        governorToken.mint(delegator, STAKEHOLDER_MINOR);
        approveAndLock(STAKEHOLDER_MINOR);
        governor.delegate(DELEGATEE_PRIMARY, delegationExpiry);
        vm.stopPrank();
        /* -------------------------------- */

        bytes32 digest = revocationDigest(DELEGATEE_PRIMARY, delegationExpiry, 1, sigExpiry);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(delegatorPk, digest);

        // Attempt signature with unexpected nonce
        vm.expectRevert();
        governor.revokeBySig(DELEGATEE_PRIMARY, delegationExpiry, 1, sigExpiry, v, r, s);
    }

    function testRevokeBySigExpiredSignature() public {
        uint256 delegatorPk = 0xD31163A80;
        address delegator = vm.addr(delegatorPk);
        uint delegationExpiry = block.timestamp + 7 days;
        uint sigExpiry = block.timestamp + 1 days;

        /* ------DELEGATOR------- */
        vm.startPrank(delegator);
        governorToken.mint(delegator, STAKEHOLDER_MINOR);
        approveAndLock(STAKEHOLDER_MINOR);
        governor.delegate(DELEGATEE_PRIMARY, delegationExpiry);
        vm.stopPrank();
        /* -------------------------------- */

        bytes32 digest = revocationDigest(DELEGATEE_PRIMARY, delegationExpiry, 0, sigExpiry);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(delegatorPk, digest);

        vm.warp(block.timestamp + 1 days + 1);

        // Attempt expired signature
        vm.expectRevert();
        governor.revokeBySig(DELEGATEE_PRIMARY, delegationExpiry, 0, sigExpiry, v, r, s);
    }

    function testRevokeBySig() public {
        uint256 delegatorPk = 0xD31163A81;
        address delegator = vm.addr(delegatorPk);
        uint delegationExpiry = block.timestamp + 7 days;
        uint sigExpiry = block.timestamp + 7 days;

        /* ------DELEGATOR------- */
        vm.startPrank(delegator);
        governorToken.mint(delegator, STAKEHOLDER_MINOR);
        approveAndLock(STAKEHOLDER_MINOR);
        governor.delegate(DELEGATEE_PRIMARY, delegationExpiry);
        vm.stopPrank();
        /* -------------------------------- */

        bytes32 digest = revocationDigest(DELEGATEE_PRIMARY, delegationExpiry, 0, sigExpiry);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(delegatorPk, digest);

        /* ------RELAYER------- */
        vm.prank(RELAYER);
        governor.revokeBySig(DELEGATEE_PRIMARY, delegationExpiry, 0, sigExpiry, v, r, s);
        /* -------------------------------- */

        // Attempt signature replay
        vm.expectRevert();
        governor.revokeBySig(DELEGATEE_PRIMARY, delegationExpiry, 0, sigExpiry, v, r, s);

        require(governor.nonces(delegator) == 1);
        (address target, uint expiry) = governor.delegations(delegator);
        require(target == address(0));
        require(expiry == 0);
    }

    function testRevokeBySigRespectsCanonicalLock() public {
        uint256 delegatorPk = 0xD31163A77;
        address delegator = vm.addr(delegatorPk);
        uint delegationExpiry = block.timestamp + 7 days;
        uint sigExpiry = block.timestamp + 7 days;

        /* ------DELEGATOR------- */
        vm.startPrank(delegator);
        governorToken.mint(delegator, STAKEHOLDER_MINOR);
        approveAndLock(STAKEHOLDER_MINOR);
        governor.delegate(DELEGATEE_PRIMARY, delegationExpiry);
        vm.stopPrank();
        /* -------------------------------- */

        /* ------DELEGATEE------- */
        vm.startPrank(DELEGATEE_PRIMARY);
        uint proposalId = pushMockProposal();

        vm.warp(block.timestamp + DEFAULT_VOTING_DELAY + 1);

        governor.castVote(proposalId, 1, "");
        governor.castVirtualVote(proposalId, 1, delegator);
        vm.stopPrank();
        /* -------------------------------- */

        bytes32 digest = revocationDigest(DELEGATEE_PRIMARY, delegationExpiry, 0, sigExpiry);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(delegatorPk, digest);

        // Attempt revocation after delegated power has been used
        vm.expectRevert();
        governor.revokeBySig(DELEGATEE_PRIMARY, delegationExpiry, 0, sigExpiry, v, r, s);
    }

    function testProxyVote() public {
        /* ------PRIMARY-DELEGATOR------- */
        vm.startPrank(DELEGATOR_PRIMARY);
        uint primaryTs = block.timestamp + 1 days;
        governor.delegate(DELEGATEE_PRIMARY, primaryTs);
        vm.stopPrank();
        /* -------------------------------- */ 

        /* ------SECONDARY-DELEGATOR------- */
        vm.startPrank(DELEGATOR_SECONDARY);
        uint secondaryTs = block.timestamp + 7 days;
        governor.delegate(DELEGATEE_SECONDARY, secondaryTs);
        vm.stopPrank();
        /* -------------------------------- */ 

        /* ------PRIMARY-DELEGATEE------- */
        vm.startPrank(DELEGATEE_PRIMARY);
        uint proposalId = pushMockProposal();

        vm.warp(block.timestamp + DEFAULT_VOTING_DELAY + 1);

        governor.castVote(proposalId, 1, "");
        vm.stopPrank();
        /* -------------------------------- */

        /* ------SECONDARY-DELEGATEE------- */
        vm.startPrank(DELEGATEE_SECONDARY);
        governor.castVote(proposalId, 1, "");
        vm.stopPrank();
        /* -------------------------------- */

        bytes[] memory votes = new bytes[](1);
        votes[0] = abi.encode(DELEGATOR_PRIMARY, DELEGATEE_PRIMARY, primaryTs);

        // Fast forward to expire primary delegation
        vm.warp(block.timestamp + 1 days);

        // Vote cast should fail with expired delegation 
        vm.expectRevert();
        governor.batchProxyVotes(proposalId, votes);
        /////////////////////////////////////
        votes[0] = abi.encode(DELEGATOR_SECONDARY, DELEGATEE_SECONDARY, secondaryTs);
        governor.batchProxyVotes(proposalId, votes);

        vm.warp(block.timestamp + DEFAULT_VOTING_PERIOD);

        (, uint finalVotes,)= governor.getTally(proposalId);
        require(finalVotes == STAKEHOLDER_MINOR * 3); 
    }

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
