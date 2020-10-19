// SPDX-License-Identifier: MIT
pragma solidity ^0.6.8;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import { DSMath } from "../libs/safeMath.sol";

interface CTokenInterface {
    function mint() external payable returns (uint);
    function redeemUnderlying(uint redeemAmount) external returns (uint);
    function redeem(uint redeemTokens) external returns (uint);

    function exchangeRateCurrent() external returns (uint);

    function balanceOf(address owner) external view returns (uint256 balance);
    function underlying() external view returns (address);

    function approve(address, uint) external;
    function transfer(address, uint) external returns (bool);
    function transferFrom(address, address, uint) external returns (bool);
}

interface FlashModuleInterface {
  function test() external view returns (address);
}

contract FlashCETHPool is ReentrancyGuard, ERC20, DSMath {

  event LogExchangeRate(uint exchangeRate);
  event LogDeposit(address indexed user, uint amount, uint mintAmt);
  event LogDepositUnderlying(address indexed user, uint amount, uint underlyingAmount, uint mintAmt);
  event LogWithdraw(address indexed user, uint cAmount, uint burnAmt);

  CTokenInterface public immutable cToken; // Compound token. Eg:- cDAI, cUSDC, etc.
  IERC20 public immutable underlyingToken; // underlying ctoken. Eg:- DAI, USDC, etc.
  FlashModuleInterface public immutable flashModule; // Flashloan module contract

  uint public exchangeRate; // initial 1 ctoken = 1 wrap token

  constructor(
    string memory _name,
    string memory _symbol,
    address _ctoken,
	address _module
  ) public ERC20(_name, _symbol) {
    cToken = CTokenInterface(_ctoken);
	flashModule = FlashModuleInterface(_module);
    underlyingToken = IERC20(0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE);
    exchangeRate = 10 ** 28;
  }

  /**
    * @dev get current exchange rate
  */
  function getExchangeRate() public {
    address flashModuleAddr = address(flashModule);
    uint _ctokenBal = cToken.balanceOf(flashModuleAddr);
    uint _tokenBal = flashModuleAddr.balance;
    _ctokenBal += wdiv(_tokenBal, cToken.exchangeRateCurrent());
    exchangeRate = wmul(_ctokenBal, totalSupply());

    emit LogExchangeRate(exchangeRate);
  }

  /**
    * @dev Deposit ctoken.
    * @param amount ctoken amount
    * @return mintAmt amount of wrap token minted
  */
  function deposit(uint amount) external nonReentrant returns (uint mintAmt) {
    require(amount != 0, "amount-is-zero");
    cToken.transferFrom(msg.sender, address(flashModule), amount);
    getExchangeRate();
    mintAmt = wmul(amount, exchangeRate);
    _mint(msg.sender, mintAmt);

    emit LogDeposit(msg.sender, amount, mintAmt);
  }

  /**
    * @dev Deposit underlying token.
    * @return mintAmt amount of wrap token minted
  */
  function depositUnderlying() external payable nonReentrant returns (uint mintAmt) {
    uint amount = msg.value;
    require(amount != 0, "amount-is-zero");
    uint initalBal = cToken.balanceOf(address(this));
    require(cToken.mint{value: amount}() == 0, "minting-reverted");
    uint finalBal = cToken.balanceOf(address(this));
    uint camt = sub(finalBal, initalBal);
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
  function withdraw(uint amount, address target) external nonReentrant returns (uint ctokenAmt) {
    require(target != address(0), "invalid-target-address");

    _burn(msg.sender, amount);
    getExchangeRate();
    ctokenAmt = wdiv(amount, exchangeRate);

    cToken.transferFrom(address(flashModule), target, ctokenAmt);

    emit LogWithdraw(msg.sender, ctokenAmt, amount);
  }

  receive() external payable {}
}