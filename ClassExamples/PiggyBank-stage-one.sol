// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract AllowanceVault {
    address public owner;

    event Deposit(address indexed from, uint256 amount);
    event EmergencyWithdrawal(address indexed to, uint256 amount);

    modifier onlyOwner() {
        require(msg.sender == owner, "only owner");
        _;
    }

    constructor() payable {
        owner = msg.sender;
        if (msg.value > 0) emit Deposit(msg.sender, msg.value);
    }

    receive() external payable {
        emit Deposit(msg.sender, msg.value);
    }

    // Owner-only emergency drain (we'll replace with per-user in a minute)
    function emergencyWithdraw(address payable to) external onlyOwner {
        uint256 amt = address(this).balance;
        (bool ok, ) = to.call{value: amt}("");
        require(ok, "send failed");
        emit EmergencyWithdrawal(to, amt);
    }

    function balance() external view returns (uint256) {
        return address(this).balance;
    }
}
