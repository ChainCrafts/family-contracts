// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IERC721Receiver} from "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

import {Marketplace} from "../../src/Marketplace.sol";

contract ReenteringBuyer is IERC721Receiver {
    Marketplace public immutable marketplace;

    uint256 public reentryAgentId;
    uint256 public reentryPrice;
    bool public attemptedReentry;
    bool public blockedByGuard;

    constructor(address marketplaceAddress) {
        marketplace = Marketplace(marketplaceAddress);
    }

    function configureReentry(uint256 agentId, uint256 price) external {
        reentryAgentId = agentId;
        reentryPrice = price;
        attemptedReentry = false;
        blockedByGuard = false;
    }

    function buy(uint256 agentId) external payable {
        marketplace.buyAgent{value: msg.value}(agentId);
    }

    function onERC721Received(address, address, uint256, bytes calldata) external returns (bytes4) {
        attemptedReentry = true;

        try marketplace.buyAgent{value: reentryPrice}(reentryAgentId) {
            blockedByGuard = false;
        } catch (bytes memory reason) {
            blockedByGuard = _selector(reason) == ReentrancyGuard.ReentrancyGuardReentrantCall.selector;
        }

        return IERC721Receiver.onERC721Received.selector;
    }

    function _selector(bytes memory reason) private pure returns (bytes4 selector_) {
        if (reason.length < 4) {
            return bytes4(0);
        }

        assembly {
            selector_ := mload(add(reason, 0x20))
        }
    }
}
