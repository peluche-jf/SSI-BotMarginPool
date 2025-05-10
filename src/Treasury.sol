// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";

contract Treasury is Initializable, UUPSUpgradeable, OwnableUpgradeable, ReentrancyGuardUpgradeable, PausableUpgradeable {
    using SafeERC20Upgradeable for IERC20Upgradeable;

    // Mapping to track allowed tokens
    mapping(address => bool) public allowedTokens;
    // Mapping to track token balances
    mapping(address => uint256) public tokenBalances;
    // Mapping to track daily withdrawal limits
    mapping(address => uint256) public dailyWithdrawals;
    mapping(address => uint256) public lastWithdrawalTimestamp;

    uint256 public constant MAX_DAILY_WITHDRAWAL = 1000000 * 10**18; // Adjust based on your needs
    uint256 public constant WITHDRAWAL_COOLDOWN = 1 days;

    event TokenAllowed(address indexed token, bool allowed);
    event TaxReceived(address indexed token, uint256 amount);
    event TaxWithdrawn(address indexed token, uint256 amount);
    event EmergencyWithdraw(address indexed token, uint256 amount);

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize() public initializer {
        __UUPSUpgradeable_init();
        __Ownable_init(msg.sender);
        __ReentrancyGuard_init();
        __Pausable_init();
    }

    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}

    function allowToken(address token, bool allowed) external onlyOwner {
        require(token != address(0), "Invalid token address");
        allowedTokens[token] = allowed;
        emit TokenAllowed(token, allowed);
    }

    function receiveTax(address token, uint256 amount) 
        external 
        nonReentrant 
        whenNotPaused 
    {
        require(allowedTokens[token], "Token not allowed");
        require(amount > 0, "Amount must be greater than 0");
        
        IERC20Upgradeable(token).safeTransferFrom(msg.sender, address(this), amount);
        tokenBalances[token] += amount;
        
        emit TaxReceived(token, amount);
    }

    function withdrawTax(address token, uint256 amount) 
        external 
        nonReentrant 
        whenNotPaused 
        onlyOwner 
    {
        require(allowedTokens[token], "Token not allowed");
        require(amount > 0, "Amount must be greater than 0");
        require(amount <= tokenBalances[token], "Insufficient balance");
        
        // Check daily withdrawal limit
        if (block.timestamp >= lastWithdrawalTimestamp[token] + WITHDRAWAL_COOLDOWN) {
            dailyWithdrawals[token] = 0;
        }
        require(dailyWithdrawals[token] + amount <= MAX_DAILY_WITHDRAWAL, "Daily withdrawal limit exceeded");
        
        tokenBalances[token] -= amount;
        dailyWithdrawals[token] += amount;
        lastWithdrawalTimestamp[token] = block.timestamp;
        
        IERC20Upgradeable(token).safeTransfer(owner(), amount);
        emit TaxWithdrawn(token, amount);
    }

    function pause() external onlyOwner {
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
    }

    function emergencyWithdraw(address token) external onlyOwner {
        require(token != address(0), "Invalid token address");
        uint256 balance = tokenBalances[token];
        require(balance > 0, "No balance to withdraw");
        
        tokenBalances[token] = 0;
        IERC20Upgradeable(token).safeTransfer(owner(), balance);
        
        emit EmergencyWithdraw(token, balance);
    }

    // Function to check if contract is paused
    function isPaused() external view returns (bool) {
        return paused();
    }
} 