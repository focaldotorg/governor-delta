pragma solidity ^0.8.10;

import "@interfaces/IProposalGuard.sol";
import "@interfaces/IERC20.sol";
import "@openzeppelin/utils/structs/EnumerableSet.sol";

contract GuardStorage {
 
    struct Token {
        /// @notice Minimum transfer amount per action 
        uint limit;
        /// @notice Permitted culmative transfer amount 
        uint budget;
        /// @notice Target token address  
        address source;
    }

    struct Store {
        /// @notice Shallow copy token context balance 
        uint balance;
        /// @notice Permitted culmative transfer amount 
        uint allowance;
    }

    /// @notice Token policy addition event
    event TokenAdded(address indexed token);

    /// @notice Token policy removal event 
    event TokenRemoved(address indexed token);

    /// @notice Token policy parameter update event
    event TokenUpdated(address indexed token, address indexed context, uint256 limit, uint256 allowance);

}

contract TransferGuard is GuardStorage, IProposalGuard {

    using EnumerableSet for EnumerableSet.AddressSet;

    /// @notice Governor target context address
    address public governor;

    /// @notice Timelock target context address
    address public timelock;

    /// @notice Token policy address indexes
    EnumerableSet.AddressSet private tokens;

    /// @notice Token policy keymap  
    mapping(address => Token) public assets;

    /// @notice Token context store 
    mapping(address => mapping(address => Store)) public store; 

    /// @notice Maximum token policy count 
    uint constant public MAX_SET_ENTRIES = 5;

    /**
      * @notice Initialisation 
      * @param contexts_ Target polic context addresses
      * @param tokens_ Preset token policy array
    **/
    constructor(address[] memory contexts_, Token[] memory tokens_) {
        governor = contexts_[0];

        _set(tokens_, false);
        _credit(contexts_, tokens_);
    } 

    /**
      * @notice Asset inventory helper
      * @param target Account target address query context
      * @param token Asset context address  
      * @return Inventory balance amount 
    **/
    function inventory(address target, address token) public returns (uint) {
        return token == address(0) ? address(target).balance : IERC20(token).balanceOf(target); 
    }

    /**
      * @notice Post execution state diff
      * @param context Target guard context address 
      * @param proposalId Associated proposal identifier 
    **/
    function record(address context, uint proposalId) public {
        require(msg.sender == governor, "TransferGuard::record: only admin");
        address[] memory entries = tokens.values();

        for (uint8 i = 0; i < entries.length; i++) {
           address token = entries[i];
           store[token][context].balance = inventory(context, token);
        }
    }
 
    /**
      * @notice Post execution state diff
      * @param context Target guard context address 
      * @param proposalId Associated proposal identifier 
    **/
    function compare(address context, uint proposalId) public {
        require(msg.sender == governor, "TransferGuard::compare: only admin");
        address[] memory entries = tokens.values();

        for (uint8 i = 0; i < entries.length; i++) {
            address token = entries[i];
            Token storage account = assets[token];
            Store storage store = store[token][context];
            uint balance = inventory(context, token);

            if (balance < store.balance) {
                uint delta = store.balance - balance;
                require(delta <= account.limit, "TransferGuard::compare: exceeds limit");
                require(delta <= store.allowance, "TransferGuard::compare: exceeds allowance");
                store.allowance -= delta;
            }

            emit TokenUpdated(token, context, account.limit, store.allowance);
        }
    }
 
    /**
      * @notice Token policy addition
      * @param token Target token policy 
    **/
    function add(Token memory token) public {
        require(msg.sender == governor, "TransferGuard::add: only admin");
        require(tokens.length() + 1 <= MAX_SET_ENTRIES, "TransferGuard::add: max tokens added");
        require(tokens.add(token.source), "TransferGuard::add: already tracked");
        assets[token.source] = token;

        emit TokenAdded(token.source);
    }

    /**
      * @notice Token policy omission 
      * @param token Target token policy 
    **/
    function remove(address token) public {
        require(msg.sender == governor, "TransferGuard::remove: only admin");
        require(tokens.remove(token), "TransferGuard::remove: not tracked");
        delete assets[token];

        emit TokenRemoved(token);
    }

    /**
      * @notice Override indexable keymap storage slots
      * @param contexts Address contexts value array
      * @param inputs Token policy value array
    **/
    function overwrite(address[] memory contexts, Token[] memory inputs) public {
        require(msg.sender == governor, "TransferGuard::overwrite: only admin"); 

        _set(inputs, true);
        _credit(contexts, inputs);
    }

    /**
      * @notice Keymap storage setter 
      * @param entries Token policy value array
      * @param onlySet Boolean flag to indicate write context 
    */
    function _set(Token[] memory entries, bool onlySet) internal {
        require(entries.length <= MAX_SET_ENTRIES, "TransferGuard::overwrite: invalid input");

        for (uint8 i = 0; i < entries.length; i++) {
            address token = entries[i].source;

            if (onlySet) {
                require(tokens.contains(token), "TransferGuard::overwrite: token not in set");

                emit TokenUpdated(token, address(0), entries[i].limit, entries[i].budget);
            } else {
                require(tokens.add(token), "TransferGuard::overwrite: token already in set");

                emit TokenAdded(token);
            }

            assets[token] = entries[i];
        } 
    }

    /**
      * @notice Credit policy context allowances
      * @param contexts Address contexts value array
      * @param entries Token policy value array
    **/
    function _credit(address[] memory contexts, Token[] memory entries) internal {
        require(entries.length <= MAX_SET_ENTRIES, "TransferGuard::overwrite: invalid input");

        for (uint8 i = 0; i < contexts.length; i++) {
            for (uint8 o = 0; o < entries.length; o++) {
                address token = entries[o].source;
                address context = contexts[i];
                store[token][context].allowance = entries[o].budget;
            }
        }
    }

}

