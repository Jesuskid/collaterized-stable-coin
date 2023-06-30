// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import {Script} from "forge-std/Script.sol";
import {DSCEngine} from "../src/DSCEngine.sol";
import  {DecentralizedStableCoin} from "../src/DecentralizedStableCoin.sol";
import {HelperConfig} from "./HelperConfig.s.sol";

contract DeployDsc is Script {
   

    function run() external returns(DecentralizedStableCoin, DSCEngine, HelperConfig) {
        vm.startBroadcast();
        HelperConfig helperConfig = new HelperConfig();
        (address wethUSDPriceFeed, address wbtcUSDPriceFeed, address weth, address wBtc, uint256 deployerKey) = helperConfig.networkConfig();

        address[] memory tokens = new address[](2);
        tokens[0] = weth;
        tokens[1] = wBtc;

        address[] memory priceFeeds = new address[](2);
        priceFeeds[0] = wethUSDPriceFeed;
        priceFeeds[1] = wbtcUSDPriceFeed;

        DecentralizedStableCoin dsc = new DecentralizedStableCoin("CediCoin", "cGHS");
        DSCEngine dscEngine = new DSCEngine(address(dsc), tokens, priceFeeds);

        dsc.transferOwnership(address(dscEngine));
        vm.stopBroadcast();
        return (dsc, dscEngine, helperConfig);
    }

}