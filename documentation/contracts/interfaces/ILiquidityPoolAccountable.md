# Overview
ILiquidityPoolAccountable is an interface that specifies the operations and events related to the accounting of a liquidity pool. CloudWalk Inc. has designed this interface to facilitate the interaction with liquidity pools that serve credit lines, enabling deposit and withdrawal activities and querying balances related to credit lines and tokens.

## Contract Details

- **Version**: Solidity 0.8.23
- **License**: MIT
- **Author**: CloudWalk Inc. (See [CloudWalk](https://cloudwalk.io))

## Events

### Deposit
```solidity
event Deposit(address indexed creditLine, uint256 amount);
```
Emitted when tokens are deposited into the liquidity pool.

#### Parameters:

| Name               | Type    | Description                                                  |
|--------------------|---------|--------------------------------------------------------------|
| creditLine         | address | The address of the credit line associated with the deposit.  |
| amount             | uint256 | The amount of tokens that have been deposited.               |


### Withdraw

```solidity
event Withdraw(address indexed tokenSource, uint256 amount);
```
Emitted when tokens are withdrawn from the liquidity pool.

#### Parameters:

| Name                 | Type    | Description                                    |
|----------------------|---------|------------------------------------------------|
| tokenSource          | address | The address of the associated token source     |
| amount               | uint256 | The amount of tokens that have been withdrawn. |

### ConfigureAdmin

```solidity
event ConfigureAdmin(address indexed admin, bool adminStatus);
```
Emitted when admin is configured.

#### Parameters:

| Name        | Type    | Description                       |
|-------------|---------|-----------------------------------|
| admin       | address | The address of the admin account. |
| adminStatus | bool    | The status of the admin.          |

### AutoRepay

```solidity
event AutoRepay(uint256 numberOfLoans);
```
Emitted when loans auto repayment is forced.

#### Parameters:

| Name          | Type    | Description                           |
|---------------|---------|---------------------------------------|
| numberOfLoans | uint256 | The number of loans that were repaid. |


## Functions
### configureAdmin
```solidity
function configureAdmin(address admin, uint256 adminStatus) external;
```
Configures an admin status.

#### Parameters:

| Name        | Type    | Description                       |
|-------------|---------|-----------------------------------|
| admin       | address | The address of the admin account. |
| adminStatus | bool    | The status of the admin.          |

### deposit
```solidity
function deposit(address creditLine, uint256 amount) external;
```
Deposits tokens into the liquidity pool on behalf of a credit line.

#### Parameters:

| Name               | Type    | Description                                                 |
|--------------------|---------|-------------------------------------------------------------|
| creditLine         | address | The address of the credit line associated with the deposit. |
| amount             | uint256 | The number of tokens to deposit.                            |

### withdraw
```solidity
function withdraw(address tokenSource, uint256 amount) external;
```
Withdraws tokens from the liquidity pool from a specific token source.

#### Parameters:

| Name                 | Type    | Description                                    |
|----------------------|---------|------------------------------------------------|
| tokenSource          | address | The address of the associated token source.    |
| amount               | uint256 | The number of tokens to withdraw.              |

### withdraw
```solidity
function autoRepay(uint256[] memory loanIds, uint256[] memory amounts) external;
```
Forces auto repayment of loans in batch mode.

#### Parameters:

| Name    | Type      | Description                                     |
|---------|-----------|-------------------------------------------------|
| loanIds | uin256[]  | The unique identifiers of the loans to repay.   |
| amounts | uint256[] | The amounts that correlate with given loan ids. |

### getTokenBalance
```solidity
function getTokenBalance(address tokenSource) external view returns (uint256);
```

Retrieves the token balance for a specific token source within the liquidity pool.

#### Parameters:

| Name                     | Type    | Description                             |
|--------------------------|---------|-----------------------------------------|
| tokenSource              | address | The address of the token source.        |

#### Returns:

The token balance of the specified token source.

### getCreditLine
```solidity
function getCreditLine(uint256 loanId) external view returns (address);
```
Retrieves the associated credit line for a given loan.

#### Parameters:

| Name              | Type    | Description                             |
|-------------------|---------|-----------------------------------------|
| loanId            | uint256 | The unique identifier of the loan.      |

#### Returns:

The `address` of the credit line associated with the loan.

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

## Usage
The ILiquidityPoolAccountable interface allows credit lines to interact seamlessly with liquidity pools. When a credit line needs to fund loans or collect repayments, it can deposit or withdraw tokens accordingly. Additionally, this interface provides read-only functions to check associated credit lines for loans and token balances for particular sources, aiding in the management and accounting of funds within the pool.

This modular approach enhances the maintainability and scalability of DeFi platforms, as liquidity pools can serve multiple credit lines with varying terms and requirements.