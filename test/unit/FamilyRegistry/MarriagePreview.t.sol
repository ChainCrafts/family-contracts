// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {AgentTypes} from "../../../src/libraries/AgentTypes.sol";
import {BaseFixture} from "../../utils/BaseFixture.t.sol";

contract FamilyRegistryMarriagePreviewTest is BaseFixture {
    function test_GetMissingMarriageApprovalsReflectsCurrentApprovalState() public {
        (bool agentAMissing, bool agentBMissing) = familyRegistry.getMissingMarriageApprovals(aliceAgentId, bobAgentId);
        assertTrue(agentAMissing);
        assertTrue(agentBMissing);

        vm.prank(alice);
        familyRegistry.approveMarriage(aliceAgentId, bobAgentId);

        (agentAMissing, agentBMissing) = familyRegistry.getMissingMarriageApprovals(aliceAgentId, bobAgentId);
        assertFalse(agentAMissing);
        assertTrue(agentBMissing);

        vm.prank(bob);
        familyRegistry.approveMarriage(bobAgentId, aliceAgentId);

        (agentAMissing, agentBMissing) = familyRegistry.getMissingMarriageApprovals(aliceAgentId, bobAgentId);
        assertFalse(agentAMissing);
        assertFalse(agentBMissing);

        vm.prank(bob);
        agentNFT.transferFrom(bob, carol, bobAgentId);

        (agentAMissing, agentBMissing) = familyRegistry.getMissingMarriageApprovals(aliceAgentId, bobAgentId);
        assertFalse(agentAMissing);
        assertTrue(agentBMissing);
    }

    function test_GetCompatibilityRemainingForMarriageTracksProgressToThreshold() public {
        assertEq(
            familyRegistry.getCompatibilityRemainingForMarriage(aliceAgentId, bobAgentId), AgentTypes.MARRIAGE_THRESHOLD
        );

        vm.prank(alice);
        workEngine.work(aliceAgentId, bobAgentId);

        assertEq(
            familyRegistry.getCompatibilityRemainingForMarriage(aliceAgentId, bobAgentId),
            AgentTypes.MARRIAGE_THRESHOLD - AgentTypes.COMPATIBILITY_INCREMENT
        );

        _setCompatibilityToThreshold(aliceAgentId, bobAgentId);

        assertEq(familyRegistry.getCompatibilityRemainingForMarriage(aliceAgentId, bobAgentId), 0);
    }

    function test_CanMarryRequiresThresholdAndActiveApprovals() public {
        assertFalse(familyRegistry.canMarry(aliceAgentId, bobAgentId));

        _setCompatibilityToThreshold(aliceAgentId, bobAgentId);
        assertFalse(familyRegistry.canMarry(aliceAgentId, bobAgentId));

        vm.prank(alice);
        familyRegistry.approveMarriage(aliceAgentId, bobAgentId);
        assertFalse(familyRegistry.canMarry(aliceAgentId, bobAgentId));

        vm.prank(bob);
        familyRegistry.approveMarriage(bobAgentId, aliceAgentId);
        assertTrue(familyRegistry.canMarry(aliceAgentId, bobAgentId));
    }

    function test_CanMarryReturnsFalseAfterMarriage() public {
        _setCompatibilityToThreshold(aliceAgentId, bobAgentId);
        _approveMarriageBoth(aliceAgentId, bobAgentId);

        assertTrue(familyRegistry.canMarry(aliceAgentId, bobAgentId));

        vm.prank(alice);
        familyRegistry.marry(aliceAgentId, bobAgentId);

        assertFalse(familyRegistry.canMarry(aliceAgentId, bobAgentId));
    }
}
