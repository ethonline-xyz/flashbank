// SPDX-License-Identifier: MIT
pragma solidity ^0.6.8;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./CTokenInterface.sol";

interface CTokenPoolInterface {
  function cToken() external view returns (CTokenInterface);
  function underlyingToken() external view returns (IERC20);
}
