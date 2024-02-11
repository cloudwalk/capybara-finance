# Overview
The ILiquidityPoolFactory interface is a smart contract interface created by CloudWalk Inc. that defines the core functionalities for a factory pattern to create new liquidity pools contracts within a lending market ecosystem on the EVM-compatible blockchain.

## Contract Details

- **Version**: Solidity 0.8.23
- **License**: MIT
- **Author**: CloudWalk Inc. (See [CloudWalk](https://cloudwalk.io))

## Events
### CreateLiquidityPool
```solidity
event CreateLiquidityPool(address indexed market, address indexed lender, uint16 indexed kind, address liquidityPool);
```
This event is emitted every time a new liquidity pool contract is created by the factory.

#### Parameters:

| Name          | Type    | Description                                               |
|---------------|---------|-----------------------------------------------------------|
| market        | address | The address of the associated lending market.             |
| lender        | address | The address of the liquidity pool lender.                 |
| kind          | uint16  | An identifier for the kind of liquidity pool.             |
| liquidityPool | address | The address of the newly created liquidity pool contract. |

## Functions

### createLiquidityPool
```solidity
function createLiquidityPool(address market, address lender, uint16 kind, bytes calldata data) external returns (address);
```

This function is responsible for creating a new liquidity pool contract.

#### Parameters:

| Name   | Type    | Description                                                                                              |
|--------|---------|----------------------------------------------------------------------------------------------------------|
| market | address | The address of the associated lending market.                                                            |
| lender | address | The address of the lender providing the financial backing for the liquidity pool.                        |
| kind   | address | An integer representing the kind (version) of the liquidity pool to be created.                          |
| data   | address | A bytes array containing the initialization parameters or configuration data for the new liquidity pool. |

### Returns:

The contract `address` of the newly created liquidity pool.

### supportedKinds
```solidity
function supportedKinds() external view returns (uint16[] memory);
```

Retrieves the list of supported credit line types

#### Returns:

An `uint16` array of supported credit lines types.

### Usage
The ILiquidityPoolFactory interface allows a lending market platform to abstract the creation of different types of liquidity pools into a single point of interaction. When a lender wants to create a new liquidity pool, they interact with the factory, specifying the market, their address, the type of liquidity pool, and any necessary configuration data. The factory then deploys a new smart contract with the specified parameters and returns the address of this new contract.

By utilizing a factory pattern and this interface, the platform can easily introduce new types of liquidity pools or update the logic for existing ones without disrupting the entire system or needing to migrate all existing contracts to a new architecture.
