pragma solidity 0.5.16;

// inherit in flashmodule 
// use as getDAI(),getUSDC()
// TODO add token address upgrability

contract FlashRegistry {
    
    function getDAI() public pure returns (address DAI) {
        DAI = address(0x0);
    }
    
    function getUSDC() public pure returns (address USDC) {
        USDC = address(0x0);
    }
    
}
