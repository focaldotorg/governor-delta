// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import "@strategies/TenureVotingStrategy.sol";
import "@strategies/extensions/BootstrappedVotingStrategy.sol";

contract BootstrappedTenureVotingStrategy is TenureVotingStrategy, BootstrappedVotingStrategy {

    constructor(address governor_, Tranche[] memory tranches_, Seed[] memory seeds_) 
        TenureVotingStrategy(governor_, tranches_) 
    public {
        for (uint i = 0; i < seeds_.length; i++) {
            address seedAccount = seeds_[i].account;
            uint seedValue = seeds_[i].basisTime;
            uint seedTime = seeds_[i].lifeTime;
            require(seedValue > 0, "TenureVotingStrategy::init: Seed value has to be non-zero");
            require(seedAccount != address(0), "TenureVotingStrategy::init: zero seed address");
            require(seedTime > block.timestamp, "TenureVotingStrategy::init: invalid seed expiration");
            require(seedTime - block.timestamp <= MAX_SEED_TIME, "TenureVotingStrategy::init: invalid seed period");
            seeds[seedAccount] = seeds_[i];
        }
    }

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
