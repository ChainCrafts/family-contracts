// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {Pausable} from "@openzeppelin/contracts/utils/Pausable.sol";

import {IAgentNFT} from "./interfaces/IAgentNFT.sol";
import {IFamilyRegistry} from "./interfaces/IFamilyRegistry.sol";
import {IWorkEngine} from "./interfaces/IWorkEngine.sol";
import {AgentTypes} from "./libraries/AgentTypes.sol";
import {Errors} from "./libraries/Errors.sol";

contract WorkEngine is Ownable, Pausable, IWorkEngine {
    IAgentNFT public immutable agentNFT;
    IFamilyRegistry public immutable familyRegistry;

    uint256 public rewardPoolBalance;
    uint256 public communityPoolBalance;

    event AgentWorked(uint256 indexed agentId, uint256 earned, uint256 newAge);
    event AgentRetired(uint256 indexed agentId, uint256 finalBalance);
    event RewardPoolFunded(address indexed funder, uint256 amount, uint256 newRewardPoolBalance);
    event CommunityPoolCredited(uint256 indexed agentId, uint256 amount, uint256 newCommunityPoolBalance);

    constructor(address initialOwner, address agentNFTAddress, address familyRegistryAddress) Ownable(initialOwner) {
        if (initialOwner == address(0) || agentNFTAddress == address(0) || familyRegistryAddress == address(0)) {
            revert Errors.ZeroAddress();
        }

        agentNFT = IAgentNFT(agentNFTAddress);
        familyRegistry = IFamilyRegistry(familyRegistryAddress);
    }

    function fundRewardPool() external payable onlyOwner {
        if (msg.value == 0) {
            revert Errors.ZeroAmount();
        }

        rewardPoolBalance += msg.value;

        emit RewardPoolFunded(msg.sender, msg.value, rewardPoolBalance);
    }

    function pause() external onlyOwner {
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
    }

    function work(uint256 agentId, uint256 counterpartyId) external whenNotPaused {
        AgentTypes.Agent memory agent = agentNFT.getAgent(agentId);
        if (agent.retired) {
            revert Errors.AgentRetired(agentId);
        }

        if (!agentNFT.ownerOrApproved(msg.sender, agentId)) {
            revert Errors.NotAgentOwnerOrApproved(agentId, msg.sender);
        }

        if (counterpartyId != 0) {
            if (counterpartyId == agentId) {
                revert Errors.InvalidPair(agentId, counterpartyId);
            }

            AgentTypes.Agent memory counterparty = agentNFT.getAgent(counterpartyId);
            if (counterparty.retired) {
                revert Errors.AgentRetired(counterpartyId);
            }

            familyRegistry.incrementCompatibility(agentId, counterpartyId);
        }

        uint256 earned = _calculateReward(agentId, agent.age, counterpartyId, agent.riskScore);
        if (earned > rewardPoolBalance) {
            revert Errors.InsufficientRewardPool(earned, rewardPoolBalance);
        }

        rewardPoolBalance -= earned;
        agentNFT.increaseBalance(agentId, earned);

        uint256 newAge = agentNFT.incrementAge(agentId);
        emit AgentWorked(agentId, earned, newAge);

        if (newAge >= AgentTypes.MAX_AGE) {
            (uint256 finalBalance, uint256 communityAllocation) = agentNFT.retireAndDistribute(agentId);
            communityPoolBalance += communityAllocation;

            if (communityAllocation != 0) {
                emit CommunityPoolCredited(agentId, communityAllocation, communityPoolBalance);
            }

            emit AgentRetired(agentId, finalBalance);
        }
    }

    /// @notice Previews the reward the agent would earn if `work` were called in the current block.
    /// @dev This uses the current block timestamp and prevrandao, so the value can change before a
    /// future transaction is mined.
    function previewWorkReward(uint256 agentId, uint256 counterpartyId) external view returns (uint256 earned) {
        AgentTypes.Agent memory agent = agentNFT.getAgent(agentId);
        if (agent.retired) {
            revert Errors.AgentRetired(agentId);
        }

        if (counterpartyId != 0) {
            if (counterpartyId == agentId) {
                revert Errors.InvalidPair(agentId, counterpartyId);
            }

            AgentTypes.Agent memory counterparty = agentNFT.getAgent(counterpartyId);
            if (counterparty.retired) {
                revert Errors.AgentRetired(counterpartyId);
            }
        }

        earned = _calculateReward(agentId, agent.age, counterpartyId, agent.riskScore);
    }

    function _calculateReward(uint256 agentId, uint256 currentAge, uint256 counterpartyId, uint8 riskScore)
        private
        view
        returns (uint256 earned)
    {
        uint256 entropy = uint256(
            keccak256(abi.encodePacked(agentId, currentAge, counterpartyId, block.prevrandao, block.timestamp))
        );
        uint256 riskVariance = (entropy % (uint256(riskScore) + 1)) * AgentTypes.RISK_REWARD_STEP;
        earned = AgentTypes.BASE_REWARD + riskVariance;
    }
}
