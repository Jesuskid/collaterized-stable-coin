//Handler

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import {StdInvariant} from "forge-std/StdInvariant.sol";
import {DeployDsc} from "../../script/DeployDsc.s.sol";
import {DSCEngine} from "../../src/DSCEngine.sol";
import {DecentralizedStableCoin} from "../../src/DecentralizedStableCoin.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/ERC20Mock.sol";
import {MockV3Aggregator} from "../../script/mocks/MockV3Aggregator.sol";
contract Handler is Test{
    DSCEngine public dscEngine;
    DecentralizedStableCoin public dsc;
    ERC20Mock public weth;
    ERC20Mock public wbtc;

    MockV3Aggregator public wethUSDPriceFeed;
    MockV3Aggregator public wbtcUSDPriceFeed;

    uint256 constant BOUND = type(uint96).max;
    constructor(DSCEngine _dscEngine, DecentralizedStableCoin _dsc) {
        dscEngine = _dscEngine;
        dsc = _dsc;

        address[] memory collateral = dscEngine.getCollateralTokens();
        weth = ERC20Mock(collateral[0]);
        wbtc = ERC20Mock(collateral[1]);

        wethUSDPriceFeed = MockV3Aggregator(dscEngine.getCollateralTokenPriceFeed(address(weth)));
        wbtcUSDPriceFeed = MockV3Aggregator(dscEngine.getCollateralTokenPriceFeed(address(wbtc)));
    }

    //deposit collateral
    function depositCollateral(uint256 collateralSeed, uint256 amount) public {
        amount = bound(amount, 1, BOUND);
        ERC20Mock collateral = getCollateralFromSeed(collateralSeed);
        vm.startPrank(msg.sender);
        collateral.mint(msg.sender, amount);
        collateral.approve(address(dscEngine), amount);
        dscEngine.depositCollateral(address(collateral), amount);
        vm.stopPrank();
    } 


    function mintDSC(uint256 amount) public{
        amount = bound(amount, 1, BOUND);
        (uint256 totalDscMinted, uint256 collateralValueInUsd) = dscEngine.getAccountInformation(msg.sender);
        int256 maxDscToMint = (int256(collateralValueInUsd) - int256(totalDscMinted)) / int256(dscEngine.getUsdValue(address(weth), 1 ether));
        
        if(maxDscToMint < 0) return;
        
        amount = bound(amount, 0, uint256(maxDscToMint));

        if(amount == 0) return;
        vm.startPrank(msg.sender);
        dscEngine.mintDsc(amount);
        vm.stopPrank();
    }

    function updateCollateralPrice() public {
        wethUSDPriceFeed.updateAnswer(471);
        wbtcUSDPriceFeed.updateAnswer(471);
    }

    function redeemCollateral(uint256 collateralSeed, uint256 amount) public {
       
        ERC20Mock collateral = getCollateralFromSeed(collateralSeed);
        uint256 maxCollateralToRedeem = dscEngine.getCollateral(msg.sender, address(collateral));
        vm.startPrank(msg.sender);
        amount = bound(amount, 0, maxCollateralToRedeem);

        if(amount <= 0) return;
        
        dscEngine.redeemCollateral(address(collateral), amount);
        vm.stopPrank();
    } 

    //helper
    function getCollateralFromSeed(uint256 collateralSeed) private view returns (ERC20Mock) {
        if (collateralSeed % 2 == 0) {
            return weth;
        } 
        return wbtc;
       
    }

}