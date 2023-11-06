# Overview

The `LendingRegistry` contract is responsible for managing credit lines and liquidity pools within the lending system. It keeps track of registered credit lines and liquidity pools, manages factories for creating them, and provides functions to interact with the lending market.

## Contract Details

- **Version**: Solidity 0.8.20
- **License**: MIT
- **Author**: CloudWalk Inc. (See [CloudWalk](https://cloudwalk.io))
- **Interface**: [ILendingRegistry](./interfaces/ILendingRegistry.md)

## Events

### CreditLineFactorySet
```solidity
event CreditLineFactorySet(address newFactory, address oldFactory);
```
Emitted when the credit line factory is set.

#### Parameters:

| Name       | Type    | Description                                 |
|------------|---------|---------------------------------------------|
| newFactory | address | The address of the new credit line factory. |
| oldFactory | address | The address of the old credit line factory. |

### LiquidityPoolFactorySet
```solidity
event LiquidityPoolFactorySet(address newFactory, address oldFactory);
```
Emitted when the liquidity pool factory is set.
#### Parameters:

| Name       | Type    | Description                                    |
|------------|---------|------------------------------------------------|
| newFactory | address | The address of the new liquidity pool factory. |
| oldFactory | address | The address of the old liquidity pool factory. |

## Errors

### CreditLineFactoryNotSet
```solidity
error CreditLineFactoryNotSet();
```
Thrown when the credit line factory is not set.

### LiquidityPoolFactoryNotSet
```solidity
error LiquidityPoolFactoryNotSet();
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

### registerCreditLine
```solidity
function registerCreditLine(address lender, address creditLine) external onlyOwner
```
Registers a credit line in the lending market.

#### Restrictions:
- Is reverted if caller is not the owner

#### Parameters:

| Name       | Type    | Description                                          |
|------------|---------|------------------------------------------------------|
| lender     | address | The address of the credit line lender to register.   |
| creditLine | address | The address of the credit line contract to register. |

### registerLiquidityPool
```solidity
function registerLiquidityPool(address lender, address liquidityPool) external onlyOwner
```
Registers a liquidity pool in the lending market.

#### Restrictions:
- Is reverted if caller is not the owner

#### Parameters:
| Name          | Type    | Description                                             |
|---------------|---------|---------------------------------------------------------|
| lender        | address | The address of the liquidity pool lender to register.   |
| liquidityPool | address | The address of the liquidity pool contract to register. |

### setCreditLineFactory
```solidity
function setCreditLineFactory(address newFactory) external onlyOwner
```
Sets the credit line factory contract.

#### Restrictions:
- Is reverted if caller is not the owner

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
