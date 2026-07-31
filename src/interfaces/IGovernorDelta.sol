pragma solidity ^0.8.10;

import "@interfaces/IERC20.sol";

interface IGovernorDelta {
   
    function canonicalToken() external view returns (IERC20);

    function totalStaked() external view returns (uint);

    function stake(address owner) external view returns (uint, uint, uint);

    function getActions(uint proposalId) external view returns (address[] memory targets, uint[] memory values, string[] memory signatures, bytes[] memory calldatas);
    
}
