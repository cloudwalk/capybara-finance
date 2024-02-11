# Protocol`s event

### Click event name to see in-contract declaration

### [RegisterCreditLine](../contracts/interfaces/core/ILendingMarket.md)
```solidity
event RegisterCreditLine(address indexed lender, address indexed creditLine);
```
Emitted when a credit line is registered.

### [RegisterLiquidityPool](../contracts/interfaces/core/ILendingMarket.md)
```solidity
event RegisterLiquidityPool(address indexed lender, address indexed liquidityPool);
```
Emitted when a liquidity pool is registered.

### [TakeLoan](../contracts/interfaces/core/ILendingMarket.md)
```solidity
event TakeLoan(uint256 indexed loanId, address indexed borrower, uint256 borrowAmount);
```
Emitted when a loan is taken.

### [RepayLoan](../contracts/interfaces/core/ILendingMarket.md)
```solidity
event RepayLoan(uint256 indexed loanId, address indexed repayer, address indexed borrower, uint256 repayAmount, uint256 remainingBalance);
```
Emitted when a loan is repaid.

### [FreezeLoan](../contracts/interfaces/core/ILendingMarket.md)
```solidity
event FreezeLoan(uint256 indexed loanId, uint256 freezeDate);
```
Emitted when the loan is frozen.

### [UnfreezeLoan](../contracts/interfaces/core/ILendingMarket.md)
```solidity
event UnfreezeLoan(uint256 indexed loanId, uint256 unfreezeDate);
```
Emitted when the loan is unfrozen.

### [UpdateLoanDuration](../contracts/interfaces/core/ILendingMarket.md)
```solidity
event UpdateLoanDuration(uint256 indexed loanId, uint256 indexed newDuration, uint256 indexed oldDuration);
```
Emitted when the duration of the loan is updated.

### [UpdateLoanMoratorium](../contracts/interfaces/core/ILendingMarket.md)
```solidity
event UpdateLoanMoratorium(uint256 indexed loanId, uint256 indexed newMoratorium, uint256 indexed oldMoratorium);
```
Emitted when the moratorium of the loan is updated.

### [UpdateLoanInterestPrimary](../contracts/interfaces/core/ILendingMarket.md)
```solidity
event UpdateLoanInterestPrimary(uint256 indexed loanId, uint256 indexed newInterestRate, uint256 indexed oldInterestRate);
```
Emitted when the primary interest rate of the loan is updated.

### [UpdateLoanInterestSecondary](../contracts/interfaces/core/ILendingMarket.md)
```solidity
event UpdateLoanInterestSecondary(uint256 indexed loanId, uint256 indexed newInterestRate, uint256 indexed oldInterestRate);
```
Emitted when the secondary interest rate of the loan is updated.

### [UpdateCreditLineLender](../contracts/interfaces/core/ILendingMarket.md)
```solidity
event UpdateCreditLineLender(address indexed creditLine, address indexed newLender, address indexed oldLender);
```
Emitted when the lender of the credit line is updated.

### [SetRegistry](../contracts/interfaces/core/ILendingMarket.md)
```solidity
event SetRegistry(address indexed oldRegistry, address indexed newRegistry);
```
Emitted when the registry contract is updated.

### [CreditLineCreated](../contracts/interfaces/core/ICreditLine.md)
```solidity
event CreditLineCreated(address indexed lender, address creditLine);
```
Emitted when a new credit line is created.

### [LiquidityPoolCreated](../contracts/interfaces/core/ICreditLine.md)
```solidity
event LiquidityPoolCreated(address indexed lender, address liquidityPool);
```
Emitted when a new liquidity pool is created.

### [ConfigureAdmin](../contracts/interfaces/ICreditLineConfigurable.md)

```solidity
event ConfigureAdmin(address indexed admin, bool adminStatus);
```

Emitted when the admin status of an account is configured.

### [ConfigureCreditLine](../contracts/interfaces/ICreditLineConfigurable.md)

```solidity
event ConfigureCreditLine(address indexed creditLine, CreditLineConfig config);
```

Emitted when the credit line's configuration is updated.

## [ConfigureBorrower](../contracts/interfaces/ICreditLineConfigurable.md)

```solidity
event ConfigureBorrower(address indexed creditLine, address indexed borrower, BorrowerConfig config);
```

Emitted when the configuration of a borrower is updated.

### [CreateCreditLine](../contracts/interfaces/ICreditLineFactory.md)
```solidity
event CreateCreditLine(
    address indexed market, address indexed lender, address indexed token, uint16 kind, address creditLine
);
```
This event is emitted every time a new credit line contract is created by the factory.

### [Deposit](../contracts/interfaces/ILiquidityPoolAccountable.md)
```solidity
event Deposit(address indexed creditLine, uint256 amount);
```
Emitted when tokens are deposited into the liquidity pool.

### [Withdraw](../contracts/interfaces/ILiquidityPoolAccountable.md)

```solidity
event Withdraw(address indexed tokenSource, uint256 amount);
```
Emitted when tokens are withdrawn from the liquidity pool.

### [ConfigureAdmin](../contracts/interfaces/ILiquidityPoolAccountable.md)

```solidity
event ConfigureAdmin(address indexed admin, bool adminStatus);
```
Emitted when admin is configured.

### [AutoRepay](../contracts/interfaces/ILiquidityPoolAccountable.md)

```solidity
event AutoRepay(uint256 numberOfLoans);
```
Emitted when loans auto repayment is forced.

### [CreateLiquidityPool](../contracts/interfaces/ILiquidityPoolFactory.md)
```solidity
event CreateLiquidityPool(address indexed market, address indexed lender, uint16 indexed kind, address liquidityPool);
```
This event is emitted every time a new liquidity pool contract is created by the factory.

### [SetCreditLineFactory](../contracts/LendingRegistry.md)
```solidity
event SetCreditLineFactory(address newFactory, address oldFactory);
```
Emitted when the credit line factory is set.

### [SetLiquidityPoolFactory](../contracts/LendingRegistry.md)
```solidity
event SetLiquidityPoolFactory(address newFactory, address oldFactory);
```
Emitted when the liquidity pool factory is set.


