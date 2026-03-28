// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {AgentTypes} from "./AgentTypes.sol";

library TraitLib {
    function blendTraits(AgentTypes.Agent memory parentA, AgentTypes.Agent memory parentB, uint256 seed)
        internal
        pure
        returns (uint8 riskScore, uint8 patience, uint8 socialScore, uint8 jobType)
    {
        riskScore = clampTrait(int256(uint256(average(parentA.riskScore, parentB.riskScore))) + jitter(seed, 0));
        patience = clampTrait(int256(uint256(average(parentA.patience, parentB.patience))) + jitter(seed, 1));
        socialScore = clampTrait(int256(uint256(average(parentA.socialScore, parentB.socialScore))) + jitter(seed, 2));

        uint8 dominantJob = parentA.balance >= parentB.balance ? parentA.jobType : parentB.jobType;
        jobType = (seed % 100) < AgentTypes.JOB_MUTATION_CHANCE ? uint8((seed >> 24) % 3) : dominantJob;
    }

    function average(uint8 left, uint8 right) internal pure returns (uint8) {
        return uint8((uint16(left) + uint16(right)) / 2);
    }

    function jitter(uint256 seed, uint8 offset) internal pure returns (int8) {
        int256 raw = int256((seed >> (offset * 8)) % 21);
        return int8(raw - 10);
    }

    function clampTrait(int256 value) internal pure returns (uint8) {
        if (value <= 0) {
            return 0;
        }

        if (value >= int256(uint256(AgentTypes.MAX_TRAIT_VALUE))) {
            return AgentTypes.MAX_TRAIT_VALUE;
        }

        return uint8(uint256(value));
    }
}
