pragma solidity ^0.8.10;

import "@interfaces/IProposalGuard.sol";
import "@interfaces/IGovernorDelta.sol";

contract GuardStorage {

    event BlacklistSelector(bytes8 selector);

    event WhitelistSelector(bytes8 selector);

}

contract FunctionSelectorGuard is GuardStorage, IProposalGuard {

    address public governor;

    address public timelock;

    mapping(string => bool) public blacklist;

    constructor(address governor_, address timelock_, string[] memory selectors_) {
        governor = governor_;
        timelock = timelock_;

        _set(selectors_, true);
    } 

    function record(address target, uint proposalId) public {
        require(msg.sender == governor || msg.sender == timelock, "TransferGuard::record: only admin");
        (, , string[] memory signatures,) IGovernorDelta(governor).getActions(proposalId);

        for (uint8 i = 0; i < signatures.length; i++) {
            require(!blacklist[signatures[i]], "WhitelistGuard::record: action call signature is blacklisted");
        }
    }
  
    function compare(address target, uint proposalId) public {
        require(msg.sender == governor || msg.sender == timelock, "TransferGuard::compare: only admin");
    }
  
    function remove(string memory selector) public {
        require(msg.sender == governor, "TransferGuard::remove: only admin");
        require(blacklist[selector], "TransferGuard::remove: not tracked");
        delete blacklist[selector];

        emit WhitelistSelector(selector);
    }

    function add(string memory selector) public {
        require(msg.sender == governor, "TransferGuard::add: only admin");
        require(!blacklist[selector], "TransferGuard::add: already tracked");
        blacklist[selector] = true;

        emit BlacklistSelector(selector);
    }

    function overwrite(address[] memory selectors, bool option) public {
        require(msg.sender == governor, "TransferGuard::overwrite: only admin"); 

        _set(selectors, option);
    }

    function _set(address[] memory entries, bool flag) internal {
        for (uint8 i = 0; i < entries.length; i++) {
            string selector = entries[i];
            blacklist[target] = flag;

            if (flag) emit BlacklistSelector(selector);
            else emit WhitelistSelector(selector); 
        } 
    }

}

