pragma solidity ^0.8.10;

interface IGovernorDelta {
    function stake(address owner) external returns (uint, uint);
}
