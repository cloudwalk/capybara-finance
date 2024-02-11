# Overview
ILiquidityPool is an interface that specifies the operations related to the liquidity pool.

## Contract Details

- **Version**: Solidity 0.8.23
- **License**: MIT
- **Author**: CloudWalk Inc. (See [CloudWalk](https://cloudwalk.io))

## Functions

#### onBeforeLoanTaken

```solidity
function onBeforeLoanTaken(uint256 loanId, address creditLine) external returns (bool);
```

A hook that is triggered by the market before a loan is taken.

#### Parameters:

| Name       | Type    | Description                                |
|------------|---------|--------------------------------------------|
| loanId     | uint256 | The unique identifier of the loan taken.   |
| creditLine | address | The address of the associated credit line. |

#### onAfterLoanTaken

```solidity
function onAfterLoanTaken(uint256 loanId, address creditLine) external returns (bool);
```

A hook that is triggered by the market after a loan is taken.

#### Parameters:

| Name       | Type    | Description                                |
|------------|---------|--------------------------------------------|
| loanId     | uint256 | The unique identifier of the loan taken.   |
| creditLine | address | The address of the associated credit line. |

#### onBeforeLoanPayment

```solidity
function onBeforeLoanPayment(uint256 loanId, uint256 repayAmount) external returns (bool);
```

A hook that is triggered by the market before the loan payment.

#### Parameters:

| Name        | Type    | Description                              |
|-------------|---------|------------------------------------------|
| loanId      | uint256 | The unique identifier of the loan taken. |
| repayAmount | uint256 | The amount to be repaid.                 |

#### onAfterLoanPayment

```solidity
function onAfterLoanPayment(uint256 loanId, uint256 repayAmount) external returns (bool);
```

A hook that is triggered by the market after the loan payment.

#### Parameters:

| Name        | Type    | Description                              |
|-------------|---------|------------------------------------------|
| loanId      | uint256 | The unique identifier of the loan taken. |
| repayAmount | uint256 | The amount to be repaid.                 |

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

Returns the address of the liquidity pool lender.

### Returns:

| Name   | Type    | Description                               |
|--------|---------|-------------------------------------------|
| lender | address | The address of the liquidity pool lender. |

#### kind

```solidity
function kind() external view returns (uint16);
```

Returns the kind of the liquidity pool.

### Returns:

| Name | Type   | Description                     |
|------|--------|---------------------------------|
| kind | uint16 | The kind of the liquidity pool. |
