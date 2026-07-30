pragma solidity ^0.8.10;

import "@interfaces/IProposalGuard.sol";
import "@interfaces/IERC20.sol";
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

    function inventory(address target, address token) public returns (uint) {
        return token == address(0) ? address(target).balance : IERC20(token).balanceOf(target); 
    }

    function record(address target) public {
        require(msg.sender == admin || msg.sender == timelock, "TransferGuard::record: only admin");
        address[] memory entries = tokens.values();

        for (uint256 i = 0; i < entries.length; i++) {
           address token = entries[i];
           assets[token].store = inventory(target, token);
        }
    }
  
    function compare(address target) public {
        require(msg.sender == admin || msg.sender == timelock, "TransferGuard::compare: only admin");
        address[] memory entries = tokens.values();

        for (uint8 i = 0; i < entries.length; i++) {
            address token = entries[i];
            Token storage account = assets[token];
            uint balance = inventory(target, token);

            if (balance < account.store) {
                uint delta = account.store - balance;
                require(delta <= account.limit, "TransferGuard::compare: exceeds limit");
                require(delta <= account.allowance, "TransferGuard::compare: exceeds allowance");
                account.allowance -= delta;
            }

            account.store = balance;

            emit TokenUpdated(token, account.limit, account.allowance);
        }
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

    function _set(Token[] memory entries, bool onlySet) internal {
        require(inputs.length <= MAX_SET_ENTRIES, "TransferGuard::overwrite: invalid input");

        for (uint8 i = 0; i < entries.length; i++) {
            address token = entries[i].source;

            if (onlySet) {
                require(tokens.contains(token), "TransferGuard::overwrite: token not in set");

                emit TokenUpdated(token, entries[i].limit, entries[i].allowance);
            } else {
                require(tokens.add(token), "TransferGuard::overwrite: token already in set");

                emit TokenAdded(token);
            }

            assets[token] = entries[i];
        } 
    }

}

