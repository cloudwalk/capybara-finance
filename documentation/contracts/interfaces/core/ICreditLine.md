# Overview

The `ICreditLine` interface is a part of a CapybaraFinance system, and it specifies a set of functionalities for credit lines.

## Contract Details

- **Version**: Solidity 0.8.23
- **License**: MIT
- **Author**: CloudWalk Inc. (See [CloudWalk](https://cloudwalk.io))

## Functions

#### onBeforeLoanTaken

```solidity
function onBeforeLoanTaken(address borrower, uint256 amount, uint256 loanId) external returns (Loan.Terms memory terms);
```

A hook that is triggered by the market before a loan is taken.

#### Parameters:

| Name     | Type    | Description                              |
|----------|---------|------------------------------------------|
| borrower | address | The address of the borrower.             |
| amount   | uint256 | The amount of the loan.                  |
| loanId   | uint256 | The unique identifier of the loan taken. |

### Returns:

| Name  | Type       | Description                                  |
|-------|------------|----------------------------------------------|
| terms | Loan.Terms | The struct containing the terms of the loan. |

#### determineLoanTerms

```solidity
function determineLoanTerms(address borrower, uint256 amount) external returns (Loan.Terms memory terms);
```

Retrieves the loan terms for the provided borrower and amount.

#### Parameters:

| Name     | Type    | Description                              |
|----------|---------|------------------------------------------|
| borrower | address | The address of the borrower.             |
| amount   | uint256 | The amount of the loan.                  |

### Returns:

| Name  | Type       | Description                                  |
|-------|------------|----------------------------------------------|
| terms | Loan.Terms | The struct containing the terms of the loan. |

#### market

```solidity
function market() external view returns (address);
```

Returns the address of the associated lending market.

### Returns:

| Name   | Type    | Description                                   |
|--------|---------|-----------------------------------------------|
| market | address | The address of the associated lending market. |

#### lender

```solidity
function lender() external view returns (address);
```

Returns the address of the credit line lender.

### Returns:

| Name   | Type    | Description                            |
|--------|---------|----------------------------------------|
| lender | address | The address of the credit line lender. |

#### token

```solidity
function token() external view returns (address);
```

Returns the address of the credit line token.

### Returns:

| Name  | Type    | Description                           |
|-------|---------|---------------------------------------|
| token | address | The address of the credit line token. |

#### kind

```solidity
function kind() external view returns (uint16);
```

Returns the kind of the credit line.

### Returns:

| Name | Type   | Description                  |
|------|--------|------------------------------|
| kind | uint16 | The kind of the credit line. |

