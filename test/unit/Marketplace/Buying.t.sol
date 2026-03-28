// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Errors} from "../../../src/libraries/Errors.sol";
import {BaseFixture} from "../../utils/BaseFixture.t.sol";
import {ReenteringBuyer} from "../../mocks/ReenteringBuyer.sol";

contract MarketplaceBuyingTest is BaseFixture {
    function test_BuyTransfersAgentAndPaysSellerExactly() public {
        vm.deal(bob, 2 ether);

        vm.prank(alice);
        agentNFT.approve(address(marketplace), aliceAgentId);

        vm.prank(alice);
        marketplace.listAgent(aliceAgentId, 1 ether);

        uint256 sellerBalanceBefore = alice.balance;

        vm.prank(bob);
        marketplace.buyAgent{value: 1 ether}(aliceAgentId);

        assertEq(agentNFT.ownerOf(aliceAgentId), bob);
        assertEq(alice.balance, sellerBalanceBefore + 1 ether);
        assertEq(marketplace.getListing(aliceAgentId).seller, address(0));
    }

    function test_RevertWhen_PaymentMismatch() public {
        vm.deal(bob, 1 ether);

        vm.prank(alice);
        agentNFT.approve(address(marketplace), aliceAgentId);

        vm.prank(alice);
        marketplace.listAgent(aliceAgentId, 1 ether);

        vm.expectRevert(abi.encodeWithSelector(Errors.IncorrectPayment.selector, 1 ether, 0.5 ether));

        vm.prank(bob);
        marketplace.buyAgent{value: 0.5 ether}(aliceAgentId);
    }

    function test_RevertWhen_ApprovalRevokedAfterListing() public {
        vm.deal(bob, 1 ether);

        vm.prank(alice);
        agentNFT.approve(address(marketplace), aliceAgentId);

        vm.prank(alice);
        marketplace.listAgent(aliceAgentId, 1 ether);

        vm.prank(alice);
        agentNFT.approve(address(0), aliceAgentId);

        vm.expectRevert(abi.encodeWithSelector(Errors.MarketplaceApprovalMissing.selector, aliceAgentId));

        vm.prank(bob);
        marketplace.buyAgent{value: 1 ether}(aliceAgentId);
    }

    function test_ReentrancyIsBlockedForBuyerReceiver() public {
        ReenteringBuyer buyer = new ReenteringBuyer(address(marketplace));
        vm.deal(address(buyer), 3 ether);

        vm.prank(alice);
        agentNFT.approve(address(marketplace), aliceAgentId);
        vm.prank(alice);
        marketplace.listAgent(aliceAgentId, 1 ether);

        vm.prank(bob);
        agentNFT.approve(address(marketplace), bobAgentId);
        vm.prank(bob);
        marketplace.listAgent(bobAgentId, 1 ether);

        buyer.configureReentry(bobAgentId, 1 ether);
        buyer.buy{value: 1 ether}(aliceAgentId);

        assertEq(agentNFT.ownerOf(aliceAgentId), address(buyer));
        assertTrue(buyer.attemptedReentry());
        assertTrue(buyer.blockedByGuard());
        assertEq(agentNFT.ownerOf(bobAgentId), bob);
    }
}
