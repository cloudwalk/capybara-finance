# Overview

The `ILendingMarket` interface defines the functions and events for the lending market. This interface is used to interact with the lending market within the lending system.

- **Version**: Solidity 0.8.23
- **License**: MIT
- **Author**: CloudWalk Inc. (See [CloudWalk](https://cloudwalk.io))

## Events

### RegisterCreditLine
```solidity
event RegisterCreditLine(address indexed lender, address indexed creditLine);
```
Emitted when a credit line is registered.

#### Parameters:

| Name	      | Type	    | Description                                  |
|------------|----------|----------------------------------------------|
| lender     | address	 | The address of the credit line lender.       |
| creditLine | address	 | The address of the credit line contract.     |

### RegisterLiquidityPool
```solidity
event RegisterLiquidityPool(address indexed lender, address indexed liquidityPool);
```
Emitted when a liquidity pool is registered.

#### Parameters:

| Name	         | Type	    | Description                                 |
|---------------|----------|---------------------------------------------|
| lender        | address	 | The address of the liquidity pool lender.   |
| liquidityPool | address	 | The address of the liquidity pool contract. |

### TakeLoan
```solidity
event TakeLoan(uint256 indexed loanId, address indexed borrower, uint256 borrowAmount);
```
Emitted when a loan is taken.

#### Parameters:

| Name	         | Type	    | Description                               |
|---------------|----------|-------------------------------------------|
| loanId        | uint256	 | The unique identifier of the loan.        |
| borrower	     | address	 | The address of the borrower.              |
| borrowAmount	 | uint256	 | The initial principal amount of the loan. |

### RepayLoan
```solidity
event RepayLoan(uint256 indexed loanId, address indexed repayer, address indexed borrower, uint256 repayAmount, uint256 remainingBalance);
```
Emitted when a loan is repaid.

#### Parameters:

| Name	             | Type	    | Description                        |
|-------------------|----------|------------------------------------|
| loanId            | uint256	 | The unique identifier of the loan. |
| repayer           | address	 | The address of the repayer.        |
| borrower	         | address	 | The address of the borrower.       |
| repayAmount       | uint256	 | The amount of the repayment.       |
| remainingBalance  | uint256	 | The remaining balance of the loan. |

### FreezeLoan
```solidity
event FreezeLoan(uint256 indexed loanId, uint256 freezeDate);
```
Emitted when the loan is frozen.

#### Parameters:

| Name	       | Type	        | Description                        |
|-------------|--------------|------------------------------------|
| loanId      | uint256	     | The unique identifier of the loan. |
| freezeDate  | uint256	     | The date when the loan was frozen. |

### UnfreezeLoan
```solidity
event UnfreezeLoan(uint256 indexed loanId, uint256 unfreezeDate);
```
Emitted when the loan is unfrozen.

#### Parameters:

| Name	       | Type	        | Description                           |
|-------------|--------------|---------------------------------------|
| loanId      | uint256	     | The unique identifier of the loan.    |
| freezeDate  | uint256	     | The date when the loan was unfrozen.  |

### UpdateLoanDuration
```solidity
event UpdateLoanDuration(uint256 indexed loanId, uint256 indexed newDuration, uint256 indexed oldDuration);
```
Emitted when the duration of the loan is updated.

#### Parameters:

| Name	        | Type	    | Description                              |
|--------------|----------|------------------------------------------|
| loanId	      | uint256	 | The unique identifier of the loan.       |
| newDuration	 | uint256	 | The new duration of the loan in periods. |
| oldDuration	 | uint256	 | The old duration of the loan in periods. |

### UpdateLoanMoratorium
```solidity
event UpdateLoanMoratorium(uint256 indexed loanId, uint256 indexed newMoratorium, uint256 indexed oldMoratorium);
```
Emitted when the moratorium of the loan is updated.

#### Parameters:

| Name	          | Type	    | Description                                |
|----------------|----------|--------------------------------------------|
| loanId	        | uint256	 | The unique identifier of the loan.         |
| newMoratorium	 | uint256	 | The new moratorium of the loan in periods. |
| oldMoratorium	 | uint256	 | The old moratorium of the loan in periods. |


### UpdateLoanInterestPrimary
```solidity
event UpdateLoanInterestPrimary(uint256 indexed loanId, uint256 indexed newInterestRate, uint256 indexed oldInterestRate);
```
Emitted when the primary interest rate of the loan is updated.

#### Parameters:

| Name	            | Type	    | Description                                |
|------------------|----------|--------------------------------------------|
| loanId	          | uint256	 | The unique identifier of the loan.         |
| newInterestRate	 | uint256	 | The new primary interest rate of the loan. |
| oldInterestRate	 | uint256	 | The old primary interest rate of the loan. |

### UpdateLoanInterestSecondary
```solidity
event UpdateLoanInterestSecondary(uint256 indexed loanId, uint256 indexed newInterestRate, uint256 indexed oldInterestRate);
```
Emitted when the secondary interest rate of the loan is updated.

#### Parameters:

| Name	            | Type	    | Description                                  |
|------------------|----------|----------------------------------------------|
| loanId	          | uint256	 | The unique identifier of the loan.           |
| newInterestRate	 | uint256	 | The new secondary interest rate of the loan. |
| oldInterestRate	 | uint256	 | The old secondary interest rate of the loan. |

### UpdateCreditLineLender
```solidity
event UpdateCreditLineLender(address indexed creditLine, address indexed newLender, address indexed oldLender);
```
Emitted when the lender of the credit line is updated.

#### Parameters:

| Name	       | Type	    | Description                              |
|-------------|----------|------------------------------------------|
| creditLine	 | address	 | The address of the credit line contract. |
| newLender	  | address	 | The address of the new lender.           |
| oldLender	  | address	 | The address of the old lender.           |

### SetRegistry
```solidity
event SetRegistry(address indexed oldRegistry, address indexed newRegistry);
```
Emitted when the registry contract is updated.

#### Parameters:

| Name	        | Type	    | Description                               |
|--------------|----------|-------------------------------------------|
| oldRegistry	 | address	 | The address of the old registry contract. |
| newRegistry	 | address	 | The address of the new registry contract. |

## Borrower functions

### takeLoan
```solidity
function takeLoan(address creditLine, uint256 amount) external whenNotPaused;
```
Allows a borrower to take a loan with the terms defined in a credit line.

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

#### Parameters:
| Name   | Type    | Description                              |
|--------|---------|------------------------------------------|
| loanId | address | The identifier of the loan to be repaid. |
| amount | uint256 | The amount to be repaid.                 |

## Loan holder functions

### freeze
```solidity
function freeze(uint256 loanId) external onlyLoanHolder(loanId) whenNotPaused;
```
Allows the owner of the loan to freeze it, preventing further actions.

#### Parameters:

| Name   | Type    | Description                              |
|--------|---------|------------------------------------------|
| loanId | address | The identifier of the loan to be frozen. |


### unfreeze
```solidity
function unfreeze(uint256 loanId) external onlyLoanHolder(loanId) whenNotPaused;
```
Allows the owner of the loan to unfreeze it, allowing further actions.

#### Parameters:

| Name   | Type    | Description                                |
|--------|---------|--------------------------------------------|
| loanId | address | The identifier of the loan to be unfrozen. |

### updateLoanDuration
```solidity
function updateLoanDuration(uint256 loanId, uint256 newDurationInPeriods) external whenNotPaused onlyLoanHolder(loanId);
```
Allows the owner of the loan to update the loan duration.

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

#### Parameters:

| Name            | Type    | Description                               |
|-----------------|---------|-------------------------------------------|
| loanId          | address | The identifier of the loan to be updated. |
| newInterestRate | uint256 | The new secondary interest rate.          |

### updateLender
```solidity
function updateLender(address creditLine, address newLender) external;
```
Updates the lender associated with a credit line contract.

#### Parameters:

| Name       | Type    | Description                              |
|------------|---------|------------------------------------------|
| creditLine | address | The address of the credit line contract. |
| newLender  | address | The new lender address.                  |

### registerCreditLine
```solidity
function registerCreditLine(address lender, address creditLine) external whenNotPaused onlyRegistry;
```
Registers a new credit line contract for a lender.

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

#### Parameters:

| Name          | Type    | Description                                                   |
|---------------|---------|---------------------------------------------------------------|
| lender        | address | The address of the lender associated with the liquidity pool. |
| liquidityPool | address | The address of the liquidity pool contract to be registered.  |

## View functions

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

### getLoanState
```solidity
function getLoanState(uint256 loanId) external view returns (Loan.State memory);
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

### getLoanBalance
```solidity
function getLoanBalance(uint256 loanId, uint256 timestamp) external view returns (uint256, uint256);
```
Gets the outstanding balance of a given loan.

#### Parameters:

| Name      | Type    | Description                                       |
|-----------|---------|---------------------------------------------------|
| loanId    | uint256 | The identifier of the loan.                       |
| timestamp | uint256 | The timestamp to get the outstanding balance for. |

#### Returns:

| Name               | Type        | Description                          |
|--------------------|-------------|--------------------------------------|
| outstandingBalance | Loan.Status | The outstanding balance of the loan. |
| timestamp          | uint256     | The applied period date of the loan. |

### registry
```solidity
function registry() external view returns (address);
```
Retrieves the address of the registry.

#### Returns:

| Name     | Type    | Description                  |
|----------|---------|------------------------------|
| registry | address | The address of the registry. |