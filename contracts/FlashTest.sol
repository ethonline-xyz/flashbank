pragma solidity 0.5.16;

import "./FlashModule.sol";
import "openzeppelin-solidity/contracts/ownership/Ownable.sol";
import "openzeppelin-solidity/contracts/token/ERC20/IERC20.sol";

// test purpose only
contract FlashTest is Ownable {
    
	// move to constructor
    // set the Lender contract address to a trusted flashmodule contract
    FlashModule public flasher = FlashModule(address(0x0));

    // @notice Borrow any ERC20 token that the FlashModule holds
    function borrow(address token, uint256 amount) public onlyOwner {
        flasher.ERC20FlashLoan(token, amount);
    }

    // this is called by FlashModule after borrower has received the tokens
    function executeOnERC20FlashLoan(address token, uint256 amount, uint256 debt) external {
        require(msg.sender == address(flasher), "only lender can execute");
        //... do whatever you want with the tokens
        // authorize loan repayment
        IERC20(token).approve(address(flasher), debt);
    }
}
