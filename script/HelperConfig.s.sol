// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import {Script} from "forge-std/Script.sol";
import {MockV3Aggregator} from "./mocks/MockV3Aggregator.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/ERC20Mock.sol";

contract HelperConfig is Script{
    struct NetworkConfig{
        address wethUSDPriceFeed;
        address wbtcUSDPriceFeed;
        address weth;
        address wbtc;
        uint256 deployerKey;
    }

    uint256 public defaultAnvilKey = 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80;

    NetworkConfig public networkConfig;

    uint8 public constant DECIMALS = 8;
    int256 public constant ETH_USD_PRICE = 2000e8;
    int256 public constant BTC_USD_PRICE = 1000e8;

    constructor (){
        if(block.chainid == 11155111){
            networkConfig = getSepoliaConfig();
        }else{
            networkConfig = getOrCreateAnvilEthConfig();
        }
    }

    function getSepoliaConfig() public view returns(NetworkConfig memory networkConfig) {
        return NetworkConfig({
            wethUSDPriceFeed: 0x694AA1769357215DE4FAC081bf1f309aDC325306,
            wbtcUSDPriceFeed: 0xA2F78ab2355fe2f984D808B5CeE7FD0A93D5270E,
            weth: 0xb16F35c0Ae2912430DAc15764477E179D9B9EbEa,
            wbtc: 0xFF82bB6DB46Ad45F017e2Dfb478102C7671B13b3,
            deployerKey: vm.envUint("PRIVATE_KEY")
        });
    }

    function getOrCreateAnvilEthConfig() public returns(NetworkConfig memory){
        if(networkConfig.wethUSDPriceFeed != address(0)){
            return networkConfig;
        }
        
        
        MockV3Aggregator wethUSDPriceFeed = new MockV3Aggregator(DECIMALS, ETH_USD_PRICE);
        MockV3Aggregator wbtcUSDPriceFeed = new MockV3Aggregator(DECIMALS, BTC_USD_PRICE);
        ERC20Mock weth = new ERC20Mock("Wrapped Ether", "WETH",msg.sender, 1e18);
        ERC20Mock wbtc = new ERC20Mock("Wrapped Bitcoin", "WBTC", msg.sender, 1e18);
        return NetworkConfig({
            wethUSDPriceFeed: address(wethUSDPriceFeed),
            wbtcUSDPriceFeed: address(wbtcUSDPriceFeed),
            weth: address(weth),
            wbtc: address(wbtc),
            deployerKey: defaultAnvilKey
        });
    }
}