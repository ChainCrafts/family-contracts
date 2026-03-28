// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Errors} from "../../src/libraries/Errors.sol";
import {BaseFixture} from "../utils/BaseFixture.t.sol";

contract AuthorizationMatrixIntegrationTest is BaseFixture {
    function test_RevertWhen_ExternallyCallingAgentNftModuleFunctions() public {
        vm.expectRevert(abi.encodeWithSelector(Errors.UnauthorizedModule.selector, address(this)));
        agentNFT.incrementAge(aliceAgentId);

        vm.expectRevert(abi.encodeWithSelector(Errors.UnauthorizedModule.selector, address(this)));
        agentNFT.increaseBalance(aliceAgentId, 1 ether);

        vm.expectRevert(abi.encodeWithSelector(Errors.UnauthorizedModule.selector, address(this)));
        agentNFT.retireAndDistribute(aliceAgentId);

        vm.expectRevert(abi.encodeWithSelector(Errors.UnauthorizedModule.selector, address(this)));
        agentNFT.setPartnerIds(aliceAgentId, bobAgentId);
    }

    function test_RevertWhen_ExternallyCallingFamilyRegistryModuleFunctions() public {
        vm.expectRevert(abi.encodeWithSelector(Errors.UnauthorizedModule.selector, address(this)));
        familyRegistry.incrementCompatibility(aliceAgentId, bobAgentId);

        vm.expectRevert(abi.encodeWithSelector(Errors.UnauthorizedModule.selector, address(this)));
        familyRegistry.consumeChildApproval(aliceAgentId, bobAgentId);
    }
}
