pragma solidity ^0.8.10;

interface IVotingStrategy {

    /// @notice Pre execution state snapshot 
    function virtualized() external returns (bool);

    /// @notice Pre execution state snapshot 
    function power(address owner) external returns (uint);

    /// @notice Pre execution state snapshot 
    function weight(address owner) external returns (uint);

    /// @notice Pre execution state snapshot 
    function predict(address owner, uint timestamp) external returns (uint); 

}
