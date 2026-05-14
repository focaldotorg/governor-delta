pragma solidity ^0.8.10;

import "@interface/IGovernorDelta.sol";
import "GovernorStorageV3.sol";

contract GovernorDelta is GovernorStorageV3, IGovernorDelta {}
