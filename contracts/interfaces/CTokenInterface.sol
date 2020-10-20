// SPDX-License-Identifier: MIT
pragma solidity ^0.6.8;

interface CTokenInterface {
    function mint(uint256 mintAmount) external returns (uint256);

    function borrow(uint256 borrowAmount) external returns (uint256);

    function repayBorrow(uint256 repayAmount) external returns (uint256);

    function redeemUnderlying(uint256 redeemAmount) external returns (uint256);

    function redeem(uint256 redeemTokens) external returns (uint256);

    function exchangeRateCurrent() external returns (uint256);

    function balanceOf(address owner) external view returns (uint256 balance);

    function underlying() external view returns (address);

    function approve(address, uint256) external;

    function transfer(address, uint256) external returns (bool);

    function transferFrom(
        address,
        address,
        uint256
    ) external returns (bool);
}
