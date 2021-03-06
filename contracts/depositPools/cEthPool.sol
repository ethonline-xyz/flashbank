// SPDX-License-Identifier: MIT
pragma solidity ^0.6.8;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

import {DSMath} from "../libs/safeMath.sol";

interface CTokenInterface {
    function mint() external payable returns (uint256);

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

interface FlashModuleInterface {
    function test() external view returns (address);
}

contract FlashCETHPool is ReentrancyGuard, ERC20, DSMath {
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
        underlyingToken = IERC20(0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE);
        exchangeRate = 10**18;
        _setupDecimals(8);
    }

    /**
     * @dev get current exchange rate
     */
    function getExchangeRate() public returns (uint) {
        if (totalSupply() != 0){
            address flashModuleAddr = address(flashModule);
            uint256 _ctokenBal = cToken.balanceOf(flashModuleAddr);
            uint256 _tokenBal = flashModuleAddr.balance;
            _ctokenBal += wdiv(_tokenBal, cToken.exchangeRateCurrent());
            exchangeRate = wdiv(_ctokenBal, totalSupply());
        } else {
            exchangeRate = 10 ** 18;
        }

        emit LogExchangeRate(exchangeRate);
        return exchangeRate;
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
        require(cToken.transferFrom(msg.sender, address(flashModule), amount), "ctoken-tranferFrom-failed");
        getExchangeRate();
        mintAmt = wdiv(amount, exchangeRate);
        _mint(msg.sender, mintAmt);

        emit LogDeposit(msg.sender, amount, mintAmt);
    }

    /**
     * @dev Deposit underlying token.
     * @return mintAmt amount of wrap token minted
     */
    function depositUnderlying()
        external
        payable
        nonReentrant
        returns (uint256 mintAmt)
    {
        uint256 amount = msg.value;
        require(amount != 0, "amount-is-zero");
        uint256 initalBal = cToken.balanceOf(address(this));
        require(cToken.mint{value: amount}() == 0, "minting-reverted");
        uint256 finalBal = cToken.balanceOf(address(this));
        uint256 camt = sub(finalBal, initalBal);
        require(cToken.transfer(address(flashModule), camt), "ctoken-tranfer-failed");

        getExchangeRate();
        mintAmt = wdiv(camt, exchangeRate);
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
        ctokenAmt = wmul(amount, exchangeRate);

        require(cToken.transferFrom(address(flashModule), target, ctokenAmt), "ctoken-tranferFrom-failed");

        emit LogWithdraw(msg.sender, ctokenAmt, amount);
    }

    receive() external payable {}
}
