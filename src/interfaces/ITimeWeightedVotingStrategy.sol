pragma solidity ^0.8.10;

interface ITimeWeightedVotingStrategy  {

    struct Tranche {
        uint64  size; 
        uint192 multiplier;
    }

}
