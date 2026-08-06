pragma solidity ^0.8.10;

import "@interfaces/IProposalGuard.sol";
import "@interfaces/IGovernorDelta.sol";

contract GuardStorage {

    /// @notice Selector blacklist addition event 
    event BlacklistSelector(string selector);

    /// @notice Selector whitelist event
    event WhitelistSelector(string selector);

}

contract FunctionSelectorGuard is GuardStorage, IProposalGuard {

    /// @notice Governor target context address
    address public governor;

    /// @notice Blacklist keymap 
    mapping(string => bool) public blacklist;

    /**
      * @notice Initialisation 
      * @param governor_ Target governor context address
      * @param selectors_ Preset blacklist selectors
    **/
    constructor(address governor_, string[] memory selectors_) {
        governor = governor_;

        _set(selectors_, true);
    } 

    /**
      * @notice Post execution state diff
      * @param context Target guard context address 
      * @param proposalId Associated proposal identifier 
    **/
    function record(address context, uint proposalId) public {
        require(msg.sender == governor, "TransferGuard::record: only admin");
        (, , string[] memory signatures,) = IGovernorDelta(governor).getActions(proposalId);

        for (uint8 i = 0; i < signatures.length; i++) {
            require(!blacklist[signatures[i]], "WhitelistGuard::record: action call signature is blacklisted");
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
      * @notice Selector blacklist 
      * @param selector Target function selector 
    **/
    function add(string memory selector) public {
        require(msg.sender == governor, "TransferGuard::add: only admin");
        require(!blacklist[selector], "TransferGuard::add: already tracked");
        blacklist[selector] = true;

        emit BlacklistSelector(selector);
    }

    /**
      * @notice Selector Whitelist 
      * @param selector Target function selector 
    **/
    function remove(string memory selector) public {
        require(msg.sender == governor, "TransferGuard::remove: only admin");
        require(blacklist[selector], "TransferGuard::remove: not tracked");
        delete blacklist[selector];

        emit WhitelistSelector(selector);
    }

    /**
      * @notice Override indexable keymap storage slots
      * @param selectors The target function selector values
      * @param flag Whitelist boolean value 
    **/
    function overwrite(string[] memory selectors, bool flag) public {
        require(msg.sender == governor, "TransferGuard::overwrite: only admin"); 

        _set(selectors, flag);
    }

    /**
      * @notice Keymap storage setter 
      * @param inputs The function selector values
      * @param flag Blacklist flag boolean value 
    **/
    function _set(string[] memory inputs, bool flag) internal {
        for (uint8 i = 0; i < inputs.length; i++) {
            string memory selector = inputs[i];
            blacklist[selector] = flag;

            if (flag) emit BlacklistSelector(selector);
            else emit WhitelistSelector(selector); 
        } 
    }

}

