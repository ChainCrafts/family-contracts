// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";

import {AgentTypes} from "../../../src/libraries/AgentTypes.sol";
import {TraitLib} from "../../../src/libraries/TraitLib.sol";

contract TraitLibHarness {
    function blendTraits(AgentTypes.Agent memory a, AgentTypes.Agent memory b, uint256 seed)
        external
        pure
        returns (uint8 riskScore, uint8 patience, uint8 socialScore, uint8 jobType)
    {
        return TraitLib.blendTraits(a, b, seed);
    }

    function clampTrait(int256 value) external pure returns (uint8) {
        return TraitLib.clampTrait(value);
    }
}

contract TraitLibTest is Test {
    TraitLibHarness internal harness;

    function setUp() public {
        harness = new TraitLibHarness();
    }

    function testFuzz_BlendTraitsStayWithinBounds(
        uint8 riskA,
        uint8 patienceA,
        uint8 socialA,
        uint8 jobA,
        uint8 riskB,
        uint8 patienceB,
        uint8 socialB,
        uint8 jobB,
        uint256 balanceA,
        uint256 balanceB,
        uint256 seed
    ) public view {
        AgentTypes.Agent memory agentA;
        AgentTypes.Agent memory agentB;

        agentA.riskScore = uint8(bound(riskA, 0, AgentTypes.MAX_TRAIT_VALUE));
        agentA.patience = uint8(bound(patienceA, 0, AgentTypes.MAX_TRAIT_VALUE));
        agentA.socialScore = uint8(bound(socialA, 0, AgentTypes.MAX_TRAIT_VALUE));
        agentA.jobType = uint8(bound(jobA, 0, AgentTypes.MAX_JOB_TYPE));
        agentA.balance = balanceA;

        agentB.riskScore = uint8(bound(riskB, 0, AgentTypes.MAX_TRAIT_VALUE));
        agentB.patience = uint8(bound(patienceB, 0, AgentTypes.MAX_TRAIT_VALUE));
        agentB.socialScore = uint8(bound(socialB, 0, AgentTypes.MAX_TRAIT_VALUE));
        agentB.jobType = uint8(bound(jobB, 0, AgentTypes.MAX_JOB_TYPE));
        agentB.balance = balanceB;

        (uint8 riskScore, uint8 patience, uint8 socialScore, uint8 jobType) = harness.blendTraits(agentA, agentB, seed);

        assertLe(riskScore, AgentTypes.MAX_TRAIT_VALUE);
        assertLe(patience, AgentTypes.MAX_TRAIT_VALUE);
        assertLe(socialScore, AgentTypes.MAX_TRAIT_VALUE);
        assertLe(jobType, AgentTypes.MAX_JOB_TYPE);
    }

    function test_ClampTraitCapsBelowZeroAndAboveMax() public view {
        assertEq(harness.clampTrait(-77), 0);
        assertEq(harness.clampTrait(500), AgentTypes.MAX_TRAIT_VALUE);
        assertEq(harness.clampTrait(47), 47);
    }
}
