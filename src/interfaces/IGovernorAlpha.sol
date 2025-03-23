pragma solidity ^0.8.10;

interface IGovernorAlpha {
    /// @notice The total number of proposals
    function proposalCount() external returns (uint);
}
