// SPDX-License-Identifier: MIT
pragma solidity ^0.6.8;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

import "../interfaces/IERC20Flash.sol";
import "../interfaces/IETHFlash.sol";
import "../interfaces/CTokenPoolInterface.sol";
import "../interfaces/CTokenInterface.sol";
import "../interfaces/WrappedEtherInterface.sol";
import "../interfaces/CETHInterface.sol";

import {DSMath} from "../libs/safeMath.sol";

// @notice Any contract that inherits this contract becomes a flash lender of any ERC20 tokens that it has whitelisted.
contract FlashModule is DSMath, Ownable, ReentrancyGuard {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    event LogFlashloanFeeChanged(uint256 newFee);
    event LogAddedCTokenPool(
        address ctokenPool,
        address ctoken,
        address underlyingToken
    );
    event LogAddedCTokenMapping(address ctoken, address underlyingToken);
    event LogAddedToken(address token);

    WrappedEtherInterface public immutable weth; // wrapped eth Contract

    address internal ethAddr = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;
    address immutable cethAddr;

    uint256 internal _flashloanFee; // e.g.: 0.003e18 means 0.3% fee
    uint256 private _ethBorrowerDebt; // for borrower debt

    mapping(address => bool) public whitelistCToken;
    mapping(address => bool) public whitelistToken;
    mapping(address => address) public ctokenMapping; // token address => ctoken address mapping

    constructor(
        uint256 _fee,
        address _cethAddr,
        address _weth
    ) public {
        _flashloanFee = _fee;
        cethAddr = _cethAddr;
        ctokenMapping[_cethAddr] = ethAddr;
        weth = WrappedEtherInterface(_weth);
    }

    // @notice Borrow tokens via a flash loan. See FlashTest for example.
    function flashloan(
        address token,
        uint256 amount,
        bytes calldata params
    ) external {
        // token must be whitelisted
        require(whitelistCToken[token], "token not whitelisted");

        // record debt
        uint256 debt = wmul(amount, add(WAD, _flashloanFee));

        // send borrower the tokens
        IERC20(token).safeTransfer(msg.sender, amount);

        // hand over control to borrower
        IERC20Flash(msg.sender).executeOnERC20FlashLoan(
            token,
            amount,
            debt,
            params
        );

        // repay the debt
        IERC20(token).safeTransferFrom(msg.sender, address(this), debt);
    }

    // @notice Borrow tokens via a flash loan. See FlashTest for example.
    function flashloanUnderlying(
        address token,
        uint256 amount,
        bytes calldata params
    ) external {
        // token must be whitelisted
        require(whitelistToken[token], "token not whitelisted");

        // record debt
        uint256 debt = wmul(amount, add(WAD, _flashloanFee));

        // borrow underlying token from compound
        CTokenInterface(ctokenMapping[token]).borrow(amount);

        // if underlying asset is eth then convert eth got from compound to weth
        if (token == ethAddr) {
            weth.deposit{value: address(this).balance}();
        }

        // send borrower the tokens
        IERC20(token).safeTransfer(msg.sender, amount);

        // hand over control to borrower
        IERC20Flash(msg.sender).executeOnERC20FlashLoan(
            token,
            amount,
            debt,
            params
        );

        // repay the debt
        IERC20(token).safeTransferFrom(msg.sender, address(this), debt);

        // payback underlying token on compound
        if (token == ethAddr) {
            // first convert weth received to eth
            weth.withdraw(weth.balanceOf(address(this)));
            // repay eth to compound by sending eth back
            CETHInterface(ctokenMapping[token]).repayBorrow{value: amount}();
        } else {
            CTokenInterface(ctokenMapping[token]).repayBorrow(uint256(-1));
        }
    }

    function ETHFlashLoan(uint256 amount, bytes calldata params)
        external
        nonReentrant
    {
        // record debt
        _ethBorrowerDebt = wmul(amount, add(WAD, _flashloanFee));

        // send borrower the eth
        msg.sender.transfer(amount);

        // hand over control to borrower
        IETHFlash(msg.sender).executeOnETHFlashLoan(
            amount,
            _ethBorrowerDebt,
            params
        );

        // check that debt was fully repaid
        require(_ethBorrowerDebt == 0, "loan not paid back");
    }

    // @notice Repay all loan
    function repayEthDebt() public payable {
        _ethBorrowerDebt = _ethBorrowerDebt.sub(msg.value); // does not allow overpayment
    }

    /**
     * @dev get flashloan fee.
     */
    function getFlashloanFee() public view returns (uint256) {
        return _flashloanFee;
    }

    /**
     * @dev Update Flashloan fee.
     * @notice can only be called by owner
     * @param fee new fee percentage
     */
    function updateFee(uint256 fee) external onlyOwner() {
        require(fee <= 9 * 10**15, "max-9%-fee");
        _flashloanFee = fee;
    }

    /**
     * @dev Enable CToken Pool.
     * @notice can only be called by owner
     * @param ctokenPoolAddr ctoken pool address
     */
    function enableCtokenPool(address ctokenPoolAddr) external onlyOwner() {
        require(ctokenPoolAddr != address(0), "ctokenPoolAddr-not-valid");
        CTokenPoolInterface ctokenPool = CTokenPoolInterface(ctokenPoolAddr);
        CTokenInterface ctoken = ctokenPool.cToken();
        require(!whitelistCToken[address(ctoken)], "ctokenPool-already-added");

        IERC20 token;
        if (address(ctoken) != cethAddr) {
            token = ctokenPool.underlyingToken();
            token.approve(address(ctoken), uint256(-1));
        } else {
            token = IERC20(ethAddr);
        }

        ctoken.approve(ctokenPoolAddr, uint256(-1));

        whitelistCToken[address(ctoken)] = true;
        whitelistToken[address(token)] = true;

        emit LogAddedCTokenPool(
            ctokenPoolAddr,
            address(ctoken),
            address(token)
        );
    }

    /**
     * @dev Add CToken mapping.
     * @notice can only be called by owner
     * @param ctokenAddr ctoken  address
     */
    function addCTokenMapping(address ctokenAddr) external onlyOwner() {
        require(ctokenAddr != address(0), "ctokenPoolAddr-not-valid");
        require(cethAddr != ctokenAddr, "ceth-mapping-already-added");
        CTokenInterface ctoken = CTokenInterface(ctokenAddr);
        address token = ctoken.underlying();
        require(
            ctokenMapping[address(token)] == address(0),
            "ctoken-mapping-already-added"
        );

        ctokenMapping[address(token)] = ctokenAddr;

        emit LogAddedCTokenMapping(address(ctokenAddr), address(token));
    }
}
