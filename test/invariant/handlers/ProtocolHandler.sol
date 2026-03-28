// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";

import {AgentNFT} from "../../../src/AgentNFT.sol";
import {FamilyRegistry} from "../../../src/FamilyRegistry.sol";
import {Marketplace} from "../../../src/Marketplace.sol";
import {WorkEngine} from "../../../src/WorkEngine.sol";
import {AgentTypes} from "../../../src/libraries/AgentTypes.sol";

contract ProtocolHandler is Test {
    AgentNFT internal immutable agentNFT;
    FamilyRegistry internal immutable familyRegistry;
    WorkEngine internal immutable workEngine;
    Marketplace internal immutable marketplace;

    address[] internal actors;

    uint256 public successfulRetiredWorkCalls;

    constructor(
        AgentNFT agentNFT_,
        FamilyRegistry familyRegistry_,
        WorkEngine workEngine_,
        Marketplace marketplace_,
        address[] memory actors_
    ) {
        agentNFT = agentNFT_;
        familyRegistry = familyRegistry_;
        workEngine = workEngine_;
        marketplace = marketplace_;
        actors = actors_;
    }

    function work(uint256 actorSeed, uint256 agentSeed, uint256 counterpartySeed) external {
        uint256 totalAgents = agentNFT.totalAgents();
        if (totalAgents == 0) {
            return;
        }

        uint256 agentId = _agentId(agentSeed, totalAgents);
        uint256 counterpartyId = counterpartySeed % (totalAgents + 1);
        bool retiredBefore = agentNFT.getAgent(agentId).retired;

        vm.prank(_actor(actorSeed));
        try workEngine.work(agentId, counterpartyId) {
            if (retiredBefore) {
                successfulRetiredWorkCalls++;
            }
        } catch {}
    }

    function approveMarriage(uint256 actorSeed, uint256 agentSeed, uint256 otherSeed) external {
        uint256 totalAgents = agentNFT.totalAgents();
        if (totalAgents < 2) {
            return;
        }

        uint256 agentId = _agentId(agentSeed, totalAgents);
        uint256 otherId = _differentAgentId(otherSeed, totalAgents, agentId);

        vm.prank(_actor(actorSeed));
        try familyRegistry.approveMarriage(agentId, otherId) {} catch {}
    }

    function revokeMarriageApproval(uint256 actorSeed, uint256 agentSeed, uint256 otherSeed) external {
        uint256 totalAgents = agentNFT.totalAgents();
        if (totalAgents < 2) {
            return;
        }

        uint256 agentId = _agentId(agentSeed, totalAgents);
        uint256 otherId = _differentAgentId(otherSeed, totalAgents, agentId);

        vm.prank(_actor(actorSeed));
        try familyRegistry.revokeMarriageApproval(agentId, otherId) {} catch {}
    }

    function marry(uint256 actorSeed, uint256 agentSeed, uint256 otherSeed) external {
        uint256 totalAgents = agentNFT.totalAgents();
        if (totalAgents < 2) {
            return;
        }

        uint256 agentId = _agentId(agentSeed, totalAgents);
        uint256 otherId = _differentAgentId(otherSeed, totalAgents, agentId);

        vm.prank(_actor(actorSeed));
        try familyRegistry.marry(agentId, otherId) {} catch {}
    }

    function approveChild(uint256 actorSeed, uint256 agentSeed, uint256 otherSeed) external {
        uint256 totalAgents = agentNFT.totalAgents();
        if (totalAgents < 2) {
            return;
        }

        uint256 agentId = _agentId(agentSeed, totalAgents);
        uint256 otherId = _differentAgentId(otherSeed, totalAgents, agentId);

        vm.prank(_actor(actorSeed));
        try familyRegistry.approveChild(agentId, otherId) {} catch {}
    }

    function revokeChildApproval(uint256 actorSeed, uint256 agentSeed, uint256 otherSeed) external {
        uint256 totalAgents = agentNFT.totalAgents();
        if (totalAgents < 2) {
            return;
        }

        uint256 agentId = _agentId(agentSeed, totalAgents);
        uint256 otherId = _differentAgentId(otherSeed, totalAgents, agentId);

        vm.prank(_actor(actorSeed));
        try familyRegistry.revokeChildApproval(agentId, otherId) {} catch {}
    }

    function mintChild(uint256 actorSeed, uint256 agentSeed, uint256 otherSeed) external {
        uint256 totalAgents = agentNFT.totalAgents();
        if (totalAgents < 2) {
            return;
        }

        uint256 agentId = _agentId(agentSeed, totalAgents);
        uint256 otherId = _differentAgentId(otherSeed, totalAgents, agentId);
        address childOwner = agentNFT.ownerOf(agentId);

        vm.prank(_actor(actorSeed));
        try agentNFT.mintChild(agentId, otherId, childOwner, "InvariantKid", "ipfs://invariant-kid") {} catch {}
    }

    function listAgent(uint256 actorSeed, uint256 agentSeed, uint96 priceSeed) external {
        uint256 totalAgents = agentNFT.totalAgents();
        if (totalAgents == 0) {
            return;
        }

        uint256 agentId = _agentId(agentSeed, totalAgents);
        address actor = _actor(actorSeed);
        uint256 price = bound(uint256(priceSeed), 1 gwei, 5 ether);

        vm.startPrank(actor);
        try agentNFT.approve(address(marketplace), agentId) {} catch {}
        try marketplace.listAgent(agentId, price) {} catch {}
        vm.stopPrank();
    }

    function buyAgent(uint256 buyerSeed, uint256 agentSeed) external {
        uint256 totalAgents = agentNFT.totalAgents();
        if (totalAgents == 0) {
            return;
        }

        uint256 agentId = _agentId(agentSeed, totalAgents);
        AgentTypes.Listing memory listing = marketplace.getListing(agentId);
        if (listing.seller == address(0)) {
            return;
        }

        address buyer = _actor(buyerSeed);
        vm.deal(buyer, buyer.balance + listing.price);

        vm.prank(buyer);
        try marketplace.buyAgent{value: listing.price}(agentId) {} catch {}
    }

    function transferAgent(uint256 agentSeed, uint256 recipientSeed) external {
        uint256 totalAgents = agentNFT.totalAgents();
        if (totalAgents == 0) {
            return;
        }

        uint256 agentId = _agentId(agentSeed, totalAgents);
        address currentOwner = agentNFT.ownerOf(agentId);
        address recipient = _differentActor(recipientSeed, currentOwner);

        vm.prank(currentOwner);
        try agentNFT.transferFrom(currentOwner, recipient, agentId) {} catch {}
    }

    function delistAgent(uint256 actorSeed, uint256 agentSeed) external {
        uint256 totalAgents = agentNFT.totalAgents();
        if (totalAgents == 0) {
            return;
        }

        uint256 agentId = _agentId(agentSeed, totalAgents);
        vm.prank(_actor(actorSeed));
        try marketplace.delistAgent(agentId) {} catch {}
    }

    function _actor(uint256 actorSeed) private view returns (address) {
        return actors[actorSeed % actors.length];
    }

    function _agentId(uint256 seed, uint256 totalAgents) private pure returns (uint256) {
        return (seed % totalAgents) + 1;
    }

    function _differentAgentId(uint256 seed, uint256 totalAgents, uint256 currentAgentId)
        private
        pure
        returns (uint256)
    {
        uint256 candidate = _agentId(seed, totalAgents);
        if (candidate == currentAgentId) {
            return currentAgentId == totalAgents ? 1 : currentAgentId + 1;
        }

        return candidate;
    }

    function _differentActor(uint256 actorSeed, address currentActor) private view returns (address) {
        address candidate = _actor(actorSeed);
        if (candidate == currentActor) {
            return actors[(actorSeed + 1) % actors.length];
        }

        return candidate;
    }
}
