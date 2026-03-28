// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {BaseFixture} from "../utils/BaseFixture.t.sol";
import {ProtocolHandler} from "./handlers/ProtocolHandler.sol";

contract ProtocolInvariants is BaseFixture {
    ProtocolHandler internal handler;

    function setUp() public override {
        super.setUp();

        address[] memory actors = new address[](6);
        actors[0] = alice;
        actors[1] = bob;
        actors[2] = carol;
        actors[3] = dave;
        actors[4] = eve;
        actors[5] = operator;

        handler = new ProtocolHandler(agentNFT, familyRegistry, workEngine, marketplace, actors);
        targetContract(address(handler));
    }

    function invariant_ProtocolBackingMatchesInternalAccounting() public view {
        uint256 aggregateBalances;
        uint256 totalAgents = agentNFT.totalAgents();

        for (uint256 i = 1; i <= totalAgents; ++i) {
            aggregateBalances += agentNFT.getAgent(i).balance;
        }

        assertEq(
            address(workEngine).balance,
            workEngine.rewardPoolBalance() + workEngine.communityPoolBalance() + aggregateBalances
        );
    }

    function invariant_PartnerLinksRemainSymmetric() public view {
        uint256 totalAgents = agentNFT.totalAgents();

        for (uint256 i = 1; i <= totalAgents; ++i) {
            uint256 partnerId = agentNFT.getAgent(i).partnerId;
            if (partnerId != 0) {
                assertEq(agentNFT.getAgent(partnerId).partnerId, i);
            }
        }
    }

    function invariant_RetiredAgentsNeverWorkAgain() public view {
        assertEq(handler.successfulRetiredWorkCalls(), 0);
    }

    function invariant_ChildIdsAlwaysPointToExistingAgents() public view {
        uint256 totalAgents = agentNFT.totalAgents();

        for (uint256 i = 1; i <= totalAgents; ++i) {
            uint256[] memory childIds = agentNFT.getAgent(i).childIds;
            for (uint256 j = 0; j < childIds.length; ++j) {
                assertTrue(agentNFT.exists(childIds[j]));
            }
        }
    }
}
