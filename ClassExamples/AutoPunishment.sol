// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract AutoPunishment {
    address punchingball = 0x5B38Da6a701c568545dCfcB03FcB875f56beddC4;
    address payable owner = payable(0xCA35b7d915458EF540aDe6068dFe2F44E8fa733c);
    uint256 finalPracticeDeadline;
    uint256 nextDeadline;
    uint256 PRACTICE_TOTAL_TIME = 30 days;
    uint256 PRACTICE_FREQUENCY = 2 days;

    constructor() payable {
    finalPracticeDeadline = block.timestamp + PRACTICE_TOTAL_TIME;
    nextDeadline = block.timestamp + PRACTICE_FREQUENCY;
    }

    function extendNextDeadline() external {
    require(msg.sender == punchingball);
    require(block.timestamp < finalPracticeDeadline);
    if (block.timestamp < nextDeadline ) { nextDeadline = nextDeadline + PRACTICE_FREQUENCY; } // you can extend deadline
    else { payable(0).transfer(address(this).balance); } // you arrive late, burn the money!
    }

    function withdraw() external {
    require(msg.sender == owner);
    require(block.timestamp >= finalPracticeDeadline);
    if (nextDeadline >= finalPracticeDeadline ) { owner.transfer(address(this).balance); } // practice ok, recover your money!
    else { payable(0).transfer(address(this).balance); } // burn the money not practised enough!
    }
}