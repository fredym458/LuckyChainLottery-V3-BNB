// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import "./LotteryTickets.sol";
import {VRFV2PlusClient} from "@chainlink/contracts/src/v0.8/vrf/dev/libraries/VRFV2PlusClient.sol";

abstract contract LotteryDraw is LotteryTickets {
    function drawNumbers() public onlyOwner {
        _drawNumbers(); 
    }

    function fulfillRandomWords(uint256 requestId, uint256[] calldata randomWords) internal override {
        require(pendingDraw, "No draw pending");
        
        uint8[5] memory winning;
        uint256 randomValue = randomWords[0];
        uint8 i = 0;

        while (i < 5) {
            uint8 num = uint8((randomValue % 50) + 1);
            bool exists = false;
            for (uint j = 0; j < i; j++) {
                if (winning[j] == num) {
                    exists = true;
                    break;
                }
            }
            if (!exists) {
                winning[i] = num;
                i++;
            }
            randomValue = uint256(keccak256(abi.encodePacked(randomValue, i)));
        }

        allRounds[roundInProgress].winningNumbers = winning;
        allRounds[roundInProgress].timestamp = block.timestamp;
        winnerSubmissionDeadline = block.timestamp + 1 hours;
        
        emit DrawFulfilled(requestId, winning);
    }

    function submitWinners(
        uint256 round,
        address[] calldata _winners3,
        address[] calldata _winners4,
        address[] calldata _winners5
    ) external onlyOwner {
        require(round == roundInProgress, "Invalid round");
        require(!winnersSubmitted, "Winners already submitted");
        require(block.timestamp <= winnerSubmissionDeadline, "Submission deadline passed");
        
        Round storage r = allRounds[round];
        
        r.winners3 = _winners3;
        r.winners4 = _winners4;
        r.winners5 = _winners5;
        
        r.prizeAmount3 = (r.prizePool * 10) / 100;
        r.prizeAmount4 = (r.prizePool * 20) / 100;
        r.prizeAmount5 = (r.prizePool * 65) / 100;
        
        uint256 totalRollover = (r.prizePool * 5) / 100;
        if (_winners3.length == 0) totalRollover += r.prizeAmount3;
        if (_winners4.length == 0) totalRollover += r.prizeAmount4;
        if (_winners5.length == 0) totalRollover += r.prizeAmount5;
        r.rollover = totalRollover;
        
        winnersSubmitted = true;
        emit WinnersSubmitted(round);
    }

    function distributePrizes(uint8 tier) external onlyOwner {
        require(winnersSubmitted, "Winners not submitted");
        Round storage r = allRounds[roundInProgress];
        require(!r.prizesDistributed, "Prizes already distributed");
        
        address[] storage winners = (tier == 3) ? r.winners3 :
                                  (tier == 4) ? r.winners4 : 
                                  r.winners5;
        
        uint256 prizeAmount;
        if (tier == 3) prizeAmount = r.prizeAmount3;
        else if (tier == 4) prizeAmount = r.prizeAmount4;
        else prizeAmount = r.prizeAmount5;
        
        if (winners.length > 0) {
            uint256 share = prizeAmount / winners.length;
            for(uint i = 0; i < winners.length; i++) {
                (bool success, ) = winners[i].call{value: share}("");
                require(success, "Transfer failed");
            }
            
        }
        
        if (tier == 5) {
            r.prizesDistributed = true;
            currentRound++;
            winnersSubmitted = false;
            pendingDraw = false;
        }
        
        emit PrizesDistributed(roundInProgress, tier);
    }

    function _drawNumbers() internal  {
        pendingDraw = true;
        roundLocked[currentRound] = true;
        roundInProgress = currentRound;
        
        allRounds[currentRound].prizePool = address(this).balance;
       

        lastRequestId = s_vrfCoordinator.requestRandomWords(
            VRFV2PlusClient.RandomWordsRequest({
                keyHash: s_keyHash,
                subId: s_subscriptionId,
                requestConfirmations: requestConfirmations,
                callbackGasLimit: callbackGasLimit,
                numWords: numWords,
                extraArgs: VRFV2PlusClient._argsToBytes(
                    VRFV2PlusClient.ExtraArgsV1({nativePayment: true})
                )
            })
        );

        s_requestInitiator[lastRequestId] = msg.sender;
        emit DrawRequested(lastRequestId);
        emit DrawStarted(roundInProgress);
    }

    // function drawNumbersManually(uint8[5] memory manualNumbers) external onlyOwner {
    //     require(_validateNumbers(manualNumbers), "Invalid winning numbers");
        
    //     // Lock current round
    //     pendingDraw = true;
    //     roundLocked[currentRound] = true;
    //     roundInProgress = currentRound;
        
        
    //     allRounds[currentRound].prizePool = address(this).balance;
        
        
    //     // Set winning numbers
    //     allRounds[currentRound].winningNumbers = manualNumbers;
    //     allRounds[currentRound].timestamp = block.timestamp;
        
    //     // Set submission deadline
    //     winnerSubmissionDeadline = block.timestamp + 1 hours;
        
    //     // Update last draw time
    //     lastDrawTime = block.timestamp;
        
    //     // Simulate VRF completion
    //     emit DrawStarted(currentRound);
    //     emit DrawFulfilled(1234, manualNumbers);  // Dummy request ID 1234
        
    //     // Finalization will happen through distributePrizes(5)
    // }
}
