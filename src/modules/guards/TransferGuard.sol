pragma solidity ^0.8.10;

import "@interfaces/IProposalGuard.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

contract GuardStorage {
 
    struct Token {
        uint store;
        uint limit;
        uint allowance;
        address source;
    }

    event TokenAdded(address indexed token);

    event TokenRemoved(address indexed token);

    event TokenUpdated(address indexed token, uint256 limit, uint256 allowance);

}

contract TransferGuard is GuardStorage, IProposalGuard {

    using EnumerableSet for EnumerableSet.AddressSet;

    address public admin;

    address public timelock;

    EnumerableSet.AddressSet private tokens;

    mapping(address => Token) public assets;

    uint constant public MAX_SET_ENTRIES = 5;

    constructor(address admin_, address timelock_, Token[] memory tokens_) {
        admin = admin_;
        timelock = timelock_;

        _set(tokens_, false);
    }  

    function record(address target) public {
        require(msg.sender == admin || msg.sender == timelock, "TransferGuard::record: only admin");
    }
  
    function compare(address target) public {
        require(msg.sender == admin || msg.sender == timelock, "TransferGuard::compare: only admin");
    }
  
    function remove(address token) public {
        require(msg.sender == admin, "TransferGuard::remove: only admin");
        require(tokens.remove(token), "TransferGuard::remove: not tracked");
        delete assets[token];

        emit TokenRemoved(token);
    }

    function add(Token memory token) public {
        require(msg.sender == admin, "TransferGuard::add: only admin");
        require(tokens.length() + 1 <= MAX_SET_ENTRIES, "TransferGuard::add: max tokens added");
        require(tokens.add(token.source), "TransferGuard::add: already tracked");
        assets[token.source] = token;

        emit TokenAdded(token.source);
    }

    function overwrite(Token[] memory inputs) public {
        require(msg.sender == admin, "TransferGuard::overwrite: only admin"); 

        _set(inputs, true);
    }

    function _set(Token[] memory inputs, bool onlySet) internal {
        require(inputs.length <= MAX_SET_ENTRIES, "TransferGuard::overwrite: invalid input");

        for (uint8 i = 0; i < inputs.length; i++) {
            address token = inputs[i].source;

            if (onlySet) {
                require(tokens.contains(token), "TransferGuard::overwrite: token not in set");

                emit TokenUpdated(token, inputs[i].limit, inputs[i].allowance);
            } else {
                require(tokens.add(token), "TransferGuard::overwrite: token already in set");

                emit TokenAdded(token);
            }

            assets[token] = inputs[i];
        } 
    }

}

