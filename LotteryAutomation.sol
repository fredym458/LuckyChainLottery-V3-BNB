// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import "./LotteryDraw.sol";
import {AutomationCompatibleInterface} from "@chainlink/contracts/src/v0.8/automation/AutomationCompatible.sol";

abstract contract LotteryAutomation is LotteryDraw, AutomationCompatibleInterface {
    function checkUpkeep(bytes calldata) external view override returns (bool upkeepNeeded, bytes memory) {
        upkeepNeeded = !pendingDraw;
        return (upkeepNeeded, bytes(""));
    }

    function performUpkeep(bytes calldata) external override {
        require(msg.sender == automationRegistry, "Not authorized");
        require(!pendingDraw, "Draw already in progress or pending");
        _drawNumbers();
    }
}
