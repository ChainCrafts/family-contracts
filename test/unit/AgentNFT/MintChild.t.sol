// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {AgentTypes} from "../../../src/libraries/AgentTypes.sol";
import {Errors} from "../../../src/libraries/Errors.sol";
import {BaseFixture} from "../../utils/BaseFixture.t.sol";

contract AgentNFTMintChildTest is BaseFixture {
    event AgentBorn(uint256 indexed childId, uint256 indexed parentAId, uint256 indexed parentBId, string name);

    function test_MintChildDebitsParentsCreditsChildAndLinksFamily() public {
        _workAs(alice, aliceAgentId, bobAgentId);
        _workAs(bob, bobAgentId, aliceAgentId);
        _setCompatibilityToThreshold(aliceAgentId, bobAgentId);
        _approveMarriageBoth(aliceAgentId, bobAgentId);

        vm.prank(alice);
        familyRegistry.marry(aliceAgentId, bobAgentId);

        AgentTypes.Agent memory parentABefore = agentNFT.getAgent(aliceAgentId);
        AgentTypes.Agent memory parentBBefore = agentNFT.getAgent(bobAgentId);

        uint256 expectedContributionA = parentABefore.balance / 10;
        uint256 expectedContributionB = parentBBefore.balance / 10;
        uint256 expectedChildId = agentNFT.totalAgents() + 1;

        _approveChildBoth(aliceAgentId, bobAgentId);

        vm.expectEmit(address(agentNFT));
        emit AgentBorn(expectedChildId, aliceAgentId, bobAgentId, "Mina");

        vm.prank(alice);
        uint256 childId = agentNFT.mintChild(aliceAgentId, bobAgentId, alice, "Mina", "ipfs://mina");

        AgentTypes.Agent memory parentAAfter = agentNFT.getAgent(aliceAgentId);
        AgentTypes.Agent memory parentBAfter = agentNFT.getAgent(bobAgentId);
        AgentTypes.Agent memory child = agentNFT.getAgent(childId);

        assertEq(childId, expectedChildId);
        assertEq(agentNFT.ownerOf(childId), alice);
        assertEq(parentAAfter.balance, parentABefore.balance - expectedContributionA);
        assertEq(parentBAfter.balance, parentBBefore.balance - expectedContributionB);
        assertEq(child.balance, 0);
        assertEq(child.lockedBalance, expectedContributionA + expectedContributionB);
        assertFalse(child.independent);
        assertEq(parentAAfter.childIds[parentAAfter.childIds.length - 1], childId);
        assertEq(parentBAfter.childIds[parentBAfter.childIds.length - 1], childId);
    }

    function test_MintChildUsesExplicitRecipientInsteadOfCallerDerivedOwner() public {
        _setCompatibilityToThreshold(aliceAgentId, bobAgentId);
        _approveMarriageBoth(aliceAgentId, bobAgentId);

        vm.prank(alice);
        familyRegistry.marry(aliceAgentId, bobAgentId);

        _approveChildBoth(aliceAgentId, bobAgentId);

        vm.prank(alice);
        uint256 childId = agentNFT.mintChild(aliceAgentId, bobAgentId, bob, "Mina", "ipfs://mina");

        assertEq(agentNFT.ownerOf(childId), bob);
    }

    function test_RevertWhen_ChildRecipientIsNotAParentOwner() public {
        _setCompatibilityToThreshold(aliceAgentId, bobAgentId);
        _approveMarriageBoth(aliceAgentId, bobAgentId);

        vm.prank(alice);
        familyRegistry.marry(aliceAgentId, bobAgentId);

        _approveChildBoth(aliceAgentId, bobAgentId);

        vm.expectRevert(abi.encodeWithSelector(Errors.InvalidChildRecipient.selector, dave));

        vm.prank(alice);
        agentNFT.mintChild(aliceAgentId, bobAgentId, dave, "Mina", "ipfs://mina");
    }

    function test_GetAgentChildReadHelpersReturnFamilyLinks() public {
        _setCompatibilityToThreshold(aliceAgentId, bobAgentId);
        _approveMarriageBoth(aliceAgentId, bobAgentId);

        vm.prank(alice);
        familyRegistry.marry(aliceAgentId, bobAgentId);

        _approveChildBoth(aliceAgentId, bobAgentId);

        vm.prank(alice);
        uint256 childId = agentNFT.mintChild(aliceAgentId, bobAgentId, alice, "Mina", "ipfs://mina");

        assertEq(agentNFT.getAgentChildCount(aliceAgentId), 1);
        assertEq(agentNFT.getAgentChildCount(bobAgentId), 1);
        assertEq(agentNFT.getAgentChildAt(aliceAgentId, 0), childId);
        assertEq(agentNFT.getAgentChildAt(bobAgentId, 0), childId);
    }

    function test_MoveOutUnlocksLockedBalanceAndHouseFunding() public {
        _setCompatibilityToThreshold(aliceAgentId, bobAgentId);
        _approveMarriageBoth(aliceAgentId, bobAgentId);

        vm.prank(alice);
        familyRegistry.marry(aliceAgentId, bobAgentId);

        _approveChildBoth(aliceAgentId, bobAgentId);

        vm.prank(alice);
        uint256 childId = agentNFT.mintChild(aliceAgentId, bobAgentId, alice, "Mina", "ipfs://mina");

        while (agentNFT.getAgent(childId).age < AgentTypes.ADULT_AGE) {
            vm.prank(alice);
            workEngine.work(childId, 0);
        }

        vm.prank(address(workEngine));
        agentNFT.increaseBalance(aliceAgentId, AgentTypes.MOVE_OUT_HOUSE_FUND);

        AgentTypes.Agent memory childBeforeMove = agentNFT.getAgent(childId);
        AgentTypes.Agent memory parentBeforeMove = agentNFT.getAgent(aliceAgentId);

        vm.prank(owner);
        agentNFT.moveOut(aliceAgentId, childId);

        AgentTypes.Agent memory childAfterMove = agentNFT.getAgent(childId);
        AgentTypes.Agent memory parentAfterMove = agentNFT.getAgent(aliceAgentId);

        assertTrue(childAfterMove.independent);
        assertEq(childAfterMove.lockedBalance, 0);
        assertEq(childAfterMove.balance, childBeforeMove.lockedBalance + AgentTypes.MOVE_OUT_HOUSE_FUND);
        assertEq(parentAfterMove.balance, parentBeforeMove.balance - AgentTypes.MOVE_OUT_HOUSE_FUND);
    }
}
