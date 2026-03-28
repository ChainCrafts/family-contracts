// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {AgentTypes} from "../../../src/libraries/AgentTypes.sol";
import {Errors} from "../../../src/libraries/Errors.sol";
import {BaseFixture} from "../../utils/BaseFixture.t.sol";

contract FamilyRegistryMarriageTest is BaseFixture {
    event AgentMarried(uint256 indexed agentA, uint256 indexed agentB);

    function test_MarryRequiresCompatibilityThreshold() public {
        _approveMarriageBoth(aliceAgentId, bobAgentId);

        vm.expectRevert(
            abi.encodeWithSelector(
                Errors.CompatibilityTooLow.selector, aliceAgentId, bobAgentId, uint8(0), AgentTypes.MARRIAGE_THRESHOLD
            )
        );

        vm.prank(alice);
        familyRegistry.marry(aliceAgentId, bobAgentId);
    }

    function test_MarryLinksPartnersAndReportsHouseholdBalance() public {
        _workAs(alice, aliceAgentId, bobAgentId);
        _workAs(bob, bobAgentId, aliceAgentId);
        _setCompatibilityToThreshold(aliceAgentId, bobAgentId);
        _approveMarriageBoth(aliceAgentId, bobAgentId);

        vm.expectEmit(address(familyRegistry));
        emit AgentMarried(aliceAgentId, bobAgentId);

        vm.prank(alice);
        familyRegistry.marry(aliceAgentId, bobAgentId);

        AgentTypes.Agent memory aliceAgent = agentNFT.getAgent(aliceAgentId);
        AgentTypes.Agent memory bobAgent = agentNFT.getAgent(bobAgentId);

        assertEq(aliceAgent.partnerId, bobAgentId);
        assertEq(bobAgent.partnerId, aliceAgentId);
        assertEq(familyRegistry.getHouseholdBalance(aliceAgentId), aliceAgent.balance + bobAgent.balance);
    }

    function test_RevertWhen_MarryingAlreadyMarriedAgent() public {
        _setCompatibilityToThreshold(aliceAgentId, bobAgentId);
        _approveMarriageBoth(aliceAgentId, bobAgentId);

        vm.prank(alice);
        familyRegistry.marry(aliceAgentId, bobAgentId);

        _setCompatibilityToThreshold(aliceAgentId, carolAgentId);

        vm.prank(alice);
        familyRegistry.approveMarriage(aliceAgentId, carolAgentId);

        vm.prank(carol);
        familyRegistry.approveMarriage(carolAgentId, aliceAgentId);

        vm.expectRevert(abi.encodeWithSelector(Errors.AlreadyMarried.selector, aliceAgentId));

        vm.prank(alice);
        familyRegistry.marry(aliceAgentId, carolAgentId);
    }
}
