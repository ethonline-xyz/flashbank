// SPDX-License-Identifier: MIT
pragma solidity ^0.6.8;

interface WrappedEtherInterface {
    function deposit() external payable;

    function withdraw(uint256 amount) external;

    function balanceOf(address owner) external view returns (uint256 balance);
}
