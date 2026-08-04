pragma solidity ^0.8.10;

import "@interfaces/IProposalGuard.sol";
import "@interfaces/IGovernorDelta.sol";

contract GuardStorage {

    /// @notice Whitelist addition event 
    event PermitAddress(address indexed target);

    /// @notice Whitelist removal event 
    event OmitAddress(address indexed target);

}

contract WhitelistGuard is GuardStorage, IProposalGuard {

    /// @notice Governor target context address
    address public governor;

    /// @notice Account whitelist address keymap 
    mapping(address => bool) public whitelist;

    /**
      * @notice Initialisation
      * @param governor_ Target governor context address
      * @param targets_ Whitelist address keymap values 
    **/
    constructor(address governor_, address[] memory targets_) {
        governor = governor_;

        _set(targets_, true);
    } 

    /**
      * @notice Pre execution state snapshot
      * @param context Target guard context address 
      * @param proposalId Associated proposal identifier 
    **/
    function record(address context, uint proposalId) public {
        require(msg.sender == governor, "TransferGuard::record: only admin");
        (address[] memory targets, , ,) = IGovernorDelta(governor).getActions(proposalId);

        for (uint8 i = 0; i < targets.length; i++) {
            require(whitelist[targets[i]], "WhitelistGuard::record: action call target not whitelisted");
        }
    }
 
    /**
      * @notice Post execution state diff
      * @param context Target guard context address 
      * @param proposalId Associated proposal identifier 
    **/
    function compare(address context, uint proposalId) public {
        require(msg.sender == governor, "TransferGuard::compare: only admin");
    }

    /**
      * @notice Whitelist address addition
      * @param source Target whitelist address
    **/
    function add(address source) public {
        require(msg.sender == governor, "TransferGuard::add: only admin");
        require(!whitelist[source], "TransferGuard::add: already tracked");
        whitelist[source] = true;

        emit PermitAddress(source);
    }

    /**
      * @notice Whitelist address omission 
      * @param source Target whitelist address
    **/
    function remove(address source) public {
        require(msg.sender == governor, "TransferGuard::remove: only admin");
        require(whitelist[source], "TransferGuard::remove: not tracked");
        delete whitelist[source];

        emit OmitAddress(source);
    }

    /**
      * @notice Override indexable keymap storage slots
      * @param inputs The whitelist address values
      * @param flag Whitelist boolean value 
    **/
    function overwrite(address[] memory inputs, bool flag) public {
        require(msg.sender == governor, "TransferGuard::overwrite: only admin"); 

        _set(inputs, option);
    }

    /**
      * @notice Keymap storage setter 
      * @param inputs The whitelist address values
      * @param flag Whitelist boolean value 
    */
    function _set(address[] memory inputs, bool flag) internal {
        for (uint8 i = 0; i < inputs.length; i++) {
            address target = inputs[i];
            whitelist[target] = flag;

            if (flag) emit PermitAddress(target);
            else emit OmitAddress(target); 
        } 
    }

}

