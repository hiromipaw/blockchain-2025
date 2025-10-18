// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract AllowanceVault {
    address public owner;
    mapping(address => uint256) public allowance;

    event Deposit(address indexed from, uint256 amount);
    event AllowanceSet(address indexed who, uint256 amount);
    event Withdrawn(address indexed who, uint256 amount);

    modifier onlyOwner() { require(msg.sender == owner, "only owner"); _; }

    constructor() payable { owner = msg.sender; if (msg.value > 0) emit Deposit(msg.sender, msg.value); }
    receive() external payable { emit Deposit(msg.sender, msg.value); }

    function setAllowance(address who, uint256 amount) external onlyOwner {
        allowance[who] = amount;
        emit AllowanceSet(who, amount);
    }

    // ✔ Pull-payment: user withdraws only their allowance
    function withdraw(uint256 amount) external {
        require(amount > 0, "amount=0");
        uint256 a = allowance[msg.sender];
        require(a >= amount, "exceeds allowance");

        // CEI: effects before interaction
        allowance[msg.sender] = a - amount;

        (bool ok, ) = payable(msg.sender).call{value: amount}("");
        require(ok, "send failed");

        emit Withdrawn(msg.sender, amount);
    }

    function balance() external view returns (uint256) { return address(this).balance; }
}
