// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.22;

import {IERC20Permit} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Permit.sol";
import {ITapOFTv2, LockTwTapPositionMsg, ERC20PermitApprovalMsg} from "../ITapOFTv2.sol";

/**
 * @title TapOFTExtExec
 * @author TapiocaDAO
 * @notice Used to execute external calls from the TapOFTv2 contract. So to not use TapOFTv2 in the call context.
 */
contract TapOFTExtExec {
    /**
     * @notice Executes an ERC20 permit approval.
     * @param _approvals The ERC20 permit approval messages.
     */
    function erc20PermitApproval(
        ERC20PermitApprovalMsg[] calldata _approvals
    ) public {
        uint256 approvalsLength = _approvals.length;
        for (uint256 i = 0; i < approvalsLength; ) {
            IERC20Permit(_approvals[i].token).permit(
                _approvals[i].owner,
                _approvals[i].spender,
                _approvals[i].value,
                _approvals[i].deadline,
                _approvals[i].v,
                _approvals[i].r,
                _approvals[i].s
            );
            unchecked {
                ++i;
            }
        }
    }
}
