// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

interface IFamilyRegistry {
    function approveMarriage(uint256 agentSelfId, uint256 agentOtherId) external;
    function revokeMarriageApproval(uint256 agentSelfId, uint256 agentOtherId) external;
    function approveChild(uint256 parentAId, uint256 parentBId) external;
    function revokeChildApproval(uint256 parentAId, uint256 parentBId) external;
    function marry(uint256 agentAId, uint256 agentBId) external;
    function incrementCompatibility(uint256 agentAId, uint256 agentBId) external returns (uint8 compatibility);
    function consumeChildApproval(uint256 parentAId, uint256 parentBId) external;
    function getCompatibility(uint256 agentAId, uint256 agentBId) external view returns (uint8 compatibility);
    function canMarry(uint256 agentAId, uint256 agentBId) external view returns (bool ready);
    function getMissingMarriageApprovals(uint256 agentAId, uint256 agentBId)
        external
        view
        returns (bool agentAMissing, bool agentBMissing);
    function getCompatibilityRemainingForMarriage(uint256 agentAId, uint256 agentBId)
        external
        view
        returns (uint8 remaining);
    function getFamily(uint256 agentId) external view returns (uint256 partnerId, uint256[] memory childIds);
    function getHouseholdBalance(uint256 agentId) external view returns (uint256 householdBalance);
    function areMarried(uint256 agentAId, uint256 agentBId) external view returns (bool married);
}
