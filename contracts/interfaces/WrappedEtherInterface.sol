// SPDX-License-Identifier: MIT
pragma solidity ^0.6.8;

interface WrappedEtherInterface {
  function deposit() external payable;
  function withdraw(uint amount) external;
}
