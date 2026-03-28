// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {AgentTypes} from "../libraries/AgentTypes.sol";

interface IMarketplace {
    function pause() external;
    function unpause() external;
    function listAgent(uint256 agentId, uint256 price) external;
    function buyAgent(uint256 agentId) external payable;
    function delistAgent(uint256 agentId) external;
    function cleanupStaleListing(uint256 agentId) external returns (bool cleaned);
    function onAgentTransfer(uint256 agentId) external;
    function getListing(uint256 agentId) external view returns (AgentTypes.Listing memory listing);
}
