// SPDX-License-Identifier: MIT
pragma solidity ^0.6.8;

import "./flashModule.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

// ERC20 Flashloan Example
contract ERC20FlashTest is Ownable {
	
    // set the Lender contract address to a trusted flashmodule contract
    FlashModule public flasher; // Flashloan Module Contract

    constructor(
    address _flashmodule
    ) public {
	flasher = FlashModule(_flashmodule);
    }	

    // @notice Borrow any ERC20 token that the FlashModule holds
    function borrow(address token, uint256 amount,bytes memory params) public onlyOwner {
	    require(amount != 0, "amount-is-zero");
        flasher.flashloan(token, amount, params);
    }

    // this is called by FlashModule after borrower has received the tokens
    function executeOnERC20FlashLoan(address token, uint256 amount, uint256 debt, bytes calldata params) external {
        require(msg.sender == address(flasher), "only lender can execute");
        //... do whatever you want with the tokens
        // authorize loan repayment
        IERC20(token).approve(address(flasher), debt);
    }
}
