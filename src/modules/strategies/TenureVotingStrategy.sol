pragma solidity ^0.8.10;

import "@interfaces/IGovernorDelta.sol";
import "@interfaces/ITimeWeightedVotingStrategy.sol";
import "@interfaces/IVotingStrategy.sol";

contract TenureVotingStrategy is IVotingStrategy, ITimeWeightedVotingStrategy {

    Tranche[] public tranches;
    IGovernorDelta public governor; 

    uint constant public MULTIPLIER_UNIT = 1e8;

    uint constant public MAX_MULTIPLIER = 2e8;

    uint constant public MIN_TRANCHE_SIZE = 30 days;

    uint constant public MAX_TRANCHE_SIZE = 730 days;

    uint constant public MAX_TRANCHE_COUNT = 10;

    constructor(address governor_, Tranche[] memory tranches_) {
        require(checkTranches(tranches_), "TenureVotingStrategy::checkTranches: invalid config");

        governor = IGovernorDelta(governor_);
        tranches = tranches_;
    }

    function virtualized() external returns (bool) {
        return true;
    }

    function power(address owner) external returns (uint) {
        (uint balance, uint deltaAmountTime) = governor.stake(owner);
        uint effectiveTime = deltaAmountTime / balance;
        Tranche memory tranche = getTranche(owner, effectiveTime);
        return balance * tranche.multiplier / MULTIPLIER_UNIT; 
    }

    function predict(address owner, uint timestamp) external returns (uint) {
        if (timestamp < block.timestamp) return 0;

        (uint balance, uint deltaAmountTime) = governor.stake(owner);
        uint effectiveTime = deltaAmountTime / balance;
        uint futureTime = effectiveTime + (timestamp - block.timestamp);
        Tranche memory tranche = getTranche(owner, futureTime);
        return balance * tranche.multiplier / MULTIPLIER_UNIT; 
    }

    function weight(address owner) external returns (uint) {
        (uint balance,) = governor.stake(owner);
        return balance;
    }

    function getTranche(address owner, uint time) public returns (Tranche memory) {
        Tranche memory selector = tranches[0]; 

        for (uint8 i = 0; i < tranches.length; i++) {
            if (time >= tranches[i].size) {
                selector = tranches[i];
            } else {
                break;
            }
        }

        return selector;
    } 

    function checkTranches(Tranche[] memory config) public pure returns (bool) {
        if (config.length > MAX_TRANCHE_COUNT) return false;

        for (uint8 i = 0; i < config.length; i++) {
            Tranche memory target = config[i];

            if (target.size < MIN_TRANCHE_SIZE) return false;
            if (target.size > MAX_TRANCHE_SIZE) return false;
            if (target.multiplier < MULTIPLIER_UNIT) return false;
            if (target.multiplier >= MAX_MULTIPLIER) return false;
            if (i == config.length) break;
            if (target.size >= config[i + 1].size) return false;
            if (target.multiplier >= config[i + 1].multiplier) return false;
        }

        return true;
    } 

    function _setTranches(Tranche[] memory config) external {
        require(checkTranches(config), "TenureVotingStrategy::checkTranches: invalid config");
        require(msg.sender == address(governor), "TenureVotingStrategy::_setTranches: governor only");
        Tranche[] storage oldTranches = tranches;
        tranches = config;

        emit NewTranches(oldTranches, tranches);
    }

}

