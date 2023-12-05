# Overview

The `LendingRegistry` contract is responsible for managing credit lines and liquidity pools within the lending system. It keeps track of registered credit lines and liquidity pools, manages factories for creating them, and provides functions to interact with the lending market.

## Contract Details

- **Version**: Solidity 0.8.20
- **License**: MIT
- **Author**: CloudWalk Inc. (See [CloudWalk](https://cloudwalk.io))
- **Interface**: [ILendingRegistry](./interfaces/ILendingRegistry.md)

## Events

### SetCreditLineFactory
```solidity
event SetCreditLineFactory(address newFactory, address oldFactory);
```
Emitted when the credit line factory is set.

#### Parameters:

| Name       | Type    | Description                                 |
|------------|---------|---------------------------------------------|
| newFactory | address | The address of the new credit line factory. |
| oldFactory | address | The address of the old credit line factory. |

### SetLiquidityPoolFactory
```solidity
event SetLiquidityPoolFactory(address newFactory, address oldFactory);
```
Emitted when the liquidity pool factory is set.
#### Parameters:

| Name       | Type    | Description                                    |
|------------|---------|------------------------------------------------|
| newFactory | address | The address of the new liquidity pool factory. |
| oldFactory | address | The address of the old liquidity pool factory. |

## Errors

### CreditLineFactoryNotConfigured
```solidity
error CreditLineFactoryNotConfigured();
```
Thrown when the credit line factory is not set.

### LiquidityPoolFactoryNotConfigured
```solidity
error LiquidityPoolFactoryNotConfigured();
```
Thrown when the liquidity pool factory is not set.

## Initializer
Initializes the upgradable contract.

#### Parameters:

| Name    | Type    | Description                                   |
|---------|---------|-----------------------------------------------|
| market_ | address | The address of the associated lending market. |

## Functions

### pause
```solidity
function pause() external onlyOwner
```
Pauses the contract.

#### Restrictions:
- Is reverted if caller is not the owner

### unpause
```solidity
function unpause() external onlyOwner
```
Unpauses the contract.

#### Restrictions:
- Is reverted if caller is not the owner

### setCreditLineFactory
```solidity
function setCreditLineFactory(address newFactory) external onlyOwner
```
Sets the credit line factory contract.

#### Restrictions:
- Is reverted if caller is not the owner
- Is reverted if credit line factory is already configured

#### Parameters:

| Name       | Type    | Description                                 |
|------------|---------|---------------------------------------------|
| newFactory | address | The address of the new credit line factory. |

### setLiquidityPoolFactory
```solidity
function setLiquidityPoolFactory(address newFactory) external onlyOwner
```
Sets the liquidity pool factory contract.

#### Restrictions:
- Is reverted if caller is not the owner
- Is reverted if liquidity pool factory is not configured

#### Parameters:

| Name       | Type    | Description                                    |
|------------|---------|------------------------------------------------|
| newFactory | address | The address of the new liquidity pool factory. |


### createCreditLine
```solidity
function createCreditLine(uint16 kind) external whenNotPaused
```
Creates a new credit line.

#### Restrictions:
- Is reverted if contract is paused
- Is reverted if credit line factory is not configured

### Parameters:

| Name | Type   | Description                        |
|------|--------|------------------------------------|
| kind | uint16 | The kind of credit line to create. |

### createLiquidityPool
```solidity
function createLiquidityPool(uint16 kind) external whenNotPaused
```
Creates a new liquidity pool.

#### Restrictions:
- Is reverted if contract is paused
- Is reverted if liquidity pool factory is not configured

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
