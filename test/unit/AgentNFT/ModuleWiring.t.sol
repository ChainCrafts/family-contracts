// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {AgentNFT} from "../../../src/AgentNFT.sol";
import {Errors} from "../../../src/libraries/Errors.sol";
import {BaseFixture} from "../../utils/BaseFixture.t.sol";

contract AgentNFTModuleWiringTest is BaseFixture {
    function test_SettersAllowRewiringBeforeFreeze() public {
        address newFamilyRegistry = makeAddr("newFamilyRegistry");
        address newWorkEngine = makeAddr("newWorkEngine");
        address newMarketplace = makeAddr("newMarketplace");

        vm.startPrank(owner);
        agentNFT.setFamilyRegistry(newFamilyRegistry);
        agentNFT.setWorkEngine(newWorkEngine);
        agentNFT.setMarketplace(newMarketplace);
        vm.stopPrank();

        assertEq(agentNFT.familyRegistry(), newFamilyRegistry);
        assertEq(agentNFT.workEngine(), newWorkEngine);
        assertEq(agentNFT.marketplace(), newMarketplace);
    }

    function test_RevertWhen_SettingAfterFreeze() public {
        vm.prank(owner);
        agentNFT.freezeModuleWiring();

        vm.expectRevert(Errors.ConfigurationFrozen.selector);

        vm.prank(owner);
        agentNFT.setMarketplace(makeAddr("replacementMarketplace"));
    }

    function test_RevertWhen_FreezingWithoutCompleteWiring() public {
        AgentNFT freshAgentNft = new AgentNFT(owner);

        vm.expectRevert(Errors.NotConfigured.selector);

        vm.prank(owner);
        freshAgentNft.freezeModuleWiring();
    }
}
