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
    event FamilyRegistrySet(address indexed previousRegistry, address indexed newRegistry);
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
        agentId = _mintAgent(recipient, name, traits, personalityCID);
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
        agent.balance += amount;
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
            _agents[agent.childIds[i]].balance += sharePerChild;
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
        string calldata personalityCID
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

        parentA.balance -= parentAFunding;
        parentB.balance -= parentBFunding;

        childId = _mintAgent(childOwner, childName, childTraits, personalityCID);

        _agents[childId].balance = parentAFunding + parentBFunding;
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

    function _getAgentStorage(uint256 agentId) private view returns (AgentTypes.Agent storage agent) {
        _requireMinted(agentId);
        agent = _agents[agentId];
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
