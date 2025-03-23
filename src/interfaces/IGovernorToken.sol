pragma solidity ^0.8.10;

interface IGovernorToken {
    function getPriorVotes(address account, uint blockNumber) external view returns (uint96);
}

