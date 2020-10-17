pragma solidity ^0.5.16;

import "./IERC20Flash.sol"; 
import "./FlashRegistry.sol";
import "openzeppelin-solidity/contracts/math/SafeMath.sol";
import "openzeppelin-solidity/contracts/token/ERC20/IERC20.sol";

// @notice Any contract that inherits this contract becomes a flash lender of any ERC20 tokens that it has whitelisted.
contract FlashModule {
    using SafeMath for uint256;
    
	// shift to constructor
    uint256 internal _tokenBorrowFee; // e.g.: 0.003e18 means 0.3% fee
    uint256 constant internal ONE = 1e18;
    
	// replace with registry or have some other mechanism to update token addresses
    // only whitelist tokens whose `transferFrom` function returns false (or reverts) on failure
    mapping(address => bool) internal _whitelist;

    // @notice Borrow tokens via a flash loan. See FlashTest for example.
    function ERC20FlashLoan(address token, uint256 amount) public {
        // token must be whitelisted by Lender
        require(_whitelist[token], "token not whitelisted");

        // record debt
        uint256 debt = amount.mul(ONE.add(_tokenBorrowFee)).div(ONE);

        // send borrower the tokens
        require(IERC20(token).transfer(msg.sender, amount), "borrow failed");

        // hand over control to borrower
        IERC20Flash(msg.sender).executeOnERC20FlashLoan(token, amount, debt);

        // repay the debt
        require(IERC20(token).transferFrom(msg.sender, address(this), debt), "repayment failed");
    }

    function tokenBorrowerFee() public view returns (uint256) {
        return _tokenBorrowFee;
    }
}
