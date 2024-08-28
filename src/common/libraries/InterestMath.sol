// SPDX-License-Identifier: MIT

pragma solidity 0.8.24;

import { ABDKMath64x64 } from "./ABDKMath64x64.sol";

/// @title InterestMath library
/// @author CloudWalk Inc. (See https://cloudwalk.io)
/// @dev Defines interest calculation functions.
library InterestMath {
    // -------------------------------------------- //
    //  Functions                                   //
    // -------------------------------------------- //

    /// @dev Calculates the outstanding balance of a loan using the compound interest formula.
    /// @param originalBalance The original balance of the loan.
    /// @param numberOfPeriods The number of periods since the loan was taken.
    /// @param interestRate The interest rate applied to the loan.
    /// @param interestRateFactor The interest rate factor.
    /// @return outstandingBalance The outstanding balance of the loan.
    function calculateOutstandingBalance(
        uint256 originalBalance,
        uint256 numberOfPeriods,
        uint256 interestRate,
        uint256 interestRateFactor
    ) internal pure returns (uint256 outstandingBalance) {
        // The equivalent formula: round(originalBalance * (1 + interestRate / interestRateFactor)^numberOfPeriods)
        // Where division operator `/` and power operator `^` take into account the fractional part and
        // the `round()` function returns an integer rounded according to standard mathematical rules.
        int128 onePlusRateValue = ABDKMath64x64.divu(interestRateFactor + interestRate, interestRateFactor);
        int128 powValue = ABDKMath64x64.pow(onePlusRateValue, numberOfPeriods);
        uint256 unroundedResult = uint256(uint128(ABDKMath64x64.mul(powValue, int128(int256(originalBalance << 64)))));
        outstandingBalance = unroundedResult >> 64;
        if ((unroundedResult - (outstandingBalance << 64)) >= (1 << 63)) {
            outstandingBalance += 1;
        }
        return outstandingBalance;
    }

    function calculateOutstandingBalance2(
        uint256 originalBalance,
        uint256 numberOfPeriods,
        uint256 interestRate,
        uint256 interestRateFactor
    ) internal view returns (uint256) {
        int128 interestRateFactor128 = int128(int256(interestRateFactor << 64));
        int128 originalBalance128 = int128 (int256 (originalBalance << 64));
        int128 R = int128(int256(interestRate << 64));

        int128 X = ABDKMath64x64.pow(
            ABDKMath64x64.divu(
                uint64(uint128(ABDKMath64x64.add(R, interestRateFactor128) >> 64)),
                interestRateFactor
            ),
            numberOfPeriods);

        uint64 numerator = uint64 (uint128 (ABDKMath64x64.mul(ABDKMath64x64.mul(originalBalance128, R), X) >> 64));
        uint64 denominator = uint64 (uint128 ((ABDKMath64x64.mul(interestRateFactor128, (X - (1 << 64)))) >> 64));
        int128 res = ABDKMath64x64.divu(numerator, denominator);
        uint256 outstandingBalance = uint64 (uint128 (res >> 64));

        return outstandingBalance;
    }

    function calculateOutstandingBalance3(
        uint256 originalBalance,
        uint256 numberOfPeriods,
        uint256 interestRate,
        uint256 interestRateFactor
    ) internal view returns (uint256) {
        int128 interestRateFactor128 = ABDKMath64x64.fromUInt(interestRateFactor);

        int128 R = ABDKMath64x64.fromUInt(interestRate);
        int128 X = ABDKMath64x64.pow(
            ABDKMath64x64.divu(
                ABDKMath64x64.toUInt(
                    ABDKMath64x64.add(R, interestRateFactor128)
                ),
                ABDKMath64x64.toUInt(interestRateFactor128)
            ),
            numberOfPeriods);

        int128 numerator = ABDKMath64x64.mul(ABDKMath64x64.mul(ABDKMath64x64.fromUInt(originalBalance), R), X);
        int128 denominator = ABDKMath64x64.mul(interestRateFactor128, (X - (1 << 64)));
        int128 res = ABDKMath64x64.divu(ABDKMath64x64.toUInt(numerator), ABDKMath64x64.toUInt(denominator));
        uint256 outstandingBalance = ABDKMath64x64.toUInt(res);

        return outstandingBalance;
    }

    function calculateOutstandingBalance4(
        uint256 originalBalance,
        uint256 numberOfPeriods,
        uint256 interestRate,
        uint256 interestRateFactor
    ) internal view returns (uint256) {
        // The equivalent formula: floor(originalBalance * x * interestRate * 2^64 / ((x-1) * 2^64 )
        // Where:
        //   a. x = (1 + interestRate / interestRateFactor)^numberOfPeriods;
        //   b. division operator `/` and power operator `^` take into account the fractional part;
        //   c. the `floor()` function returns an integer with the dropped fractional part
        int128 onePlusRateValue = ABDKMath64x64.divu(interestRateFactor + interestRate, interestRateFactor);
        int128 x = ABDKMath64x64.pow(onePlusRateValue, numberOfPeriods);
        int128 xMinus1 = x - int128(int256(1 << 64));
        uint256 X = uint256(int256(x));
        uint256 XMinus1 = uint256(int256(xMinus1));
        uint256 result = originalBalance * interestRate * X / (interestRateFactor * XMinus1);
        return result;
    }
}
