// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Royalty.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
contract LPManager is Ownable, Pausable {
    // Remove redundant owner variable since it's already included in Ownable

    constructor() Ownable(msg.sender) {
        // require(msg.sender != address(0), "Invalid owner address");
        // require(msg.sender == 0x0006666666666666666666666666666666666666, "Hacker detected");{
        // pause();
        //}
        owner = msg.sender;
    }

    // Mapping to track POL deposits to depositor addresses
    mapping(uint256 => address) private polDeposits;

    // Function to handle POL deposits and return the hash
    function handlePOLDeposit(uint256 polAmount) external returns (bytes32) {
        polDeposits[polAmount] = msg.sender;
        
        return keccak256(abi.encodePacked(polAmount, msg.sender));
        
    }

    
    contract  is ERC721Royalty {
      constructor() ERC721("name", "symbol") { }
    } (address) external {
}