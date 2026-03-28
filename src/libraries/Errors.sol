// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

library Errors {
    error AlreadyConfigured();
    error AgentDoesNotExist(uint256 agentId);
    error AgentRetired(uint256 agentId);
    error AgentTooYoung(uint256 agentId, uint256 age, uint256 requiredAge);
    error AlreadyMarried(uint256 agentId);
    error AlreadyIndependent(uint256 agentId);
    error ChildApprovalMissing(uint256 parentAId, uint256 parentBId);
    error ConfigurationFrozen();
    error InvalidChildRecipient(address recipient);
    error InvalidSicknessLevel(uint8 sicknessLevel, uint8 maxSicknessLevel);
    error CompatibilityTooLow(uint256 agentAId, uint256 agentBId, uint8 compatibility, uint8 threshold);
    error IncorrectPayment(uint256 expected, uint256 actual);
    error InsufficientAgentBalance(uint256 agentId, uint256 requested, uint256 available);
    error InsufficientRewardPool(uint256 requested, uint256 available);
    error InvalidCounterparty(uint256 counterpartyId);
    error InvalidJobType(uint8 jobType);
    error InvalidPair(uint256 agentAId, uint256 agentBId);
    error InvalidPrice(uint256 price);
    error InvalidTraitValue(uint8 value);
    error ListingNotFound(uint256 agentId);
    error MarketplaceApprovalMissing(uint256 agentId);
    error MarriageApprovalMissing(uint256 agentAId, uint256 agentBId);
    error MoveOutRequired(uint256 agentId);
    error NotAgentOwner(uint256 agentId, address caller);
    error NotAgentOwnerOrApproved(uint256 agentId, address caller);
    error NotConfigured();
    error NotMarriedPair(uint256 agentAId, uint256 agentBId);
    error NotParentOfChild(uint256 parentId, uint256 childId);
    error NotSeller(uint256 agentId, address caller);
    error SellerChanged(uint256 agentId, address expectedSeller, address actualSeller);
    error SicknessAssessmentRequired(uint256 agentId);
    error SicknessAlreadySet(uint256 agentId);
    error UnauthorizedModule(address caller);
    error ZeroAddress();
    error ZeroAmount();
}
