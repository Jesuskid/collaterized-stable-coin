// //SPDX-License-Identifier: UNLICENSED

// pragma solidity ^0.8.19;
// import "forge-std/Test.sol";
// import {StdInvariant} from "forge-std/StdInvariant.sol";
// import {DeployDsc} from "../../script/DeployDsc.s.sol";
// import {DSCEngine} from "../../src/DSCEngine.sol";
// import {DecentralizedStableCoin} from "../../src/DecentralizedStableCoin.sol";
// import {HelperConfig} from "../../script/HelperConfig.s.sol";
// import {ERC20Mock} from "@openzeppelin/contracts/mocks/ERC20Mock.sol";
// import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
// import {MockV3Aggregator} from "../../script/mocks/MockV3Aggregator.sol";


// //Have our invariant tests 

// // What are our invariats

// /*
// * 1. The totalSupply of the DSC should be less than the balances all collateral
// * 2. Getter view functions should never revert
// */

// contract OpenInvariantTest is StdInvariant, Test{
//     DeployDsc public deployDsc;
//     DSCEngine public dscEngine;
//     DecentralizedStableCoin public dsc;
//     HelperConfig public helperConfig;
//     address public wethUSDPriceFeed;
//     address public weth;
//     address public wbtc;

//     address public USER = makeAddr("user");
//     address public liquidator = makeAddr("liquidator");
//     uint256 public constant COLLATERAL_10 = 10e18;
//     uint256 public constant STARTING_BALANCE = 100e18;

//     uint256 amountCollateral = 10 ether;
//     uint256 amountToMint = 100 ether;
//     uint256 public collateralToCover = 20 ether;

//     function setUp() public {
//         deployDsc = new DeployDsc();
//         (dsc, dscEngine, helperConfig) = deployDsc.run();
//         (wethUSDPriceFeed, ,weth,wbtc,) = helperConfig.networkConfig();
//         ERC20Mock(weth).mint(USER, STARTING_BALANCE);

//         targetContract(address(dscEngine));
//     }


//     function invariant_protocolMustHaveMoreValueThanTotalSupply() public view returns (bool) {
//         uint256 totalSupply = dsc.totalSupply();
//         uint256 wethDeposited = IERC20(weth).balanceOf(address(dscEngine));
//         uint256 wBtcDeposited = IERC20(wbtc).balanceOf(address(dscEngine));

//         uint256 wethValue = dscEngine.getUsdValue(weth, wethDeposited);
//         uint256 wBtcValue = dscEngine.getUsdValue(wbtc, wBtcDeposited);

//         uint256 totalValue = wethValue + wBtcValue;

//         assert(totalValue >= totalSupply);
//     } 
// }