// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract HelloStorage {
    // Private state variable stored on-chain
    string private greeting;

    // Emitted on every state change (shows up in transaction logs)
    event GreetingChanged(address indexed changer, string newGreeting);

    // Runs once at deployment time
    constructor(string memory initialGreeting) {
        greeting = initialGreeting;
    }

    // "view" = read-only, no state change, no gas when called locally
    function greet() external view returns (string memory) {
        return greeting;
    }

    // State-changing function = requires a transaction + gas
    function setGreeting(string calldata newGreeting) external {
        require(bytes(newGreeting).length > 0, "Greeting cannot be empty");
        greeting = newGreeting;
        emit GreetingChanged(msg.sender, newGreeting);
    }
}