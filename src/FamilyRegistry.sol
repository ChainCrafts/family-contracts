// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

import {IAgentNFT} from "./interfaces/IAgentNFT.sol";
import {IFamilyRegistry} from "./interfaces/IFamilyRegistry.sol";
import {AgentTypes} from "./libraries/AgentTypes.sol";
import {Errors} from "./libraries/Errors.sol";

contract FamilyRegistry is Ownable, IFamilyRegistry {
    IAgentNFT public immutable agentNFT;
    address public workEngine;
    bool public moduleWiringFrozen;

    mapping(bytes32 pairKey => uint8 compatibility) private _compatibility;
    mapping(bytes32 pairKey => mapping(uint256 agentId => address approverOwner)) private _marriageApprovals;
    mapping(bytes32 pairKey => mapping(uint256 agentId => address approverOwner)) private _childApprovals;

    event AgentBonded(uint256 indexed agentA, uint256 indexed agentB, uint8 compatibility);
    event AgentMarried(uint256 indexed agentA, uint256 indexed agentB);
    event MarriageApprovalGranted(uint256 indexed agentSelfId, uint256 indexed agentOtherId, address indexed approver);
    event MarriageApprovalRevoked(uint256 indexed agentSelfId, uint256 indexed agentOtherId, address indexed approver);
    event ChildApprovalGranted(uint256 indexed parentAId, uint256 indexed parentBId, address indexed approver);
    event ChildApprovalRevoked(uint256 indexed parentAId, uint256 indexed parentBId, address indexed approver);
    event WorkEngineSet(address indexed previousEngine, address indexed newEngine);
    event ModuleWiringFrozen();

    constructor(address initialOwner, address agentNFTAddress) Ownable(initialOwner) {
        if (agentNFTAddress == address(0) || initialOwner == address(0)) {
            revert Errors.ZeroAddress();
        }

        agentNFT = IAgentNFT(agentNFTAddress);
    }

    modifier onlyWorkEngine() {
        if (msg.sender != workEngine) {
            revert Errors.UnauthorizedModule(msg.sender);
        }
        _;
    }

    modifier onlyAgentNFT() {
        if (msg.sender != address(agentNFT)) {
            revert Errors.UnauthorizedModule(msg.sender);
        }
        _;
    }

    function setWorkEngine(address engine) external onlyOwner {
        if (moduleWiringFrozen) {
            revert Errors.ConfigurationFrozen();
        }

        if (engine == address(0)) {
            revert Errors.ZeroAddress();
        }

        address previousEngine = workEngine;
        workEngine = engine;
        emit WorkEngineSet(previousEngine, engine);
    }

    function freezeModuleWiring() external onlyOwner {
        if (moduleWiringFrozen) {
            revert Errors.ConfigurationFrozen();
        }

        if (workEngine == address(0)) {
            revert Errors.NotConfigured();
        }

        moduleWiringFrozen = true;
        emit ModuleWiringFrozen();
    }

    function approveMarriage(uint256 agentSelfId, uint256 agentOtherId) external {
        _requireDistinctPair(agentSelfId, agentOtherId);
        _requireAuthorizedOwnerOrOperator(msg.sender, agentSelfId);

        bytes32 pairKey = _pairKey(agentSelfId, agentOtherId);
        _marriageApprovals[pairKey][agentSelfId] = agentNFT.ownerOf(agentSelfId);

        emit MarriageApprovalGranted(agentSelfId, agentOtherId, msg.sender);
    }

    function revokeMarriageApproval(uint256 agentSelfId, uint256 agentOtherId) external {
        _requireDistinctPair(agentSelfId, agentOtherId);
        _requireAuthorizedOwnerOrOperator(msg.sender, agentSelfId);

        delete _marriageApprovals[_pairKey(agentSelfId, agentOtherId)][agentSelfId];

        emit MarriageApprovalRevoked(agentSelfId, agentOtherId, msg.sender);
    }

    function approveChild(uint256 parentAId, uint256 parentBId) external {
        _requireDistinctPair(parentAId, parentBId);
        _requireAuthorizedOwnerOrOperator(msg.sender, parentAId);

        AgentTypes.Agent memory parentA = agentNFT.getAgent(parentAId);
        AgentTypes.Agent memory parentB = agentNFT.getAgent(parentBId);
        if (parentA.retired) {
            revert Errors.AgentRetired(parentAId);
        }

        if (parentB.retired) {
            revert Errors.AgentRetired(parentBId);
        }

        if (parentA.partnerId != parentBId || parentB.partnerId != parentAId) {
            revert Errors.NotMarriedPair(parentAId, parentBId);
        }

        bytes32 pairKey = _pairKey(parentAId, parentBId);
        _childApprovals[pairKey][parentAId] = agentNFT.ownerOf(parentAId);

        emit ChildApprovalGranted(parentAId, parentBId, msg.sender);
    }

    function revokeChildApproval(uint256 parentAId, uint256 parentBId) external {
        _requireDistinctPair(parentAId, parentBId);
        _requireAuthorizedOwnerOrOperator(msg.sender, parentAId);

        delete _childApprovals[_pairKey(parentAId, parentBId)][parentAId];

        emit ChildApprovalRevoked(parentAId, parentBId, msg.sender);
    }

    function marry(uint256 agentAId, uint256 agentBId) external {
        _requireDistinctPair(agentAId, agentBId);

        if (!agentNFT.ownerOrApproved(msg.sender, agentAId) && !agentNFT.ownerOrApproved(msg.sender, agentBId)) {
            revert Errors.NotAgentOwnerOrApproved(agentAId, msg.sender);
        }

        AgentTypes.Agent memory agentA = agentNFT.getAgent(agentAId);
        AgentTypes.Agent memory agentB = agentNFT.getAgent(agentBId);

        if (agentA.retired) {
            revert Errors.AgentRetired(agentAId);
        }

        if (agentB.retired) {
            revert Errors.AgentRetired(agentBId);
        }

        if (agentA.partnerId != 0) {
            revert Errors.AlreadyMarried(agentAId);
        }

        if (agentB.partnerId != 0) {
            revert Errors.AlreadyMarried(agentBId);
        }

        if (agentA.age < AgentTypes.ADULT_AGE) {
            revert Errors.AgentTooYoung(agentAId, agentA.age, AgentTypes.ADULT_AGE);
        }

        if (agentB.age < AgentTypes.ADULT_AGE) {
            revert Errors.AgentTooYoung(agentBId, agentB.age, AgentTypes.ADULT_AGE);
        }

        bytes32 pairKey = _pairKey(agentAId, agentBId);
        uint8 compatibility = _compatibility[pairKey];
        if (compatibility < AgentTypes.MARRIAGE_THRESHOLD) {
            revert Errors.CompatibilityTooLow(agentAId, agentBId, compatibility, AgentTypes.MARRIAGE_THRESHOLD);
        }

        _requireRecordedApproval(_marriageApprovals[pairKey][agentAId], agentAId, agentAId, agentBId, true);
        _requireRecordedApproval(_marriageApprovals[pairKey][agentBId], agentBId, agentAId, agentBId, true);

        delete _marriageApprovals[pairKey][agentAId];
        delete _marriageApprovals[pairKey][agentBId];

        agentNFT.setPartnerIds(agentAId, agentBId);

        emit AgentMarried(agentAId, agentBId);
    }

    function incrementCompatibility(uint256 agentAId, uint256 agentBId)
        external
        onlyWorkEngine
        returns (uint8 compatibility)
    {
        _requireDistinctPair(agentAId, agentBId);

        bytes32 pairKey = _pairKey(agentAId, agentBId);
        uint256 updated = _compatibility[pairKey] + AgentTypes.COMPATIBILITY_INCREMENT;
        if (updated > AgentTypes.MAX_TRAIT_VALUE) {
            updated = AgentTypes.MAX_TRAIT_VALUE;
        }

        compatibility = uint8(updated);
        _compatibility[pairKey] = compatibility;

        emit AgentBonded(agentAId, agentBId, compatibility);
    }

    function consumeChildApproval(uint256 parentAId, uint256 parentBId) external onlyAgentNFT {
        _requireDistinctPair(parentAId, parentBId);

        bytes32 pairKey = _pairKey(parentAId, parentBId);
        _requireRecordedApproval(_childApprovals[pairKey][parentAId], parentAId, parentAId, parentBId, false);
        _requireRecordedApproval(_childApprovals[pairKey][parentBId], parentBId, parentAId, parentBId, false);

        delete _childApprovals[pairKey][parentAId];
        delete _childApprovals[pairKey][parentBId];
    }

    function getCompatibility(uint256 agentAId, uint256 agentBId) external view returns (uint8 compatibility) {
        _requireDistinctPair(agentAId, agentBId);
        compatibility = _compatibility[_pairKey(agentAId, agentBId)];
    }

    function canMarry(uint256 agentAId, uint256 agentBId) external view returns (bool ready) {
        _requireDistinctPair(agentAId, agentBId);

        AgentTypes.Agent memory agentA = agentNFT.getAgent(agentAId);
        AgentTypes.Agent memory agentB = agentNFT.getAgent(agentBId);
        if (
            agentA.retired || agentB.retired || agentA.partnerId != 0 || agentB.partnerId != 0
                || agentA.age < AgentTypes.ADULT_AGE || agentB.age < AgentTypes.ADULT_AGE
        ) {
            return false;
        }

        bytes32 pairKey = _pairKey(agentAId, agentBId);
        if (_compatibility[pairKey] < AgentTypes.MARRIAGE_THRESHOLD) {
            return false;
        }

        (bool agentAApproved, bool agentBApproved) = _getMarriageApprovals(pairKey, agentAId, agentBId);
        ready = agentAApproved && agentBApproved;
    }

    function getMissingMarriageApprovals(uint256 agentAId, uint256 agentBId)
        external
        view
        returns (bool agentAMissing, bool agentBMissing)
    {
        _requireDistinctPair(agentAId, agentBId);

        bytes32 pairKey = _pairKey(agentAId, agentBId);
        (bool agentAApproved, bool agentBApproved) = _getMarriageApprovals(pairKey, agentAId, agentBId);
        return (!agentAApproved, !agentBApproved);
    }

    function getCompatibilityRemainingForMarriage(uint256 agentAId, uint256 agentBId)
        external
        view
        returns (uint8 remaining)
    {
        _requireDistinctPair(agentAId, agentBId);

        uint8 compatibility = _compatibility[_pairKey(agentAId, agentBId)];
        if (compatibility >= AgentTypes.MARRIAGE_THRESHOLD) {
            return 0;
        }

        remaining = AgentTypes.MARRIAGE_THRESHOLD - compatibility;
    }

    function getFamily(uint256 agentId) external view returns (uint256 partnerId, uint256[] memory childIds) {
        AgentTypes.Agent memory agent = agentNFT.getAgent(agentId);
        return (agent.partnerId, agent.childIds);
    }

    function getHouseholdBalance(uint256 agentId) external view returns (uint256 householdBalance) {
        AgentTypes.Agent memory agent = agentNFT.getAgent(agentId);
        householdBalance = agent.balance;

        if (agent.partnerId != 0) {
            householdBalance += agentNFT.getAgent(agent.partnerId).balance;
        }
    }

    function areMarried(uint256 agentAId, uint256 agentBId) public view returns (bool married) {
        if (!agentNFT.exists(agentAId) || !agentNFT.exists(agentBId) || agentAId == 0 || agentBId == 0) {
            return false;
        }

        AgentTypes.Agent memory agentA = agentNFT.getAgent(agentAId);
        AgentTypes.Agent memory agentB = agentNFT.getAgent(agentBId);
        married = agentA.partnerId == agentBId && agentB.partnerId == agentAId;
    }

    function _pairKey(uint256 agentAId, uint256 agentBId) private pure returns (bytes32) {
        return agentAId < agentBId
            ? keccak256(abi.encodePacked(agentAId, agentBId))
            : keccak256(abi.encodePacked(agentBId, agentAId));
    }

    function _requireDistinctPair(uint256 agentAId, uint256 agentBId) private view {
        if (agentAId == 0 || agentBId == 0 || agentAId == agentBId) {
            revert Errors.InvalidPair(agentAId, agentBId);
        }

        if (!agentNFT.exists(agentAId)) {
            revert Errors.AgentDoesNotExist(agentAId);
        }

        if (!agentNFT.exists(agentBId)) {
            revert Errors.AgentDoesNotExist(agentBId);
        }
    }

    function _requireAuthorizedOwnerOrOperator(address caller, uint256 agentId) private view {
        if (!agentNFT.ownerOrApproved(caller, agentId)) {
            revert Errors.NotAgentOwnerOrApproved(agentId, caller);
        }
    }

    function _getMarriageApprovals(uint256 agentAId, uint256 agentBId) private view returns (bool, bool) {
        return _getMarriageApprovals(_pairKey(agentAId, agentBId), agentAId, agentBId);
    }

    function _getMarriageApprovals(bytes32 pairKey, uint256 agentAId, uint256 agentBId)
        private
        view
        returns (bool agentAApproved, bool agentBApproved)
    {
        agentAApproved = _hasRecordedApproval(_marriageApprovals[pairKey][agentAId], agentAId);
        agentBApproved = _hasRecordedApproval(_marriageApprovals[pairKey][agentBId], agentBId);
    }

    function _hasRecordedApproval(address recordedOwner, uint256 approverAgentId) private view returns (bool) {
        return recordedOwner != address(0) && recordedOwner == agentNFT.ownerOf(approverAgentId);
    }

    function _requireRecordedApproval(
        address recordedOwner,
        uint256 approverAgentId,
        uint256 leftAgentId,
        uint256 rightAgentId,
        bool marriageApproval
    ) private view {
        if (!_hasRecordedApproval(recordedOwner, approverAgentId)) {
            if (marriageApproval) {
                revert Errors.MarriageApprovalMissing(leftAgentId, rightAgentId);
            }

            revert Errors.ChildApprovalMissing(leftAgentId, rightAgentId);
        }
    }
}
