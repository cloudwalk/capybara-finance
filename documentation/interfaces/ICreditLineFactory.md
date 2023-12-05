# Overview
The ICreditLineFactory interface is a smart contract interface created by CloudWalk Inc. that defines the core functionalities for a factory pattern to create new credit line contracts within a lending market ecosystem on the EVM-compatible blockchain.

## Contract Details

- **Version**: Solidity 0.8.20
- **License**: MIT
- **Author**: CloudWalk Inc. (See [CloudWalk](https://cloudwalk.io))

## Events
### CreateCreditLine
```solidity
event CreateCreditLine(address indexed market, uint16 indexed kind, address creditLine);
```
This event is emitted every time a new credit line contract is created by the factory.

#### Parameters:

| Name           | Type          | Description                                            |
|----------------|---------------|--------------------------------------------------------|
| market         | address       | The address of the associated lending market.          |
| kind           | uint16        | An identifier for the kind of credit line.             |
| creditLine     | address       | The address of the newly created credit line contract. |

## Functions

### createCreditLine
```solidity
function createCreditLine(address market, address lender, uint16 kind, bytes calldata data) external returns (address);
```

This function is responsible for creating a new credit line contract.

#### Parameters:

| Name         | Type    | Description                                                                                           |
|--------------|---------|-------------------------------------------------------------------------------------------------------|
| market       | address | The address of the associated lending market.                                                         |
| lender       | address | The address of the lender providing the financial backing for the credit line.                        |
| kind         | address | An integer representing the kind (version) of the credit line to be created.                          |
| data         | address | A bytes array containing the initialization parameters or configuration data for the new credit line. |

### Returns:

The contract `address` of the newly created credit line.

### supportedKinds
```solidity
function supportedKinds() external view returns (uint16[] memory);
```

Retrieves the list of supported credit line types

#### Returns:

An `uint16` array of supported credit lines types.

### Usage
The ICreditLineFactory interface allows a lending market platform to abstract the creation of different types of credit lines into a single point of interaction. When a lender wants to create a new credit line, they interact with the factory, specifying the market, their address, the type of credit line, and any necessary configuration data. The factory then deploys a new smart contract with the specified parameters and returns the address of this new contract.

By utilizing a factory pattern and this interface, the platform can easily introduce new types of credit lines or update the logic for existing ones without disrupting the entire system or needing to migrate all existing contracts to a new architecture.
