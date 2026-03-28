// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {AgentTypes} from "../../src/libraries/AgentTypes.sol";
import {BaseFixture} from "../utils/BaseFixture.t.sol";

contract LifecycleFlowIntegrationTest is BaseFixture {
    function test_LifecycleFlowFromWorkToMarriageToChildToRetirement() public {
        _setCompatibilityToThreshold(aliceAgentId, bobAgentId);
        _approveMarriageBoth(aliceAgentId, bobAgentId);

        vm.prank(alice);
        familyRegistry.marry(aliceAgentId, bobAgentId);

        _approveChildBoth(aliceAgentId, bobAgentId);

        vm.prank(alice);
        uint256 childId = agentNFT.mintChild(aliceAgentId, bobAgentId, "Ada", "ipfs://ada");

        address aliceOwner = agentNFT.ownerOf(aliceAgentId);
        while (agentNFT.getAgent(aliceAgentId).age < AgentTypes.MAX_AGE) {
            vm.prank(aliceOwner);
            workEngine.work(aliceAgentId, 0);
        }

        AgentTypes.Agent memory retiredAlice = agentNFT.getAgent(aliceAgentId);
        AgentTypes.Agent memory child = agentNFT.getAgent(childId);

        assertTrue(retiredAlice.retired);
        assertEq(retiredAlice.balance, 0);
        assertGt(child.balance, 0);
    }
}
