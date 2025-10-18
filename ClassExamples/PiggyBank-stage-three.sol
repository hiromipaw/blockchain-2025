// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract AllowanceVault {
    address public owner;

    struct Limit {
        uint256 remainingTotal;     // total remaining allowance
        uint256 dailyLimit;         // resettable daily limit
        uint256 spentToday;         // amount spent today
        uint256 dayStart;           // epoch of current 'day' window
    }

    mapping(address => Limit) public limits;

    event Deposit(address indexed from, uint256 amount);
    event AllowanceConfigured(address indexed who, uint256 total, uint256 daily);
    event Withdrawn(address indexed who, uint256 amount);

    modifier onlyOwner() { require(msg.sender == owner, "only owner"); _; }

    constructor() payable { owner = msg.sender; if (msg.value > 0) emit Deposit(msg.sender, msg.value); }
    receive() external payable { emit Deposit(msg.sender, msg.value); }

    function setAllowance(address who, uint256 total, uint256 daily) external onlyOwner {
        require(who != address(0), "zero addr");
        require(daily <= total, "daily <= total");
        Limit storage L = limits[who];
        L.remainingTotal = total;
        L.dailyLimit = daily;
        // reset window
        L.spentToday = 0;
        L.dayStart = block.timestamp;
        emit AllowanceConfigured(who, total, daily);
    }

    function _rolloverIfNeeded(Limit storage L) internal {
        // classroom-friendly: 1 minute "day" for fast demo
        if (block.timestamp >= L.dayStart + 1 minutes) {
            L.dayStart = block.timestamp;
            L.spentToday = 0;
        }
    }

    function withdraw(uint256 amount) external {
        require(amount > 0, "amount=0");
        Limit storage L = limits[msg.sender];
        _rolloverIfNeeded(L);
        require(L.remainingTotal >= amount, "exceeds total");
        require(L.spentToday + amount <= L.dailyLimit, "exceeds daily");

        // CEI
        L.remainingTotal -= amount;
        L.spentToday += amount;

        (bool ok, ) = payable(msg.sender).call{value: amount}("");
        require(ok, "send failed");
        emit Withdrawn(msg.sender, amount);
    }

    // views
    function balance() external view returns (uint256) { return address(this).balance; }
    function viewAllowance(address who) external view returns (uint256 totalRem, uint256 dailyLim, uint256 spent, uint256 secondsLeft) {
        Limit storage L = limits[who];
        uint256 resetAt = L.dayStart + 1 minutes;
        secondsLeft = block.timestamp >= resetAt ? 0 : (resetAt - block.timestamp);
        return (L.remainingTotal, L.dailyLimit, L.spentToday, secondsLeft);
    }
}