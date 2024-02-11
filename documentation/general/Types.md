# Protocol`s custom data types

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

### Terms
```solidity
struct Terms {
    address token;
    uint32 periodInSeconds;
    uint32 durationInPeriods;
    uint32 interestRateFactor;
    address addonRecipient;
    uint64 addonAmount;
    uint32 interestRatePrimary;
    uint32 interestRateSecondary;
    bool autoRepayment;
    Interest.Formula interestFormula;
}
```
This struct defines the agreement parameters for a loan, including token type, loan period, duration, interest rates, interest calculation formula, and details about additional charges or payments.

#### Parameters

| Name                  | Type             | Description                                                                                                                                                                                    |
|-----------------------|------------------|------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| token                 | address          | The ERC-20 token address that will be used for the loan. This sets which cryptocurrency is involved in the lending agreement.                                                                  |
| periodInSeconds       | uint32           | The length of each loan period in seconds. It's a measure of time upon which interest calculation and loan repayments are based.                                                               |
| durationInPeriods     | uint32           | The total number of periods that the loan will last, defining the full term over which the loan is expected to be repaid.                                                                      |
| interestRateFactor    | uint32           | A multiplier used to provide precision in interest calculations. Typically, this would be a large number (like 10^18) to allow for fractional rates.                                           |
| addonRecipient        | address          | The recipient of additional payments or fees. This address may receive funds related to penalties, service charges, or other loan-related fees outside of the principal and interest payments. |
| addonAmount           | uint64           | The amount of additional payments or fees that may be due from the borrower, separate from the loan's principal and interest.                                                                  |
| interestRatePrimary   | uint32           | The primary interest rate applied to the loan. This is the main rate used for calculating the interest on the principal amount.                                                                |
| interestRateSecondary | uint32           | An additional interest rate that may apply under certain conditions defined by the loan terms.                                                                                                 |
| autoRepayment         | bool             | The flag for marking if the loan can be repaid automatically.                                                                                                                                  |
| interestFormula       | Interest.Formula | The method by which interest is calculated (e.g., simple or compound) as defined in the Interest library.                                                                                      |

### State
```solidity
struct State {
    address token;
    uint32 interestRatePrimary;
    uint32 interestRateSecondary;
    uint32 interestRateFactor;
    address borrower;
    uint32 startDate;
    uint64 initialBorrowAmount;
    uint32 periodInSeconds;
    uint32 durationInPeriods;
    uint64 trackedBorrowAmount;
    uint32 trackDate;
    uint32 freezeDate;
    bool autoRepayment;
    Interest.Formula interestFormula;
}
```

The State struct holds the current state of a loan, including the amount borrowed, the amount repaid, start dates, last repayment dates, and freeze dates.

#### Parameters

| Name                  | Type             | Description                                                                                                                                                |
|-----------------------|------------------|------------------------------------------------------------------------------------------------------------------------------------------------------------|
| token                 | address          | Duplicates the token parameter from the Terms struct for internal tracking within the loan's state.                                                        |
| interestRatePrimary   | uint32           | Reflects the primary interest rate of the loan that is currently being applied to the principal amount.                                                    |
| interestRateSecondary | uint32           | Indicates the secondary rate in use, which may be applied based on the loan's progression or specific triggers within the loan agreement.                  |
| interestRateFactor    | uint32           | Duplicates the interestRateFactor from the Terms struct for consistent interest calculation during the loan's life.                                        |
| borrower              | address          | The address of the loan borrower                                                                                                                           |
| startDate             | uint32           | The timestamp when the loan began. This is critical for determining periods for interest accrual and repayment schedules.                                  |
| initialBorrowAmount   | uint64           | The original amount of capital borrowed at the start of the loan.                                                                                          |
| periodInSeconds       | uint32           | Duplicates the periodInSeconds parameter from the Terms struct for internal tracking.                                                                      |
| durationInPeriods     | uint32           | Duplicates the durationInPeriods parameter from the Terms struct for internal state purposes.                                                              |
| trackedBorrowAmount   | uint64           | The current amount owed by the borrower, which may change over time as payments are made or additional interest is accrued.                                |
| trackDate             | uint32           | The timestamp of the last update to the loan amount, which could be due to a repayment or interest capitalization event.                                   |
| freezeDate            | uint32           | he timestamp when the loan was frozen, if applicable. While frozen, the typical loan operations like accruing interest or making repayments may be halted. |
| autoRepayment         | bool             | The flag for marking if the loan can be repaid automatically.                                                                                              |
| interestFormula       | Interest.Formula | Matches the interestFormula from the Terms struct, denoting which interest calculation method is in use.                                                   |

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

### Formula
```solidity
enum Formula {
    Simple,  // 0
    Compound // 1
}
```
Defines the types of interest calculation formulas available:
<ul>
<li> Simple: The Simple interest calculation is a linear method where the interest is calculated only on the principal amount, i.e., the original amount of money deposited or borrowed. It does not account for compounding over time.
<li> Compound: The Compound interest calculation involves re-investing each period's interest back into the principal amount. Consequently, interest in the next period is then calculated on the principal amount, which includes the previous period's interest. This method can lead to exponential growth of the principal amount over time as the interest itself earns interest.
</ul>

### Status
```solidity
enum Status {
    Nonexistent, // 0
    Active,      // 1
    Repaid,      // 2
    Frozen,      // 3
    Defaulted,   // 4
    Recovered    // 5
}
```
This enumeration lists all possible states a loan can have, from nonexistence to recovery post-default, allowing smart contracts to keep track of the current condition of a loan.

#### Statuses

| Status        | Description                                                                                                                                                                                                                                                                          |
|---------------|--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| Nonexistent   | This status indicates that a loan record does not exist in the system. It's like a placeholder for a position where a loan might be created in the future or a marker for an invalid or uninitialized loan state.                                                                    |
| Active        | An active status means that the loan is currently ongoing. The borrower has an outstanding debt that needs to be serviced according to the loan terms, and the loan has neither been repaid in full nor defaulted.                                                                   |
| Repaid        | When a loan is marked as repaid, it signifies that the borrower has fulfilled their obligation by paying back the borrowed principal along with any accrued interest, and there is no remaining balance.                                                                             |
| Frozen        | A loan becomes frozen typically due to a special intervention or trigger within the loan agreement, such as a mutual decision to pause repayments or due to an unusual event. While frozen, loan terms like interest accrual or repayments are temporarily suspended.                |
| Defaulted     | This status is used when the borrower fails to make scheduled payments or otherwise violates the loan terms, resulting in a default. It marks a breach of the contract, triggering potential collection actions and other default-related procedures.                                |
| Recovered     | After a loan has defaulted, there may be recovery actions taken by the lender or an associated party to recoup the outstanding debt. If these actions are successful and the funds are substantially recovered, the loan status may be updated to recovered to reflect this change.  |
