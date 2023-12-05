# Overview
CreditLineFactory is a Solidity contract designed to create new instances of credit lines for a lending platform. It leverages an inheritance structure that includes Ownable for access control and implements the ICreditLineFactory interface for credit line creation functionality.

## Contract Details

- **Version**: Solidity 0.8.20
- **License**: MIT
- **Author**: CloudWalk Inc. (See [CloudWalk](https://cloudwalk.io))
- **Interface**: [ICreditLineFactory](./interfaces/ICreditLineFactory.md)

## Errors
### UnsupportedKind
```solidity
error UnsupportedKind(uint16 kind);
```
Emitted when an attempt is made to create a credit line of a kind that is not supported by the factory.


## Initializer
CreditLineFactory
```solidity
initialize(address registry_);
```
Initializes the contract by setting the registry address and assigning ownership.

#### Parameters:

| Name      | Type     | Description                                     |
|-----------|----------|-------------------------------------------------|
| registry_ | address  | The address of the associated lending registry. |

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

### createCreditLine
```solidity
function createCreditLine(address market, address lender, uint16 kind, bytes calldata data) external onlyOwner returns (address creditLine);
```
Creates a new credit line contract with specified parameters. It checks if the kind of credit line is supported and, if so, proceeds with creation; otherwise, it reverts.

#### Restrictions:
- Is reverted if caller is not the owner

#### Parameters:

| Name   | Type    | Description                                                  |
|--------|---------|--------------------------------------------------------------|
| market | address | The address of the market where the credit line is created.  |
| lender | address | The address of the lender for the credit line.               |
| kind   | uint16  | The type identifier for the credit line.                     |
| data   | bytes   | Additional data required for credit line creation.           |
### Returns:

| Name        | Type     | Description                                    |
|-------------|----------|------------------------------------------------|
| creditLine  | address  | The address of the newly created credit line.  |

### supportedKinds
```solidity
function supportedKinds() external view returns (uint16[] memory);
```

Retrieves the list of supported credit line types

#### Returns:

An `uint16` array of supported credit lines types.
