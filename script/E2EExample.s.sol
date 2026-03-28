// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script} from "forge-std/Script.sol";
import {console2} from "forge-std/console2.sol";

import {AgentNFT} from "../src/AgentNFT.sol";
import {FamilyRegistry} from "../src/FamilyRegistry.sol";
import {WorkEngine} from "../src/WorkEngine.sol";
import {Marketplace} from "../src/Marketplace.sol";

contract E2EExample is Script {
    uint8 internal constant MARRIAGE_THRESHOLD = 80;

    struct Actors {
        uint256 deployerPrivateKey;
        uint256 alicePrivateKey;
        uint256 bobPrivateKey;
        uint256 carolPrivateKey;
        address deployer;
        address alice;
        address bob;
        address carol;
    }

    struct Params {
        uint256 initialRewardPool;
        uint256 actorFunding;
        uint256 salePrice;
        string childName;
        string childCid;
    }

    struct Deployment {
        AgentNFT agentNFT;
        FamilyRegistry familyRegistry;
        WorkEngine workEngine;
        Marketplace marketplace;
        uint256 aliceAgentId;
        uint256 bobAgentId;
        uint256 carolAgentId;
        uint256 childId;
    }

    function run()
        external
        returns (AgentNFT agentNFT, FamilyRegistry familyRegistry, WorkEngine workEngine, Marketplace marketplace)
    {
        Actors memory actors = _loadActors();
        Params memory params = _loadParams();
        Deployment memory deployment = _deployAndSeed(actors, params);

        _runLifecycle(actors, params, deployment);
        _logResult(actors, deployment);

        agentNFT = deployment.agentNFT;
        familyRegistry = deployment.familyRegistry;
        workEngine = deployment.workEngine;
        marketplace = deployment.marketplace;
    }

    function _loadActors() internal view returns (Actors memory actors) {
        actors.deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        actors.alicePrivateKey = vm.envUint("ALICE_PRIVATE_KEY");
        actors.bobPrivateKey = vm.envUint("BOB_PRIVATE_KEY");
        actors.carolPrivateKey = vm.envUint("CAROL_PRIVATE_KEY");

        actors.deployer = vm.addr(actors.deployerPrivateKey);
        actors.alice = vm.addr(actors.alicePrivateKey);
        actors.bob = vm.addr(actors.bobPrivateKey);
        actors.carol = vm.addr(actors.carolPrivateKey);
    }

    function _loadParams() internal view returns (Params memory params) {
        params.initialRewardPool = vm.envOr("INITIAL_REWARD_POOL", uint256(100 ether));
        params.actorFunding = vm.envOr("E2E_ACTOR_FUNDING", uint256(0));
        params.salePrice = vm.envOr("E2E_SALE_PRICE", uint256(1 ether));
        params.childName = vm.envOr("E2E_CHILD_NAME", string("Nova"));
        params.childCid = vm.envOr("E2E_CHILD_CID", string("ipfs://nova"));
    }

    function _deployAndSeed(Actors memory actors, Params memory params) internal returns (Deployment memory deployment) {
        vm.startBroadcast(actors.deployerPrivateKey);

        deployment.agentNFT = new AgentNFT(actors.deployer);
        deployment.familyRegistry = new FamilyRegistry(actors.deployer, address(deployment.agentNFT));
        deployment.workEngine =
            new WorkEngine(actors.deployer, address(deployment.agentNFT), address(deployment.familyRegistry));
        deployment.marketplace = new Marketplace(address(deployment.agentNFT));

        deployment.agentNFT.setFamilyRegistry(address(deployment.familyRegistry));
        deployment.familyRegistry.setWorkEngine(address(deployment.workEngine));
        deployment.agentNFT.setWorkEngine(address(deployment.workEngine));
        deployment.agentNFT.setMarketplace(address(deployment.marketplace));
        deployment.workEngine.fundRewardPool{value: params.initialRewardPool}();

        if (params.actorFunding != 0) {
            payable(actors.alice).transfer(params.actorFunding);
            payable(actors.bob).transfer(params.actorFunding);
            payable(actors.carol).transfer(params.actorFunding);
        }

        deployment.aliceAgentId = deployment.agentNFT.mint(actors.alice, "Aylin", 0, 78, 34, 81, "ipfs://demo-aylin");
        deployment.bobAgentId = deployment.agentNFT.mint(actors.bob, "Mert", 1, 42, 76, 64, "ipfs://demo-mert");
        deployment.carolAgentId = deployment.agentNFT.mint(actors.carol, "Deniz", 2, 23, 89, 58, "ipfs://demo-deniz");

        vm.stopBroadcast();
    }

    function _runLifecycle(Actors memory actors, Params memory params, Deployment memory deployment) internal {
        while (
            deployment.familyRegistry.getCompatibility(deployment.aliceAgentId, deployment.bobAgentId)
                < MARRIAGE_THRESHOLD
        ) {
            vm.broadcast(actors.alicePrivateKey);
            deployment.workEngine.work(deployment.aliceAgentId, deployment.bobAgentId);
        }

        vm.broadcast(actors.alicePrivateKey);
        deployment.familyRegistry.approveMarriage(deployment.aliceAgentId, deployment.bobAgentId);

        vm.broadcast(actors.bobPrivateKey);
        deployment.familyRegistry.approveMarriage(deployment.bobAgentId, deployment.aliceAgentId);

        vm.broadcast(actors.alicePrivateKey);
        deployment.familyRegistry.marry(deployment.aliceAgentId, deployment.bobAgentId);

        vm.broadcast(actors.alicePrivateKey);
        deployment.familyRegistry.approveChild(deployment.aliceAgentId, deployment.bobAgentId);

        vm.broadcast(actors.bobPrivateKey);
        deployment.familyRegistry.approveChild(deployment.bobAgentId, deployment.aliceAgentId);

        vm.broadcast(actors.alicePrivateKey);
        deployment.childId = deployment.agentNFT.mintChild(
            deployment.aliceAgentId, deployment.bobAgentId, params.childName, params.childCid
        );

        vm.broadcast(actors.alicePrivateKey);
        deployment.agentNFT.approve(address(deployment.marketplace), deployment.childId);

        vm.broadcast(actors.alicePrivateKey);
        deployment.marketplace.listAgent(deployment.childId, params.salePrice);

        vm.broadcast(actors.carolPrivateKey);
        deployment.marketplace.buyAgent{value: params.salePrice}(deployment.childId);

        require(deployment.agentNFT.ownerOf(deployment.childId) == actors.carol, "E2E: child owner mismatch");
        require(
            deployment.familyRegistry.areMarried(deployment.aliceAgentId, deployment.bobAgentId), "E2E: marriage failed"
        );
    }

    function _logResult(Actors memory actors, Deployment memory deployment) internal view {
        console2.log("AgentNFT:", address(deployment.agentNFT));
        console2.log("FamilyRegistry:", address(deployment.familyRegistry));
        console2.log("WorkEngine:", address(deployment.workEngine));
        console2.log("Marketplace:", address(deployment.marketplace));
        console2.log("Alice agent:", deployment.aliceAgentId);
        console2.log("Bob agent:", deployment.bobAgentId);
        console2.log("Carol agent:", deployment.carolAgentId);
        console2.log("Child agent:", deployment.childId);
        console2.log(
            "Compatibility:",
            deployment.familyRegistry.getCompatibility(deployment.aliceAgentId, deployment.bobAgentId)
        );
        console2.log("Child owner:", deployment.agentNFT.ownerOf(deployment.childId));
        console2.log("Expected Carol owner:", actors.carol);
    }
}
