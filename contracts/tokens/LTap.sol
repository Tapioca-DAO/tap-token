// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.18;

import "@boringcrypto/boring-solidity/contracts/BoringOwnable.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/draft-ERC20Permit.sol";

/*

__/\\\\\\\\\\\\\\\_____/\\\\\\\\\_____/\\\\\\\\\\\\\____/\\\\\\\\\\\_______/\\\\\_____________/\\\\\\\\\_____/\\\\\\\\\____        
 _\///////\\\/////____/\\\\\\\\\\\\\__\/\\\/////////\\\_\/////\\\///______/\\\///\\\________/\\\////////____/\\\\\\\\\\\\\__       
  _______\/\\\________/\\\/////////\\\_\/\\\_______\/\\\_____\/\\\_______/\\\/__\///\\\____/\\\/____________/\\\/////////\\\_      
   _______\/\\\_______\/\\\_______\/\\\_\/\\\\\\\\\\\\\/______\/\\\______/\\\______\//\\\__/\\\_____________\/\\\_______\/\\\_     
    _______\/\\\_______\/\\\\\\\\\\\\\\\_\/\\\/////////________\/\\\_____\/\\\_______\/\\\_\/\\\_____________\/\\\\\\\\\\\\\\\_    
     _______\/\\\_______\/\\\/////////\\\_\/\\\_________________\/\\\_____\//\\\______/\\\__\//\\\____________\/\\\/////////\\\_   
      _______\/\\\_______\/\\\_______\/\\\_\/\\\_________________\/\\\______\///\\\__/\\\_____\///\\\__________\/\\\_______\/\\\_  
       _______\/\\\_______\/\\\_______\/\\\_\/\\\______________/\\\\\\\\\\\____\///\\\\\/________\////\\\\\\\\\_\/\\\_______\/\\\_ 
        _______\///________\///________\///__\///______________\///////////_______\/////_____________\/////////__\///________\///__

*/

/// @title LTAP
/// @notice Locked TAP
contract LTap is BoringOwnable, ERC20Permit {
    IERC20 tapToken;
    uint256 public lockedUntil;
    uint256 public maxLockedUntil;

    /// @notice Creates a new LTAP token
    /// @dev LTAP tokens are minted by depositing TAP
    /// @param _tapToken Address of the TAP token
    /// @param _maxLockedUntil Latest possible end of locking period
    constructor(
        IERC20 _tapToken,
        uint256 _maxLockedUntil
    ) ERC20("LTAP", "LTAP") ERC20Permit("LTAP") {
        tapToken = _tapToken;
        lockedUntil = _maxLockedUntil;
        maxLockedUntil = _maxLockedUntil;
    }

    function deposit(uint256 amount) external {
        tapToken.transferFrom(msg.sender, address(this), amount);
        _mint(msg.sender, amount);
    }

    function redeem() external {
        require(block.timestamp > lockedUntil, "Still locked");
        uint256 amount = balanceOf(msg.sender);
        _burn(msg.sender, amount);
        tapToken.transfer(msg.sender, amount);
    }

    function setLockedUntil(uint256 _lockedUntil) external onlyOwner {
        require(_lockedUntil <= maxLockedUntil, "Too late");
        lockedUntil = _lockedUntil;
    }
}
