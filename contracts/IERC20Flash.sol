pragma solidity ^0.5.16;

interface IERC20Flash {
    function executeOnERC20FlashLoan(address token, uint256 amount, uint256 debt) external;
}