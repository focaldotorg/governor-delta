pragma solidity ^0.8.10;

import "@interfaces/IProposalGuard.sol";
import "@interfaces/IERC20.sol";
import "@openzeppelin/utils/structs/EnumerableSet.sol";

contract GuardStorage {
 
    struct Token {
        /// @notice Shallow copy token context balance  
        uint store;
        /// @notice Maximum transfer amount per proposal 
        uint limit;
        /// @notice Permitted culmative transfer amount 
        uint allowance;
        /// @notice Target token address  
        address source;
        /// @notice Target beneficiary address  
        address beneficiary;
    }

    /// @notice Token set removal event
    event TokenAdded(address indexed token);

    /// @notice Token set addition event
    event TokenRemoved(address indexed token);

    /// @notice Token policy introduction event
    event PermitPolicy(address indexed token, address indexed beneficiary);

    /// @notice Token policy omission event 
    event OmitPolicy(address indexed token, address indexed beneficiary);

    /// @notice Token policy parameter update event
    event PolicyUpdate(address indexed token, address indexed context, uint256 limit, uint256 allowance);

}

contract TransferGuard is GuardStorage, IProposalGuard {

    using EnumerableSet for EnumerableSet.AddressSet;

    /// @notice Governor target context address
    address public governor;

    /// @notice Token policy address indexes
    EnumerableSet.AddressSet private tokens;

    /// @notice Token address context store 
    mapping(address => mapping(address => Token)) public policies; 

    /// @notice Maximum token policy count 
    uint constant public MAX_SET_ENTRIES = 5;

    /**
      * @notice Initialisation 
      * @param governor_ Target governor address
      * @param tokens_ Preset token policy array
    **/
    constructor(address governor_, Token[] memory tokens_) public {
        governor = governor_;

        _set(tokens_, false);
    } 

    /**
      * @notice Asset inventory helper
      * @param context Account context address  
      * @param token Asset context address  
      * @return Inventory balance amount 
    **/
    function inventory(address context, address token) public view returns (uint) {
        return token == address(0) ? address(context).balance : IERC20(token).balanceOf(context); 
    }

    /**
      * @notice Post execution state diff
      * @param context Target guard context address 
      * @param proposalId Associated proposal identifier 
    **/
    function record(address context, uint proposalId) external {
        require(msg.sender == governor, "TransferGuard::record: only admin");
        address[] memory entries = tokens.values();

        for (uint8 i = 0; i < entries.length; i++) {
           address token = entries[i];
           policies[token][context].store = inventory(context, token);
        }
    }
 
    /**
      * @notice Post execution state diff
      * @param context Target guard context address 
      * @param proposalId Associated proposal identifier 
    **/
    function compare(address context, uint proposalId) external {
        require(msg.sender == governor, "TransferGuard::compare: only admin");
        address[] memory entries = tokens.values();

        for (uint8 i = 0; i < entries.length; i++) {
            address token = entries[i];
            Token storage account = policies[token][context];
            uint balance = inventory(context, token);

            if (balance < account.store) {
                uint delta = account.store - balance;
                require(delta <= account.limit, "TransferGuard::compare: exceeds limit");
                require(delta <= account.allowance, "TransferGuard::compare: exceeds allowance");
                account.allowance -= delta;

                emit PolicyUpdate(token, context, account.limit, account.allowance);
            }
        }
    }
 
    /**
      * @notice Token policy addition
      * @param token Target token policy 
    **/
    function add(Token memory token) external {
        require(msg.sender == governor, "TransferGuard::add: only admin");
        require(tokens.contains(token.source), "TransferGuard::add: already tracked");
        policies[token.source][token.beneficiary] = token;

        emit PermitPolicy(token.source, token.beneficiary);
    }

    /**
      * @notice Token policy omission 
      * @param token Target token address index
      * @param context Target context address 
    **/
    function remove(address token, address context) external {
        require(msg.sender == governor, "TransferGuard::remove: only admin");
        delete policies[token][context];

        emit OmitPolicy(token, context);
    }

    /**
      * @notice Override indexable keymap storage slots
      * @param inputs Token policy value array
    **/
    function overwrite(Token[] memory inputs) external {
        require(msg.sender == governor, "TransferGuard::overwrite: only admin"); 

        _set(inputs, true);
    }

    /**
      * @notice Token set inclusion 
      * @param token Target token address 
    **/
    function push(address token) external {
        require(tokens.length() + 1 <= MAX_SET_ENTRIES, "TransferGuard::push: max tokens added");
        require(tokens.add(token), "TransferGuard::push: token already added");

        emit TokenAdded(token);
    }

    /**
      * @notice Token set exclusion 
      * @param token Target token address 
    **/
    function pull(address token) external {
        require(tokens.remove(token), "TransferGuard::push: token not in set");

        emit TokenRemoved(token);
    }

    /**
      * @notice Keymap storage setter 
      * @param entries Token policy value array
      * @param onlySet Boolean flag to indicate write context 
    */
    function _set(Token[] memory entries, bool onlySet) internal {
        for (uint8 i = 0; i < entries.length; i++) {
            address token = entries[i].source;
            address context = entries[i].beneficiary;
            policies[token][context] = entries[i];

            if (!onlySet) {
                if (tokens.add(token)) {
                    require(tokens.length() + 1 <= MAX_SET_ENTRIES, "TransferGuard::_set: exceeds set count");

                    emit TokenAdded(token);
                }
            } else {
                require(tokens.contains(token), "TransferGuard::_set: token not in set");
            }

            emit PolicyUpdate(token, context, entries[i].limit, entries[i].allowance);
        } 
    }

}

