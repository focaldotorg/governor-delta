// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import "@strategies/PolycentricVotingStrategy.sol";
import "@strategies/extensions/EnduedVotingStrategy.sol";

contract EnduedPolycentricVotingStrategy is PolycentricVotingStrategy, EnduedVotingStrategy {

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
        override(PolycentricVotingStrategy, EnduedVotingStrategy) 
    public view returns (uint) {
        if (timestamp < block.timestamp) return 0;

        (uint balance, uint deltaAmountTime, uint lastUpdateTime) = governor.stake(owner);
        uint effectiveTime = deltaAmountTime / balance;
        uint deltaTime = timestamp - lastUpdateTime;
        uint futureTime = effectiveTime + deltaTime;
        uint realisedTime = seededTime(owner) + futureTime;
        UD60x18 s = ud(balance);
        UD60x18 w = timeWeight(futureTime);
        // V_P = W(α · S + sqrt(S) · (1 - α))
        UD60x18 alpha = powerRatio(futureTime);
        UD60x18 rt = s.sqrt().mul(convert(1).sub(alpha));
        UD60x18 lt = s.mul(alpha);
        // Where lt = α · S, rt = sqrt(S) · (1 - α) and alpha = α 
        return w.mul(lt.add(rt)).unwrap() / PRB_UINT;
    }

}
