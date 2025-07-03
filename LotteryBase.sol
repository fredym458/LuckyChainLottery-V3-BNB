// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {VRFConsumerBaseV2Plus} from "@chainlink/contracts/src/v0.8/vrf/dev/VRFConsumerBaseV2Plus.sol";
import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";

abstract contract LotteryBase is VRFConsumerBaseV2Plus {
    // State variables and mappings
    uint256 public usdTicketPrice = 10 * 10 ** 8;
    uint256 public lastDrawTime;
    uint256 public currentRound;
    bool public paused;
    uint256 public roundInProgress;
    bool public winnersSubmitted;
    uint256 public winnerSubmissionDeadline;
    address public automationRegistry;
    
    struct Ticket {
        address player;
        uint8[5] numbers;
    }

    struct Round {
        uint256 timestamp;
        uint256 prizePool;
        uint8[5] winningNumbers;
        Ticket[] tickets;
        address[] winners3;
        address[] winners4;
        address[] winners5;
        bool prizesDistributed;
        uint256 rollover;
        uint256 prizeAmount3;
        uint256 prizeAmount4;
        uint256 prizeAmount5;
    }

    mapping(uint256 => uint256) public totalTicketsPerDraw;
    mapping(uint256 => mapping(address => bool)) internal hasParticipated;
    mapping(uint256 => uint256) public uniqueParticipantsPerDraw;
    mapping(uint256 => Round) public allRounds;
    mapping(uint256 => mapping(address => Ticket[])) public playerTickets;
    mapping(uint256 => bool) public roundLocked;

    AggregatorV3Interface internal priceFeed;
    address vrfCoordinator = 0xDA3b641D438362C440Ac5458c57e00a712b66700;
    uint256 public s_subscriptionId;
    bytes32 public s_keyHash = 0x8596b430971ac45bdf6088665b9ad8e8630c9d5049ab54b14dff711bee7c0e26;
    uint32 public callbackGasLimit = 500000;
    uint16 public requestConfirmations = 3;
    uint32 public numWords = 1;
    uint256 public lastRequestId;
    bool public pendingDraw;
    mapping(uint256 => address) internal s_requestInitiator;
    uint256 internal nonce;

    // Events
    event DrawRequested(uint256 indexed requestId);
    event DrawFulfilled(uint256 indexed requestId, uint8[5] winningNumbers);
    event TicketPurchased(address indexed player, uint8[5] numbers, uint256 round);
    event EmergencyWithdrawal(uint256 amount, address recipient);
    event PrizePoolFunded(address indexed sender, uint256 amount);
    event DrawStarted(uint256 indexed round);
    event WinnersSubmitted(uint256 indexed round);
    event PrizesDistributed(uint256 indexed round, uint8 tier);

    modifier whenNotPaused() {
        require(!paused, "Contract is paused");
        _;
    }


    constructor(uint256 subscriptionId) VRFConsumerBaseV2Plus(vrfCoordinator) {
        priceFeed = AggregatorV3Interface(0x2514895c72f50D8bd4B4F9b1110F0D6bD2c97526);
        lastDrawTime = block.timestamp;
        currentRound = 1;
        paused = false;
        s_subscriptionId = subscriptionId;
    }

    function pause() external onlyOwner {
        paused = true;
    }

    function unpause() external onlyOwner {
        paused = false;
    }

    function fundPrizePool() external payable onlyOwner {
        require(msg.value > 0, "Must send BNB");
        emit PrizePoolFunded(msg.sender, msg.value);
    }

    function emergencyWithdraw() external onlyOwner {
        uint256 contractBalance = address(this).balance;
        require(contractBalance > 0, "No funds to withdraw");


        (bool success, ) = owner().call{value: contractBalance}("");
        require(success, "Transfer failed");

        emit EmergencyWithdrawal(contractBalance, owner());
    }

    // Getters **************************************************

    function getusdTicketPriceInBNB() public view returns (uint256) {
        (, int256 price, , , ) = priceFeed.latestRoundData();
        require(price > 0, "Invalid BNB price");
        uint256 bnbUsdPrice = uint256(price);
        return (usdTicketPrice * 1e18) / bnbUsdPrice;
    }


    function getPrizePoolInUSD() public view returns (uint256) {
        (, int256 price, , , ) = priceFeed.latestRoundData();
        require(price > 0, "Invalid BNB/USD price");
        uint256 bnbPrice = uint256(price);
        uint256 usdValue = (address(this).balance * bnbPrice) / 1e26;
        return usdValue;
    }

    function getWinningNumbers(uint256 round) external view returns (uint8[5] memory) {
        return allRounds[round].winningNumbers;
    }

    function getWinningAddresses(uint256 round) external view returns (address[] memory winners3, address[] memory winners4, address[] memory winners5) {
        Round storage r = allRounds[round];
        return (r.winners3, r.winners4, r.winners5);
    }

    function getAllTicketsForRound(uint256 round) external view returns (address[] memory players, uint8[5][] memory numbersList) {
        Round storage r = allRounds[round];
        uint256 numTickets = r.tickets.length;
        
        players = new address[](numTickets);
        numbersList = new uint8[5][](numTickets);
        
        for (uint i = 0; i < numTickets; i++) {
            Ticket storage ticket = r.tickets[i];
            players[i] = ticket.player;
            numbersList[i] = ticket.numbers;
        }
    }

    // Setters **************************************************

    function setUsdTicketPrice(uint256 newPrice) external onlyOwner {
        require(newPrice > 0, "Price must be greater than 0");
        usdTicketPrice = newPrice;
    }

    function setCallbackGasLimit(uint32 _newLimit) external onlyOwner {
        require(_newLimit >= 100000, "Too low");
        callbackGasLimit = _newLimit;
    }

    function setAutomationRegistry(address _registry) external onlyOwner {
        require(_registry != address(0), "Invalid address");
        automationRegistry = _registry;
    }

    function setPendingDraw(bool value) external onlyOwner {
        pendingDraw = value;
    }

    function setWinnersSubmitted(bool value) external onlyOwner {
        winnersSubmitted = value;
    }

    function updateVRFSettings(address _coordinator, bytes32 _keyHash) external onlyOwner {
        require(_coordinator != address(0), "Invalid coordinator address");
        require(_keyHash != bytes32(0), "Invalid key hash");

        vrfCoordinator = _coordinator;
        s_keyHash = _keyHash;
    }

    function updatePriceFeed(address _newFeed) external onlyOwner {
        require(_newFeed != address(0), "Invalid price feed address");
        priceFeed = AggregatorV3Interface(_newFeed);
    }

    function updateSubscriptionId(uint256 newSubId) external onlyOwner {
        require(newSubId > 0, "Invalid subscription ID");
        s_subscriptionId = newSubId;
    }




    
    function _validateNumbers(uint8[5] memory numbers) internal pure virtual returns (bool);
    function _generateRandomNumbers() internal virtual returns (uint8[5] memory);
}
