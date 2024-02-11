# Protocol`s custom errors

### Unauthorized
```solidity
error Unauthorized();
```
Indicates that the operation failed because the caller does not have the required permissions. Typically used in modifier checks where the caller must be an admin or hold a specific role.

### ZeroAddress
```solidity
error ZeroAddress();
```
Thrown when a function receives zero address as an address parameter.

### InvalidAmount
```solidity
error InvalidAmount();
```
Signifies that a function was called with an amount that is not acceptable for the operation. This could be due to the amount being zero when it needs to be positive, or outside an allowed range, for instance.

### AlreadyConfigured
```solidity
error AlreadyConfigured();
```
This error is thrown when array lengths do not match each other. It prevents panic errors while accessing out of bonds array indexes.

### ArrayLengthMismatch
```solidity
error AlreadyConfigured();
```
This error is emitted when there is an attempt to reconfigure something that has already been set. It prevents overwriting configurations that are meant to be immutable or have been finalized.

### NotImplemented
```solidity
error NotImplemented();
```
This is used to indicate that a called function or feature is not implemented. It can be used in stub functions or during development to signify that functionality is pending.

### InterestFormulaNotImplemented
```solidity
error InterestFormulaNotImplemented();
```
This error is thrown when an attempt is made to calculate the outstanding balance using an interest formula that is not supported or implemented by the library.

### SafeCastOverflowedUintDowncast

```solidity
error SafeCastOverflowedUintDowncast(uint8 bits, uint256 value);
```
Thrown if value doesn't fit in an uint of `bits` size.

### InvalidCreditLineConfiguration
```solidity
error InvalidCreditLineConfiguration();
```
Occurs when attempting to set a configuration that does not meet system requirements or constraints.

### InvalidBorrowerConfiguration
```solidity
error InvalidBorrowerConfiguration();
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

### UnsupportedKind
```solidity
error UnsupportedKind(uint16 kind);
```
Emitted when an attempt is made to create a credit line or liquidity pool of a kind that is not supported by the factory.

### ZeroBalance

```solidity
error ZeroBalance();
```
Thrown when the token source balance is zero.

### InsufficientBalance
```solidity
error InsufficientBalance();
```
Thrown when the token balance is insufficient to fulfill a request.

### LoanNotExist
```solidity
error LoanNotExist();
```
Occurs when attempting to interact with a loan that does not exist.

### LoanNotFrozen
```solidity
error LoanNotFrozen();
```
Occurs when attempting to interact with a loan that was not frozen.

### LoanAlreadyRepaid
```solidity
error LoanAlreadyRepaid();
```
Occurs when attempting to interact with a loan that was already repaid.

### LoanAlreadyFrozen
```solidity
error LoanAlreadyFrozen();
```
Occurs when attempting to interact with a loan that was already frozen.

### CreditLineNotRegistered
```solidity
error CreditLineNotRegistered();
```
Occurs when attempting to interact with a credit line that is not registered.

### LiquidityPoolNotRegistered
```solidity
error LiquidityPoolNotRegistered();
```
Occurs when attempting to interact with a liquidity pool that is not registered.

### CreditLineAlreadyRegistered
```solidity
error CreditLineAlreadyRegistered();
```
Occurs when attempting to interact with a credit line that was already registered.

### LiquidityPoolAlreadyRegistered
```solidity
error LiquidityPoolAlreadyRegistered();
```
Occurs when attempting to interact with a liquidity pool that was already registered.

### InappropriateInterestRate
```solidity
error InappropriateInterestRate();
```
Occurs when attempting to provide inappropriate interest rate.

### InappropriateLoanDuration
```solidity
error InappropriateLoanDuration();
```
Occurs when attempting to provide inappropriate loan duration.

### InappropriateLoanMoratorium
```solidity
error InappropriateLoanMoratorium();
```
Occurs when attempting to provide inappropriate loan moratorium.

### AutoRepaymentNotAllowed
```solidity
error AutoRepaymentNotAllowed();
```
Thrown when loan auto repayment is not allowed.

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