# Overview
The LiquidityPoolFactory is a Solidity contract responsible for creating liquidity pool contracts within a lending platform. Liquidity pools facilitate the management of funds and their allocation to credit lines. This factory contract supports the creation of accountable liquidity pools of a specific kind.

## Contract Details

- **Version**: Solidity 0.8.20
- **License**: MIT
- **Author**: CloudWalk Inc. (See [CloudWalk](https://cloudwalk.io))
- **Interface**: [ILiquidityPoolFactory](./interfaces/ILiquidityPoolFactory.md)

## Errors

### UnsupportedKind
```solidity
error UnsupportedKind(uint16 kind);
```
This error is thrown when attempting to create a liquidity pool of an unsupported kind.

## Initializer
```solidity
initialize(address registry_)
```
Initializer for creating a LiquidityPoolFactory contract.

#### Parameters:

| Name      | Type    | Description                                     |
|-----------|---------|-------------------------------------------------|
| registry_ | address | The address of the associated lending registry. |

## Functions

### pause
```solidity
function pause() external onlyAdmin whenNotPaused;
```
Pauses all contract functions subject to pause controls.

#### Restrictions:
- Is reverted if caller is not the owner


### unpause
```solidity
function unpause() external onlyAdmin whenPaused;
```
Unpauses the contract and allows functions to be called again.

#### Restrictions:
- Is reverted if caller is not the owner

### createLiquidityPool

```solidity
function createLiquidityPool(address market, address lender, uint16 kind, bytes calldata data) external onlyOwner returns (address liquidityPool);
```
Creates a new liquidity pool contract of the specified kind.

#### Restrictions:
- Is reverted if caller is not the owner

#### Parameters:

| Name   | Type    | Description                                                                                              |
|--------|---------|----------------------------------------------------------------------------------------------------------|
| market | address | The address of the associated lending market.                                                            |
| lender | address | The address of the lender providing the financial backing for the liquidity pool.                        |
| kind   | address | An integer representing the kind (version) of the liquidity pool to be created.                          |
| data   | address | A bytes array containing the initialization parameters or configuration data for the new liquidity pool. |

### supportedKinds
```solidity
function supportedKinds() external view returns (uint16[] memory);
```

Retrieves the list of supported credit line types

#### Returns:

An `uint16` array of supported credit lines types.