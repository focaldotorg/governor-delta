pragma solidity ^0.8.10;

interface IVotingStrategy {
    function virtualization() external returns (bool);
    function power(address owner) external returns (uint);
    function weight(address owner) external returns (uint);
    function predict(address owner, uint timestamp) external returns (uint); 
}
