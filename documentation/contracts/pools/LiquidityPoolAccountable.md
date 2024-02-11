# Overview

The `LiquidityPoolAccountable` is a Solidity contract designed for managing liquidity pools in a lending platform. It allows lenders to deposit and withdraw funds into/from liquidity pools, tracks credit lines associated with loans, and ensures accountable handling of assets.

## Contract Details

- **Version**: Solidity 0.8.23
- **License**: MIT
- **Author**: CloudWalk Inc. (See [CloudWalk](https://cloudwalk.io))
- **Interface**: [ILiquidityPoolAccountable](../interfaces/ILiquidityPoolAccountable.md)

## Storage Variables

| Name                | Type                        | Description                                                |
|---------------------|-----------------------------|------------------------------------------------------------|
| _market             | address                     | The address of the associated lending market.              |
| _admins             | mapping(address => bool)    | The mapping of account to admin status.                    |
| _creditLines        | mapping(uint256 => address) | Maps loan identifiers to associated credit line addresses. |
| _creditLineBalances | mapping(address => uint256) | Maps credit line addresses to their token balances.        |

## Errors

### ZeroBalance

```solidity
error ZeroBalance();
```
Thrown when the token source balance is zero.

### InsufficientBalance
```solidity
error InsufficientBalance();
```
Thrown when the token balance is insufficient to fulfill a request.

## Modifiers
### onlyMarket
```solidity
modifier onlyMarket();
```
Ensures that the function can only be called by the lending market associated with the contract.

## Initializer
 
```solidity
function initialize(address market_, address lender_) external initializer;
```
Initializes the contract with the address of the associated lending market and the lender. It performs basic input validation for these addresses.

#### Parameters

| Name      | Type      | Description                               |
|-----------|-----------|-------------------------------------------|
| _market   | address   | The address of the associated market      |
| lender_   | address   | The address of the liquidity pool's owner |

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
Unpauses the contract, allowing functions to be called again.

#### Restrictions:
- Is reverted if caller is not the owner


### configureAdmin
```solidity
function configureAdmin(address admin, uint256 adminStatus) external;
```
Configures an admin status.

#### Restrictions:
- Is reverted if admin is zero address
- Is reverted if the admin is already configured

#### Parameters:

| Name        | Type    | Description                       |
|-------------|---------|-----------------------------------|
| admin       | address | The address of the admin account. |
| adminStatus | bool    | The status of the admin.          |

### deposit
```solidity
function deposit(address creditLine, uint256 amount) external onlyOwner;
```
Allows the owner (lender) to deposit funds for a specified credit line.

#### Restrictions:
- Is reverted if caller is not the owner
- Is reverted if credit line balance is zero
- Is reverted if amount is zero

#### Parameters:

| Name       | Type     | Description                                     |
|------------|----------|-------------------------------------------------|
| creditLine | address	 | The address of the credit line to deposit into. |
| amount     | uint256	 | The amount to deposit into the credit line.     |

### withdraw
```solidity
function withdraw(address tokenSource, uint256 amount) external onlyOwner;
```
Allows the owner (lender) to withdraw funds from either a credit line, non-credit line balance, or rescue tokens from the contract.

#### Restrictions:
- Is reverted if caller is not the owner
- Is reverted if amount is zero
- Is reverted if pool's balance is insufficient

#### Parameters

| Name         | Type     | Description                            |
|--------------|----------|----------------------------------------|
| tokenSource  | address  | The source of tokens to withdraw from. |
| amount       | uint256  | The amount to withdraw.                |

### withdraw
```solidity
function autoRepay(uint256[] memory loanIds, uint256[] memory amounts) external onlyAdmin;
```
Forces auto repayment of loans in batch mode.

#### Restrictions:
- Is reverted if caller is not the admin
- Is reverted if arrays length mismatch

#### Parameters:

| Name    | Type      | Description                                     |
|---------|-----------|-------------------------------------------------|
| loanIds | uin256[]  | The unique identifiers of the loans to repay.   |
| amounts | uint256[] | The amounts that correlate with given loan ids. |

### onBeforeLoanTaken
```solidity
function onBeforeLoanTaken(uint256 loanId, address creditLine) external whenNotPaused onlyMarket;
```
Called by the lending market before a loan is taken. It takes the loan identifier and the associated credit line address.

#### Restrictions:
- Is reverted if caller is not the market
- Is reverted if contract is paused

#### Parameters

| Name        | Type     | Description                                         |
|-------------|----------|-----------------------------------------------------|
| loanId      | uint256  | The id of the created loan.                         |
| creditLine  | address  | The credit line that was used to define loan terms. |

### onAfterLoanTaken
```solidity
function onAfterLoanTaken(uint256 loanId, address creditLine) external whenNotPaused onlyMarket;
```
Called by the lending market after a loan is taken. It associates the loan identifier with the credit line and deducts the initial borrow amount from the credit line balance.

#### Restrictions:
- Is reverted if caller is not the market
- Is reverted if contract is paused

#### Parameters:

| Name        | Type     | Description                                         |
|-------------|----------|-----------------------------------------------------|
| loanId      | uint256  | The id of the created loan.                         |
| creditLine  | address  | The credit line that was used to define loan terms. |

### onBeforeLoanPayment
```solidity
function onBeforeLoanPayment(uint256 loanId, uint256 amount) external whenNotPaused onlyMarket;
```
Called by the lending market before a loan payment is made. It takes the loan identifier and the payment amount.

#### Restrictions:
- Is reverted if caller is not the market
- Is reverted if contract is paused

#### Parameters:

| Name       | Type    | Description                                         |
|------------|---------|-----------------------------------------------------|
| loanId     | uint256 | The id of the loan.                                 |
| creditLine | address | The credit line that was used to define loan terms. |

### onAfterLoanPayment
```solidity
function onAfterLoanPayment(uint256 loanId, uint256 amount) external whenNotPaused onlyMarket;
```
Called by the lending market after a loan payment is made. It either increases the credit line balance or the non-credit line balance based on the loan identifier.

#### Restrictions:
- Is reverted if caller is not the market
- Is reverted if contract is paused

#### Parameters:

| Name       | Type    | Description                                         |
|------------|---------|-----------------------------------------------------|
| loanId     | uint256 | The id of the loan.                                 |
| creditLine | address | The credit line that was used to define loan terms. |

### getTokenBalance
```solidity
function getTokenBalance(address tokenSource) external view returns (uint256);
```
Returns the token balance for a given token source, including credit line balances, non-credit line balances, and native token balances.

#### Parameters:

| Name        | Type    | Description                                   |
|-------------|---------|-----------------------------------------------|
| tokenSource | address | The source of tokens to check the balance of. |
		


### getCreditLine
```solidity
function getCreditLine(uint256 loanId) external view returns (address);
```
Returns the credit line associated with a loan identifier.

#### Parameters:
| Name   | Type    | Description                 |
|--------|---------|-----------------------------|
| loanId | uint256 | The identifier of the loan. |

### isAdmin
```solidity
function isAdmin(address account) external view returns (bool);
```
Retrieves the admin status of the account.

#### Parameters:

| Name    | Type    | Description                               |
|---------|---------|-------------------------------------------|
| account | address | The address to check the admin status of. |

#### Returns:

The `bool` admin status of the account.

### market
```solidity
function market() external view returns (address);
```
Returns the address of the associated lending market.

### lender
```solidity
function lender() external view returns (address);
```
Returns the address of the lender (owner) of the contract.

### kind
```solidity
function kind() external pure returns (uint16);
```
Returns the type identifier for the liquidity pool, which can be used to distinguish between different types of liquidity pools in the system.