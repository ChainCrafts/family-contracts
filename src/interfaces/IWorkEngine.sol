// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

interface IWorkEngine {
    function fundRewardPool() external payable;
    function work(uint256 agentId, uint256 counterpartyId) external;
    function rewardPoolBalance() external view returns (uint256);
    function communityPoolBalance() external view returns (uint256);
}
