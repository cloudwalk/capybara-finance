# Overview
The Interest library by CloudWalk Inc. provides an enumeration to distinguish between different interest calculation formulas in financial operations, typically used within smart contracts that deal with lending and borrowing. By defining clear interest calculation methods, this library facilitates the implementation of various financial models.

## Contract Details

- **Version**: Solidity 0.8.23
- **License**: MIT
- **Author**: CloudWalk Inc. (See [CloudWalk](https://cloudwalk.io))

## Types

### Formula
```solidity
enum Formula {
    Simple,  // 0
    Compound // 1
}
```
Defines the types of interest calculation formulas available:
<ul>
<li >Simple (0):
The Simple interest calculation is a linear method where the interest is calculated only on the principal amount, i.e., the original amount of money deposited or borrowed. It does not account for compounding over time.

<li> Compound (1):
The Compound interest calculation involves re-investing each period's interest back into the principal amount. Consequently, interest in the next period is then calculated on the principal amount, which includes the previous period's interest. This method can lead to exponential growth of the principal amount over time as the interest itself earns interest.
</ul>

## Usage
The Interest library's Formula enumeration is being used in smart contracts for specifying how interest should be calculated for a particular loan or investment.