// SPDX-License-Identifier: MIT
pragma solidity ^0.6.8;

import "./flashModule.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

// ETH Flashloan Example
contract ETHFlashTest is Ownable {
    // set the Lender contract address to a trusted flashmodule contract
    FlashModule public flasher; // Flashloan Module Contract

    constructor(address _flashmodule) public {
        flasher = FlashModule(_flashmodule);
    }

    // Borrow any ETH that the FlashModule holds
    function borrowETH(uint256 amount, bytes memory params) public onlyOwner {
        require(amount != 0, "amount-is-zero");
        flasher.ETHFlashLoan(amount, params);
    }

    // this is called by FlashModule after borrower has received the ETH
    function executeOnETHFlashLoan(
        uint256 amount,
        uint256 debt,
        bytes calldata params
    ) external {
        require(msg.sender == address(flasher), "only lender can execute");

        //... do whatever you want with the ETH
        //...

        // repay loan
        flasher.repayEthDebt{value: debt}();
    }
}
