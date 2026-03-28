// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {AgentTypes} from "../../src/libraries/AgentTypes.sol";
import {ProtocolHandler} from "../invariant/handlers/ProtocolHandler.sol";
import {BaseFixture} from "../utils/BaseFixture.t.sol";

contract RandomizedLifecycleSequencesIntegrationTest is BaseFixture {
    ProtocolHandler internal handler;

    function setUp() public override {
        super.setUp();
        handler = new ProtocolHandler(agentNFT, familyRegistry, workEngine, marketplace, _actors());
    }

    function test_LongRandomizedLifecycleSequenceSeedOne() public {
        _bootstrapFamilyState();
        _runRandomizedSequence(0xA11CE, 512);
    }

    function test_LongRandomizedLifecycleSequenceSeedTwo() public {
        _bootstrapFamilyState();
        _runRandomizedSequence(0xB0B, 512);
    }

    function _bootstrapFamilyState() internal {
        _setCompatibilityToThreshold(aliceAgentId, bobAgentId);
        _approveMarriageBoth(aliceAgentId, bobAgentId);

        vm.prank(alice);
        familyRegistry.marry(aliceAgentId, bobAgentId);

        _approveChildBoth(aliceAgentId, bobAgentId);

        vm.prank(alice);
        agentNFT.mintChild(aliceAgentId, bobAgentId, alice, "BootstrapKid", "ipfs://bootstrap-kid");
    }

    function _runRandomizedSequence(uint256 seed, uint256 steps) internal {
        for (uint256 i = 0; i < steps; ++i) {
            uint256 stepSeed = uint256(keccak256(abi.encode(seed, i)));
            uint256 action = stepSeed % 15;
            uint256 actorSeed = uint256(keccak256(abi.encode(stepSeed, uint256(1))));
            uint256 agentSeed = uint256(keccak256(abi.encode(stepSeed, uint256(2))));
            uint256 otherSeed = uint256(keccak256(abi.encode(stepSeed, uint256(3))));
            uint96 priceSeed = uint96(uint256(keccak256(abi.encode(stepSeed, uint256(4)))));

            if (action <= 4) {
                handler.work(actorSeed, agentSeed, otherSeed);
            } else if (action == 5) {
                handler.approveMarriage(actorSeed, agentSeed, otherSeed);
            } else if (action == 6) {
                handler.revokeMarriageApproval(actorSeed, agentSeed, otherSeed);
            } else if (action == 7) {
                handler.marry(actorSeed, agentSeed, otherSeed);
            } else if (action == 8) {
                handler.approveChild(actorSeed, agentSeed, otherSeed);
            } else if (action == 9) {
                handler.revokeChildApproval(actorSeed, agentSeed, otherSeed);
            } else if (action == 10) {
                handler.mintChild(actorSeed, agentSeed, otherSeed);
            } else if (action == 11) {
                handler.listAgent(actorSeed, agentSeed, priceSeed);
            } else if (action == 12) {
                handler.buyAgent(actorSeed, agentSeed);
            } else if (action == 13) {
                handler.transferAgent(agentSeed, actorSeed);
            } else {
                handler.delistAgent(actorSeed, agentSeed);
            }
        }

        _assertProtocolState();
    }

    function _assertProtocolState() internal view {
        uint256 totalAgents = agentNFT.totalAgents();
        uint256 aggregateBalances;

        assertGe(totalAgents, 4);
        assertEq(handler.successfulRetiredWorkCalls(), 0);

        for (uint256 i = 1; i <= totalAgents; ++i) {
            AgentTypes.Agent memory agent = agentNFT.getAgent(i);
            aggregateBalances += agent.balance + agent.lockedBalance;
            uint256 partnerId = agent.partnerId;

            if (partnerId != 0) {
                (,,,,,,, uint256 reciprocalPartnerId,) = agentNFT.getAgentCore(partnerId);
                assertEq(reciprocalPartnerId, i);
            }

            uint256 childCount = agentNFT.getAgentChildCount(i);
            for (uint256 j = 0; j < childCount; ++j) {
                assertTrue(agentNFT.exists(agentNFT.getAgentChildAt(i, j)));
            }

            AgentTypes.Listing memory listing = marketplace.getListing(i);
            if (listing.seller != address(0)) {
                assertEq(agentNFT.ownerOf(i), listing.seller);
                assertTrue(agentNFT.ownerOrApproved(address(marketplace), i));
            }
        }

        assertEq(
            address(workEngine).balance,
            workEngine.rewardPoolBalance() + workEngine.communityPoolBalance() + aggregateBalances
        );
        assertGt(agentNFT.getAgentChildCount(aliceAgentId), 0);
    }

    function _actors() internal view returns (address[] memory actors_) {
        actors_ = new address[](6);
        actors_[0] = alice;
        actors_[1] = bob;
        actors_[2] = carol;
        actors_[3] = dave;
        actors_[4] = eve;
        actors_[5] = operator;
    }
}
