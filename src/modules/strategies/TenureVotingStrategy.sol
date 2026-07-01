pragma solidity ^0.8.10;

import "@interfaces/IGovernorDelta.sol";
import "@interfaces/ITimeWeightedVotingStrategy.sol";
import "@interfaces/IVotingStrategy.sol";

contract TenureVotingStrategy is IVotingStrategy, ITimeWeightedVotingStrategy {

    Tranche[] public tranches;
    IGovernorDelta public governor; 

    /// @notice Base multiplier scaling unit 
    uint constant public MULTIPLIER_UNIT = 10e6;

    /// @notice Maximum multiplier value
    uint constant public MAX_MULTIPLIER = 20e6;

    /// @notice Minimum tranche boundary / size 
    uint constant public MIN_TRANCHE_SIZE = 30 days;

    /// @notice Maximum tranche boundary / size 
    uint constant public MAX_TRANCHE_SIZE = 730 days;

    /// @notice Maximum tranche total 
    uint constant public MAX_TRANCHE_COUNT = 10;

    constructor(address governor_, Tranche[] memory tranches_) public {
        require(checkTranches(tranches_), "TenureVotingStrategy::checkTranches: invalid config");

        governor = IGovernorDelta(governor_);
        tranches = tranches_;
    }

    /**
      * @notice Returns the module configuration type  
      * @return A boolean value to indicate whether the module has virtual weighting
    **/
    function virtualized() external pure returns (bool) {
        return true;
    }

    /**
      * @notice Returns the current voting power of a given account
      * @param owner The address to query for
      * @return The voting power of the account 
      * @dev Uses capital time integral to compute averaged time weight (effective time)
      * @dev When effectie time reaches a tranche boundry, the multiplier is applied
    **/
    function power(address owner) external view returns (uint) {
        (uint balance, uint deltaAmountTime) = governor.stake(owner);
        uint effectiveTime = deltaAmountTime / balance;
        Tranche memory tranche = getTranche(effectiveTime);
        return balance * tranche.multiplier / MULTIPLIER_UNIT; 
    }

    /**
      * @notice Returns the future projected voting power of a given account
      * @param owner The address to query for
      * @param timestamp The future time to query the voting power at
      * @return The future voting power of the account 
      * @dev Uses capital time integral to compute averaged time weight (effective time)
      * @dev Projects future effective time by adding difference from future date-time
    **/
    function predict(address owner, uint timestamp) external view returns (uint) {
        if (timestamp < block.timestamp) return 0;

        (uint balance, uint deltaAmountTime) = governor.stake(owner);
        uint effectiveTime = deltaAmountTime / balance;
        uint futureTime = effectiveTime + (timestamp - block.timestamp);
        Tranche memory tranche = getTranche(futureTime);
        return balance * tranche.multiplier / MULTIPLIER_UNIT; 
    }

    /**
      * @notice Returns the current voting weight of a given account
      * @param owner The address to query for
      * @return The voting weight of the account 
    **/
    function weight(address owner) external view returns (uint) {
        (uint balance,) = governor.stake(owner);
        return balance;
    }

    /**
      * @notice Returns the equivalent tranche for a indexed duration 
      * @param duration The fixed time value to query (eg. 10 days)
      * @return The tranche assoicated with the inputted time 
    **/
    function getTranche(uint duration) public view returns (Tranche memory) {
        Tranche memory selector = tranches[0]; 

        for (uint8 i = 0; i < tranches.length; i++) {
            if (duration >= tranches[i].size) {
                selector = tranches[i];
            } else {
                break;
            }
        }

        return selector;
    } 

    /**
      * @notice Checks whether a tranche configuration is correct
      * @param config The tranche config array
      * @return The boolean indicating whether the config is valid 
    **/
    function checkTranches(Tranche[] memory config) public pure returns (bool) {
        if (config.length > MAX_TRANCHE_COUNT) return false;

        for (uint8 i = 0; i < config.length; i++) {
            Tranche memory target = config[i];

            if (target.size < MIN_TRANCHE_SIZE) return false;
            if (target.size > MAX_TRANCHE_SIZE) return false;
            if (target.multiplier < MULTIPLIER_UNIT) return false;
            if (target.multiplier > MAX_MULTIPLIER) return false;
            if (i == config.length - 1) break;
            if (target.size >= config[i + 1].size) return false;
            if (target.multiplier >= config[i + 1].multiplier) return false;
        }

        return true;
    } 

    /**
      * @notice Admin function to set the tranche configuration 
      * @param config The tranche config array
    **/
    function _setTranches(Tranche[] memory config) external {
        require(checkTranches(config), "TenureVotingStrategy::checkTranches: invalid config");
        require(msg.sender == address(governor), "TenureVotingStrategy::_setTranches: governor only");
        Tranche[] memory oldTranches = tranches;
        tranches = config;

        emit NewTranches(oldTranches, tranches);
    }

}

