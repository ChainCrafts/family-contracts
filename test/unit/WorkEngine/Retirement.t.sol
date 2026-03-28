// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {AgentTypes} from "../../../src/libraries/AgentTypes.sol";
import {Errors} from "../../../src/libraries/Errors.sol";
import {BaseFixture} from "../../utils/BaseFixture.t.sol";

contract WorkEngineRetirementTest is BaseFixture {
    event AgentRetired(uint256 indexed agentId, uint256 finalBalance);

    function test_RetirementSendsBalanceToCommunityPoolWithoutChildren() public {
        _ageAgentTo(carolAgentId, AgentTypes.MAX_AGE - 1);

        AgentTypes.Agent memory beforeFinalWork = agentNFT.getAgent(carolAgentId);
        uint256 expectedEarned = _expectedReward(beforeFinalWork, carolAgentId, 0);
        uint256 expectedFinalBalance = beforeFinalWork.balance + expectedEarned;

        vm.expectEmit(address(workEngine));
        emit AgentRetired(carolAgentId, expectedFinalBalance);

        vm.prank(carol);
        workEngine.work(carolAgentId, 0);

        AgentTypes.Agent memory retiredAgent = agentNFT.getAgent(carolAgentId);

        assertTrue(retiredAgent.retired);
        assertEq(retiredAgent.age, AgentTypes.MAX_AGE);
        assertEq(retiredAgent.balance, 0);
        assertEq(workEngine.communityPoolBalance(), expectedFinalBalance);
    }

    function test_RetirementDistributesBalanceToChild() public {
        _workAs(alice, aliceAgentId, bobAgentId);
        _workAs(bob, bobAgentId, aliceAgentId);
        _setCompatibilityToThreshold(aliceAgentId, bobAgentId);
        _approveMarriageBoth(aliceAgentId, bobAgentId);

        vm.prank(alice);
        familyRegistry.marry(aliceAgentId, bobAgentId);

        _approveChildBoth(aliceAgentId, bobAgentId);

        vm.prank(alice);
        uint256 childId = agentNFT.mintChild(aliceAgentId, bobAgentId, "Lale", "ipfs://lale");

        _ageAgentTo(aliceAgentId, AgentTypes.MAX_AGE - 1);

        AgentTypes.Agent memory childBefore = agentNFT.getAgent(childId);
        AgentTypes.Agent memory parentBeforeFinalWork = agentNFT.getAgent(aliceAgentId);
        uint256 expectedEarned = _expectedReward(parentBeforeFinalWork, aliceAgentId, 0);
        uint256 expectedFinalBalance = parentBeforeFinalWork.balance + expectedEarned;

        vm.prank(alice);
        workEngine.work(aliceAgentId, 0);

        AgentTypes.Agent memory childAfter = agentNFT.getAgent(childId);
        AgentTypes.Agent memory retiredParent = agentNFT.getAgent(aliceAgentId);

        assertTrue(retiredParent.retired);
        assertEq(retiredParent.balance, 0);
        assertEq(childAfter.balance, childBefore.balance + expectedFinalBalance);
    }

    function test_RevertWhen_RetiredAgentWorks() public {
        _ageAgentTo(carolAgentId, AgentTypes.MAX_AGE);

        vm.expectRevert(abi.encodeWithSelector(Errors.AgentRetired.selector, carolAgentId));

        vm.prank(carol);
        workEngine.work(carolAgentId, 0);
    }

    function _ageAgentTo(uint256 agentId, uint256 targetAge) internal {
        address agentOwner = agentNFT.ownerOf(agentId);

        while (agentNFT.getAgent(agentId).age < targetAge) {
            vm.prank(agentOwner);
            workEngine.work(agentId, 0);
        }
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
