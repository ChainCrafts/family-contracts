// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Errors} from "../../../src/libraries/Errors.sol";
import {BaseFixture} from "../../utils/BaseFixture.t.sol";

contract FamilyRegistryMarriageApprovalTest is BaseFixture {
    function test_RevertWhen_UnauthorizedCallerApprovesMarriage() public {
        vm.expectRevert(abi.encodeWithSelector(Errors.NotAgentOwnerOrApproved.selector, aliceAgentId, eve));

        vm.prank(eve);
        familyRegistry.approveMarriage(aliceAgentId, bobAgentId);
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

    function test_ApproveChildRequiresMarriage() public {
        vm.expectRevert(abi.encodeWithSelector(Errors.NotMarriedPair.selector, aliceAgentId, bobAgentId));

        vm.prank(alice);
        familyRegistry.approveChild(aliceAgentId, bobAgentId);
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
        agentNFT.mintChild(aliceAgentId, bobAgentId, "Mete", "ipfs://mete");
    }
}
