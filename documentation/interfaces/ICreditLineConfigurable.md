# Overview

The `ICreditLineConfigurable` interface is a part of a CapybaraFinance system and it specifies a set of functionalities for configurable credit lines, including setting parameters for managing different loans and borrowers configurations.

## Contract Details

- **Version**: Solidity 0.8.20
- **License**: MIT
- **Author**: CloudWalk Inc. (See [CloudWalk](https://cloudwalk.io))

## Structs

### CreditLineConfig
```solidity
struct CreditLineConfig {
    uint256 minBorrowAmount;
    uint256 maxBorrowAmount;
    uint256 periodInSeconds;
    uint256 durationInPeriods;
    uint256 addonPeriodCostRate;
    uint256 addonFixedCostRate;
}
```

Defines the general configuration for a credit line with the following parameters:

| Name                | Type    | Description                                                  |
|---------------------|---------|--------------------------------------------------------------|
| minBorrowAmount     | uint256 | The minimum amount that can be borrowed.                     |
| maxBorrowAmount     | uint256 | The maximum amount that can be borrowed.                     |
| periodInSeconds     | uint256 | The duration of one loan period in seconds.                  |
| durationInPeriods   | uint256 | The total loan duration measured in loan periods.            |
| addonPeriodCostRate | uint256 | The cost rate for additional payments calculated per period. |
| addonFixedCostRate  | uint256 | The fixed cost rate for additional payments.                 |

### BorrowerConfig
```solidity
struct BorrowerConfig {
    uint256 minBorrowAmount;
    uint256 maxBorrowAmount;
    uint256 expiration;
    uint256 interestRatePrimary;
    uint256 interestRateSecondary;
    address addonRecipient;
    uint256 addonAmount;
    Interest.Formula interestFormula;
    BorrowPolicy policy;
}
```

Defines a borrower-specific configuration with parameters:

| Name                  | Type             | Description                                             |
|-----------------------|------------------|---------------------------------------------------------|
| minBorrowAmount       | uint256          | The minimum borrowable amount for the borrower.         |
| maxBorrowAmount       | uint256          | The maximum borrowable amount for the borrower.         |
| expiration            | uint256          | The expiration date of the borrower's configuration.    |
| interestRatePrimary   | uint256          | The primary interest rate applied to the loan.          |
| interestRateSecondary | uint256          | The secondary interest rate.                            |
| addonRecipient        | address          | The recipient address for additional payments and fees. |
| addonAmount           | uint256          | The specified amount for additional payments and fees.  |
| interestFormula       | Interest.Formula | The formula used to calculate interest on the loan.     |
| policy                | BorrowPolicy     | The borrowing policy as per BorrowPolicy enumeration.   |

## Enums

### BorrowPolicy
```solidity
enum BorrowPolicy {
    Reset,
    Decrease,
    Keep
}
```

Specifies the policy to be applied to a borrower's allowance:
<ul>
<li> Reset: Resets the borrow allowance after the first loan is taken.
<li> Decrease: Decreases the borrow allowance after each loan is taken.
<li> Keep: Leaves the borrow allowance unchanged.
</ul>

## Events

### AdminConfigured

```solidity
event AdminConfigured(address indexed admin, bool adminStatus);
```

Emitted when the admin status of an account is configured.

#### Parameters:

| Name        | Type      | Description                                                 |
|-------------|-----------|-------------------------------------------------------------|
| admin       | address   | The address of the admin account.                           |
| adminStatus | bool      | Boolean indicating whether the account is set as an admin.  |

### TokenConfigured
```solidity
event TokenConfigured(address creditLine, address indexed token);
```

Emitted when the token associated with the credit line is configured.

#### Parameters:

| Name              | Type      | Description                     |
|-------------------|-----------|---------------------------------|
| creditLine        | address   | The address of the credit line. |
| token             | address   | The address of the token.       |

### CreditLineConfigurationUpdated

```solidity
event CreditLineConfigurationUpdated(address indexed creditLine, CreditLineConfig config);
```

Emitted when the credit line's configuration is updated.

#### Parameters:

| Name              | Type             | Description                            |
|-------------------|------------------|----------------------------------------|
| creditLine        | address          | The address of the credit line.        |
| config            | CreditLineConfig | The updated credit line configuration. |


## BorrowerConfigurationUpdated

```solidity
event BorrowerConfigurationUpdated(address indexed creditLine, address indexed borrower, BorrowerConfig config);
```

Emitted when the configuration of a borrower is updated.

#### Parameters

| Name       | Type           | Description                         |
|------------|----------------|-------------------------------------|
| creditLine | address        | The address of the credit line.     |
| borrower   | address        | The address of the borrower.        |
| config     | BorrowerConfig | The updated borrower configuration. |


## Functions

#### configureToken
```solidity
function configureToken(address token) external;
```

Configures the token associated with the credit line for lending operations.

#### Parameters:

| Name    | Type      | Description                                                      |
|---------|-----------|------------------------------------------------------------------|
| token   | address   | The address of the token to be associated with the credit line.  |

#### configureAdmin

```solidity
function configureAdmin(address admin, bool adminStatus) external;
```


Configures an account's admin status.

#### Parameters:

| Name            | Type    | Description                                        |
|-----------------|---------|----------------------------------------------------|
| admin           | address | The address of the admin.                          |
| adminStatus     | bool    | A boolean indicating the admin status to be set.   |

### configureCreditLine

```solidity
function configureCreditLine(CreditLineConfig memory config) external;
```

Updates the configuration of the credit line.

#### Parameters:

| Name       | Type                 | Description                                     |
|------------|----------------------|-------------------------------------------------|
| config     | CreditLineConfig     | The struct with the new configuration settings. |


### configureBorrower
```solidity
function configureBorrower(address borrower, BorrowerConfig memory config) external;
```
Configures a specific borrower with a set of parameters.

#### Parameters:

| Name         | Type             | Description                                     |
|--------------|------------------|-------------------------------------------------|
| borrower     | address          | The address of the borrower.                    |
| config       | BorrowerConfig   | The struct with the new configuration settings. |

### configureBorrowers

```solidity
function configureBorrowers(address[] memory borrowers, BorrowerConfig[] memory configs) external;
```
Configures multiple borrowers in a single transaction.

#### Parameters:

| Name      | Type             | Description                                         |
|-----------|------------------|-----------------------------------------------------|
| borrowers | address          | An array of borrower addresses.                     |
| configs   | BorrowerConfig   | An array of structs corresponding to each borrower. |


### getBorrowerConfiguration
```solidity
function getBorrowerConfiguration(address borrower) external view returns (BorrowerConfig memory);

```
Retrieves the current configuration of a borrower.

#### Parameters:

| Name           | Type    | Description                  |
|----------------|---------|------------------------------|
| borrower       | address | The address of the borrower. |

borrower: The address of the borrower.
#### Returns:

A `BorrowerConfig` struct containing the borrower's current configuration.

### creditLineConfiguration

```solidity
function creditLineConfiguration() external view returns (CreditLineConfig memory);
```
Retrieves the current configuration of the credit line.

#### Returns:

A `CreditLineConfig` struct containing the credit line's current configuration.

#### isAdmin
```solidity
function isAdmin(address account) external view returns (bool);
```
Checks if a given account is an admin.

#### Parameters:

| Name            | Type    | Description                                 |
|-----------------|---------|---------------------------------------------|
| account         | address | The address of the account to be checked.   |

#### Returns:

A `boolean` indicating whether the account is an admin.