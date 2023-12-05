# Overview
The Loan library developed by CloudWalk Inc. encapsulates types and enumerations relevant to managing loan state and terms within a blockchain context. It provides standardized definitions for the status of loans, loan terms for new agreements, and state for tracking the progress and changes to loans over time.

## Contract Details

- **Version**: Solidity 0.8.20
- **License**: MIT
- **Author**: CloudWalk Inc. (See [CloudWalk](https://cloudwalk.io))

## Types
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

### Terms
```solidity
struct Terms {
    address token;
    uint256 periodInSeconds;
    uint256 durationInPeriods;
    uint256 interestRateFactor;
    uint256 interestRatePrimary;
    uint256 interestRateSecondary;
    Interest.Formula interestFormula;
    address addonRecipient;
    uint256 addonAmount;
}
```
This struct defines the agreement parameters for a loan, including token type, loan period, duration, interest rates, interest calculation formula, and details about additional charges or payments.

#### Parameters

| Name                  | Type             | Description                                                                                                                                                                                    |
|-----------------------|------------------|------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| token                 | address          | The ERC-20 token address that will be used for the loan. This sets which cryptocurrency is involved in the lending agreement.                                                                  |
| periodInSeconds       | uint256          | The length of each loan period in seconds. It's a measure of time upon which interest calculation and loan repayments are based.                                                               |
| durationInPeriods     | uint256          | The total number of periods that the loan will last, defining the full term over which the loan is expected to be repaid.                                                                      |
| interestRateFactor    | uint256          | A multiplier used to provide precision in interest calculations. Typically, this would be a large number (like 10^18) to allow for fractional rates.                                           |
| interestRatePrimary   | uint256          | The primary interest rate applied to the loan. This is the main rate used for calculating the interest on the principal amount.                                                                |
| interestRateSecondary | uint256          | An additional interest rate that may apply under certain conditions defined by the loan terms.                                                                                                 |
| interestFormula       | Interest.Formula | The method by which interest is calculated (e.g., simple or compound) as defined in the Interest library.                                                                                      |
| addonRecipient        | address          | The recipient of additional payments or fees. This address may receive funds related to penalties, service charges, or other loan-related fees outside of the principal and interest payments. |
| addonAmount           | uint256          | The amount of additional payments or fees that may be due from the borrower, separate from the loan's principal and interest.                                                                  |

### State
```solidity
struct State {
    address token;
    address borrower;
    uint256 periodInSeconds;
    uint256 durationInPeriods;
    uint256 interestRateFactor;
    uint256 interestRatePrimary;
    uint256 interestRateSecondary;
    Interest.Formula interestFormula;
    uint256 initialBorrowAmount;
    uint256 trackedBorrowAmount;
    uint256 startDate;
    uint256 trackDate;
    uint256 freezeDate;
}
```

The State struct holds the current state of a loan, including the amount borrowed, the amount repaid, start dates, last repayment dates, and freeze dates.

#### Parameters

| Name                  | Type             | Description                                                                                                                                                |
|-----------------------|------------------|------------------------------------------------------------------------------------------------------------------------------------------------------------|
| token                 | address          | Duplicates the token parameter from the Terms struct for internal tracking within the loan's state.                                                        |
| borrower              | address          | The address of the loan borrower                                                                                                                           |
| periodInSeconds       | uint256          | Duplicates the periodInSeconds parameter from the Terms struct for internal tracking.                                                                      |
| durationInPeriods     | uint256          | Duplicates the durationInPeriods parameter from the Terms struct for internal state purposes.                                                              |
| interestRateFactor    | uint256          | Duplicates the interestRateFactor from the Terms struct for consistent interest calculation during the loan's life.                                        |
| interestRatePrimary   | uint256          | Reflects the primary interest rate of the loan that is currently being applied to the principal amount.                                                    |
| interestRateSecondary | uint256          | Indicates the secondary rate in use, which may be applied based on the loan's progression or specific triggers within the loan agreement.                  |
| interestFormula       | Interest.Formula | Matches the interestFormula from the Terms struct, denoting which interest calculation method is in use.                                                   |
| initialBorrowAmount   | uint256          | The original amount of capital borrowed at the start of the loan.                                                                                          |
| trackedBorrowAmount   | uint256          | The current amount owed by the borrower, which may change over time as payments are made or additional interest is accrued.                                |
| startDate             | uint256          | The timestamp when the loan began. This is critical for determining periods for interest accrual and repayment schedules.                                  |
| trackDate             | uint256          | The timestamp of the last update to the loan amount, which could be due to a repayment or interest capitalization event.                                   |
| freezeDate            | uint256          | he timestamp when the loan was frozen, if applicable. While frozen, the typical loan operations like accruing interest or making repayments may be halted. |
