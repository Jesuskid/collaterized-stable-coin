
pragma solidity ^0.8.0;
import "forge-std/Test.sol";
import {DeployDsc} from "../../script/DeployDsc.s.sol";
import {DSCEngine} from "../../src/DSCEngine.sol";
import {DecentralizedStableCoin} from "../../src/DecentralizedStableCoin.sol";
import {HelperConfig} from "../../script/HelperConfig.s.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/ERC20Mock.sol";
import {MockV3Aggregator} from "../../script/mocks/MockV3Aggregator.sol";

contract DSCEngineTest is Test{

    DeployDsc public deployDsc;
    DSCEngine public dscEngine;
    DecentralizedStableCoin public dsc;
    HelperConfig public helperConfig;
    address public wethUSDPriceFeed;
    address public weth;

    address public USER = makeAddr("user");
    address public liquidator = makeAddr("liquidator");
    uint256 public constant COLLATERAL_10 = 10e18;
    uint256 public constant STARTING_BALANCE = 100e18;

    uint256 amountCollateral = 10 ether;
    uint256 amountToMint = 100 ether;
    uint256 public collateralToCover = 20 ether;

    function setUp() public {
        deployDsc = new DeployDsc();
        (dsc, dscEngine, helperConfig) = deployDsc.run();
        (wethUSDPriceFeed, ,weth, ,) = helperConfig.networkConfig();
        ERC20Mock(weth).mint(USER, STARTING_BALANCE);
    }

    ///////////////////
    // Test Functions//
    ///////////////////

    ///////////////////////
    // Constructor Tests //
    ///////////////////////
    address[] public priceFeeds;
    address[] public tokens;
    function testRevertsIftokenLenghtNotMatchesPriceFeed() public {
        tokens.push(weth);
        priceFeeds.push(wethUSDPriceFeed);
        priceFeeds.push(wethUSDPriceFeed);

        vm.expectRevert("Token and price feed arrays must be the same length");
        new DSCEngine(address(dsc),tokens, priceFeeds);
    }

    ///////////////////
    // Price Tests   //
    ///////////////////
    function testGetUsdValue() public {
        uint256 ethAmount = 15e18;
        uint256 expectedUsd = 30000e18;
        uint256 usdValue = dscEngine.getUsdValue(address(weth), ethAmount);
        assertEq(usdValue, expectedUsd);
    }

    function testGetTokenAmountFromUsd() public {
        uint256 usdAmount = 30000e18;
        uint256 expectedEth = 15e18;
        uint256 ethAmount = dscEngine.getTokenAmountFromUsd(address(weth), usdAmount);
        assertEq(ethAmount, expectedEth);
    }


    ////////////////////////////
    // Deposit collateral    //
    //////////////////////////

    function testRevertIfCollateralZero() public {
        vm.startPrank(USER);
        ERC20Mock(weth).mint(USER, COLLATERAL_10);
        ERC20Mock(weth).approve(address(dscEngine), COLLATERAL_10);
        vm.stopPrank();
    }


    function testRevertUnApprovedCollateral() public {
        ERC20Mock mockToken = new ERC20Mock("Mock", "Mock", USER, COLLATERAL_10);
        mockToken.mint(USER, COLLATERAL_10);
        vm.startPrank(USER);
        vm.expectRevert("Token is not allowed");    
        dscEngine.depositCollateral(address(mockToken), COLLATERAL_10);
        vm.stopPrank();
    }

    modifier depositCollateral() {
        vm.startPrank(USER);
        ERC20Mock(weth).mint(USER, COLLATERAL_10);
        ERC20Mock(weth).approve(address(dscEngine), COLLATERAL_10);
        dscEngine.depositCollateral(address(weth), COLLATERAL_10);
        vm.stopPrank();
        _;
    }

    modifier depositCollateralAndMintDSC() {
        vm.startPrank(USER);
        ERC20Mock(weth).mint(USER, COLLATERAL_10);
        ERC20Mock(weth).approve(address(dscEngine), COLLATERAL_10);
        dscEngine.depositCollateralAndMintDSC(address(weth), COLLATERAL_10, amountToMint);
        console.log("DSC Balance", dsc.balanceOf(USER));
        vm.stopPrank();
        _;
    }

    function testCanGetCollateralAndAccountInfo() public depositCollateral{
        (uint256 totalDscMinted, uint256 collateralAmountUSD) = dscEngine.getAccountInformation(USER);
        uint256 expectedDepsoitAmount = dscEngine.getTokenAmountFromUsd(weth, collateralAmountUSD);
        assertEq(totalDscMinted, 0);
        assertEq(COLLATERAL_10, expectedDepsoitAmount);
    }

    function testMintCollateral() public {
        uint amount = 10e18;
        vm.assume(amount > 0);
        uint256 expectedDscMinted = amount;
        vm.startPrank(USER);
        ERC20Mock(weth).mint(USER, amount);
        ERC20Mock(weth).approve(address(dscEngine), amount);
        dscEngine.depositCollateralAndMintDSC(weth, amount, expectedDscMinted);
        vm.stopPrank();
        (uint256 totalDscMinted, uint256 collateralAmountUSD) = dscEngine.getAccountInformation(USER);
        assertEq(totalDscMinted, expectedDscMinted);
    }


    function testRedeemCollateral() public depositCollateralAndMintDSC {
        uint amount = 10e18;
        vm.startPrank(USER);
        dsc.approve(address(dscEngine), amount);
        dscEngine.reedeemCollateralForDsc(weth, amount , amount);
        vm.stopPrank();
        (uint256 totalDscMinted, uint256 collateralAmountUSD) = dscEngine.getAccountInformation(USER);
        assertEq(totalDscMinted, 0);
    }

    function testRevertIfNotEnoughDsc() public depositCollateralAndMintDSC {
        uint amount = 10e18;
        vm.startPrank(USER);
        vm.expectRevert("Not enough DSC");    
        dscEngine.reedeemCollateralForDsc(address(weth), amount , amount + 1);
        vm.stopPrank();
    }

    function testLiquidate() public depositCollateralAndMintDSC {
        uint amount = 10000e18;
        int256 price = 7e8;
        vm.startPrank(liquidator);
        ERC20Mock(weth).mint(liquidator, amount);
        ERC20Mock(weth).approve(address(dscEngine), amount);

        dscEngine.depositCollateralAndMintDSC(weth, amount, amountToMint);
        
        MockV3Aggregator(wethUSDPriceFeed).updateAnswer(price);

       //1th is 2000 usd
       //1weth is 2000 usd
       //deposit 10 weth you get 

        uint healthFactor = dscEngine.getHealthFactor(USER);
        console.log("Health factor before liquidation", healthFactor);
        console.log(dscEngine.getAccountCollateralValueInUsd(USER));


         (uint256 totalDscBefore, ) = dscEngine.getAccountInformation(USER);

        dsc.approve(address(dscEngine), amountToMint);
        dscEngine.liquidate(weth, USER, amountToMint);

        vm.stopPrank();
        (uint256 totalDscMinted, ) = dscEngine.getAccountInformation(USER);
        console.log("Total DSC before", totalDscBefore);
        console.log("Total DSC after", totalDscMinted);
        assertGt(totalDscBefore, totalDscMinted);
    }   

    function testRevertIfNotEnoughCollateralToRedeem() public depositCollateralAndMintDSC {
        uint amount = 100e18;
        vm.startPrank(USER);
        vm.expectRevert("Not enough collateral");    
        dsc.approve(address(dscEngine), amount);
        dscEngine.reedeemCollateralForDsc(weth, amount + 2, amount);
        vm.stopPrank();
    }

}