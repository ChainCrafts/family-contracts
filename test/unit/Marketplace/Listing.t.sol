// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Pausable} from "@openzeppelin/contracts/utils/Pausable.sol";

import {AgentTypes} from "../../../src/libraries/AgentTypes.sol";
import {Errors} from "../../../src/libraries/Errors.sol";
import {BaseFixture} from "../../utils/BaseFixture.t.sol";

contract MarketplaceListingTest is BaseFixture {
    event AgentListed(uint256 indexed agentId, uint256 price);
    event AgentDelisted(uint256 indexed agentId, address indexed seller, uint256 price);

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

        vm.expectEmit(address(marketplace));
        emit AgentListed(aliceAgentId, 1 ether);

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

        vm.expectEmit(address(marketplace));
        emit AgentDelisted(aliceAgentId, alice, 1 ether);

        vm.prank(alice);
        agentNFT.transferFrom(alice, dave, aliceAgentId);

        AgentTypes.Listing memory staleListing = marketplace.getListing(aliceAgentId);
        assertEq(staleListing.seller, address(0));
        assertEq(staleListing.price, 0);

        vm.prank(dave);
        agentNFT.approve(address(marketplace), aliceAgentId);

        vm.prank(dave);
        marketplace.listAgent(aliceAgentId, 2 ether);

        AgentTypes.Listing memory listing = marketplace.getListing(aliceAgentId);
        assertEq(listing.seller, dave);
        assertEq(listing.price, 2 ether);
    }

    function test_DelistEmitsEventAndClearsListing() public {
        vm.prank(alice);
        agentNFT.approve(address(marketplace), aliceAgentId);

        vm.prank(alice);
        marketplace.listAgent(aliceAgentId, 1 ether);

        vm.expectEmit(address(marketplace));
        emit AgentDelisted(aliceAgentId, alice, 1 ether);

        vm.prank(alice);
        marketplace.delistAgent(aliceAgentId);

        AgentTypes.Listing memory listing = marketplace.getListing(aliceAgentId);
        assertEq(listing.seller, address(0));
        assertEq(listing.price, 0);
    }

    function test_CleanupStaleListingClearsRevokedApprovalListing() public {
        vm.prank(alice);
        agentNFT.approve(address(marketplace), aliceAgentId);

        vm.prank(alice);
        marketplace.listAgent(aliceAgentId, 1 ether);

        vm.prank(alice);
        agentNFT.approve(address(0), aliceAgentId);

        vm.expectEmit(address(marketplace));
        emit AgentDelisted(aliceAgentId, alice, 1 ether);

        bool cleaned = marketplace.cleanupStaleListing(aliceAgentId);
        assertTrue(cleaned);

        AgentTypes.Listing memory listing = marketplace.getListing(aliceAgentId);
        assertEq(listing.seller, address(0));
        assertEq(listing.price, 0);
    }

    function test_CleanupStaleListingReturnsFalseForActiveListing() public {
        vm.prank(alice);
        agentNFT.approve(address(marketplace), aliceAgentId);

        vm.prank(alice);
        marketplace.listAgent(aliceAgentId, 1 ether);

        bool cleaned = marketplace.cleanupStaleListing(aliceAgentId);
        assertFalse(cleaned);

        AgentTypes.Listing memory listing = marketplace.getListing(aliceAgentId);
        assertEq(listing.seller, alice);
        assertEq(listing.price, 1 ether);
    }

    function test_RevertWhen_ListCalledWhilePaused() public {
        vm.prank(owner);
        marketplace.pause();

        vm.expectRevert(Pausable.EnforcedPause.selector);

        vm.prank(alice);
        marketplace.listAgent(aliceAgentId, 1 ether);
    }

    function test_RevertWhen_NonOwnerPausesMarketplace() public {
        vm.expectRevert(abi.encodeWithSelector(Errors.UnauthorizedModule.selector, alice));

        vm.prank(alice);
        marketplace.pause();
    }

    function test_RevertWhen_DelistCalledWhilePaused() public {
        vm.prank(alice);
        agentNFT.approve(address(marketplace), aliceAgentId);

        vm.prank(alice);
        marketplace.listAgent(aliceAgentId, 1 ether);

        vm.prank(owner);
        marketplace.pause();

        vm.expectRevert(Pausable.EnforcedPause.selector);

        vm.prank(alice);
        marketplace.delistAgent(aliceAgentId);
    }

    function test_UnpauseRestoresListing() public {
        vm.prank(owner);
        marketplace.pause();

        vm.prank(owner);
        marketplace.unpause();

        vm.prank(alice);
        agentNFT.approve(address(marketplace), aliceAgentId);

        vm.prank(alice);
        marketplace.listAgent(aliceAgentId, 1 ether);

        AgentTypes.Listing memory listing = marketplace.getListing(aliceAgentId);
        assertEq(listing.seller, alice);
        assertEq(listing.price, 1 ether);
    }
}
