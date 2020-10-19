pragma solidity ^0.6.8;

// instead of importing flashmodule import interface
import "./module.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

// Flashloan Example
contract FlashTest is Ownable {
	
	// move to constructor-done
    // set the Lender contract address to a trusted flashmodule contract
    FlashModule public flasher; // Flashloan Module Contract

    constructor(
    address _module
    ) public {
	flasher = FlashModule(_module);
    }	

    // @notice Borrow any ERC20 token that the FlashModule holds
    function borrow(address token, uint256 amount,bytes memory params) public onlyOwner {
	    require(amount != 0, "amount-is-zero");
        flasher.flashloan(token, amount, params);
    }

    // this is called by FlashModule after borrower has received the tokens
    function executeOnERC20FlashLoan(address token, uint256 amount, uint256 debt,bytes calldata params) external {
        require(msg.sender == address(flasher), "only lender can execute");
        //... do whatever you want with the tokens
        // authorize loan repayment
        IERC20(token).approve(address(flasher), debt);
    }
}
