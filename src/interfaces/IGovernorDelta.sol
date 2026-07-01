pragma solidity ^0.8.10;

interface IGovernorDelta {
    function stake(address owner) external view returns (uint, uint);
}
