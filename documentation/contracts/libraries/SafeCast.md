# Overview
The SafeCat library defines safe casting functions from uint256 to needed sizes.

## Contract Details

- **Version**: Solidity 0.8.23
- **License**: MIT
- **Author**: CloudWalk Inc. (See [CloudWalk](https://cloudwalk.io))


## Errors

### SafeCastOverflowedUintDowncast

```solidity
error SafeCastOverflowedUintDowncast(uint8 bits, uint256 value);
```
Thrown if value doesn't fit in an uint of `bits` size.

## Functions

### toUint64

```solidity
function toUint64(uint256 value) internal pure returns (uint64);
```
Returns the downcasted uint64 from uint256, reverting on overflow (when the input is greater than largest uint64).

### toUint32

```solidity
function toUint32(uint256 value) internal pure returns (uint32);
```
Returns the downcasted uint32 from uint256, reverting on overflow (when the input is greater than largest uint32).