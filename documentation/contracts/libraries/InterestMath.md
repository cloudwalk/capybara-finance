# Overview
The InterestMath library created by CloudWalk Inc. extends the functionality of the Interest library to perform interest-related mathematical calculations. It specifically deals with the computation of outstanding balances on loans using different interest calculation methods, providing solid groundwork for developers dealing with financial contracts in the Solidity ecosystem.

## Contract Details

- **Version**: Solidity 0.8.23
- **License**: MIT
- **Author**: CloudWalk Inc. (See [CloudWalk](https://cloudwalk.io))

## Constants
### MAX_COMPOUND_STEP
```solidity
uint256 constant MAX_COMPOUND_STEP = 10;
```
A predefined maximum number of compounding steps that the library uses as a safeguard to prevent excessive gas usage during calculations.

## Errors
### InterestFormulaNotImplemented
```solidity
error InterestFormulaNotImplemented();
```
This error is thrown when an attempt is made to calculate the outstanding balance using an interest formula that is not supported or implemented by the library.


## Functions
### calculateOutstandingBalance
```solidity
function calculateOutstandingBalance(uint256 originalBalance, uint256 numberOfPeriods, uint256 interestRate, uint256 interestRateFactor, Interest.Formula interestFormula) internal pure returns (uint256 remainingBalance);
```
Calculates the outstanding balance for a loan given the original balance, the number of periods since the loan was taken, the interest rate, the interest rate factor, and the interest formula. Currently, it only supports the compound interest formula, and other formulas would lead to the InterestFormulaNotImplemented error being thrown.

### _calculateOutstandingBalance

```solidity
function _calculateOutstandingBalance(uint256 originalBalance, uint256 numberOfPeriods, uint256 interestRate, uint256 interestRateFactor) private pure returns (uint256);
```

A recursive function that breaks down the outstanding balance calculation into steps not exceeding the MAX_COMPOUND_STEP constant, ensuring manageable gas consumption for each recursive call.


### _compoundOutstandingBalance
```solidity
function _compoundOutstandingBalance(uint256 originalBalance, uint256 numberOfPeriods, uint256 interestRate, uint256 interestRateFactor) private pure returns (uint256);
```
Executes the compound interest calculation for a defined number of periods, which is equal to or less than MAX_COMPOUND_STEP. It applies the mathematical formula for compounding by raising the combined interest rate factor to the power of the number of periods and adjusting for the interest rate factor to maintain precision.