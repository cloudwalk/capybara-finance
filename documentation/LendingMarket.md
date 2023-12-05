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

## Errors
### LoanNotExist
```solidity
error LoanNotExist();
```
Occurs when attempting to interact with a loan that does not exist.

### LoanNotFrozen
```solidity
error LoanNotFrozen();
```
Occurs when attempting to interact with a loan that was not frozen.

### LoanAlreadyRepaid
```solidity
error LoanAlreadyRepaid();
```
Occurs when attempting to interact with a loan that was already repaid.

### LoanAlreadyFrozen
```solidity
error LoanAlreadyFrozen();
```
Occurs when attempting to interact with a loan that was already frozen.

### CreditLineNotRegistered
```solidity
error CreditLineNotRegistered();
```
Occurs when attempting to interact with a credit line that is not registered.

### LiquidityPoolNotRegistered
```solidity
error LiquidityPoolNotRegistered();
```
Occurs when attempting to interact with a liquidity pool that is not registered.

### CreditLineAlreadyRegistered
```solidity
error CreditLineNotRegistered();
```
Occurs when attempting to interact with a credit line that was already registered.

### LiquidityPoolAlreadyRegistered
```solidity
error LiquidityPoolAlreadyRegistered();
```
Occurs when attempting to interact with a liquidity pool that was already registered.

### InappropriateInterestRate
```solidity
error InappropriateInterestRate();
```
Occurs when attempting to provide inappropriate interest rate.

### InappropriateLoanDuration
```solidity
error InappropriateLoanDuration();
```
Occurs when attempting to provide inappropriate loan duration.

### InappropriateLoanMoratorium
```solidity
error InappropriateLoanMoratorium();
```
Occurs when attempting to provide inappropriate loan moratorium.

## Modifiers

### onlyRegistry
```solidity
modifier onlyRegistryOrOwner();
```
Ensures that a function can only be called by the registry contract or the owner.

### onlyLoanHolder
```solidity
modifier onlyOngoingLoan(uint256 loanId);
```
Ensures that a function can only be called to interact with the existing loan.


## Initializer
```solidity
function initialize(string memory _name, string memory symbol_) external initializer;
```
Initializes the contract with the provided name and symbol.

#### Parameters:

| Name	   | Type	   | Description                                   |
|---------|---------|-----------------------------------------------|
| name_   | string  | The name of the NFT token.                    |
| symbol_ | string  | The symbol of the NFT token.                  |

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
- Is reverted if registry is already configured

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
- Is reverted if caller is not the registry or the owner
- Is reverted if contract is paused
- Is reverted if lender address is zero
- Is reverted if credit line address is zero
- Is reverted if credit line is already registered

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
- Is reverted if caller is not the registry or the owner
- Is reverted if contract is paused
- is reverted if lender address is zero
- Is reverted if liquidity pool address if zero
- Is reverted of liquidity pool is already registered

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
- Is reverted if credit line address is zero
- Is reverted if amount is zero
- Is reverted if credit line is not registered
- Is reverted if liquidity pool is not registered

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
- Is reverted if amount is zero

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
- Is reverted is loan is repaid or does not exist
- Is reverted if loan is already frozen

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
- Is reverted is loan is repaid or does not exist
- Is reverted if loan is not frozen

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
- Is reverted is loan is repaid or does not exist
- Is reverted if new duration is less than current

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
- Is reverted is loan is repaid or does not exist
- Is reverted if new moratorium is less than current

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
- Is reverted is loan is repaid or does not exist
- Is reverted if new interest rate is bigger than current

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
- Is reverted is loan is repaid or does not exist
- Is reverted if new interest rate is bigger than current

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

### getLoan
```solidity
function getLoanStored(uint256 loanId) external view returns (Loan.State memory);
```
Returns the stored state of a loan.

#### Parameters:

| Name            | Type    | Description                 |
|-----------------|---------|-----------------------------|
| loanId          | uint256 | The identifier of the loan. |

#### Returns:

| Name | Type       | Description            |
|------|------------|------------------------|
| loan | Loan.State | The state of the loan. |

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

### getOutstandingBalance
```solidity
function getOutstandingBalance(uint256 loanId) external view returns (uint256);
```
Returns the current outstanding balance of the loan.

#### Parameters:

| Name            | Type    | Description                 |
|-----------------|---------|-----------------------------|
| loanId          | uint256 | The identifier of the loan. |

#### Returns:

| Name               | Type        | Description                          |
|--------------------|-------------|--------------------------------------|
| outstandingBalance | Loan.Status | The outstanding balance of the loan. |

### getCurrentPeriodDate
```solidity
function getCurrentPeriodDate(uint256 loanId) external view returns (uint256);
```
Returns the current period of a loan.

#### Parameters:

| Name            | Type    | Description                 |
|-----------------|---------|-----------------------------|
| loanId          | uint256 | The identifier of the loan. |

#### Returns:

| Name       | Type    | Description                     |
|------------|---------|---------------------------------|
| periodDate | uint256 | The current period of the loan. |

### registry
```solidity
function registry() external view returns (address);
```
Retrieves the address of the registry.

#### Returns:

| Name     | Type    | Description                  |
|----------|---------|------------------------------|
| registry | address | The address of the registry. |

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
