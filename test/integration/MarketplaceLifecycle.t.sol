// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {AgentTypes} from "../../src/libraries/AgentTypes.sol";
import {BaseFixture} from "../utils/BaseFixture.t.sol";

contract MarketplaceLifecycleIntegrationTest is BaseFixture {
    function test_RetiredAgentsRemainTradableAcrossMultipleSales() public {
        vm.deal(eve, 3 ether);
        vm.deal(alice, 3 ether);

        while (agentNFT.getAgent(carolAgentId).age < AgentTypes.MAX_AGE) {
            _workAs(carol, carolAgentId, 0);
        }

        vm.prank(carol);
        agentNFT.approve(address(marketplace), carolAgentId);

        vm.prank(carol);
        marketplace.listAgent(carolAgentId, 1 ether);

        vm.prank(eve);
        marketplace.buyAgent{value: 1 ether}(carolAgentId);

        assertEq(agentNFT.ownerOf(carolAgentId), eve);
        assertTrue(agentNFT.getAgent(carolAgentId).retired);

        vm.prank(eve);
        agentNFT.approve(address(marketplace), carolAgentId);

        vm.prank(eve);
        marketplace.listAgent(carolAgentId, 2 ether);

        vm.prank(alice);
        marketplace.buyAgent{value: 2 ether}(carolAgentId);

        assertEq(agentNFT.ownerOf(carolAgentId), alice);
        assertTrue(agentNFT.getAgent(carolAgentId).retired);
    }
}
