// SPDX-License-Identifier: MIT

// This is considered an Exogenous, Decentralized, Anchored (pegged), Crypto Collateralized low volitility coin

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
// view & pure functions

pragma solidity 0.8.19;

import {ERC20Burnable, ERC20} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

/*
 * @title DecentralizedStableCoin
 * @author 
 * Collateral: Exogenous
 * Minting (Stability Mechanism): Decentralized (Algorithmic)
 * Value (Relative Stability): Anchored (Pegged to USD)
 * Collateral Type: Crypto
 *
 * This is the contract meant to be owned by DSCEngine. It is a ERC20 token that can be minted and burned by the DSCEngine smart contract.
 */
contract DecentralizedStableCoin is ERC20Burnable, Ownable {
    error MintToZeroAddress();
    error AmountMustBeGreaterThanZero();

    constructor(string memory name_, string memory symbol_) ERC20(name_, symbol_) {}

    function mint(address account, uint256 amount) external onlyOwner returns(bool){
        if(account == address(0)){
            revert MintToZeroAddress();
        }
        if(amount == 0){
           revert AmountMustBeGreaterThanZero();
        }
        _mint(account, amount);
        return true;
    }

    function burn( uint256 amount) public override onlyOwner {
        uint256 balance = balanceOf(msg.sender);
        require(balance >= amount, "ERC20: burn amount exceeds balance");
        super.burn(amount);
    }
    function decimals() public view virtual override returns (uint8) {
        return 18;
    }

 
}
