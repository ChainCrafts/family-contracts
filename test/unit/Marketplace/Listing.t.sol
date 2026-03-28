// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {AgentTypes} from "../../../src/libraries/AgentTypes.sol";
import {Errors} from "../../../src/libraries/Errors.sol";
import {BaseFixture} from "../../utils/BaseFixture.t.sol";

contract MarketplaceListingTest is BaseFixture {
    function test_ListRequiresApprovalAndNonZeroPrice() public {
        vm.expectRevert(abi.encodeWithSelector(Errors.InvalidPrice.selector, 0));

        vm.prank(alice);
        marketplace.listAgent(aliceAgentId, 0);

        vm.expectRevert(abi.encodeWithSelector(Errors.MarketplaceApprovalMissing.selector, aliceAgentId));

        vm.prank(alice);
        marketplace.listAgent(aliceAgentId, 1 ether);
    }

    function test_ListStoresSellerWhileOwnerRetainsNft() public {
        vm.prank(alice);
        agentNFT.approve(address(marketplace), aliceAgentId);

        vm.prank(alice);
        marketplace.listAgent(aliceAgentId, 1 ether);

        AgentTypes.Listing memory listing = marketplace.getListing(aliceAgentId);
        assertEq(listing.seller, alice);
        assertEq(listing.price, 1 ether);
        assertEq(agentNFT.ownerOf(aliceAgentId), alice);
    }

    function test_CurrentOwnerCanOverwriteStaleListingAfterTransfer() public {
        vm.prank(alice);
        agentNFT.approve(address(marketplace), aliceAgentId);

        vm.prank(alice);
        marketplace.listAgent(aliceAgentId, 1 ether);

        vm.prank(alice);
        agentNFT.transferFrom(alice, dave, aliceAgentId);

        vm.prank(dave);
        agentNFT.approve(address(marketplace), aliceAgentId);

        vm.prank(dave);
        marketplace.listAgent(aliceAgentId, 2 ether);

        AgentTypes.Listing memory listing = marketplace.getListing(aliceAgentId);
        assertEq(listing.seller, dave);
        assertEq(listing.price, 2 ether);
    }
}
