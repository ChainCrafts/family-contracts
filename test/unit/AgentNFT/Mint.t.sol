// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {Test} from "forge-std/Test.sol";

import {AgentNFT} from "../../../src/AgentNFT.sol";
import {AgentTypes} from "../../../src/libraries/AgentTypes.sol";
import {Errors} from "../../../src/libraries/Errors.sol";
import {BaseFixture} from "../../utils/BaseFixture.t.sol";

contract AgentNFTMintTest is BaseFixture {
    event AgentBorn(uint256 indexed childId, uint256 indexed parentAId, uint256 indexed parentBId, string name);

    function test_MintStoresTraitsAndOwnership() public {
        uint256 expectedId = agentNFT.totalAgents() + 1;

        vm.prank(owner);
        uint256 agentId = agentNFT.mint(dave, "Selim", AgentTypes.JOB_TRADER, 65, 44, 72, "ipfs://selim");

        AgentTypes.Agent memory agent = agentNFT.getAgent(agentId);

        assertEq(agentId, expectedId);
        assertEq(agentNFT.ownerOf(agentId), dave);
        assertEq(agent.id, agentId);
        assertEq(agent.name, "Selim");
        assertEq(agent.jobType, AgentTypes.JOB_TRADER);
        assertEq(agent.riskScore, 65);
        assertEq(agent.patience, 44);
        assertEq(agent.socialScore, 72);
        assertEq(agent.personalityCID, "ipfs://selim");
    }

    function test_GetAgentCoreReturnsCompactFields() public {
        vm.prank(owner);
        uint256 agentId = agentNFT.mint(dave, "Selim", AgentTypes.JOB_TRADER, 65, 44, 72, "ipfs://selim");

        (
            uint256 id,
            uint8 jobType,
            uint8 riskScore,
            uint8 patience,
            uint8 socialScore,
            uint256 age,
            uint256 balance,
            uint256 partnerId,
            bool retired
        ) = agentNFT.getAgentCore(agentId);

        assertEq(id, agentId);
        assertEq(jobType, AgentTypes.JOB_TRADER);
        assertEq(riskScore, 65);
        assertEq(patience, 44);
        assertEq(socialScore, 72);
        assertEq(age, AgentTypes.ADULT_AGE);
        assertEq(balance, 0);
        assertEq(partnerId, 0);
        assertFalse(retired);
    }

    function test_MintEmitsAgentBorn() public {
        uint256 expectedId = agentNFT.totalAgents() + 1;

        vm.expectEmit(address(agentNFT));
        emit AgentBorn(expectedId, 0, 0, "Naz");

        vm.prank(owner);
        agentNFT.mint(eve, "Naz", AgentTypes.JOB_LENDER, 12, 88, 41, "ipfs://naz");
    }

    function test_RevertWhen_NonOwnerMintsGenesisAgent() public {
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, alice));

        vm.prank(alice);
        agentNFT.mint(alice, "Denizhan", AgentTypes.JOB_FARMER, 25, 40, 55, "ipfs://unauthorized");
    }

    function test_RevertWhen_TraitOutOfBounds() public {
        vm.expectRevert(abi.encodeWithSelector(Errors.InvalidTraitValue.selector, uint8(101)));

        vm.prank(owner);
        agentNFT.mint(eve, "Bugra", AgentTypes.JOB_FARMER, 101, 50, 50, "ipfs://bad-trait");
    }
}
