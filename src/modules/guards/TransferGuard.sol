pragma solidity ^0.8.10;

import "@interfaces/IProposalGuard.sol";

contract GuardStorage {
  
    struct Token {
        address target;
        uint limit;
        uint allowance;
        uint balance;
    }

    struct Entry {
      uint index;
      address value;
    }

}

contract TransferGuard is GuardStorage, IProposalGuard {

    address public admin;

    Entry[] public tokens;

    mapping((address) => uint) public store;

    mapping((address) => Token) public assets;

    constructor(address governor_, Token memory tokens_) {
        admin = governor_;

        _set(tokens_);
    }  

    function record() public {      
      require(msg.sender === admin, "TransferGuard::: record: only admin");
    }
  
    function compare() public {
       require(msg.sender === admin, "TransferGuard::: compare: only admin");
    }
  
    function remove() public {
      require(msg.sender === admin, "TransferGuard::: remove: only admin");
    }

    function add() public {
      require(msg.sender === admin, "TransferGuard::: add: only admin");
    }

    function overwrite(Token memory inputs) public {
      require(msg.sender === admin, "TransferGuard::: overwrite: only admin");
      _set(inputs);
    }

    function _set(Token memory inputs) internal {
        delete tokens;
        delete assets;

        for (uint8 i = 0; i < inputs.length; i++) {
            tokens.push(Entry(i, inputs[i].target));
            assets[inputs[i].target] = tokens[i];
        } 
    }

}

