// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {Pausable} from "@openzeppelin/contracts/utils/Pausable.sol";

import {AgentTypes} from "../../../src/libraries/AgentTypes.sol";
import {Errors} from "../../../src/libraries/Errors.sol";
import {BaseFixture} from "../../utils/BaseFixture.t.sol";

contract WorkEngineWorkTest is BaseFixture {
    event AgentWorked(uint256 indexed agentId, uint256 earned, uint256 newAge);
    event RewardPoolFunded(address indexed funder, uint256 amount, uint256 newRewardPoolBalance);

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

    function test_PreviewWorkRewardMatchesCurrentBlockExecution() public {
        AgentTypes.Agent memory beforeWork = agentNFT.getAgent(aliceAgentId);
        uint256 previewedReward = workEngine.previewWorkReward(aliceAgentId, bobAgentId);

        vm.prank(alice);
        workEngine.work(aliceAgentId, bobAgentId);

        AgentTypes.Agent memory afterWork = agentNFT.getAgent(aliceAgentId);
        assertEq(afterWork.balance, beforeWork.balance + previewedReward);
    }

    function test_FundRewardPoolEmitsAccountingEvent() public {
        uint256 amount = 5 ether;
        uint256 expectedBalance = workEngine.rewardPoolBalance() + amount;

        vm.expectEmit(address(workEngine));
        emit RewardPoolFunded(owner, amount, expectedBalance);

        vm.prank(owner);
        workEngine.fundRewardPool{value: amount}();

        assertEq(workEngine.rewardPoolBalance(), expectedBalance);
    }

    function test_RevertWhen_NonOwnerPausesWorkEngine() public {
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, alice));

        vm.prank(alice);
        workEngine.pause();
    }

    function test_RevertWhen_WorkCalledWhilePaused() public {
        vm.prank(owner);
        workEngine.pause();

        vm.expectRevert(Pausable.EnforcedPause.selector);

        vm.prank(alice);
        workEngine.work(aliceAgentId, bobAgentId);
    }

    function test_UnpauseRestoresWork() public {
        vm.prank(owner);
        workEngine.pause();

        vm.prank(owner);
        workEngine.unpause();

        vm.prank(alice);
        workEngine.work(aliceAgentId, 0);

        assertEq(agentNFT.getAgent(aliceAgentId).age, 1);
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
