// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract AutoPunishmentVisual {
    // --- Roles ---
    address public punchingball;
    address payable public owner;

    // --- Timing/state (public for easy viewing) ---
    uint256 public finalPracticeDeadline;
    uint256 public nextDeadline;
    uint256 public PRACTICE_TOTAL_TIME;  // in seconds
    uint256 public PRACTICE_FREQUENCY;   // in seconds

    // --- Events to make it visual in Remix ---
    event Deployed(address indexed owner, address indexed punchingball, uint256 stakeWei);
    event OnTimeCheckIn(address indexed by, uint256 at, uint256 oldDeadline, uint256 newDeadline);
    event LateBurn(uint256 at, uint256 amountWei);
    event Withdrawn(address indexed to, uint256 amountWei);
    event FinalBurn(uint256 at, uint256 amountWei);

    /**
     * @param _punchingball  address allowed to call extendNextDeadline()
     * @param totalMinutes   total program length (minutes)  — use small numbers for class
     * @param freqMinutes    check-in frequency  (minutes)
     *
     * Payable so you can stake ETH on deploy (fake ETH in Remix VM).
     */
    constructor(address _punchingball, uint256 totalMinutes, uint256 freqMinutes) payable {
        require(_punchingball != address(0), "punchingball required");
        require(totalMinutes > 0 && freqMinutes > 0, "minutes > 0");
        require(totalMinutes >= freqMinutes, "total >= freq");

        owner = payable(msg.sender);
        punchingball = _punchingball;

        PRACTICE_TOTAL_TIME = totalMinutes * 1 minutes;
        PRACTICE_FREQUENCY  = freqMinutes * 1 minutes;

        finalPracticeDeadline = block.timestamp + PRACTICE_TOTAL_TIME;
        nextDeadline          = block.timestamp + PRACTICE_FREQUENCY;

        emit Deployed(owner, punchingball, msg.value);
    }

    // Optional: let anyone top-up the stake (nice to show balance changes).
    receive() external payable {}

    /**
     * Same rule as your original:
     * - If now < nextDeadline → extend by one frequency (on time)
     * - Else (late)          → burn entire balance to address(0)
     */
    function extendNextDeadline() external {
        require(msg.sender == punchingball, "only punchingball");
        require(block.timestamp < finalPracticeDeadline, "program ended");

        if (block.timestamp < nextDeadline) {
            uint256 old = nextDeadline;
            nextDeadline = nextDeadline + PRACTICE_FREQUENCY;
            emit OnTimeCheckIn(msg.sender, block.timestamp, old, nextDeadline);
        } else {
            uint256 amt = address(this).balance;
            if (amt > 0) {
                (bool ok, ) = payable(address(0)).call{value: amt}("");
                require(ok, "burn failed");
            }
            emit LateBurn(block.timestamp, amt);
        }
    }

    /**
     * Same rule as your original:
     * - Only owner can withdraw, only after finalPracticeDeadline
     * - If nextDeadline >= finalPracticeDeadline → success, owner gets balance
     * - Else → burn remaining balance
     */
    function withdraw() external {
        require(msg.sender == owner, "only owner");
        require(block.timestamp >= finalPracticeDeadline, "too early");

        uint256 bal = address(this).balance;
        if (nextDeadline >= finalPracticeDeadline) {
            if (bal > 0) {
                (bool ok, ) = owner.call{value: bal}("");
                require(ok, "send failed");
            }
            emit Withdrawn(owner, bal);
        } else {
            if (bal > 0) {
                (bool ok, ) = payable(address(0)).call{value: bal}("");
                require(ok, "burn failed");
            }
            emit FinalBurn(block.timestamp, bal);
        }
    }

    // Convenience read functions for on-screen timers
    function secondsToNextDeadline() external view returns (uint256) {
        return block.timestamp >= nextDeadline ? 0 : (nextDeadline - block.timestamp);
    }

    function secondsToEnd() external view returns (uint256) {
        return block.timestamp >= finalPracticeDeadline ? 0 : (finalPracticeDeadline - block.timestamp);
    }
}