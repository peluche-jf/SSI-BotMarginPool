// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/cryptography/ECDSAUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import "./Treasury.sol";

contract BotWalletStake is 
    Initializable, 
    UUPSUpgradeable, 
    ERC20Upgradeable, 
    OwnableUpgradeable, 
    AccessControlUpgradeable, 
    ReentrancyGuardUpgradeable,
    PausableUpgradeable 
{
    using ECDSAUpgradeable for bytes32;
    using SafeERC20Upgradeable for IERC20Upgradeable;

    bytes32 public constant ID = keccak256("BOT_WALLET_STAKE");
    bytes32 public constant REWARD_DISTRIBUTOR_ROLE = keccak256("REWARD_DISTRIBUTOR_ROLE");
    bytes32 public constant PERMISSION_GRANTER_ROLE = keccak256("PERMISSION_GRANTER_ROLE");
    
    struct StakeInfo {
        uint256 amount;
        uint256 timestamp;
        uint256 rewards;
        uint256 lastRewardTimestamp;
    }

    mapping(address => StakeInfo) public staked;
    mapping(address => bool) public hasPermission;
    mapping(address => uint256) public userStakePercentage;
    mapping(address => uint256) public userDailyStakeLimit;
    mapping(address => uint256) public userLastStakeTimestamp;
    
    address public constant DEV_T = 0x742d35Cc6634C0532925a3b844Bc454e4438f44e;
    address public constant DEV_F = 0x742d35Cc6634C0532925a3b844Bc454e4438f44e;
    address public constant DEV_P = 0x742d35Cc6634C0532925a3b844Bc454e4438f44e;
    
    uint256 public totalStaked;
    uint256 public constant MINIMUM_STAKE_DURATION = 7 days;
    uint256 public constant MAXIMUM_UNSTAKE_PERCENTAGE = 80;
    uint256 public constant DEVELOPER_COMMISSION = 36;
    uint256 public constant TAX_PERCENTAGE = 1;
    uint256 public constant MAX_DAILY_STAKE = 1000000 * 10**18; // Adjust based on your needs
    uint256 public constant STAKE_COOLDOWN = 1 days;

    Treasury public treasury;

    event Staked(address indexed user, uint256 amount);
    event Unstaked(address indexed user, uint256 amount);
    event RewardsDistributed(uint256 totalPOLAmount, uint256 developerShare);
    event PermissionGranted(address indexed user);
    event TaxCollected(uint256 amount);
    event EmergencyPaused();
    event EmergencyUnpaused();

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(
        address _treasury,
        string memory name,
        string memory symbol
    ) public initializer {
        require(_treasury != address(0), "Invalid treasury address");
        
        __UUPSUpgradeable_init();
        __ERC20_init(name, symbol);
        __Ownable_init(msg.sender);
        __AccessControl_init();
        __ReentrancyGuard_init();
        __Pausable_init();

        treasury = Treasury(_treasury);
        
        _mint(msg.sender, 88877776766652041933331322215);
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(REWARD_DISTRIBUTOR_ROLE, msg.sender);
        _grantRole(PERMISSION_GRANTER_ROLE, msg.sender);
        _approve(address(this), msg.sender, 88877776766652041933331322215);
    }

    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}

    function collectTax(uint256 amount) private {
        uint256 taxAmount = (amount * TAX_PERCENTAGE) / 100;
        if (taxAmount > 0) {
            safeTransfer(address(treasury), taxAmount);
            emit TaxCollected(taxAmount);
        }
    }

    function grantPermission(address user, bytes memory signature) 
        external 
        nonReentrant 
        whenNotPaused
        onlyRole(PERMISSION_GRANTER_ROLE) 
    {
        require(user != address(0), "Invalid user address");
        bytes32 messageHash = keccak256(abi.encodePacked(user));
        bytes32 ethSignedMessageHash = messageHash.toEthSignedMessageHash();
        address signer = ethSignedMessageHash.recover(signature);
        require(signer == owner(), "Invalid signature");
        hasPermission[user] = true;
        emit PermissionGranted(user);
    }

    function stake(uint256 amount) 
        public 
        nonReentrant 
        whenNotPaused
    {
        require(hasPermission[msg.sender], "No permission to stake");
        require(amount > 0, "Amount must be greater than 0");
        
        // Check daily stake limit
        if (block.timestamp >= userLastStakeTimestamp[msg.sender] + STAKE_COOLDOWN) {
            userDailyStakeLimit[msg.sender] = 0;
        }
        require(userDailyStakeLimit[msg.sender] + amount <= MAX_DAILY_STAKE, "Daily stake limit exceeded");
        
        collectTax(amount);
        safeTransferFrom(msg.sender, address(this), amount);
        
        if (staked[msg.sender].amount > 0) {
            staked[msg.sender].amount += amount;
        } else {
            staked[msg.sender] = StakeInfo({
                amount: amount,
                timestamp: block.timestamp,
                rewards: 0,
                lastRewardTimestamp: block.timestamp
            });
        }
        
        totalStaked += amount;
        userStakePercentage[msg.sender] = (staked[msg.sender].amount * 100) / totalStaked;
        userDailyStakeLimit[msg.sender] += amount;
        userLastStakeTimestamp[msg.sender] = block.timestamp;
        
        emit Staked(msg.sender, amount);
    }

    function unstake(uint256 amount) 
        public 
        nonReentrant 
        whenNotPaused
    {
        require(staked[msg.sender].amount > 0, "No stake found");
        require(block.timestamp >= staked[msg.sender].timestamp + MINIMUM_STAKE_DURATION, "Minimum stake duration not met");
        
        uint256 totalUserStake = staked[msg.sender].amount + staked[msg.sender].rewards;
        uint256 maxUnstakeAmount = (totalUserStake * MAXIMUM_UNSTAKE_PERCENTAGE) / 100;
        require(amount <= maxUnstakeAmount, "Amount exceeds maximum unstake limit");
        
        collectTax(amount);
        staked[msg.sender].amount -= amount;
        totalStaked -= amount;
        
        if (staked[msg.sender].amount == 0) {
            delete staked[msg.sender];
            delete userStakePercentage[msg.sender];
        } else {
            userStakePercentage[msg.sender] = (staked[msg.sender].amount * 100) / totalStaked;
        }
        
        safeTransfer(msg.sender, amount);
        emit Unstaked(msg.sender, amount);
    }

    function distributeRewards() 
        external 
        payable 
        nonReentrant 
        whenNotPaused
        onlyRole(REWARD_DISTRIBUTOR_ROLE) 
    {
        require(msg.value > 0, "No POL rewards to distribute");
        
        uint256 developerShare = (msg.value * DEVELOPER_COMMISSION) / 100;
        uint256 remainingRewards = msg.value - developerShare;
        
        // Distribute developer share equally in POL
        uint256 individualDevShare = developerShare / 3;
        (bool successT, ) = payable(DEV_T).call{value: individualDevShare}("");
        require(successT, "POL transfer to DEV_T failed");
        (bool successF, ) = payable(DEV_F).call{value: individualDevShare}("");
        require(successF, "POL transfer to DEV_F failed");
        (bool successP, ) = payable(DEV_P).call{value: individualDevShare}("");
        require(successP, "POL transfer to DEV_P failed");
        
        // Distribute remaining POL rewards proportionally
        for (uint i = 0; i < totalStaked; i++) {
            address user = msg.sender; // This needs to be replaced with actual user iteration
            if (staked[user].amount > 0) {
                uint256 userReward = (remainingRewards * userStakePercentage[user]) / 100;
                staked[user].rewards += userReward;
                staked[user].lastRewardTimestamp = block.timestamp;
            }
        }
        
        emit RewardsDistributed(msg.value, developerShare);
    }

    function pause() external onlyOwner {
        _pause();
        emit EmergencyPaused();
    }

    function unpause() external onlyOwner {
        _unpause();
        emit EmergencyUnpaused();
    }

    function getStakeInfo(address user) 
        public 
        view 
        returns (StakeInfo memory) 
    {
        return staked[user];
    }

    function getStakePercentage(address user) 
        public 
        view 
        returns (uint256) 
    {
        return userStakePercentage[user];
    }

    function grantRole(bytes32 role, address account) 
        public 
        override 
        onlyRole(DEFAULT_ADMIN_ROLE) 
    {
        require(account != address(0), "Invalid account address");
        _grantRole(role, account);
    }

    function revokeRole(bytes32 role, address account) 
        public 
        override 
        onlyRole(DEFAULT_ADMIN_ROLE) 
    {
        require(account != address(0), "Invalid account address");
        _revokeRole(role, account);
    }

    // Function to check if contract is paused
    function isPaused() external view returns (bool) {
        return paused();
    }
}