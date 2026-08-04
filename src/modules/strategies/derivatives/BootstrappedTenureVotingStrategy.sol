// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import "@strategies/TenureVotingStrategy.sol";
import "@strategies/extensions/BootstrappedVotingStrategy.sol";

contract BootstrappedTenureVotingStrategy is TenureVotingStrategy, BootstrappedVotingStrategy {

    /**
      * @notice Initialisation
      * @param governor_ Target governor context address 
      * @param tranches_ Power multiplier target value array 
      * @param seeds_ Preallocated power multiplier values 
    **/
    constructor(address governor_, Tranche[] memory tranches_, Seed[] memory seeds_) 
        TenureVotingStrategy(governor_, tranches_) 
    public {
        for (uint i = 0; i < seeds_.length; i++) {
            address seedAccount = seeds_[i].account;
            uint seedValue = seeds_[i].basisTime;
            uint seedTime = seeds_[i].lifeTime;
            require(seedAccount != address(0), "TenureVotingStrategy::init: zero seed address");
            require(seedValue > 0, "TenureVotingStrategy::init: seed value has to be non-zero");
            require(seedValue >= MULTIPLIER_UNIT, "TenureVotingStrategy::init: seed value lte decimal factor");
            require(seedTime > block.timestamp, "TenureVotingStrategy::init: invalid seed expiration");
            require(seedTime - block.timestamp <= MAX_SEED_TIME, "TenureVotingStrategy::init: invalid seed period");
            seeds[seedAccount] = seeds_[i];
        }
    }

    /**
      * @notice Returns the future projected voting power of a given account
      * @param owner The address to query for
      * @param timestamp The future time to query the voting power at
      * @return The future voting power of the account 
    **/
    function predict(address owner, uint timestamp)   
        override(TenureVotingStrategy, BootstrappedVotingStrategy) 
    public view returns (uint) {
        if (timestamp < block.timestamp) return 0;

        (uint balance, uint deltaAmountTime, uint lastUpdateTime) = governor.stake(owner);
        uint baseEffectiveTime = deltaAmountTime / balance;
        uint deltaTime = timestamp - lastUpdateTime;
        uint futureTime = baseEffectiveTime + deltaTime;
        uint realisedTime = seededEffectiveTime(owner) + futureTime;
        Tranche memory tranche = getTranche(realisedTime);
        return balance * tranche.multiplier / MULTIPLIER_UNIT; 
    }

}
