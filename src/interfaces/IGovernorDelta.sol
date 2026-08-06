pragma solidity ^0.8.10;

import "@interfaces/IERC20.sol";

interface IGovernorDelta {

    /// @notice The governing asset used to query voting weight 
    function canonicalToken() external view returns (IERC20);

    /// @notice The total amount of staked canonical tokens 
    function totalStaked() external view returns (uint);

    /// @notice Helper to query address stake values
    function stake(address owner) external view returns (uint, uint, uint);

    /// @notice Helper to query proposal action values
    function getActions(uint proposalId) external view returns (address[] memory targets, uint[] memory values, string[] memory signatures, bytes[] memory calldatas);
    
}
