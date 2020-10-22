pragma solidity ^0.6.0;
pragma experimental ABIEncoderV2;

interface CTokenInterface {
    function exchangeRateCurrent() external returns (uint256);

    function balanceOf(address owner) external view returns (uint256 balance);

    function underlying() external view returns (address);
}

interface FlashModuleInterface {
    function test() external view returns (address);
}

interface TokenInterface {
    function balanceOf(address) external view returns (uint);
    function decimals() external view returns (uint);
}

interface ComptrollerLensInterface {
    function markets(address) external view returns (bool, uint, bool);
}

interface OrcaleComp {
    function getUnderlyingPrice(address) external view returns (uint);
}

interface cTokenPoolInterface {
    function getExchangeRate() external returns(uint);
    function createdBlockNumber() external view returns(uint);
    function underlyingToken() external view returns (TokenInterface);
    function cToken() external view returns (CTokenInterface);
    function flashModule() external view returns (FlashModuleInterface);

}
interface ChainLinkInterface {
    function latestAnswer() external view returns (int256);
    function decimals() external view returns (uint256);
}

contract DSMath {

    function add(uint x, uint y) internal pure returns (uint z) {
        require((z = x + y) >= x, "math-not-safe");
    }

    function mul(uint x, uint y) internal pure returns (uint z) {
        require(y == 0 || (z = x * y) / y == x, "math-not-safe");
    }

    uint constant WAD = 10 ** 18;
    uint constant RAY = 10 ** 27;

    function rmul(uint x, uint y) internal pure returns (uint z) {
        z = add(mul(x, y), RAY / 2) / RAY;
    }

    function wmul(uint x, uint y) internal pure returns (uint z) {
        z = add(mul(x, y), WAD / 2) / WAD;
    }

    function rdiv(uint x, uint y) internal pure returns (uint z) {
        z = add(mul(x, RAY), y / 2) / y;
    }

    function wdiv(uint x, uint y) internal pure returns (uint z) {
        z = add(mul(x, WAD), y / 2) / y;
    }

    function sub(uint x, uint y) internal pure returns (uint z) {
        require((z = x - y) <= x, "ds-math-sub-underflow");
    }

}

contract Helper is DSMath {
     /**
     * @dev Return ethereum address
     */
    function getEthAddress() internal pure returns (address) {
        return 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE; // ETH Address
    }

    /**
     * @dev Return WTH address
     */
    function getWethAddress() internal pure returns (address) {
        return 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2; // WETH Address mainnet
        // return 0xd0A1E359811322d97991E03f863a0C30C2cF029C; // WETH Address kovan
    }

     /**
     * @dev Return eth price feed address
     */
    function getEthPriceFeed() internal pure returns (address) {
        return 0x5f4eC3Df9cbd43714FE2740f5E3616155c5b8419; // mainnet
        // return 0x9326BFA02ADD2366b30bacB125260Af641031331; // kovan
    }
}

contract CompoundHelpers is Helper {
    /**
     * @dev get Compound Comptroller
     */
    function getComptroller() public pure returns (ComptrollerLensInterface) {
        return ComptrollerLensInterface(0x3d9819210A31b4961b30EF54bE2aeD79B9c9Cd3B); // mainnet
        // return ComptrollerLensInterface(0x1f5D7F3CaAC149fE41b8bd62A3673FE6eC0AB73b); // kovan
    }

    /**
     * @dev get Compound Open Feed Oracle Address
     */
    function getOracleAddress() public pure returns (address) {
        // return 0x9B8Eb8b3d6e2e0Db36F41455185FEF7049a35CaE; // mainnet
        return 0xbBdE93962Ca9fe39537eeA7380550ca6845F8db7; // kovan
    }

    /**
     * @dev get ETH Address
     */
    function getCETHAddress() public pure returns (address) {
        // return 0x4Ddc2D193948926D02f9B1fE9e1daa0718270ED5; // mainnet
        return 0x41B5844f4680a8C38fBb695b7F9CFd1F64474a72;
    }

    struct TokenData {
        uint exchangeRate;
        uint balance;
        uint tokenPriceInUsd;
        uint currentBlock;
        uint createdBlockNumber;
    }

    function priceFeedMapping(address ctoken) internal view returns(uint price) {
        if (ctoken == 0xF0d0EB522cfa50B716B3b1604C4F0fA6f04376AD) { // cdai
            price = uint(ChainLinkInterface(0x777A68032a88E5A84678A77Af2CD65A7b3c0775a).latestAnswer());
        } else if (ctoken == 0x41B5844f4680a8C38fBb695b7F9CFd1F64474a72) { // ceth
            price = uint(ChainLinkInterface(0x9326BFA02ADD2366b30bacB125260Af641031331).latestAnswer());
        } else if (ctoken == 0x4a92E71227D294F041BD82dd8f78591B75140d63) { // cusdc
            price = uint(ChainLinkInterface(0x777A68032a88E5A84678A77Af2CD65A7b3c0775a).latestAnswer());
        } else {
            revert("no-token-found");
        }
    }

}


contract CompoundResolver is CompoundHelpers {

    function getCompPrice(CTokenInterface cToken) public view returns (uint tokenPrice) {
        uint price = priceFeedMapping(address(cToken));
        tokenPrice = price * 10 ** 10;
    }
}

contract FlashloanBankResolver is CompoundResolver {
    
    function getStats(address[] memory pools) public returns (TokenData[] memory){
        TokenData[] memory tokensData = new TokenData[](pools.length);
        for (uint i = 0; i < pools.length; i++) {
            cTokenPoolInterface ctokenPool = cTokenPoolInterface(pools[i]);
            CTokenInterface ctoken = ctokenPool.cToken();
            TokenInterface token = ctokenPool.underlyingToken();
            FlashModuleInterface flashModule = ctokenPool.flashModule();
            uint256 _tokenBal = token.balanceOf(address(flashModule));
            uint256 _ctokenBal = ctoken.balanceOf(address(flashModule));
            _tokenBal += wmul(_ctokenBal, ctoken.exchangeRateCurrent());
            tokensData[i] = TokenData(
                ctokenPool.getExchangeRate(),
                _tokenBal,
                getCompPrice(ctoken),
                block.number,
                ctokenPool.createdBlockNumber()
            );
        }
        return tokensData;
    }
}