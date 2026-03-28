// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

library AgentTypes {
    uint8 internal constant JOB_TRADER = 0;
    uint8 internal constant JOB_FARMER = 1;
    uint8 internal constant JOB_LENDER = 2;
    uint8 internal constant MAX_JOB_TYPE = JOB_LENDER;

    uint256 internal constant ADULT_AGE = 18;
    uint256 internal constant SICKNESS_ASSESSMENT_AGE = 60;
    uint8 internal constant MAX_TRAIT_VALUE = 100;
    uint256 internal constant MAX_AGE = 100;
    uint8 internal constant MAX_SICKNESS_PENALTY = 40;
    uint8 internal constant MARRIAGE_THRESHOLD = 80;
    uint8 internal constant COMPATIBILITY_INCREMENT = 5;
    uint256 internal constant CHILD_FUNDING_BPS = 1_000;
    uint256 internal constant BPS_DENOMINATOR = 10_000;
    uint8 internal constant JOB_MUTATION_CHANCE = 30;
    uint256 internal constant MOVE_OUT_HOUSE_FUND = 0.5 ether;

    uint256 internal constant BASE_REWARD = 1e15;
    uint256 internal constant RISK_REWARD_STEP = 1e13;

    struct Agent {
        uint256 id;
        string name;
        uint8 jobType;
        uint8 riskScore;
        uint8 patience;
        uint8 socialScore;
        uint256 age;
        uint256 balance;
        uint256 lockedBalance;
        uint256 partnerId;
        uint256 maxAge;
        uint256[] childIds;
        bool retired;
        bool independent;
        bool sicknessEvaluated;
        uint8 sicknessLevel;
        string personalityCID;
    }

    struct Listing {
        address seller;
        uint256 price;
    }
}
