# Overview

The `ICreditLineConfigurable` interface is a part of a CapybaraFinance system, and it specifies a set of functionalities for configurable credit lines, including setting parameters for managing different loans and borrowers configurations.

## Contract Details

- **Version**: Solidity 0.8.23
- **License**: MIT
- **Author**: CloudWalk Inc. (See [CloudWalk](https://cloudwalk.io))

## Structs

### CreditLineConfig
```solidity
struct CreditLineConfig {
    uint32 periodInSeconds;
    uint32 interestRateFactor;
    uint32 minInterestRatePrimary;
    uint32 maxInterestRatePrimary;
    uint32 minInterestRateSecondary;
    uint32 maxInterestRateSecondary;
    uint32 addonPeriodCostRate;
    uint32 addonFixedCostRate;
    uint32 minDurationInPeriods;
    uint32 maxDurationInPeriods;
    uint64 minBorrowAmount;
    uint64 maxBorrowAmount;
}
```

Defines the general configuration for a credit line with the following parameters:

| Name                     | Type   | Description                                                   |
|--------------------------|--------|---------------------------------------------------------------|
| periodInSeconds          | uint32 | The duration of one loan period in seconds.                   |
| interestRateFactor       | uint32 | The interest rate factor used for interest calculation        |
| minInterestRatePrimary   | uint32 | The minimum primary interest rate to be applied to the loan   |
| maxInterestRatePrimary   | uint32 | The maximum primary interest rate to be applied to the loan   |
| minInterestRateSecondary | uint32 | The minimum secondary interest rate to be applied to the loan |
| maxInterestRateSecondary | uint32 | The maximum secondary interest rate to be applied to the loan |
| addonPeriodCostRate      | uint32 | The cost rate for additional payments calculated per period.  |
| addonFixedCostRate       | uint32 | The fixed cost rate for additional payments.                  |
| minDurationInPeriods     | uint32 | The maximum duration of the loan determined in periods.       |
| maxDurationInPeriods     | uint32 | The maximum duration of the loan determined in periods.       |
| minBorrowAmount          | uint64 | The minimum amount that can be borrowed.                      |
| maxBorrowAmount          | uint64 | The maximum amount that can be borrowed.                      |


### BorrowerConfig
```solidity
struct BorrowerConfig {
    uint32 durationInPeriods;
    uint32 interestRatePrimary;
    uint32 interestRateSecondary;
    address addonRecipient;
    uint32 expiration;
    uint64 minBorrowAmount;
    uint64 maxBorrowAmount;
    Interest.Formula interestFormula;
    BorrowPolicy policy;
    bool autoRepayment;
}
```

Defines a borrower-specific configuration with parameters:

| Name                  | Type             | Description                                                   |
|-----------------------|------------------|---------------------------------------------------------------|
| durationInPeriods     | uint32           | The total duration of the loan determined in periods.         |
| interestRatePrimary   | uint32           | The primary interest rate applied to the loan.                |
| interestRateSecondary | uint32           | The secondary interest rate.                                  |
| addonRecipient        | address          | The recipient address for additional payments and fees.       |
| expiration            | uint32           | The expiration date of the borrower's configuration.          |
| minBorrowAmount       | uint64           | The minimum borrowable amount for the borrower.               |
| maxBorrowAmount       | uint64           | The maximum borrowable amount for the borrower.               |
| interestFormula       | Interest.Formula | The formula used to calculate interest on the loan.           |
| policy                | BorrowPolicy     | The borrowing policy as per BorrowPolicy enumeration.         |
| autoRepayment         | bool             | The flag for marking if the loan can be repaid automatically. |

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

### ConfigureAdmin

```solidity
event ConfigureAdmin(address indexed admin, bool adminStatus);
```

Emitted when the admin status of an account is configured.

#### Parameters:

| Name        | Type      | Description                                                 |
|-------------|-----------|-------------------------------------------------------------|
| admin       | address   | The address of the admin account.                           |
| adminStatus | bool      | Boolean indicating whether the account is set as an admin.  |

### ConfigureCreditLine

```solidity
event ConfigureCreditLine(address indexed creditLine, CreditLineConfig config);
```

Emitted when the credit line's configuration is updated.

#### Parameters:

| Name              | Type             | Description                            |
|-------------------|------------------|----------------------------------------|
| creditLine        | address          | The address of the credit line.        |
| config            | CreditLineConfig | The updated credit line configuration. |


## ConfigureBorrower

```solidity
event ConfigureBorrower(address indexed creditLine, address indexed borrower, BorrowerConfig config);
```

Emitted when the configuration of a borrower is updated.

#### Parameters

| Name       | Type           | Description                         |
|------------|----------------|-------------------------------------|
| creditLine | address        | The address of the credit line.     |
| borrower   | address        | The address of the borrower.        |
| config     | BorrowerConfig | The updated borrower configuration. |


## Functions

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