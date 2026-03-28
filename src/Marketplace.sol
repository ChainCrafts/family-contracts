// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

import {IAgentNFT} from "./interfaces/IAgentNFT.sol";
import {IMarketplace} from "./interfaces/IMarketplace.sol";
import {AgentTypes} from "./libraries/AgentTypes.sol";
import {Errors} from "./libraries/Errors.sol";

contract Marketplace is ReentrancyGuard, IMarketplace {
    IAgentNFT public immutable agentNFT;

    mapping(uint256 agentId => AgentTypes.Listing listing) private _listings;

    event AgentListed(uint256 indexed agentId, uint256 price);
    event AgentSold(uint256 indexed agentId, address indexed buyer, uint256 price);

    constructor(address agentNFTAddress) {
        if (agentNFTAddress == address(0)) {
            revert Errors.ZeroAddress();
        }

        agentNFT = IAgentNFT(agentNFTAddress);
    }

    function listAgent(uint256 agentId, uint256 price) external {
        if (price == 0) {
            revert Errors.InvalidPrice(price);
        }

        if (!agentNFT.ownerOrApproved(msg.sender, agentId)) {
            revert Errors.NotAgentOwnerOrApproved(agentId, msg.sender);
        }

        if (!agentNFT.ownerOrApproved(address(this), agentId)) {
            revert Errors.MarketplaceApprovalMissing(agentId);
        }

        address seller = agentNFT.ownerOf(agentId);
        _listings[agentId] = AgentTypes.Listing({seller: seller, price: price});

        emit AgentListed(agentId, price);
    }

    function buyAgent(uint256 agentId) external payable nonReentrant {
        AgentTypes.Listing memory listing = _listings[agentId];
        if (listing.seller == address(0)) {
            revert Errors.ListingNotFound(agentId);
        }

        if (msg.value != listing.price) {
            revert Errors.IncorrectPayment(listing.price, msg.value);
        }

        address currentOwner = agentNFT.ownerOf(agentId);
        if (currentOwner != listing.seller) {
            revert Errors.SellerChanged(agentId, listing.seller, currentOwner);
        }

        if (!agentNFT.ownerOrApproved(address(this), agentId)) {
            revert Errors.MarketplaceApprovalMissing(agentId);
        }

        delete _listings[agentId];

        agentNFT.safeTransferFrom(listing.seller, msg.sender, agentId);

        (bool success,) = payable(listing.seller).call{value: listing.price}("");
        require(success, "SELLER_PAYMENT_FAILED");

        emit AgentSold(agentId, msg.sender, listing.price);
    }

    function delistAgent(uint256 agentId) external {
        AgentTypes.Listing memory listing = _listings[agentId];
        if (listing.seller == address(0)) {
            revert Errors.ListingNotFound(agentId);
        }

        if (listing.seller != msg.sender) {
            revert Errors.NotSeller(agentId, msg.sender);
        }

        delete _listings[agentId];
    }

    function getListing(uint256 agentId) external view returns (AgentTypes.Listing memory listing) {
        listing = _listings[agentId];
    }
}
