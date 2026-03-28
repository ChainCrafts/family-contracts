// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

import {IAgentNFT} from "./interfaces/IAgentNFT.sol";
import {IFamilyRegistry} from "./interfaces/IFamilyRegistry.sol";
import {IMarketplace} from "./interfaces/IMarketplace.sol";
import {AgentTypes} from "./libraries/AgentTypes.sol";
import {Errors} from "./libraries/Errors.sol";
import {TraitLib} from "./libraries/TraitLib.sol";

contract AgentNFT is ERC721, Ownable, IAgentNFT {
    struct ChildTraits {
        uint8 riskScore;
        uint8 patience;
        uint8 socialScore;
        uint8 jobType;
    }

    mapping(uint256 agentId => AgentTypes.Agent agent) private _agents;
    uint256 private _nextAgentId = 1;

    address public override familyRegistry;
    address public override workEngine;
    address public override marketplace;
    bool public moduleWiringFrozen;

    event AgentBorn(uint256 indexed childId, uint256 indexed parentAId, uint256 indexed parentBId, string name);
    event AgentMovedOut(uint256 indexed parentId, uint256 indexed childId, uint256 unlockedBalance, uint256 houseFunding);
    event AgentSicknessSet(uint256 indexed agentId, uint8 sicknessLevel, uint256 maxAge);
    event FamilyRegistrySet(address indexed previousRegistry, address indexed newRegistry);
    event MarriageBalancesMerged(uint256 indexed agentAId, uint256 indexed agentBId, uint256 combinedBalance);
    event WorkEngineSet(address indexed previousEngine, address indexed newEngine);
    event MarketplaceSet(address indexed previousMarketplace, address indexed newMarketplace);
    event ModuleWiringFrozen();

    constructor(address initialOwner) ERC721("MonadFamily", "MFAM") Ownable(initialOwner) {
        if (initialOwner == address(0)) {
            revert Errors.ZeroAddress();
        }
    }

    modifier onlyFamilyRegistry() {
        if (msg.sender != familyRegistry) {
            revert Errors.UnauthorizedModule(msg.sender);
        }
        _;
    }

    modifier onlyWorkEngine() {
        if (msg.sender != workEngine) {
            revert Errors.UnauthorizedModule(msg.sender);
        }
        _;
    }

    function setFamilyRegistry(address registry) external onlyOwner {
        _requireWiringNotFrozen();
        _requireModuleAddress(registry);
        address previousRegistry = familyRegistry;
        familyRegistry = registry;
        emit FamilyRegistrySet(previousRegistry, registry);
    }

    function setWorkEngine(address engine) external onlyOwner {
        _requireWiringNotFrozen();
        _requireModuleAddress(engine);
        address previousEngine = workEngine;
        workEngine = engine;
        emit WorkEngineSet(previousEngine, engine);
    }

    function setMarketplace(address market) external onlyOwner {
        _requireWiringNotFrozen();
        _requireModuleAddress(market);
        address previousMarketplace = marketplace;
        marketplace = market;
        emit MarketplaceSet(previousMarketplace, market);
    }

    function freezeModuleWiring() external onlyOwner {
        _requireWiringNotFrozen();

        if (familyRegistry == address(0) || workEngine == address(0) || marketplace == address(0)) {
            revert Errors.NotConfigured();
        }

        moduleWiringFrozen = true;
        emit ModuleWiringFrozen();
    }

    function owner() public view override(Ownable, IAgentNFT) returns (address) {
        return super.owner();
    }

    function mint(
        address recipient,
        string calldata name,
        uint8 jobType,
        uint8 riskScore,
        uint8 patience,
        uint8 socialScore,
        string calldata personalityCID
    ) external onlyOwner returns (uint256 agentId) {
        ChildTraits memory traits = ChildTraits({
            riskScore: riskScore, patience: patience, socialScore: socialScore, jobType: jobType
        });
        agentId = _mintAgent(recipient, name, traits, personalityCID, AgentTypes.ADULT_AGE, true);
        emit AgentBorn(agentId, 0, 0, name);
    }

    /// @notice Mints a child NFT to an explicit parent-owner recipient after both parents approve.
    /// @dev `childOwner` must be the current owner of either parent. The caller must still be
    /// authorized for at least one parent agent.
    function mintChild(
        uint256 parentAId,
        uint256 parentBId,
        address childOwner,
        string calldata childName,
        string calldata personalityCID
    ) external returns (uint256 childId) {
        if (familyRegistry == address(0)) {
            revert Errors.NotConfigured();
        }

        _requireDistinctPair(parentAId, parentBId);

        AgentTypes.Agent storage parentA = _getAgentStorage(parentAId);
        AgentTypes.Agent storage parentB = _getAgentStorage(parentBId);

        if (parentA.retired) {
            revert Errors.AgentRetired(parentAId);
        }

        if (parentB.retired) {
            revert Errors.AgentRetired(parentBId);
        }

        if (parentA.partnerId != parentBId || parentB.partnerId != parentAId) {
            revert Errors.NotMarriedPair(parentAId, parentBId);
        }

        _validateChildOwner(parentAId, parentBId, childOwner);
        IFamilyRegistry(familyRegistry).consumeChildApproval(parentAId, parentBId);

        childId = _createChild(parentAId, parentBId, childOwner, childName, personalityCID);

        emit AgentBorn(childId, parentAId, parentBId, childName);
    }

    function moveOut(uint256 parentId, uint256 childId) external {
        _requireMinted(parentId);
        AgentTypes.Agent storage child = _getAgentStorage(childId);

        if (
            msg.sender != owner() && !ownerOrApproved(msg.sender, parentId) && !ownerOrApproved(msg.sender, childId)
        ) {
            revert Errors.NotAgentOwnerOrApproved(parentId, msg.sender);
        }

        if (!_isParentOfChild(parentId, childId)) {
            revert Errors.NotParentOfChild(parentId, childId);
        }

        if (child.independent) {
            revert Errors.AlreadyIndependent(childId);
        }

        if (child.age < AgentTypes.ADULT_AGE) {
            revert Errors.AgentTooYoung(childId, child.age, AgentTypes.ADULT_AGE);
        }

        AgentTypes.Agent storage parent = _getAgentStorage(parentId);
        _decreaseBalance(parent, parentId, AgentTypes.MOVE_OUT_HOUSE_FUND);

        uint256 unlockedBalance = child.lockedBalance;
        child.lockedBalance = 0;
        child.balance += unlockedBalance + AgentTypes.MOVE_OUT_HOUSE_FUND;
        child.independent = true;

        emit AgentMovedOut(parentId, childId, unlockedBalance, AgentTypes.MOVE_OUT_HOUSE_FUND);
    }

    function setSickness(uint256 agentId, uint8 sicknessLevel) external onlyOwner {
        AgentTypes.Agent storage agent = _getAgentStorage(agentId);
        if (agent.retired) {
            revert Errors.AgentRetired(agentId);
        }

        if (agent.age < AgentTypes.SICKNESS_ASSESSMENT_AGE) {
            revert Errors.AgentTooYoung(agentId, agent.age, AgentTypes.SICKNESS_ASSESSMENT_AGE);
        }

        if (agent.sicknessEvaluated) {
            revert Errors.SicknessAlreadySet(agentId);
        }

        if (sicknessLevel > AgentTypes.MAX_SICKNESS_PENALTY) {
            revert Errors.InvalidSicknessLevel(sicknessLevel, AgentTypes.MAX_SICKNESS_PENALTY);
        }

        agent.sicknessLevel = sicknessLevel;
        agent.sicknessEvaluated = true;
        agent.maxAge = AgentTypes.MAX_AGE - sicknessLevel;

        emit AgentSicknessSet(agentId, sicknessLevel, agent.maxAge);
    }

    function totalAgents() external view returns (uint256) {
        return _nextAgentId - 1;
    }

    function exists(uint256 agentId) external view returns (bool) {
        return _ownerOf(agentId) != address(0);
    }

    function ownerOrApproved(address caller, uint256 agentId) public view returns (bool) {
        address agentOwner = _ownerOf(agentId);
        if (agentOwner == address(0)) {
            return false;
        }

        return caller == agentOwner || getApproved(agentId) == caller || isApprovedForAll(agentOwner, caller);
    }

    function getAgent(uint256 agentId) external view returns (AgentTypes.Agent memory agent) {
        _requireMinted(agentId);
        agent = _agents[agentId];
    }

    function getAgentCore(uint256 agentId)
        external
        view
        returns (
            uint256 id,
            uint8 jobType,
            uint8 riskScore,
            uint8 patience,
            uint8 socialScore,
            uint256 age,
            uint256 balance,
            uint256 partnerId,
            bool retired
        )
    {
        AgentTypes.Agent storage agent = _getAgentStorage(agentId);
        return (
            agent.id,
            agent.jobType,
            agent.riskScore,
            agent.patience,
            agent.socialScore,
            agent.age,
            agent.balance,
            agent.partnerId,
            agent.retired
        );
    }

    function getAgentChildCount(uint256 agentId) external view returns (uint256 childCount) {
        childCount = _getAgentStorage(agentId).childIds.length;
    }

    function getAgentChildAt(uint256 agentId, uint256 index) external view returns (uint256 childId) {
        childId = _getAgentStorage(agentId).childIds[index];
    }

    function incrementAge(uint256 agentId) external onlyWorkEngine returns (uint256 newAge) {
        AgentTypes.Agent storage agent = _getAgentStorage(agentId);
        if (agent.retired) {
            revert Errors.AgentRetired(agentId);
        }

        newAge = ++agent.age;
    }

    function increaseBalance(uint256 agentId, uint256 amount) external onlyWorkEngine {
        if (amount == 0) {
            revert Errors.ZeroAmount();
        }

        AgentTypes.Agent storage agent = _getAgentStorage(agentId);
        if (!agent.independent) {
            revert Errors.MoveOutRequired(agentId);
        }

        agent.balance += amount;
    }

    function decreaseBalance(uint256 agentId, uint256 amount) external onlyWorkEngine {
        if (amount == 0) {
            revert Errors.ZeroAmount();
        }

        AgentTypes.Agent storage agent = _getAgentStorage(agentId);
        _decreaseBalance(agent, agentId, amount);
    }

    function retireAndDistribute(uint256 agentId)
        external
        onlyWorkEngine
        returns (uint256 finalBalance, uint256 communityAllocation)
    {
        AgentTypes.Agent storage agent = _getAgentStorage(agentId);
        if (agent.retired) {
            revert Errors.AgentRetired(agentId);
        }

        finalBalance = agent.balance;
        agent.balance = 0;
        agent.retired = true;

        uint256 childCount = agent.childIds.length;
        if (childCount == 0) {
            return (finalBalance, finalBalance);
        }

        uint256 sharePerChild = finalBalance / childCount;
        uint256 totalDistributed = sharePerChild * childCount;

        for (uint256 i = 0; i < childCount; ++i) {
            _creditLifecycleBalance(agent.childIds[i], sharePerChild);
        }

        communityAllocation = finalBalance - totalDistributed;
    }

    function setPartnerIds(uint256 agentAId, uint256 agentBId) external onlyFamilyRegistry {
        _requireDistinctPair(agentAId, agentBId);

        AgentTypes.Agent storage agentA = _getAgentStorage(agentAId);
        AgentTypes.Agent storage agentB = _getAgentStorage(agentBId);

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

        agentA.partnerId = agentBId;
        agentB.partnerId = agentAId;
        agentA.independent = true;
        agentB.independent = true;

        uint256 combinedBalance = agentA.balance + agentA.lockedBalance + agentB.balance + agentB.lockedBalance;

        if (agentAId < agentBId) {
            agentA.balance = (combinedBalance / 2) + (combinedBalance % 2);
            agentB.balance = combinedBalance / 2;
        } else {
            agentB.balance = (combinedBalance / 2) + (combinedBalance % 2);
            agentA.balance = combinedBalance / 2;
        }

        agentA.lockedBalance = 0;
        agentB.lockedBalance = 0;

        emit MarriageBalancesMerged(agentAId, agentBId, combinedBalance);
    }

    function _update(address to, uint256 tokenId, address auth) internal virtual override returns (address from) {
        from = super._update(to, tokenId, auth);

        if (from != address(0) && to != from && marketplace != address(0)) {
            IMarketplace(marketplace).onAgentTransfer(tokenId);
        }
    }

    function _mintAgent(
        address recipient,
        string calldata name,
        ChildTraits memory traits,
        string calldata personalityCID,
        uint256 initialAge,
        bool independent
    )
        private
        returns (uint256 agentId)
    {
        if (recipient == address(0)) {
            revert Errors.ZeroAddress();
        }

        _validateAgentTraits(traits.jobType, traits.riskScore, traits.patience, traits.socialScore);

        agentId = _nextAgentId++;
        _mint(recipient, agentId);

        AgentTypes.Agent storage agent = _agents[agentId];
        agent.id = agentId;
        agent.name = name;
        agent.jobType = traits.jobType;
        agent.riskScore = traits.riskScore;
        agent.patience = traits.patience;
        agent.socialScore = traits.socialScore;
        agent.age = initialAge;
        agent.maxAge = AgentTypes.MAX_AGE;
        agent.independent = independent;
        agent.personalityCID = personalityCID;
    }

    function _validateChildOwner(uint256 parentAId, uint256 parentBId, address childOwner) private view {
        address parentAOwner = ownerOf(parentAId);
        address parentBOwner = ownerOf(parentBId);

        if (
            !_isCallerAuthorizedForAgent(msg.sender, parentAOwner, parentAId)
                && !_isCallerAuthorizedForAgent(msg.sender, parentBOwner, parentBId)
        ) {
            revert Errors.NotAgentOwnerOrApproved(parentAId, msg.sender);
        }

        if (childOwner == address(0)) {
            revert Errors.ZeroAddress();
        }

        if (childOwner != parentAOwner && childOwner != parentBOwner) {
            revert Errors.InvalidChildRecipient(childOwner);
        }
    }

    function _isCallerAuthorizedForAgent(address caller, address agentOwner, uint256 agentId) private view returns (bool) {
        return caller == agentOwner || getApproved(agentId) == caller || isApprovedForAll(agentOwner, caller);
    }

    function _createChild(
        uint256 parentAId,
        uint256 parentBId,
        address childOwner,
        string calldata childName,
        string calldata personalityCID
    ) private returns (uint256 childId) {
        AgentTypes.Agent storage parentA = _agents[parentAId];
        AgentTypes.Agent storage parentB = _agents[parentBId];

        ChildTraits memory childTraits = _blendChildTraits(parentA, parentB, parentAId, parentBId);

        uint256 parentAFunding = _childFunding(parentA.balance);
        uint256 parentBFunding = _childFunding(parentB.balance);

        _decreaseBalance(parentA, parentAId, parentAFunding);
        _decreaseBalance(parentB, parentBId, parentBFunding);

        childId = _mintAgent(childOwner, childName, childTraits, personalityCID, 0, false);

        _agents[childId].lockedBalance = parentAFunding + parentBFunding;
        parentA.childIds.push(childId);
        parentB.childIds.push(childId);
    }

    function _blendChildTraits(
        AgentTypes.Agent storage parentA,
        AgentTypes.Agent storage parentB,
        uint256 parentAId,
        uint256 parentBId
    ) private view returns (ChildTraits memory traits) {
        uint256 seed = uint256(
            keccak256(abi.encodePacked(block.prevrandao, block.timestamp, _nextAgentId, parentAId, parentBId))
        );
        (traits.riskScore, traits.patience, traits.socialScore, traits.jobType) =
            TraitLib.blendTraits(parentA, parentB, seed);
    }

    function _childFunding(uint256 parentBalance) private pure returns (uint256) {
        return (parentBalance * AgentTypes.CHILD_FUNDING_BPS) / AgentTypes.BPS_DENOMINATOR;
    }

    function _creditLifecycleBalance(uint256 agentId, uint256 amount) private {
        AgentTypes.Agent storage agent = _agents[agentId];
        if (agent.independent) {
            agent.balance += amount;
        } else {
            agent.lockedBalance += amount;
        }
    }

    function _decreaseBalance(AgentTypes.Agent storage agent, uint256 agentId, uint256 amount) private {
        if (amount > agent.balance) {
            revert Errors.InsufficientAgentBalance(agentId, amount, agent.balance);
        }

        agent.balance -= amount;
    }

    function _getAgentStorage(uint256 agentId) private view returns (AgentTypes.Agent storage agent) {
        _requireMinted(agentId);
        agent = _agents[agentId];
    }

    function _isParentOfChild(uint256 parentId, uint256 childId) private view returns (bool) {
        AgentTypes.Agent storage parent = _getAgentStorage(parentId);
        uint256 childCount = parent.childIds.length;
        for (uint256 i = 0; i < childCount; ++i) {
            if (parent.childIds[i] == childId) {
                return true;
            }
        }

        return false;
    }

    function _requireWiringNotFrozen() private view {
        if (moduleWiringFrozen) {
            revert Errors.ConfigurationFrozen();
        }
    }

    function _requireModuleAddress(address moduleAddress) private pure {
        if (moduleAddress == address(0)) {
            revert Errors.ZeroAddress();
        }
    }

    function _validateAgentTraits(uint8 jobType, uint8 riskScore, uint8 patience, uint8 socialScore) private pure {
        if (jobType > AgentTypes.MAX_JOB_TYPE) {
            revert Errors.InvalidJobType(jobType);
        }

        if (riskScore > AgentTypes.MAX_TRAIT_VALUE) {
            revert Errors.InvalidTraitValue(riskScore);
        }

        if (patience > AgentTypes.MAX_TRAIT_VALUE) {
            revert Errors.InvalidTraitValue(patience);
        }

        if (socialScore > AgentTypes.MAX_TRAIT_VALUE) {
            revert Errors.InvalidTraitValue(socialScore);
        }
    }

    function _requireMinted(uint256 agentId) private view {
        if (_ownerOf(agentId) == address(0)) {
            revert Errors.AgentDoesNotExist(agentId);
        }
    }

    function _requireDistinctPair(uint256 agentAId, uint256 agentBId) private pure {
        if (agentAId == 0 || agentBId == 0 || agentAId == agentBId) {
            revert Errors.InvalidPair(agentAId, agentBId);
        }
    }
}
