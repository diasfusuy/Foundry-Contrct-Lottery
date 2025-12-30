// Layout of Contract:
// version
// imports
// errors
// interfaces, libraries, contracts
// Type declarations
// State variables
// Events
// Modifiers
// Functions

// Layout of Functions:
// constructor
// receive function (if exists)
// fallback function (if exists)
// external
// public
// internal
// private
// view & pure functions

// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

/** 
 * @title Raffle contract
 * @author diasf
 * @notice This contract is for creating a raffle
 * @dev Implements Chainlink VRFv2.5
 */ 
contract Raffle {

    uint256 private immutable I_ENTERENCE_FEE;
    constructor(uint256 entranceFee) {
        I_ENTERENCE_FEE = entranceFee;
    }

    function enterRaffle() public payable {

    }

    function pickWinner() public {}

    //** Getter Functions */
    function getEntranceFee() external view returns (uint256) {
        return I_ENTERENCE_FEE;
    }
}