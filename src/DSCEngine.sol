// Layout of Contract:
// version
// imports
// errors
// interfaces, libraries, contracts
// Type declarations
// State variables
// Events
// Modifiers
// Functions

// Layout of Functions:
// constructor
// receive function (if exists)
// fallback function (if exists)
// external
// public
// internal
// private
// internal & private view & pure functions
// external & public view & pure functions

// SPDX-License-Identifier: MIT

pragma solidity 0.8.19;

import {OracleLib} from "./library/OracleLib.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {DecentralizedStableCoin} from "./DecentralizedStableCoin.sol";
import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";

/*
 * @title DSCEngine
 * @author Rawllings
 *
 * The system is deisgned to be as minimal as possible, and have the tokens maintain a 1 token == $1 peg at all times.
 * This is a stablecoin with the properties:
 * - Exegenously Collateralized
 * - Dollar Pegged
 * - Algorithmically Stable
 *
 * It is similar to DAI if DAI had no governance, no fees, and was backed by only WETH and WBTC.
 *
 * @notice This contract is the core of the Decentralized Stablecoin system. It handles all the logic
 * for minting and redeeming DSC, as well as depositing and withdrawing collateral.
 * @notice This contract is based on the MakerDAO DSS system
 */
contract DSCEngine is ReentrancyGuard {

    using OracleLib for AggregatorV3Interface;

    //////////////////////////
    // State variables //
    //////////////////////////
    uint256 public constant AGGREGATOR_PRICE_FEE_PRECISION = 1e10;
    uint256 public constant DSC_PRECISION = 1e18;
    uint256 public constant LIQUIDATION_TRESHOLD = 150;
    uint256 public constant LIQUIDATION_PRECISION = 100;
    uint256 public constant LIQUIDATION_BONUS = 10;
    uint256 public constant MIN_HEALTH_FACTOR = 1.1e18;

    DecentralizedStableCoin immutable public dsc;
    mapping(address token => address priceFeed) private _s_priceFeeds;
    mapping(address user => mapping(address token => uint256)) private _s_userCollateralBalances;
    mapping(address user => uint256 amountDscMinted) private _s_userDSCBalances;
    address[] private _s_collateralTokens;


    //////////////////////////
    // Events //
    //////////////////////////
    event CollateralDeposited(address indexed user, address indexed token, uint256 amount);
    event CollateralWithdrawn(address indexed user, address indexed token, address redeemedfrom, address redeemedto, uint256 amount);
    event DSCMinted(address indexed user, uint256 amount);
    event DSCBurned(address indexed user, uint256 amount);
    event DSCRedeemed(address indexed user, uint256 amount);

    //////////////////////////
    // Modifiers //
    //////////////////////////

    modifier moreThanZero(uint256 _amount) {
        require(_amount > 0, "Amount must be greater than zero");
        _;
    }

    modifier isAllowedToken(address _token) {
        require(_s_priceFeeds[_token] != address(0), "Token is not allowed");
        _;
    }

    //////////////////////////
    // Constructor //
    //////////////////////////


    constructor(address dscAddress, address[] memory tokenAddresses, address[] memory priceFeedAddresses){
        require(tokenAddresses.length == priceFeedAddresses.length, "Token and price feed arrays must be the same length");
        
        //eth bnb btc
        for(uint256 i = 0; i < tokenAddresses.length; i++){
            _s_priceFeeds[tokenAddresses[i]] = priceFeedAddresses[i];
            _s_collateralTokens.push(tokenAddresses[i]);
        }
        dsc = DecentralizedStableCoin(dscAddress);


    }

    //////////////////////////
    // Function Definitions //
    //////////////////////////


    //////////////////////////
    // External Functions //
    //////////////////////////

    /*
        * @notice This function allows a user to deposit collateral into the system, and mint DSC against it.
        * @param tokenCollateralAddress The address of the collateral token to deposit
        * @param collateralAmount The amount of collateral to deposit
        * @param dscToMint The amount of DSC to mint
     */

    function depositCollateralAndMintDSC(address tokenCollateralAddress, uint256 collateralAmount, uint256 dscToMint) external nonReentrant returns(bool){
        // deposit collateral
        depositCollateral(tokenCollateralAddress, collateralAmount);
        // mint dsc
        mintDsc(dscToMint);
        // return true
        return true;
    }

    /**
        * @notice This function allows a user to deposit collateral into the system, and mint DSC against it.
        * @param collateralToken The address of the collateral token to deposit
        * @param amount The amount of collateral to deposit
     */
    function depositCollateral(address collateralToken, uint256 amount) public moreThanZero(amount) isAllowedToken(collateralToken) {
        _s_userCollateralBalances[msg.sender][collateralToken] += amount;
        emit CollateralDeposited(msg.sender, collateralToken, amount);
        bool success = IERC20(collateralToken).transferFrom(msg.sender, address(this), amount);
        if(!success){
            revert("Transfer failed");
        }
    }


     function mintDsc(uint256 dscAmount) public moreThanZero(dscAmount) {
        _s_userDSCBalances[msg.sender] += dscAmount;
        _revertIfHealthFactorIsBroken(msg.sender);
        emit DSCMinted(msg.sender, dscAmount);
         bool minted = dsc.mint(msg.sender, dscAmount);
        if(!minted){
            revert("Minting failed");
        }
    }

    
    
    /*
        * @notice This function allows a user to withdraw collateral from the system, and burn DSC against it.
        * @param tokenCollateralAddress The address of the collateral token to withdraw
        * @param collateralAmount The amount of collateral to withdraw
        * @param dscToBurn The amount of DSC to burn
     */
    function reedeemCollateralForDsc(address collateralToken, uint256 amountCollateral, uint256 amountDscToBurn) external {
        burnDSC(amountDscToBurn);
        _reedeemCollateral(collateralToken, amountCollateral, msg.sender, msg.sender); //this checks health factor
        _revertIfHealthFactorIsBroken(msg.sender);
    }

    function redeemCollateral(address collateralToken, uint256 amountCollateral) external {
        _reedeemCollateral(collateralToken, amountCollateral, msg.sender, msg.sender); //this checks health factor
        _revertIfHealthFactorIsBroken(msg.sender);
    }


    function burnDSC(uint256 dscAmount) public nonReentrant returns(bool burnt){
        // burn dsc
        _burnBsc(dscAmount, msg.sender, msg.sender);
         _revertIfHealthFactorIsBroken(msg.sender);
         return true;
    }

    //if someone is almost undercollaterized you are paid to liquidate them

    /*
    * @notice this function allows a thridparty to liduidate a user
    * @param collateral The address of the collateral token to withdraw
    * @param user The address of the user to liquidate
    * @param debToCover The amount of debt to cover
    * @notice you can partially liqudate a user
    * @notice You will get a bonus for liquidation
    * @notice It only works if the entire system is overcollaterized
    * @notice a known bug would be if the system is at 100% or under 100% collateralization
    */
    function liquidate(address collateral, address user, uint256 debToCover) external moreThanZero(debToCover) nonReentrant{
        //check health factor

        uint256 startingUserHealthFactor = healthFactor(user);
        
        if(startingUserHealthFactor >= MIN_HEALTH_FACTOR){
            revert("User is not undercollaterized");
        }

        // Calculate the available collateral (user's collateral balance).
        uint256 availableCollateral = _s_userCollateralBalances[user][collateral];

        // Calculate the maximum debt that can be covered based on available collateral and the bonus.
        uint256 maxDebtCover = (availableCollateral * LIQUIDATION_PRECISION) / (LIQUIDATION_BONUS + LIQUIDATION_PRECISION);

        // Use the lesser value between the debt to cover requested and the maximum debt that can be covered.
        uint256 debtToCoverFinal = debToCover < maxDebtCover ? debToCover : maxDebtCover;

        // We want Now burn their dsc debt and take their collateral
        //remember collateral ratio is 150%
        //Bad userL $140 $100 dsc
        //debtToCover $100 DSC 
        uint256 tokenAmountFromDebtCovered = getTokenAmountFromUsd(collateral, debtToCoverFinal);
        // give them a bonus for liquidating
        //implement a function to liquidate in event the protocol is insolvent
        uint256 bonusCollateral = (tokenAmountFromDebtCovered * LIQUIDATION_BONUS) / LIQUIDATION_PRECISION;

        uint amountToCover = tokenAmountFromDebtCovered + bonusCollateral;

        require(_s_userCollateralBalances[user][collateral] >= amountToCover, "Not enough collateral to liquidate");


        _reedeemCollateral(collateral, amountToCover, user, msg.sender);

        //burn dsc
        _burnBsc(debtToCoverFinal, user, msg.sender);

        uint256 endingUserHealthFactor = healthFactor(user);

        // if(endingUserHealthFactor <= startingUserHealthFactor){
        //     revert("DscEngine Health Factor not improved");
        // }

        _revertIfHealthFactorIsBroken(msg.sender);
    }


    
    /////////////////////////////////////////
    // Public and external view Functions ///
    /////////////////////////////////////////

    function getAccountCollateralValueInUsd(address user) public view  returns(uint256 totalCollateralValueInUsd){
        // loop through each token get amount depoisited and map to price to get usd value
        for(uint256 i = 0; i < _s_collateralTokens.length; i++){
            address token = _s_collateralTokens[i];
            uint256 amountDeposited = _s_userCollateralBalances[user][token];
            // uint256 price = OracleLib.getLatestPrice(_s_priceFeeds[_s_collateralTokens[i]]);
            uint256 usdValue = getUsdValue(token, amountDeposited);
            totalCollateralValueInUsd += usdValue;
        }

        return totalCollateralValueInUsd;
    }


    function getUsdValue(address token, uint256 amount) public view returns(uint256){
        // uint256 price = OracleLib.getLatestPrice(_s_priceFeeds[token]);
        (,int price,,,) = AggregatorV3Interface(_s_priceFeeds[token]).stalePriceCheck();
        uint256 usdPrice = (uint256(price) * AGGREGATOR_PRICE_FEE_PRECISION);
        return (usdPrice * amount) / DSC_PRECISION;
    }

    //get amount of token equivalent to usd wei
    function getTokenAmountFromUsd(address token, uint256 usdAmountInWei) public view returns(uint256){
        // price of ETH
        // $/ETH
        AggregatorV3Interface priceFeed = AggregatorV3Interface(_s_priceFeeds[token]);

        // dollar value per 1 token
        (,int price,,,) = priceFeed.stalePriceCheck();
        uint256 usdPrice = (uint256(price) * AGGREGATOR_PRICE_FEE_PRECISION);

        //equivalent number of tokens per $1
        return (usdAmountInWei * DSC_PRECISION) / usdPrice;
    }


      function getAccountInformation(address user) external view returns(uint256 totalDscMinted, uint256 collateralAmount){
        (totalDscMinted, collateralAmount)  = _getAccountInformation(user);
        return (totalDscMinted, collateralAmount);
      }


    //////////////////////////
    // Internal Functions //
    //////////////////////////


    function _getAccountInformation(address user) internal view  returns(uint256 totalDSC, uint256 totalCollateral){
        //total DSC minted
        uint256 totalDscMinted = _s_userDSCBalances[user];
        
        uint256 collateralValueInUsd = getAccountCollateralValueInUsd(user);
        
        //total collateral deposited
        return (totalDscMinted, collateralValueInUsd);
    }

     /**
        * @notice This function allows a user to withdraw collateral from the system.
        * @param user The address of the user to withdraw collateral for
    */
    function healthFactor(address user) public view  returns(uint256){
        (uint256 totalDSC, uint256 totalCollateral) = _getAccountInformation(user);
        return _calculateHealthFactor(totalDSC, totalCollateral);
    }

    function _calculateHealthFactor(uint256 totalDSC, uint256 totalCollateral) internal view returns(uint256){
        if(totalDSC == 0){
            return type(uint256).max;
        }
        uint256 collateralAdjustedForTreshold =  (totalCollateral * LIQUIDATION_TRESHOLD) / LIQUIDATION_PRECISION;
        uint256 healthFactor_ = (collateralAdjustedForTreshold * DSC_PRECISION) / totalDSC;
        return healthFactor_;
    }


    function _revertIfHealthFactorIsBroken(address user) internal view {
        //check health facotr
        uint256 _healthFactor_ = healthFactor(user);
        if(_healthFactor_ < MIN_HEALTH_FACTOR){
            revert("Health factor is too low");
        }
    }
    
    
    // inoder to mint collateral the user must have a health factor above 1
    // 1. check health factor
    //DRY: Don't repeat yourself
    // CEI, Check Effects Interactions
    function _reedeemCollateral(address collateralToken, uint256 collateralAmount, address from, address to) private{
        //check health facotr
        _s_userCollateralBalances[from][collateralToken] -= collateralAmount;
        emit CollateralWithdrawn(from, collateralToken, from, to, collateralAmount);
        bool success = IERC20(collateralToken).transfer(to, collateralAmount);
        if(!success){
            revert("Transfer failed");
        }
    }



    /*
    * Low level function to burn DSC
    */
    function _burnBsc(uint256 amountToBurn, address onBehalfOf, address dscFrom) private {
        _s_userDSCBalances[onBehalfOf] -= amountToBurn;
        bool success = dsc.transferFrom(dscFrom, address(this), amountToBurn);
        if(!success){
            revert("Transfer failed");
        }
        dsc.burn(amountToBurn);
    }

    //////////////////////////////////////////
    // External and Public view Functions   //
    //////////////////////////////////////////


    function getDsc() public view returns(address){
        return address(dsc);
    }

    function getCollateralTokens() public view returns(address[] memory){
        return _s_collateralTokens;
    }

    function getHealthFactor(address user) public view returns(uint256){
        return healthFactor(user);
    }

    function getCollateral(address user, address collateral) public view returns(uint256){
        return _s_userCollateralBalances[user][collateral];
    }

    function getCollateralTokenPriceFeed(address collateral) public view returns(address){
        return _s_priceFeeds[collateral];
    }

}