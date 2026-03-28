// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Errors} from "../../../src/libraries/Errors.sol";
import {BaseFixture} from "../../utils/BaseFixture.t.sol";

contract AgentNFTBalanceTest is BaseFixture {
    function test_DecreaseBalanceReducesStoredBalance() public {
        vm.prank(address(workEngine));
        agentNFT.increaseBalance(aliceAgentId, 5 ether);

        vm.prank(address(workEngine));
        agentNFT.decreaseBalance(aliceAgentId, 2 ether);

        (, , , , , , uint256 balance,,) = agentNFT.getAgentCore(aliceAgentId);
        assertEq(balance, 3 ether);
    }

    function test_RevertWhen_DecreaseBalanceAmountIsZero() public {
        vm.expectRevert(abi.encodeWithSelector(Errors.ZeroAmount.selector));

        vm.prank(address(workEngine));
        agentNFT.decreaseBalance(aliceAgentId, 0);
    }

    function test_RevertWhen_DecreaseBalanceExceedsStoredBalance() public {
        vm.prank(address(workEngine));
        agentNFT.increaseBalance(aliceAgentId, 1 ether);

        vm.expectRevert(
            abi.encodeWithSelector(Errors.InsufficientAgentBalance.selector, aliceAgentId, 2 ether, 1 ether)
        );

        vm.prank(address(workEngine));
        agentNFT.decreaseBalance(aliceAgentId, 2 ether);
    }
}
