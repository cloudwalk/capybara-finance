# Overview
The `ILendingRegistry` interface defines the functions and events for the lending registry. This interface is used to create credit lines, liquidity pools, and retrieve information about the lending market within the lending system.

- **Version**: Solidity 0.8.20
- **License**: MIT
- **Author**: CloudWalk Inc. (See [CloudWalk](https://cloudwalk.io))

## Events

### CreditLineCreated
```solidity
event CreditLineCreated(address indexed lender, address creditLine);
```
Emitted when a new credit line is created.

#### Parameters:
| Name        | Type     | Description                              |
|-------------|----------|------------------------------------------|
| lender	     | address	 | The address of the credit line lender.   |
| creditLine	 | address	 | The address of the credit line contract. |

### LiquidityPoolCreated
```solidity
event LiquidityPoolCreated(address indexed lender, address liquidityPool);
```
Emitted when a new liquidity pool is created.

#### Parameters:

| Name           | Type     | Description                                 |
|----------------|----------|---------------------------------------------|
| lender	        | address	 | The address of the liquidity pool lender.   |
| liquidityPool	 | address	 | The address of the liquidity pool contract. |

## Functions

### createCreditLine
```solidity
function createCreditLine(uint16 kind) external whenNotPaused
```
Creates a new credit line.

### Parameters:

| Name | Type   | Description                        |
|------|--------|------------------------------------|
| kind | uint16 | The kind of credit line to create. |

### createLiquidityPool
```solidity
function createLiquidityPool(uint16 kind) external whenNotPaused
```
Creates a new liquidity pool.
#### Parameters:

| Name | Type   | Description                           |
|------|--------|---------------------------------------|
| kind | uint16 | The kind of liquidity pool to create. |

### creditLineFactory
```solidity
function creditLineFactory() external view returns (address)
```
Retrieves the address of the credit line factory.

### liquidityPoolFactory
```solidity
function liquidityPoolFactory() external view returns (address)
```
Retrieves the address of the liquidity pool factory.

### market
```solidity
function market() external view returns (address)
```
Retrieves the address of the associated lending market.