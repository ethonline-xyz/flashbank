// SPDX-License-Identifier: MIT
pragma solidity ^0.6.8;

interface IETHFlash {
    function executeOnETHFlashLoan(uint256 amount, uint256 debt, bytes calldata params) external;
}
