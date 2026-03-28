// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {Pausable} from "@openzeppelin/contracts/utils/Pausable.sol";

import {IAgentNFT} from "./interfaces/IAgentNFT.sol";
import {IMarketplace} from "./interfaces/IMarketplace.sol";
import {AgentTypes} from "./libraries/AgentTypes.sol";
import {Errors} from "./libraries/Errors.sol";

contract Marketplace is ReentrancyGuard, Pausable, IMarketplace {
    IAgentNFT public immutable agentNFT;

    mapping(uint256 agentId => AgentTypes.Listing listing) private _listings;

    event AgentListed(uint256 indexed agentId, uint256 price);
    event AgentSold(uint256 indexed agentId, address indexed buyer, uint256 price);
    event AgentDelisted(uint256 indexed agentId, address indexed seller, uint256 price);

    constructor(address agentNFTAddress) {
        if (agentNFTAddress == address(0)) {
            revert Errors.ZeroAddress();
        }

        agentNFT = IAgentNFT(agentNFTAddress);
    }

    modifier onlyAgentNFT() {
        if (msg.sender != address(agentNFT)) {
            revert Errors.UnauthorizedModule(msg.sender);
        }
        _;
    }

    function pause() external {
        if (msg.sender != agentNFT.owner()) {
            revert Errors.UnauthorizedModule(msg.sender);
        }
        _pause();
    }

    function unpause() external {
        if (msg.sender != agentNFT.owner()) {
            revert Errors.UnauthorizedModule(msg.sender);
        }
        _unpause();
    }

    function listAgent(uint256 agentId, uint256 price) external whenNotPaused {
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

    function buyAgent(uint256 agentId) external payable nonReentrant whenNotPaused {
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

    function delistAgent(uint256 agentId) external whenNotPaused {
        AgentTypes.Listing memory listing = _listings[agentId];
        if (listing.seller == address(0)) {
            revert Errors.ListingNotFound(agentId);
        }

        if (listing.seller != msg.sender) {
            revert Errors.NotSeller(agentId, msg.sender);
        }

        delete _listings[agentId];

        emit AgentDelisted(agentId, listing.seller, listing.price);
    }

    function cleanupStaleListing(uint256 agentId) external returns (bool cleaned) {
        AgentTypes.Listing memory listing = _listings[agentId];
        if (listing.seller == address(0)) {
            return false;
        }

        if (agentNFT.exists(agentId)) {
            address currentOwner = agentNFT.ownerOf(agentId);
            if (currentOwner == listing.seller && agentNFT.ownerOrApproved(address(this), agentId)) {
                return false;
            }
        }

        _clearListing(agentId, listing);
        return true;
    }

    function onAgentTransfer(uint256 agentId) external onlyAgentNFT {
        AgentTypes.Listing memory listing = _listings[agentId];
        if (listing.seller != address(0)) {
            _clearListing(agentId, listing);
        }
    }

    function getListing(uint256 agentId) external view returns (AgentTypes.Listing memory listing) {
        listing = _listings[agentId];
    }

    function _clearListing(uint256 agentId, AgentTypes.Listing memory listing) private {
        delete _listings[agentId];
        emit AgentDelisted(agentId, listing.seller, listing.price);
    }
}
