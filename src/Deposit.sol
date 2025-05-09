// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./LPManager.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract Deposit is LPManager {

    
    function deposit() public payable {
        require(msg.value > 0, "Deposit amount must be greater than 0");
        tax(msg.value);
        
        

    }

    function tax() public payable {
        require(msg.value > 0, "Comission not enough");
        uint256 comission = msg.value*99/100;
        owner.transfer(comission);
        return msg.value -= comission;
    }
}