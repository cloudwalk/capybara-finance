# Overview
CreditLineConfigurable is a Solidity contract for managing credit lines in a lending platform. It allows configurable terms for borrowing, administrative controls, and loan issuance based on predefined policies.

## Contract Details

- **Version**: Solidity 0.8.20
- **License**: MIT
- **Author**: CloudWalk Inc. (See [CloudWalk](https://cloudwalk.io))
- **Interface**: [ICreditLineConfigurable](./interfaces/ICreditLineConfigurable.md)

## Constants
| Name                  | Type    | Description                                                         |
|-----------------------|---------|---------------------------------------------------------------------|
| INTEREST_RATE_FACTOR  | uint256 | The rate factor used for interest rate calculations, set to 10^6.   |

## Storage Variables

| Name       | Type                                | Description                                                 |
|------------|-------------------------------------|-------------------------------------------------------------|
| _market    | address                             | The address of the associated lending market.               |
| _token     | address                             | The address of the associated token.                        |
| _config    | CreditLineConfig                    | The configuration of the credit line terms.                 |
| _admins    | mapping(address => bool)            | Stores admin status of addresses.                           |
| _borrowers | mapping(address => BorrowerConfig)  | Maps borrower addresses to their respective configurations. |

## Errors
### InvalidCreditLineConfiguration
```solidity
error InvalidCreditLineConfiguration(string message);
```
Occurs when attempting to set a configuration that does not meet system requirements or constraints.


### BorrowerConfigurationExpired
```solidity
error BorrowerConfigurationExpired();
```
Indicates that the action cannot proceed because the borrower's configuration has expired.



### UnsupportedBorrowPolicy
```solidity
error UnsupportedBorrowPolicy();
```
Triggered when a borrow policy being utilized is not supported by the system.


### ArrayLengthMismatch
```solidity
error ArrayLengthMismatch();
```
Emitted when the length of two arrays that are expected to match in length do not.


## Modifiers
### onlyMarket
```solidity
modifier onlyMarket();
```

Ensures that the function can only be called by the current market address configured in the contract.


### onlyAdmin
```solidity
modifier onlyAdmin();
```
Allows restricted access to functions for accounts marked as admins within the contract.

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


### configureToken
```solidity
function configureToken(address token_) external onlyOwner;
```
Sets the token to be used in the credit line contracts.

#### Restrictions:
- Is reverted if caller is not the owner

#### Parameters:

| Name   | Type     | Description                                |
|--------|----------|--------------------------------------------|
| token_ | address	 | The address of the token to be configured. |

### configureAdmin
```solidity
function configureAdmin(address admin, bool status) external onlyOwner;
```
Updates the administrative status of an address, enabling or disabling admin functions for that address.

#### Restrictions:
- Is reverted if caller is not the owner

#### Parameters:

| Name    | Type    | Description                                 |
|---------|---------|---------------------------------------------|
| admin   | address | The address for which to set admin status.  |
| status  | bool    | The boolean flag for admin status.          |

### configureCreditLine
```solidity
function configureCreditLine(CreditLineConfig calldata config) external onlyOwner;
```
Updates the terms of credit line loans configuration.

#### Restrictions:
- Is reverted if caller is not the owner

#### Parameters

| Name    | Type              | Description                               |
|---------|-------------------|-------------------------------------------|
| config  | CreditLineConfig  | The new terms for the credit line to set. |


### configureBorrower
```solidity
function configureBorrower(address borrower, BorrowerConfig calldata config) external whenNotPaused onlyAdmin;
```
Allows setting the borrowing configuration for an individual borrower.

#### Restrictions:
- Is reverted if caller is not the admin
- Is reverted if contract is paused

#### Parameters:

| Name      | Type           | Description                                 |
|-----------|----------------|---------------------------------------------|
| borrower  | address        | The address of the borrower to configure.   |
| config    | BorrowerConfig | The configuration details for the borrower. |

### configureBorrowers

```solidity
function configureBorrowers(address[] memory borrowers, BorrowerConfig[] memory configs) external whenNotPaused onlyAdmin;
```
Configures multiple borrowers in a single transaction.

#### Restrictions:
- Is reverted if caller is not the admin
- Is reverted if contract is paused

#### Parameters:

| Name      | Type             | Description                                         |
|-----------|------------------|-----------------------------------------------------|
| borrowers | address          | An array of borrower addresses.                     |
| configs   | BorrowerConfig   | An array of structs corresponding to each borrower. |

### onLoanTaken

```solidity
function onLoanTaken(address borrower, uint256 amount) external whenNotPaused onlyMarket returns (Loan.Terms memory terms)
```
Called when a loan is taken out by a borrower. It determines the loan terms based on the borrower's configuration and updates the borrower's credit policy accordingly.

#### Restrictions:
- Is reverted if caller is not the market
- Is reverted if contract is paused

#### Parameters:

| Name      | Type     | Description                                 |
|-----------|----------|---------------------------------------------|
| borrower  | address  | The address of the borrower taking a loan.  |
| amount    | uint256  | The amount of the loan being taken.         |

#### Returns:
| Type        | Description             |
|-------------|-------------------------|
| Loan.Terms  | The terms of the loan.  |

### determineLoanTerms
```solidity
function determineLoanTerms(address borrower, uint256 amount) public view returns (Loan.Terms memory terms)
```
Determines the terms of the loan based on the borrower's configuration and the credit line's configuration.

#### Parameters:

| Name      | Type     | Description                            |
|-----------|----------|----------------------------------------|
| borrower  | address  | The address of the borrower.           |
| amount    | uint256  | The amount of credit being requested.  |

#### Returns:
| Type        | Description                                         |
|-------------|-----------------------------------------------------|
| Loan.Terms  | The terms of the loan based on the configurations.  |

### calculateAddonAmount
```solidity
function calculateAddonAmount(uint256 amount) public view returns (uint256);
```
Calculates the additional payment amount required according to the configured credit line terms.

#### Parameters:

| Name    | Type     | Description                               |
|---------|----------|-------------------------------------------|
| amount	 | uint256	 | The initial principal amount of the loan. |

### market
```solidity
function market() external view returns (address);
```
Returns the address of the market associated with this credit line.


### lender
```solidity
function lender() external view returns (address);
```
Returns the address of the lender which is typically the owner of the credit line contract.

### token
```solidity
function token() external view returns (address);
```
Gets the address of the token configured for the credit line.


### kind
```solidity
function kind() external pure returns (uint16);
```
Provides the type identifier for the credit line, which can be used to distinguish between different credit line kinds in the system.

### getBorrowerConfiguration
```solidity
function getBorrowerConfiguration(address borrower) external view returns (BorrowerConfig memory);
```
Retrieves the current configuration for a specified borrower.

#### Parameters:

| Name      | Type     | Description                           |
|-----------|----------|---------------------------------------|
| borrower	 | address  | The address of the borrower to query. |


### isAdmin
```solidity
function isAdmin(address account) external view returns (bool);
```
Checks if the provided address is marked as an admin in the credit line system.

#### Parameters:

| Name     | Type    | Description                             |
|----------|---------|-----------------------------------------|
| account  | address | The address to check for admin status.  |