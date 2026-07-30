pragma solidity ^0.8.10;

import "@interfaces/IProposalGuard.sol";
import "@interfaces/IGovernorDelta.sol";

contract GuardStorage {

    event PermitAddress(address indexed target);

    event OmitAddress(address indexed target);

}

contract WhitelistGuard is GuardStorage, IProposalGuard {

    address public governor;

    address public timelock;

    mapping(address => bool) public whitelist;

    constructor(address governor_, address timelock_, address[] memory targets_) {
        governor = governor_;
        timelock = timelock_;

        _set(targets_, true);
    } 

    function record(address target, uint proposalId) public {
        require(msg.sender == governor || msg.sender == timelock, "TransferGuard::record: only admin");
        (address[] memory targets, , ,) IGovernorDelta(governor).getActions(proposalId);

        for (uint8 i = 0; i < targets.length; i++) {
            require(whitelist[targets[i]], "WhitelistGuard::record: action call target not whitelisted");
        }
    }
  
    function compare(address target, uint proposalId) public {
        require(msg.sender == governor || msg.sender == timelock, "TransferGuard::compare: only admin");
    }
  
    function remove(address source) public {
        require(msg.sender == governor, "TransferGuard::remove: only admin");
        require(whitelist[source], "TransferGuard::remove: not tracked");
        delete whitelist[source];

        emit OmitAddress(source);
    }

    function add(address source) public {
        require(msg.sender == governor, "TransferGuard::add: only admin");
        require(!whitelist[source], "TransferGuard::add: already tracked");
        whitelist[source] = true;

        emit PermitAddress(source);
    }

    function overwrite(address[] memory inputs, bool option) public {
        require(msg.sender == governor, "TransferGuard::overwrite: only admin"); 

        _set(inputs, option);
    }

    function _set(address[] memory entries, bool flag) internal {
        for (uint8 i = 0; i < entries.length; i++) {
            address target = entries[i];
            whitelist[target] = flag;

            emit PermitAddress(target);
        } 
    }

}

