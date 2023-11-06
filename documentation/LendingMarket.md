# Overview
The LendingMarket contract is an implementation of a lending market contract. It facilitates loan management and interactions between borrowers, lenders, and credit lines. The contract also interacts with NFT tokens to represent loans as NFTs.

## Contract Details

- **Version**: Solidity 0.8.20
- **License**: MIT
- **Author**: CloudWalk Inc. (See [CloudWalk](https://cloudwalk.io))
- **Interface**: [ILendingMarket](./interfaces/ILendingMarket.md)

## Storage Variables
| Name	           | Type	                          | Description                                                                                  |
|-----------------|--------------------------------|----------------------------------------------------------------------------------------------|
| _nft            | address                        | The address of the NFT token associated with the lending market.                             |
| _registry       | address                        | 	The address of the registry contract used for registering credit lines and liquidity pools. |
| _creditLines    | mapping(address => address)    | 	Mapping of credit line contracts to their respective lenders.                               |
| _liquidityPools | mapping(address => address)    | 	Mapping of liquidity pool contracts to their respective lenders.                            |
| _loans          | mapping(uint256 => Loan.State) | 	Mapping of loan identifiers (loan IDs) to their respective states.                          |

## Modifiers

### onlyRegistry
```solidity
modifier onlyRegistry();
```
Ensures that a function can only be called by the registry contract.

### onlyLoanHolder
```solidity
modifier onlyLoanHolder(uint256 loanId);
```
Ensures that a function can only be called by the owner (holder) of a specific loan.


## Initializer
```solidity
function initialize(address nft_) external initializer;
```
Initializes the contract with the provided NFT token address.

#### Parameters:

| Name | Type    | Description                                                      |
|------|---------|------------------------------------------------------------------|
| nft_ | address | The address of the NFT token associated with the lending market. |

## Functions
### pause
```solidity
function pause() external onlyOwner;
```
Pauses the contract, preventing certain functions from being called.

#### Restrictions:
- Is reverted if caller is not the owner

### unpause
```solidity
function unpause() external onlyOwner;
```
Unpauses the contract, allowing paused functions to be called again.

#### Restrictions:
- Is reverted if caller is not the owner

### setRegistry
```solidity
function setRegistry(address newRegistry) external onlyOwner;
```
Sets the address of the registry contract used for registering credit lines and liquidity pools.

#### Restrictions:
- Is reverted if caller is not the owner

#### Parameters:

| Name        | Type    | Description                               |
|-------------|---------|-------------------------------------------|
| newRegistry | address | The address of the new registry contract. |

### registerCreditLine
```solidity
function registerCreditLine(address lender, address creditLine) external whenNotPaused onlyRegistry;
```
Registers a new credit line contract for a lender.

#### Restrictions:
- Is reverted if caller is not the registry
- Is reverted if contract is paused

#### Parameters:

| Name       | Type    | Description                                                |
|------------|---------|------------------------------------------------------------|
| lender     | address | The address of the lender associated with the credit line. |
| creditLine | address | The address of the credit line contract to be registered.  |


### registerLiquidityPool
```solidity
function registerLiquidityPool(address lender, address liquidityPool) external whenNotPaused onlyRegistry;
```
Registers a new liquidity pool contract for a lender.

#### Restrictions:
- Is reverted if caller is not the registry
- Is reverted if contract is paused

#### Parameters:

| Name          | Type    | Description                                                   |
|---------------|---------|---------------------------------------------------------------|
| lender        | address | The address of the lender associated with the liquidity pool. |
| liquidityPool | address | The address of the liquidity pool contract to be registered.  |

### takeLoan
```solidity
function takeLoan(address creditLine, uint256 amount) external whenNotPaused;
```
Allows a borrower to take a loan with the terms defined in a credit line.

#### Restrictions:
- Is reverted if contract is paused

#### Parameters:

| Name       | Type    | Description                         |
|------------|---------|-------------------------------------|
| creditLine | address | The address of the credit line.     |
| amount     | uint256 | The amount of the loan to be taken. |

### repayLoan
```solidity
function repayLoan(uint256 loanId, uint256 amount) external whenNotPaused;
```
Allows a borrower to repay a loan.

#### Restrictions:
- Is reverted if contract is paused

#### Parameters:
| Name   | Type    | Description                              |
|--------|---------|------------------------------------------|
| loanId | address | The identifier of the loan to be repaid. |
| amount | uint256 | The amount to be repaid.                 |

### freeze
```solidity
function freeze(uint256 loanId) external onlyLoanHolder(loanId) whenNotPaused;
```
Allows the owner of the loan to freeze it, preventing further actions.

#### Restrictions:
- Is reverted if caller is not the owner of the loan
- Is reverted if contract is paused

#### Parameters:

| Name   | Type    | Description                              |
|--------|---------|------------------------------------------|
| loanId | address | The identifier of the loan to be frozen. |


### unfreeze
```solidity
function unfreeze(uint256 loanId) external onlyLoanHolder(loanId) whenNotPaused;
```
Allows the owner of the loan to unfreeze it, allowing further actions.

#### Restrictions:
- Is reverted if caller is not the owner of the loan
- Is reverted if contract is paused

#### Parameters:

| Name   | Type    | Description                                |
|--------|---------|--------------------------------------------|
| loanId | address | The identifier of the loan to be unfrozen. |

### updateLoanDuration
```solidity
function updateLoanDuration(uint256 loanId, uint256 newDurationInPeriods) external whenNotPaused onlyLoanHolder(loanId);
```
Allows the owner of the loan to update the loan duration.

#### Restrictions:
- Is reverted if caller is not the owner of the loan
- Is reverted if contract is paused

#### Parameters:

| Name                 | Type    | Description                               |
|----------------------|---------|-------------------------------------------|
| loanId               | address | The identifier of the loan to be updated. |
| newDurationInPeriods | uint256 | The new duration of the loan in periods.  |

### updateLoanMoratorium
```solidity
function updateLoanMoratorium(uint256 loanId, uint256 newMoratoriumInPeriods) external whenNotPaused onlyLoanHolder(loanId);
```
Allows the owner of the loan to update the loan moratorium.

#### Restrictions:
- Is reverted if caller is not the owner of the loan
- Is reverted if contract is paused

#### Parameters:

| Name                   | Type    | Description                               |
|------------------------|---------|-------------------------------------------|
| loanId                 | address | The identifier of the loan to be updated. |
| newMoratoriumInPeriods | uint256 | The new moratorium duration in periods.   |

### updateLoanInterestRatePrimary
```solidity
function updateLoanInterestRatePrimary(uint256 loanId, uint256 newInterestRate) external whenNotPaused onlyLoanHolder(loanId);
```
Allows the owner of the loan to update the primary interest rate of the loan.

#### Restrictions:
- Is reverted if caller is not the owner of the loan
- Is reverted if contract is paused

#### Parameters:

| Name            | Type    | Description                               |
|-----------------|---------|-------------------------------------------|
| loanId          | address | The identifier of the loan to be updated. |
| newInterestRate | uint256 | The new primary interest rate.            |

### updateLoanInterestRateSecondary
```solidity
function updateLoanInterestRateSecondary(uint256 loanId, uint256 newInterestRate) external whenNotPaused onlyLoanHolder(loanId);
```
Allows the owner of the loan to update the secondary interest rate of the loan.

#### Restrictions:
- Is reverted if caller is not the owner of the loan
- Is reverted if contract is paused

#### Parameters:

| Name            | Type    | Description                               |
|-----------------|---------|-------------------------------------------|
| loanId          | address | The identifier of the loan to be updated. |
| newInterestRate | uint256 | The new secondary interest rate.          |

### updateLender
```solidity
function updateLender(address creditLine, address newLender) external;
```
Updates the lender associated with a credit line contract.<br>
<b>Note:</b> <i>This function is not yet implemented in version 1.0.0 and will be reverted if called.</i>

#### Parameters:

| Name       | Type    | Description                              |
|------------|---------|------------------------------------------|
| creditLine | address | The address of the credit line contract. |
| newLender  | address | The new lender address.                  |

### getLender
```solidity
function getLender(address creditLine) external view returns (address);
```
Returns the lender associated with a credit line contract.
#### Parameters:

| Name       | Type    | Description                              |
|------------|---------|------------------------------------------|
| creditLine | address | The address of the credit line contract. |

#### Returns:

| Name   | Type    | Description                                                |
|--------|---------|------------------------------------------------------------|
| lender | address | The address of the lender associated with the credit line. |

### getLiquidityPool
```solidity
function getLiquidityPool(address lender) external view returns (address);
```
Returns the liquidity pool associated with a lender.

#### Parameters:

| Name   | Type    | Description                |
|--------|---------|----------------------------|
| lender | address | The address of the lender. |

#### Returns:

| Name          | Type    | Description                                                   |
|---------------|---------|---------------------------------------------------------------|
| liquidityPool | address | The address of the liquidity pool associated with the lender. |

### getLoanStored
```solidity
function getLoanStored(uint256 loanId) external view returns (Loan.State memory);
```
Returns the stored state of a loan.

#### Parameters:

| Name            | Type    | Description                 |
|-----------------|---------|-----------------------------|
| loanId          | uint256 | The identifier of the loan. |

#### Returns:

| Name      | Type       | Description            |
|-----------|------------|------------------------|
| loanState | Loan.State | The state of the loan. |

### getLoanCurrent
```solidity
function getLoanCurrent(uint256 loanId) external view returns (Loan.Status, Loan.State memory);
```
Returns the current status and state of a loan.

#### Parameters:

| Name            | Type    | Description                 |
|-----------------|---------|-----------------------------|
| loanId          | uint256 | The identifier of the loan. |

#### Returns:

| Name       | Type        | Description                     |
|------------|-------------|---------------------------------|
| loanStatus | Loan.Status | The current status of the loan. |
| loanState  | Loan.State  | The state of the loan.          |


### calculatePeriodDate
```solidity
function calculatePeriodDate(uint256 periodInSeconds, uint256 extraPeriods, uint256 extraSeconds) public view returns (uint256)
```
Calculates the date and time for a specific period based on the current timestamp, considering additional periods and seconds.

#### Parameters:

| Name            | Type    | Description                          |
|-----------------|---------|--------------------------------------|
| periodInSeconds | uint256 | The duration of a period in seconds. |
| extraPeriods    | uint256 | The number of extra periods to add.  |
| extraSeconds    | uint256 | The number of extra seconds to add.  |

#### Returns:

| Name       | Type    | Description                 |
|------------|---------|-----------------------------|
| periodDate | uint256 | The calculated period date. |

### calculateOutstandingBalance
```solidity
function calculateOutstandingBalance(uint256 originalBalance, uint256 numberOfPeriods, uint256 interestRate, uint256 interestRateFactor, Interest.Formula interestFormula) public pure returns (uint256)
```
Calculates the outstanding balance of a loan based on its original balance, the number of periods since it was taken, the interest rate, interest rate factor, and the interest calculation formula.

#### Parameters:

| Name               | Type             | Description                                                        |
|--------------------|------------------|--------------------------------------------------------------------|
| originalBalance    | uint256          | The original balance of the loan.                                  |
| numberOfPeriods    | uint256          | TThe number of periods since the loan was taken.                   |
| interestRate       | uint256          | The number of periods since the loan was taken.                    |
| interestRateFactor | uint256          | The interest rate factor used with the interest rate.              |
| interestFormula    | Interest.Formula | The formula used to calculate interest (e.g., Simple or Compound). |

#### Returns:

| Name               | Type    | Description                          |
|--------------------|---------|--------------------------------------|
| outstandingBalance | uint256 | The outstanding balance of the loan. |
