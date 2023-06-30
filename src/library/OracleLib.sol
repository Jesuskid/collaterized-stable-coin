// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;
import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";

/**
 * @title OracleLib
 * @dev OracleLib is a library for handling oracle related functions
 * @notice this library checks the chainlink oracle for the price of the collateral
 * if the price is stale the function would revert
 *
 * if the chainLink network is down the function would revert
 */

 library OracleLib{

    uint256 private constant TIME_OUT = 3 hours;

    function stalePriceCheck(AggregatorV3Interface priceFeed) public view returns(uint80, int256, uint256, uint256, uint80){
        (uint80 roundId, int256 answer, uint256 startedAt,uint256 updatedAt,uint80 answeredInRound) = priceFeed.latestRoundData();
        uint256 secondsElapsed = block.timestamp - updatedAt;

        require(secondsElapsed < TIME_OUT, "OracleLib: stale price feed");

        return(roundId, answer, startedAt, updatedAt, answeredInRound);
    }

 }