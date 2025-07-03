// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import "./LotteryAutomation.sol";

contract Lottery is LotteryAutomation {
    constructor(uint256 subscriptionId) LotteryBase(subscriptionId) {}
}
