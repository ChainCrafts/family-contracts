// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script} from "forge-std/Script.sol";

import {AgentNFT} from "../src/AgentNFT.sol";

contract SeedDemoAgents is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address agentNFTAddress = vm.envAddress("AGENT_NFT");

        vm.startBroadcast(deployerPrivateKey);

        AgentNFT agentNFT = AgentNFT(agentNFTAddress);
        agentNFT.mint(vm.envAddress("DEMO_OWNER_ALICE"), "Aylin", 0, 78, 34, 81, "ipfs://demo-aylin");
        agentNFT.mint(vm.envAddress("DEMO_OWNER_BOB"), "Mert", 1, 42, 76, 64, "ipfs://demo-mert");
        agentNFT.mint(vm.envAddress("DEMO_OWNER_CAROL"), "Deniz", 2, 23, 89, 58, "ipfs://demo-deniz");
    }
}
