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
import {
    VRFConsumerBaseV2Plus
} from "lib/chainlink-brownie-contracts/contracts/src/v0.8/vrf/dev/VRFConsumerBaseV2Plus.sol";
import {
    VRFV2PlusClient
} from "lib/chainlink-brownie-contracts/contracts/src/v0.8/vrf/dev/libraries/VRFV2PlusClient.sol";

contract Raffle is VRFConsumerBaseV2Plus {
    /* Errors */
    error Raffle__SendMoreToEnterRaffle();
    error Raffle__TransferFailed();
    error Raffle__RaffleNotOpen();
    error Raffle__EnoughTimeNotPassed();
    error Raffle__UpkeepNotNeeded(uint256 balance, uint256 playersLength, uint256 raffleState);

    // Type Declarations
    enum RaffleState {
        OPEN, 
        CALCULATING
    }

    // State Variables
    uint16 private constant REQUEST_CONFIRMATION = 3;
    uint32 private constant NUM_WORDS = 1;
    uint256 private immutable I_ENTERENCE_FEE;
    uint256 private immutable I_INTERVAL;
    bytes32 private immutable I_KEY_HASH;
    uint256 private immutable I_SUBSCRIBTION_ID;
    uint32 private immutable I_CALLBACK_GAS_LIMIT;
    address payable[] private s_players;
    uint256 private s_lastTimeStamp;
    address private s_recentWinner;
    RaffleState private s_raffleState;    

    /* Events */
    event RaffleEnter(address indexed player);
    event WinnerPicked(address indexed winner);


    constructor(
        uint256 entranceFee,
        uint256 interval,
        address vrfCoordinator,
        bytes32 gasLane,
        uint256 subscriptionId,
        uint32 callbackGasLimit
    ) VRFConsumerBaseV2Plus(vrfCoordinator) {
        I_ENTERENCE_FEE = entranceFee;
        I_INTERVAL = interval;
        I_KEY_HASH = gasLane;
        I_SUBSCRIBTION_ID = subscriptionId;
        I_CALLBACK_GAS_LIMIT = callbackGasLimit;

        s_lastTimeStamp = block.timestamp;
        s_raffleState = RaffleState.OPEN;
    }

    function enterRaffle() external payable {
        // require(msg.value >= I_ENTERENCE_FEE, "Not enough ETH sent");
        if (msg.value < I_ENTERENCE_FEE) {
            revert Raffle__SendMoreToEnterRaffle();
        }
        if(s_raffleState != RaffleState.OPEN){
            revert Raffle__RaffleNotOpen();
        }
        s_players.push(payable(msg.sender));
        emit RaffleEnter(msg.sender);
    }

    /**
     * @dev This is the function that the Chainlink Keeper nodes call to see
     * if lottery is ready to have winner picked.
     * The following should be true in order for upkeepNeeded to be true:
     * 1. The time interval has passed between raffle runs.
     * 2. The lottery is in an "open" state.
     * 3. The contract has ETH.
     * 4. Implicity, players have entered the lottery.
     * @param - ignored 
     * @return upkeepNeeded - true if enough time has passed, has players, eth, and is open 
     * @return - ignored
     */
    function checkUpkeep(bytes memory /* checkData */) public
        view returns (bool upkeepNeeded, bytes memory /* performData */) 
        {
            bool timeHasPassed = ((block.timestamp - s_lastTimeStamp) > I_INTERVAL);
            bool isOpen = s_raffleState == RaffleState.OPEN;
            bool hasBalance = address(this).balance > 0;
            bool hasPlayers = s_players.length > 0;
            upkeepNeeded = timeHasPassed && isOpen && hasBalance && hasPlayers;
            return(upkeepNeeded, "");
        }

    // 1. Get a random number
    // 2. Use random number to pick a player
    // 3. Be automatically called
    function performUpkeep(bytes calldata /* performData */ ) external {
        // Check to see if enough time has passed
        (bool upkeepNeeded,) = checkUpkeep("");
        if(!upkeepNeeded)
            revert Raffle__UpkeepNotNeeded(address(this).balance, s_players.length, uint256(s_raffleState));

        s_raffleState = RaffleState.CALCULATING;
        VRFV2PlusClient.RandomWordsRequest memory request = VRFV2PlusClient.RandomWordsRequest({
            keyHash: I_KEY_HASH,
            subId: I_SUBSCRIBTION_ID,
            requestConfirmations: REQUEST_CONFIRMATION,
            callbackGasLimit: I_CALLBACK_GAS_LIMIT,
            numWords: NUM_WORDS,
            extraArgs: VRFV2PlusClient._argsToBytes(VRFV2PlusClient.ExtraArgsV1({nativePayment: false}))
        });
        s_vrfCoordinator.requestRandomWords(request);
    }

    //CEI: Checks, Effects, Interactions pattern
    function fulfillRandomWords(uint256 /* requestId */, uint256[] calldata randomWords) internal virtual override {
        // Checks
        
        // Effects (internal state changes)
        uint256 indexOfWinner = randomWords[0] % s_players.length;
        address payable recentWinner = s_players[indexOfWinner];
        s_recentWinner = recentWinner;

        s_raffleState = RaffleState.OPEN;
        s_players = new address payable[](0);
        s_lastTimeStamp = block.timestamp; 
        
        // Interactions (External contract interactions)
        (bool success, ) = recentWinner.call{value: address(this).balance}("");
        if(!success){
            revert Raffle__TransferFailed();
        }
        emit WinnerPicked(recentWinner);
    }

    //** Getter Functions */
    function getEntranceFee() external view returns (uint256) {
        return I_ENTERENCE_FEE;
    }

    function getRaffleState() external view returns(RaffleState) {
        return s_raffleState;
    }
}
