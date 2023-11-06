# Overview

The `ILendingMarket` interface defines the functions and events for the lending market. This interface is used to interact with the lending market within the lending system.

- **Version**: Solidity 0.8.20
- **License**: MIT
- **Author**: CloudWalk Inc. (See [CloudWalk](https://cloudwalk.io))

## Events

### CreditLineRegistered
```solidity
event CreditLineRegistered(address indexed lender, address indexed creditLine);
```
Emitted when a credit line is registered.

#### Parameters:

| Name	      | Type	    | Description                                  |
|------------|----------|----------------------------------------------|
| lender     | address	 | The address of the credit line lender.       |
| creditLine | address	 | The address of the credit line contract.     |

LiquidityPoolRegistered
```solidity
event LiquidityPoolRegistered(address indexed lender, address indexed liquidityPool);
```
Emitted when a liquidity pool is registered.

#### Parameters:

| Name	         | Type	    | Description                                 |
|---------------|----------|---------------------------------------------|
| lender        | address	 | The address of the liquidity pool lender.   |
| liquidityPool | address	 | The address of the liquidity pool contract. |

### LoanTaken
```solidity
event LoanTaken(uint256 indexed loanId, address indexed borrower, uint256 borrowAmount);
```
Emitted when a loan is taken.

#### Parameters:

| Name	         | Type	    | Description                               |
|---------------|----------|-------------------------------------------|
| loanId        | uint256	 | The unique identifier of the loan.        |
| borrower	     | address	 | The address of the borrower.              |
| borrowAmount	 | uint256	 | The initial principal amount of the loan. |

### LoanRepaid
```solidity
event LoanRepaid(uint256 indexed loanId, address indexed borrower);
```
Emitted when a loan is repaid (fully).

#### Parameters:

| Name	     | Type	    | Description                         |
|-----------|----------|-------------------------------------|
| loanId    | uint256	 | The unique identifier of the loan.  |
| borrower	 | address	 | The address of the borrower.        |
LoanRepayment
```solidity
event LoanRepayment(uint256 indexed loanId, address indexed repayer,address indexed borrower, uint256 repayAmount, uint256 remainingBalance);
```
Emitted when a loan is repaid (fully or partially).

#### Parameters:

| Name	            | Type	    | Description                         |
|------------------|----------|-------------------------------------|
| loanId           | 	uint256 | 	The unique identifier of the loan. |
| repayer          | 	address | 	The address of the repayer.        |
| borrower         | 	address | 	The address of the borrower.       |
| repayAmount      | 	uint256 | 	The amount of the repayment.       |
| remainingBalance | 	uint256 | 	The remaining balance of the loan. |

### LoanStatusChanged
```solidity
event LoanStatusChanged(uint256 indexed loanId, Loan.Status indexed newStatus, Loan.Status indexed oldStatus);
```
Emitted when the status of the loan is changed.

#### Parameters:

| Name	     | Type	        | Description                        |
|-----------|--------------|------------------------------------|
| loanId    | uint256	     | The unique identifier of the loan. |
| newStatus | Loan.Status	 | The new status of the loan.        |
| oldStatus | Loan.Status	 | The old status of the loan.        |

### LoanDurationUpdated
```solidity
event LoanDurationUpdated(uint256 indexed loanId, uint256 indexed newDuration, uint256 indexed oldDuration);
```
Emitted when the duration of the loan is updated.

#### Parameters:

| Name	        | Type	    | Description                              |
|--------------|----------|------------------------------------------|
| loanId	      | uint256	 | The unique identifier of the loan.       |
| newDuration	 | uint256	 | The new duration of the loan in periods. |
| oldDuration	 | uint256	 | The old duration of the loan in periods. |

### LoanMoratoriumUpdated
```solidity
event LoanMoratoriumUpdated(uint256 indexed loanId, uint256 indexed newMoratorium, uint256 indexed oldMoratorium);
```
Emitted when the moratorium of the loan is updated.

#### Parameters:

| Name	          | Type	    | Description                                |
|----------------|----------|--------------------------------------------|
| loanId	        | uint256	 | The unique identifier of the loan.         |
| newMoratorium	 | uint256	 | The new moratorium of the loan in periods. |
| oldMoratorium	 | uint256	 | The old moratorium of the loan in periods. |


### LoanInterestRatePrimaryUpdated
```solidity
event LoanInterestRatePrimaryUpdated(uint256 indexed loanId, uint256 indexed newInterestRate, uint256 indexed oldInterestRate);
```
Emitted when the primary interest rate of the loan is updated.

#### Parameters:

| Name	            | Type	    | Description                                |
|------------------|----------|--------------------------------------------|
| loanId	          | uint256	 | The unique identifier of the loan.         |
| newInterestRate	 | uint256	 | The new primary interest rate of the loan. |
| oldInterestRate	 | uint256	 | The old primary interest rate of the loan. |

### LoanInterestRateSecondaryUpdated
```solidity
event LoanInterestRateSecondaryUpdated(uint256 indexed loanId, uint256 indexed newInterestRate, uint256 indexed oldInterestRate);
```
Emitted when the secondary interest rate of the loan is updated.

#### Parameters:

| Name	            | Type	    | Description                                  |
|------------------|----------|----------------------------------------------|
| loanId	          | uint256	 | The unique identifier of the loan.           |
| newInterestRate	 | uint256	 | The new secondary interest rate of the loan. |
| oldInterestRate	 | uint256	 | The old secondary interest rate of the loan. |

### CreditLineLenderUpdated
```solidity
event CreditLineLenderUpdated(address indexed creditLine, address indexed newLender, address indexed oldLender);
```
Emitted when the lender of the credit line is updated.

#### Parameters:

| Name	       | Type	    | Description                              |
|-------------|----------|------------------------------------------|
| creditLine	 | address	 | The address of the credit line contract. |
| newLender	  | address	 | The address of the new lender.           |
| oldLender	  | address	 | The address of the old lender.           |

### RegistryUpdated
```solidity
event RegistryUpdated(address indexed oldRegistry, address indexed newRegistry);
```
Emitted when the registry contract is updated.

#### Parameters:

| Name	        | Type	    | Description                               |
|--------------|----------|-------------------------------------------|
| oldRegistry	 | address	 | The address of the old registry contract. |
| newRegistry	 | address	 | The address of the new registry contract. |

## Functions

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