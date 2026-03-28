// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Errors} from "../../../src/libraries/Errors.sol";
import {BaseFixture} from "../../utils/BaseFixture.t.sol";

contract FamilyRegistryMarriageApprovalTest is BaseFixture {
    event MarriageApprovalGranted(uint256 indexed agentSelfId, uint256 indexed agentOtherId, address indexed approver);
    event MarriageApprovalRevoked(uint256 indexed agentSelfId, uint256 indexed agentOtherId, address indexed approver);
    event ChildApprovalGranted(uint256 indexed parentAId, uint256 indexed parentBId, address indexed approver);
    event ChildApprovalRevoked(uint256 indexed parentAId, uint256 indexed parentBId, address indexed approver);

    function test_RevertWhen_UnauthorizedCallerApprovesMarriage() public {
        vm.expectRevert(abi.encodeWithSelector(Errors.NotAgentOwnerOrApproved.selector, aliceAgentId, eve));

        vm.prank(eve);
        familyRegistry.approveMarriage(aliceAgentId, bobAgentId);
    }

    function test_ApproveMarriageEmitsEvent() public {
        vm.expectEmit(address(familyRegistry));
        emit MarriageApprovalGranted(aliceAgentId, bobAgentId, alice);

        vm.prank(alice);
        familyRegistry.approveMarriage(aliceAgentId, bobAgentId);
    }

    function test_RevertWhen_UnauthorizedCallerRevokesMarriageApproval() public {
        vm.expectRevert(abi.encodeWithSelector(Errors.NotAgentOwnerOrApproved.selector, aliceAgentId, eve));

        vm.prank(eve);
        familyRegistry.revokeMarriageApproval(aliceAgentId, bobAgentId);
    }

    function test_RevokeMarriageApprovalEmitsEvent() public {
        vm.prank(alice);
        familyRegistry.approveMarriage(aliceAgentId, bobAgentId);

        vm.expectEmit(address(familyRegistry));
        emit MarriageApprovalRevoked(aliceAgentId, bobAgentId, alice);

        vm.prank(alice);
        familyRegistry.revokeMarriageApproval(aliceAgentId, bobAgentId);
    }

    function test_MarriageApprovalsTurnStaleAfterTransfer() public {
        _setCompatibilityToThreshold(aliceAgentId, bobAgentId);

        vm.prank(alice);
        familyRegistry.approveMarriage(aliceAgentId, bobAgentId);

        vm.prank(bob);
        familyRegistry.approveMarriage(bobAgentId, aliceAgentId);

        vm.prank(bob);
        agentNFT.transferFrom(bob, carol, bobAgentId);

        vm.expectRevert(abi.encodeWithSelector(Errors.MarriageApprovalMissing.selector, aliceAgentId, bobAgentId));

        vm.prank(alice);
        familyRegistry.marry(aliceAgentId, bobAgentId);
    }

    function test_MarriageApprovalsRemainStaleAcrossRepeatedOwnershipChurn() public {
        _setCompatibilityToThreshold(aliceAgentId, bobAgentId);
        _approveMarriageBoth(aliceAgentId, bobAgentId);

        vm.prank(bob);
        agentNFT.transferFrom(bob, carol, bobAgentId);

        vm.prank(carol);
        familyRegistry.approveMarriage(bobAgentId, aliceAgentId);

        vm.prank(carol);
        agentNFT.transferFrom(carol, bob, bobAgentId);

        (bool aliceMissing, bool bobMissing) = familyRegistry.getMissingMarriageApprovals(aliceAgentId, bobAgentId);
        assertFalse(aliceMissing);
        assertTrue(bobMissing);

        vm.expectRevert(abi.encodeWithSelector(Errors.MarriageApprovalMissing.selector, aliceAgentId, bobAgentId));

        vm.prank(alice);
        familyRegistry.marry(aliceAgentId, bobAgentId);

        vm.prank(bob);
        familyRegistry.approveMarriage(bobAgentId, aliceAgentId);

        vm.prank(alice);
        familyRegistry.marry(aliceAgentId, bobAgentId);

        assertTrue(familyRegistry.areMarried(aliceAgentId, bobAgentId));
    }

    function test_ApproveChildRequiresMarriage() public {
        vm.expectRevert(abi.encodeWithSelector(Errors.NotMarriedPair.selector, aliceAgentId, bobAgentId));

        vm.prank(alice);
        familyRegistry.approveChild(aliceAgentId, bobAgentId);
    }

    function test_ApproveChildEmitsEvent() public {
        _setCompatibilityToThreshold(aliceAgentId, bobAgentId);
        _approveMarriageBoth(aliceAgentId, bobAgentId);

        vm.prank(alice);
        familyRegistry.marry(aliceAgentId, bobAgentId);

        vm.expectEmit(address(familyRegistry));
        emit ChildApprovalGranted(aliceAgentId, bobAgentId, alice);

        vm.prank(alice);
        familyRegistry.approveChild(aliceAgentId, bobAgentId);
    }

    function test_RevertWhen_UnauthorizedCallerRevokesChildApproval() public {
        _setCompatibilityToThreshold(aliceAgentId, bobAgentId);
        _approveMarriageBoth(aliceAgentId, bobAgentId);

        vm.prank(alice);
        familyRegistry.marry(aliceAgentId, bobAgentId);

        vm.expectRevert(abi.encodeWithSelector(Errors.NotAgentOwnerOrApproved.selector, aliceAgentId, eve));

        vm.prank(eve);
        familyRegistry.revokeChildApproval(aliceAgentId, bobAgentId);
    }

    function test_RevokeChildApprovalEmitsEvent() public {
        _setCompatibilityToThreshold(aliceAgentId, bobAgentId);
        _approveMarriageBoth(aliceAgentId, bobAgentId);

        vm.prank(alice);
        familyRegistry.marry(aliceAgentId, bobAgentId);

        vm.prank(alice);
        familyRegistry.approveChild(aliceAgentId, bobAgentId);

        vm.expectEmit(address(familyRegistry));
        emit ChildApprovalRevoked(aliceAgentId, bobAgentId, alice);

        vm.prank(alice);
        familyRegistry.revokeChildApproval(aliceAgentId, bobAgentId);
    }

    function test_ChildApprovalsTurnStaleAfterTransfer() public {
        _setCompatibilityToThreshold(aliceAgentId, bobAgentId);
        _approveMarriageBoth(aliceAgentId, bobAgentId);

        vm.prank(alice);
        familyRegistry.marry(aliceAgentId, bobAgentId);

        _approveChildBoth(aliceAgentId, bobAgentId);

        vm.prank(bob);
        agentNFT.transferFrom(bob, carol, bobAgentId);

        vm.expectRevert(abi.encodeWithSelector(Errors.ChildApprovalMissing.selector, aliceAgentId, bobAgentId));

        vm.prank(alice);
        agentNFT.mintChild(aliceAgentId, bobAgentId, alice, "Mete", "ipfs://mete");
    }

    function test_ChildApprovalsRemainStaleAcrossRepeatedOwnershipChurn() public {
        _setCompatibilityToThreshold(aliceAgentId, bobAgentId);
        _approveMarriageBoth(aliceAgentId, bobAgentId);

        vm.prank(alice);
        familyRegistry.marry(aliceAgentId, bobAgentId);

        _approveChildBoth(aliceAgentId, bobAgentId);

        vm.prank(bob);
        agentNFT.transferFrom(bob, carol, bobAgentId);

        vm.prank(carol);
        familyRegistry.approveChild(bobAgentId, aliceAgentId);

        vm.prank(carol);
        agentNFT.transferFrom(carol, bob, bobAgentId);

        vm.expectRevert(abi.encodeWithSelector(Errors.ChildApprovalMissing.selector, aliceAgentId, bobAgentId));

        vm.prank(alice);
        agentNFT.mintChild(aliceAgentId, bobAgentId, alice, "Mete", "ipfs://mete");

        vm.prank(bob);
        familyRegistry.approveChild(bobAgentId, aliceAgentId);

        vm.prank(alice);
        uint256 childId = agentNFT.mintChild(aliceAgentId, bobAgentId, alice, "Mete", "ipfs://mete");

        assertEq(agentNFT.ownerOf(childId), alice);
    }

    function test_RevokeMarriageApprovalPreventsMarriage() public {
        _setCompatibilityToThreshold(aliceAgentId, bobAgentId);
        _approveMarriageBoth(aliceAgentId, bobAgentId);

        vm.prank(alice);
        familyRegistry.revokeMarriageApproval(aliceAgentId, bobAgentId);

        vm.expectRevert(abi.encodeWithSelector(Errors.MarriageApprovalMissing.selector, aliceAgentId, bobAgentId));

        vm.prank(bob);
        familyRegistry.marry(aliceAgentId, bobAgentId);
    }

    function test_RevokeChildApprovalPreventsMintChild() public {
        _setCompatibilityToThreshold(aliceAgentId, bobAgentId);
        _approveMarriageBoth(aliceAgentId, bobAgentId);

        vm.prank(alice);
        familyRegistry.marry(aliceAgentId, bobAgentId);

        _approveChildBoth(aliceAgentId, bobAgentId);

        vm.prank(alice);
        familyRegistry.revokeChildApproval(aliceAgentId, bobAgentId);

        vm.expectRevert(abi.encodeWithSelector(Errors.ChildApprovalMissing.selector, aliceAgentId, bobAgentId));

        vm.prank(bob);
        agentNFT.mintChild(aliceAgentId, bobAgentId, alice, "Mete", "ipfs://mete");
    }
}
