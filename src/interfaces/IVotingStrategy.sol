pragma solidity ^0.8.10;

interface IVotingStrategy {
    function power(address owner) external returns (uint);
    function weight(address owner) external returns (uint); 
    function reduce(bytes32[] memory attestations) external;
    function virtualization() external returns (bool);
}
