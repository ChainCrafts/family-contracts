// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {AgentTypes} from "../../../src/libraries/AgentTypes.sol";
import {Errors} from "../../../src/libraries/Errors.sol";
import {BaseFixture} from "../../utils/BaseFixture.t.sol";

contract WorkEngineWorkTest is BaseFixture {
    event AgentWorked(uint256 indexed agentId, uint256 earned, uint256 newAge);

    function test_WorkRequiresOwnerOrOperator() public {
        vm.expectRevert(abi.encodeWithSelector(Errors.NotAgentOwnerOrApproved.selector, aliceAgentId, eve));

        vm.prank(eve);
        workEngine.work(aliceAgentId, bobAgentId);
    }

    function test_WorkCreditsBalanceAgeAndCompatibility() public {
        AgentTypes.Agent memory beforeWork = agentNFT.getAgent(aliceAgentId);
        uint256 expectedEarned = _expectedReward(beforeWork, aliceAgentId, bobAgentId);
        uint256 rewardPoolBefore = workEngine.rewardPoolBalance();

        vm.expectEmit(address(workEngine));
        emit AgentWorked(aliceAgentId, expectedEarned, beforeWork.age + 1);

        vm.prank(alice);
        workEngine.work(aliceAgentId, bobAgentId);

        AgentTypes.Agent memory afterWork = agentNFT.getAgent(aliceAgentId);

        assertEq(afterWork.age, beforeWork.age + 1);
        assertEq(afterWork.balance, beforeWork.balance + expectedEarned);
        assertEq(familyRegistry.getCompatibility(aliceAgentId, bobAgentId), AgentTypes.COMPATIBILITY_INCREMENT);
        assertEq(workEngine.rewardPoolBalance(), rewardPoolBefore - expectedEarned);
    }

    function test_WorkAllowsApprovedOperator() public {
        vm.prank(alice);
        agentNFT.setApprovalForAll(operator, true);

        vm.prank(operator);
        workEngine.work(aliceAgentId, 0);

        assertEq(agentNFT.getAgent(aliceAgentId).age, 1);
    }

    function test_WorkCapsCompatibilityAtOneHundred() public {
        for (uint256 i = 0; i < 25; ++i) {
            vm.prank(alice);
            workEngine.work(aliceAgentId, bobAgentId);
        }

        assertEq(familyRegistry.getCompatibility(aliceAgentId, bobAgentId), AgentTypes.MAX_TRAIT_VALUE);
    }

    function _expectedReward(AgentTypes.Agent memory agent, uint256 agentId, uint256 counterpartyId)
        internal
        view
        returns (uint256)
    {
        uint256 entropy = uint256(
            keccak256(abi.encodePacked(agentId, agent.age, counterpartyId, block.prevrandao, block.timestamp))
        );
        return AgentTypes.BASE_REWARD + ((entropy % (uint256(agent.riskScore) + 1)) * AgentTypes.RISK_REWARD_STEP);
    }
}
