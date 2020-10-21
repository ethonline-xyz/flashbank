// SPDX-License-Identifier: MIT
pragma solidity ^0.6.8;

import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

import "../interfaces/CTokenInterface.sol";
import "../interfaces/FlashModuleInterface.sol";

import {DSMath} from "../libs/safeMath.sol";

contract FlashCTokenPool is ReentrancyGuard, ERC20, DSMath {
    using SafeERC20 for IERC20;

    event LogExchangeRate(uint256 exchangeRate);
    event LogDeposit(address indexed user, uint256 amount, uint256 mintAmt);
    event LogDepositUnderlying(
        address indexed user,
        uint256 amount,
        uint256 underlyingAmount,
        uint256 mintAmt
    );
    event LogWithdraw(address indexed user, uint256 cAmount, uint256 burnAmt);

    CTokenInterface public immutable cToken; // Compound token. Eg:- cDAI, cUSDC, etc.
    IERC20 public immutable underlyingToken; // underlying ctoken. Eg:- DAI, USDC, etc.
    FlashModuleInterface public immutable flashModule; // Flashloan module contract

    uint256 public exchangeRate; // initial 1 ctoken = 1 wrap token

    constructor(
        string memory _name,
        string memory _symbol,
        address _ctoken,
        address _flashmodule
    ) public ERC20(_name, _symbol) {
        cToken = CTokenInterface(_ctoken);
        flashModule = FlashModuleInterface(_flashmodule);
        underlyingToken = IERC20(CTokenInterface(_ctoken).underlying());
        IERC20(CTokenInterface(_ctoken).underlying()).approve(
            _ctoken,
            uint256(-1)
        );
        exchangeRate = 10**28;
    }

    /**
     * @dev get current exchange rate
     */
    function getExchangeRate() public {
        if (totalSupply() != 0) {
            address flashModuleAddr = address(flashModule);
            uint256 _ctokenBal = cToken.balanceOf(flashModuleAddr);
            uint256 _tokenBal = underlyingToken.balanceOf(flashModuleAddr);
            _ctokenBal += wdiv(_tokenBal, cToken.exchangeRateCurrent());
            exchangeRate = wmul(_ctokenBal, totalSupply());
        }
        emit LogExchangeRate(exchangeRate);
    }

    /**
     * @dev Deposit ctoken.
     * @param amount ctoken amount
     * @return mintAmt amount of wrap token minted
     */
    function deposit(uint256 amount)
        external
        nonReentrant
        returns (uint256 mintAmt)
    {
        require(amount != 0, "amount-is-zero");
        cToken.transferFrom(msg.sender, address(flashModule), amount);
        getExchangeRate();
        mintAmt = wmul(amount, exchangeRate);
        _mint(msg.sender, mintAmt);

        emit LogDeposit(msg.sender, amount, mintAmt);
    }

    /**
     * @dev Deposit underlying token.
     * @param amount underlying token amount
     * @return mintAmt amount of wrap token minted
     */
    function depositUnderlying(uint256 amount)
        external
        nonReentrant
        returns (uint256 mintAmt)
    {
        require(amount != 0, "amount-is-zero");
        underlyingToken.safeTransferFrom(msg.sender, address(this), amount);
        uint256 initalBal = cToken.balanceOf(address(this));
        require(cToken.mint(amount) == 0, "minting-reverted");
        uint256 finalBal = cToken.balanceOf(address(this));
        uint256 camt = sub(finalBal, initalBal);
        cToken.transfer(address(flashModule), camt);
        getExchangeRate();
        mintAmt = wmul(camt, exchangeRate);
        _mint(msg.sender, mintAmt);

        emit LogDepositUnderlying(msg.sender, camt, amount, mintAmt);
    }

    /**
     * @dev Withdraw ctokens.
     * @param amount wrap token amount
     * @param target withdraw tokens to address
     * @return ctokenAmt amount of token withdrawn
     */
    function withdraw(uint256 amount, address target)
        external
        nonReentrant
        returns (uint256 ctokenAmt)
    {
        require(target != address(0), "invalid-target-address");

        _burn(msg.sender, amount);
        getExchangeRate();
        ctokenAmt = wdiv(amount, exchangeRate);

        cToken.transferFrom(address(flashModule), target, ctokenAmt);

        emit LogWithdraw(msg.sender, ctokenAmt, amount);
    }
}
