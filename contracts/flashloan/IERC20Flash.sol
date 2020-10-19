// SPDX-License-Identifier: MIT
pragma solidity ^0.6.8;

interface IERC20Flash {
    function executeOnERC20FlashLoan(address token, uint256 amount, uint256 debt, bytes calldata params) external;
}
