// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";

import {AgentNFT} from "../../src/AgentNFT.sol";
import {FamilyRegistry} from "../../src/FamilyRegistry.sol";
import {Marketplace} from "../../src/Marketplace.sol";
import {WorkEngine} from "../../src/WorkEngine.sol";
import {AgentTypes} from "../../src/libraries/AgentTypes.sol";

abstract contract BaseFixture is Test {
    AgentNFT internal agentNFT;
    FamilyRegistry internal familyRegistry;
    WorkEngine internal workEngine;
    Marketplace internal marketplace;

    address internal owner = makeAddr("owner");
    address internal alice = makeAddr("alice");
    address internal bob = makeAddr("bob");
    address internal carol = makeAddr("carol");
    address internal dave = makeAddr("dave");
    address internal eve = makeAddr("eve");
    address internal operator = makeAddr("operator");

    uint256 internal aliceAgentId;
    uint256 internal bobAgentId;
    uint256 internal carolAgentId;

    function setUp() public virtual {
        vm.deal(owner, 2_000 ether);
        vm.deal(alice, 25 ether);
        vm.deal(bob, 25 ether);
        vm.deal(carol, 25 ether);
        vm.deal(dave, 25 ether);
        vm.deal(eve, 25 ether);
        vm.deal(operator, 25 ether);

        vm.startPrank(owner);

        agentNFT = new AgentNFT(owner);
        familyRegistry = new FamilyRegistry(owner, address(agentNFT));
        workEngine = new WorkEngine(owner, address(agentNFT), address(familyRegistry));
        marketplace = new Marketplace(address(agentNFT));

        agentNFT.setFamilyRegistry(address(familyRegistry));
        familyRegistry.setWorkEngine(address(workEngine));
        agentNFT.setWorkEngine(address(workEngine));
        agentNFT.setMarketplace(address(marketplace));
        workEngine.fundRewardPool{value: 1_000 ether}();

        aliceAgentId = agentNFT.mint(alice, "Aylin", AgentTypes.JOB_TRADER, 78, 34, 81, "ipfs://aylin");
        bobAgentId = agentNFT.mint(bob, "Mert", AgentTypes.JOB_FARMER, 42, 76, 64, "ipfs://mert");
        carolAgentId = agentNFT.mint(carol, "Deniz", AgentTypes.JOB_LENDER, 23, 89, 58, "ipfs://deniz");

        vm.stopPrank();
    }

    function _mintAgent(
        address ownerAddress,
        string memory name,
        uint8 jobType,
        uint8 riskScore,
        uint8 patience,
        uint8 socialScore,
        string memory personalityCid
    ) internal returns (uint256) {
        vm.prank(owner);
        return agentNFT.mint(ownerAddress, name, jobType, riskScore, patience, socialScore, personalityCid);
    }

    function _approveMarriageBoth(uint256 agentAId, uint256 agentBId) internal {
        vm.prank(agentNFT.ownerOf(agentAId));
        familyRegistry.approveMarriage(agentAId, agentBId);

        vm.prank(agentNFT.ownerOf(agentBId));
        familyRegistry.approveMarriage(agentBId, agentAId);
    }

    function _approveChildBoth(uint256 agentAId, uint256 agentBId) internal {
        vm.prank(agentNFT.ownerOf(agentAId));
        familyRegistry.approveChild(agentAId, agentBId);

        vm.prank(agentNFT.ownerOf(agentBId));
        familyRegistry.approveChild(agentBId, agentAId);
    }

    function _workAs(address caller, uint256 agentId, uint256 counterpartyId) internal {
        vm.prank(caller);
        workEngine.work(agentId, counterpartyId);
    }

    function _setCompatibilityToThreshold(uint256 agentAId, uint256 agentBId) internal {
        while (familyRegistry.getCompatibility(agentAId, agentBId) < AgentTypes.MARRIAGE_THRESHOLD) {
            vm.prank(agentNFT.ownerOf(agentAId));
            workEngine.work(agentAId, agentBId);
        }
    }
}
