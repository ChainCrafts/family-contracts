// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {FamilyRegistry} from "../../../src/FamilyRegistry.sol";
import {Errors} from "../../../src/libraries/Errors.sol";
import {BaseFixture} from "../../utils/BaseFixture.t.sol";

contract FamilyRegistryModuleWiringTest is BaseFixture {
    function test_SetWorkEngineAllowsRewiringBeforeFreeze() public {
        address newWorkEngine = makeAddr("newWorkEngine");

        vm.prank(owner);
        familyRegistry.setWorkEngine(newWorkEngine);

        assertEq(familyRegistry.workEngine(), newWorkEngine);
    }

    function test_RevertWhen_SettingAfterFreeze() public {
        vm.prank(owner);
        familyRegistry.freezeModuleWiring();

        vm.expectRevert(Errors.ConfigurationFrozen.selector);

        vm.prank(owner);
        familyRegistry.setWorkEngine(makeAddr("replacementWorkEngine"));
    }

    function test_RevertWhen_FreezingWithoutWorkEngine() public {
        FamilyRegistry freshFamilyRegistry = new FamilyRegistry(owner, address(agentNFT));

        vm.expectRevert(Errors.NotConfigured.selector);

        vm.prank(owner);
        freshFamilyRegistry.freezeModuleWiring();
    }
}
