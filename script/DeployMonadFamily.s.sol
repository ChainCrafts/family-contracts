// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script} from "forge-std/Script.sol";
import {console2} from "forge-std/console2.sol";

import {AgentNFT} from "../src/AgentNFT.sol";
import {FamilyRegistry} from "../src/FamilyRegistry.sol";
import {WorkEngine} from "../src/WorkEngine.sol";
import {Marketplace} from "../src/Marketplace.sol";

contract DeployMonadFamily is Script {
    function run()
        external
        returns (AgentNFT agentNFT, FamilyRegistry familyRegistry, WorkEngine workEngine, Marketplace marketplace)
    {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        uint256 initialRewardPool = vm.envOr("INITIAL_REWARD_POOL", uint256(0));
        address deployer = vm.addr(deployerPrivateKey);

        vm.startBroadcast(deployerPrivateKey);

        agentNFT = new AgentNFT(deployer);
        familyRegistry = new FamilyRegistry(deployer, address(agentNFT));
        workEngine = new WorkEngine(deployer, address(agentNFT), address(familyRegistry));
        marketplace = new Marketplace(address(agentNFT));

        agentNFT.setFamilyRegistry(address(familyRegistry));
        familyRegistry.setWorkEngine(address(workEngine));
        agentNFT.setWorkEngine(address(workEngine));
        agentNFT.setMarketplace(address(marketplace));

        if (initialRewardPool != 0) {
            workEngine.fundRewardPool{value: initialRewardPool}();
        }

        vm.stopBroadcast();

        console2.log("AgentNFT:", address(agentNFT));
        console2.log("FamilyRegistry:", address(familyRegistry));
        console2.log("WorkEngine:", address(workEngine));
        console2.log("Marketplace:", address(marketplace));
    }
}
