// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {AgentTypes} from "../../../src/libraries/AgentTypes.sol";
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
        uint256 childId = agentNFT.mintChild(aliceAgentId, bobAgentId, "Mina", "ipfs://mina");

        AgentTypes.Agent memory parentAAfter = agentNFT.getAgent(aliceAgentId);
        AgentTypes.Agent memory parentBAfter = agentNFT.getAgent(bobAgentId);
        AgentTypes.Agent memory child = agentNFT.getAgent(childId);

        assertEq(childId, expectedChildId);
        assertEq(agentNFT.ownerOf(childId), alice);
        assertEq(parentAAfter.balance, parentABefore.balance - expectedContributionA);
        assertEq(parentBAfter.balance, parentBBefore.balance - expectedContributionB);
        assertEq(child.balance, expectedContributionA + expectedContributionB);
        assertEq(parentAAfter.childIds[parentAAfter.childIds.length - 1], childId);
        assertEq(parentBAfter.childIds[parentBAfter.childIds.length - 1], childId);
    }
}
