pragma solidity ^0.8.10;

interface IProposalGuard {

  function record(address target, uint proposalId) external;

  function compare(address target, uint proposalId) external;

}




