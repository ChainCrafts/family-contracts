// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {AgentTypes} from "../libraries/AgentTypes.sol";

interface IAgentNFT is IERC721 {
    function mint(
        address owner,
        string calldata name,
        uint8 jobType,
        uint8 riskScore,
        uint8 patience,
        uint8 socialScore,
        string calldata personalityCID
    ) external returns (uint256 agentId);

    function mintChild(uint256 parentAId, uint256 parentBId, string calldata childName, string calldata personalityCID)
        external
        returns (uint256 childId);

    function familyRegistry() external view returns (address);
    function workEngine() external view returns (address);
    function marketplace() external view returns (address);
    function totalAgents() external view returns (uint256);
    function exists(uint256 agentId) external view returns (bool);
    function ownerOrApproved(address caller, uint256 agentId) external view returns (bool);
    function getAgent(uint256 agentId) external view returns (AgentTypes.Agent memory agent);
    function incrementAge(uint256 agentId) external returns (uint256 newAge);
    function increaseBalance(uint256 agentId, uint256 amount) external;
    function retireAndDistribute(uint256 agentId) external returns (uint256 finalBalance, uint256 communityAllocation);
    function setPartnerIds(uint256 agentAId, uint256 agentBId) external;
}
