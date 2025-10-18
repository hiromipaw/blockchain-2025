// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * AllowanceVault — teaching contract (final version)
 *
 * Features:
 * - Owner-managed per-user allowances
 * - Daily withdrawal limit per user (demo uses 1 minute = "one day")
 * - Pull-payments (users withdraw their own funds)
 * - CEI ordering + optional nonReentrant guard
 * - Pause switch for ops safety
 *
 * Notes:
 * - Uses minutes for classroom speed; change to "1 days" for production.
 * - ETH only for clarity; token version would use ERC20 transfer/permit.
 */
contract AllowanceVault {
    // ----- Ownership & control -----
    address public owner;
    bool public paused;

    // Reentrancy guard (belt-and-suspenders; CEI already used)
    bool private locked;
    modifier nonReentrant() {
        require(!locked, "reentrant");
        locked = true;
        _;
        locked = false;
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "only owner");
        _;
    }

    modifier whenNotPaused() {
        require(!paused, "paused");
        _;
    }

    // ----- Per-user allowance & daily limit -----
    struct Limit {
        uint256 remainingTotal;  // total remaining allowance for the user
        uint256 dailyLimit;      // max withdrawable per day window
        uint256 spentToday;      // how much already withdrawn in current window
        uint256 dayStart;        // start timestamp of the current "day" window
    }

    mapping(address => Limit) public limits;

    // ----- Events for observability -----
    event Deposit(address indexed from, uint256 amount);
    event AllowanceConfigured(address indexed who, uint256 total, uint256 daily);
    event Withdrawn(address indexed who, uint256 amount);
    event Paused(bool on);
    event EmergencyWithdrawal(address indexed to, uint256 amount);

    // ----- Constructor -----
    constructor() payable {
        owner = msg.sender;
        if (msg.value > 0) emit Deposit(msg.sender, msg.value);
    }

    // Accept ETH top-ups (e.g., from owner/others)
    receive() external payable { emit Deposit(msg.sender, msg.value); }

    // ----- Admin controls -----
    function setPaused(bool on) external onlyOwner {
        paused = on;
        emit Paused(on);
    }

    /**
     * Configure a user's allowance.
     * @param who User address
     * @param total Total allowance (resets remaining to this value)
     * @param daily Daily limit within each window (must be <= total)
     */
    function setAllowance(address who, uint256 total, uint256 daily) external onlyOwner {
        require(who != address(0), "zero addr");
        require(daily <= total, "daily > total");
        Limit storage L = limits[who];
        L.remainingTotal = total;
        L.dailyLimit = daily;
        // reset daily window
        L.spentToday = 0;
        L.dayStart = block.timestamp;
        emit AllowanceConfigured(who, total, daily);
    }

    // Optional emergency drain to a safe multisig if something goes wrong.
    // (Keep for teaching; in real systems, prefer timelocks/multisig governance.)
    function emergencyWithdraw(address payable to) external onlyOwner {
        uint256 amt = address(this).balance;
        (bool ok, ) = to.call{value: amt}("");
        require(ok, "send failed");
        emit EmergencyWithdrawal(to, amt);
    }

    // ----- Core user flow -----

    /**
     * Withdraw an amount of ETH within your limits.
     * - Pull-payment: the user calls this to receive funds.
     * - CEI ordering + nonReentrant guard reduce reentrancy risk.
     */
    function withdraw(uint256 amount) external whenNotPaused nonReentrant {
        require(amount > 0, "amount=0");
        Limit storage L = limits[msg.sender];

        // Deterministic "day" rollover — classroom demo uses 1 minute as "a day".
        _rolloverIfNeeded(L);

        require(L.remainingTotal >= amount, "exceeds total");
        require(L.spentToday + amount <= L.dailyLimit, "exceeds daily");

        // --- CEI: Effects before Interactions ---
        L.remainingTotal -= amount;
        L.spentToday += amount;

        // Interaction last
        (bool ok, ) = payable(msg.sender).call{value: amount}("");
        require(ok, "send failed");

        emit Withdrawn(msg.sender, amount);
    }

    // ----- Internal helpers -----

    // For class speed: 1 minute window behaves like "one day".
    // Change to "1 days" for a real app.
    function _rolloverIfNeeded(Limit storage L) internal {
        if (block.timestamp >= L.dayStart + 1 minutes) {
            L.dayStart = block.timestamp;
            L.spentToday = 0;
        }
    }

    // ----- Views -----

    function balance() external view returns (uint256) {
        return address(this).balance;
    }

    /**
     * Convenience getter for UIs and students.
     * Returns remaining total, daily limit, spent today, and seconds to reset.
     */
    function viewAllowance(address who)
        external
        view
        returns (uint256 totalRem, uint256 dailyLim, uint256 spent, uint256 secondsLeft)
    {
        Limit storage L = limits[who];
        uint256 resetAt = L.dayStart + 1 minutes; // change to + 1 days in prod
        secondsLeft = block.timestamp >= resetAt ? 0 : (resetAt - block.timestamp);
        return (L.remainingTotal, L.dailyLimit, L.spentToday, secondsLeft);
    }
}