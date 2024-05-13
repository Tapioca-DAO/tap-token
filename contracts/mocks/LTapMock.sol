// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.22;

import {ERC20, ERC20Permit} from "@openzeppelin/contracts/token/ERC20/extensions/draft-ERC20Permit.sol";
import {SafeERC20, IERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

/*

████████╗ █████╗ ██████╗ ██╗ ██████╗  ██████╗ █████╗ 
╚══██╔══╝██╔══██╗██╔══██╗██║██╔═══██╗██╔════╝██╔══██╗
   ██║   ███████║██████╔╝██║██║   ██║██║     ███████║
   ██║   ██╔══██║██╔═══╝ ██║██║   ██║██║     ██╔══██║
   ██║   ██║  ██║██║     ██║╚██████╔╝╚██████╗██║  ██║
   ╚═╝   ╚═╝  ╚═╝╚═╝     ╚═╝ ╚═════╝  ╚═════╝╚═╝  ╚═╝
   
*/

contract LTapMock is Ownable, ERC20Permit {
    using SafeERC20 for IERC20;

    IERC20 public tapToken;
    bool public openRedemption;

    error TapNotSet();
    error RedemptionNotOpen();

    constructor(address _lbp, address _owner) ERC20("LTAPMock", "LTAPMock") ERC20Permit("LTAPMock") {
        _transferOwnership(_owner);
    }

    modifier tapExists() {
        if (address(tapToken) == address(0)) revert TapNotSet();
        _;
    }

    // TESTNET only
    function mint(address _to, uint256 _amount) external onlyOwner {
        _mint(_to, _amount);
    }

    /// @notice Sets the TAP token address
    /// @param _tapToken The TAP token address
    function setTapToken(address _tapToken) external onlyOwner {
        tapToken = IERC20(_tapToken);
    }

    function setOpenRedemption() external onlyOwner tapExists {
        openRedemption = true;
    }

    function redeem() external tapExists {
        if (!openRedemption) revert RedemptionNotOpen();
        uint256 amount = balanceOf(msg.sender);
        _burn(msg.sender, amount);
        tapToken.safeTransfer(msg.sender, amount);
    }
}
