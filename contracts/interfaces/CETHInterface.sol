// SPDX-License-Identifier: MIT
pragma solidity ^0.6.8;

interface CETHInterface {
    function mint() external payable;

    function repayBorrow() external payable;
}
