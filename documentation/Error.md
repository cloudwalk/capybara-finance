# Overview
The Error library by CloudWalk Inc. Defines a set of standard errors that can be used across smart contracts to provide clear and concise error handling.

## Contract Details

- **Version**: Solidity 0.8.20
- **License**: MIT
- **Author**: CloudWalk Inc. (See [CloudWalk](https://cloudwalk.io))

## Errors
### Unauthorized
```solidity
error Unauthorized();
```
Indicates that the operation failed because the caller does not have the required permissions. Typically used in modifier checks where the caller must be an admin or hold a specific role.

### InvalidAddress
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
This error is emitted when there is an attempt to reconfigure something that has already been set. It prevents overwriting configurations that are meant to be immutable or have been finalized.

### NotImplemented
```solidity
error NotImplemented();
```
This is used to indicate that a called function or feature is not implemented. It can be used in stub functions or during development to signify that functionality is pending.

