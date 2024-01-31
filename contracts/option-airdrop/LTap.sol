// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.22;

import {ERC20, ERC20Permit} from "@openzeppelin/contracts/token/ERC20/extensions/draft-ERC20Permit.sol";
import {SafeERC20, IERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {BoringOwnable} from "@boringcrypto/boring-solidity/contracts/BoringOwnable.sol";

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
    using SafeERC20 for IERC20;

    IERC20 tapToken;
    address immutable lbp;
    bool openRedemption;

    error TapNotSet();
    error RedemptionNotOpen();

    /// @notice Creates a new LTAP token
    /// @dev LTAP tokens are minted by depositing TAP
    constructor(address _lbp) ERC20("LTAP", "LTAP") ERC20Permit("LTAP") {
        _mint(_lbp, 5_000_000 * 1e18); // 5M LTAP for LBP
    }

    modifier tapExists() {
        if (address(tapToken) == address(0)) revert TapNotSet();
        _;
    }
    /// @notice Sets the TAP token address
    /// @param _tapToken The TAP token address

    function setTapToken(address _tapToken) external onlyOwner {
        tapToken = IERC20(_tapToken);
    }

    function setOpenRedemption() external onlyOwner {
        openRedemption = true;
    }

    function redeem() external tapExists {
        if (!openRedemption) revert RedemptionNotOpen();
        uint256 amount = balanceOf(msg.sender);
        _burn(msg.sender, amount);
        tapToken.safeTransfer(msg.sender, amount);
    }
}
