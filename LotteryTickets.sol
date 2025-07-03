// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import "./LotteryBase.sol";

abstract contract LotteryTickets is LotteryBase {
    
    function buyTicket(uint8[5] memory numbers) external payable whenNotPaused {
        require(!roundLocked[currentRound], "Round locked");
        require(msg.value == getusdTicketPriceInBNB(), "Incorrect BNB amount");
        require(_validateNumbers(numbers), "Numbers must be unique and between 1 and 50");

        uint256 ownerCut = msg.value / 10;
       
        (bool sent, ) = owner().call{value: ownerCut}("");
        require(sent, "Transfer to owner failed");

        Ticket memory ticket = Ticket(msg.sender, numbers);
        allRounds[currentRound].tickets.push(ticket);
        playerTickets[currentRound][msg.sender].push(ticket);

        totalTicketsPerDraw[currentRound]++;

        if (!hasParticipated[currentRound][msg.sender]) {
            hasParticipated[currentRound][msg.sender] = true;
            uniqueParticipantsPerDraw[currentRound]++;
        }

        emit TicketPurchased(msg.sender, numbers, currentRound);
    }

    function buyTicketWithRandomNumbers() external payable whenNotPaused {
        require(!roundLocked[currentRound], "Round locked");
        require(msg.value == getusdTicketPriceInBNB(), "Incorrect BNB amount");

        uint8[5] memory randomNumbers = _generateRandomNumbers();

        uint256 ownerCut = msg.value / 10;
       
        (bool sent, ) = owner().call{value: ownerCut}("");
        require(sent, "Transfer to owner failed");

        Ticket memory ticket = Ticket(msg.sender, randomNumbers);
        allRounds[currentRound].tickets.push(ticket);
        playerTickets[currentRound][msg.sender].push(ticket);

        totalTicketsPerDraw[currentRound]++;

        if (!hasParticipated[currentRound][msg.sender]) {
            hasParticipated[currentRound][msg.sender] = true;
            uniqueParticipantsPerDraw[currentRound]++;
        }

        emit TicketPurchased(msg.sender, randomNumbers, currentRound);
    }

    function bulkTicketsWithRandomNumbers(uint8 ticketCount) external payable whenNotPaused {
        require(!roundLocked[currentRound], "Round locked");
        require(ticketCount >= 1 && ticketCount <= 10, "Must buy between 1 and 10 tickets");

        uint256 ticketPriceETH = getusdTicketPriceInBNB();
        uint256 totalCost = ticketPriceETH * ticketCount;
        require(msg.value == totalCost, "Incorrect BNB amount");

        uint256 ownerCut = msg.value / 10;
        
        (bool sent, ) = owner().call{value: ownerCut}("");
        require(sent, "Transfer to owner failed");

        for (uint8 i = 0; i < ticketCount; i++) {
            uint8[5] memory randomNumbers = _generateRandomNumbers();

            Ticket memory ticket = Ticket(msg.sender, randomNumbers);
            allRounds[currentRound].tickets.push(ticket);
            playerTickets[currentRound][msg.sender].push(ticket);

            totalTicketsPerDraw[currentRound]++;
            emit TicketPurchased(msg.sender, randomNumbers, currentRound);
        }

        if (!hasParticipated[currentRound][msg.sender]) {
            hasParticipated[currentRound][msg.sender] = true;
            uniqueParticipantsPerDraw[currentRound]++;
        }
    }

    function getMyTickets(uint256 round) external view returns (address[] memory players, uint8[5][] memory numbersList) {
        uint256 len = playerTickets[round][msg.sender].length;
        players = new address[](len);
        numbersList = new uint8[5][](len);

        for (uint i = 0; i < len; i++) {
            Ticket memory t = playerTickets[round][msg.sender][i];
            players[i] = t.player;
            numbersList[i] = t.numbers;
        }
    }

    function _generateRandomNumbers() internal override returns (uint8[5] memory result) {
        uint8 count = 0;
        uint256 seed = uint256(keccak256(abi.encodePacked(block.timestamp, msg.sender, nonce)));
        nonce++;

        while (count < 5) {
            uint8 num = uint8((seed % 50) + 1);
            bool exists = false;

            for (uint8 j = 0; j < count; j++) {
                if (result[j] == num) {
                    exists = true;
                    break;
                }
            }

            if (!exists) {
                result[count] = num;
                count++;
            }

            seed = uint256(keccak256(abi.encodePacked(seed, count, nonce)));
        }
        return result;
    }

    function _validateNumbers(uint8[5] memory numbers) internal pure override returns (bool) {
        for (uint i = 0; i < 5; i++) {
            if (numbers[i] < 1 || numbers[i] > 50) return false;
            for (uint j = 0; j < i; j++) {
                if (numbers[i] == numbers[j]) return false;
            }
        }
        return true;
    }
    
}
