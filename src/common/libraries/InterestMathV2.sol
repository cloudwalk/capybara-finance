// SPDX-License-Identifier: MIT

pragma solidity 0.8.24;

import { Interest } from "./Interest.sol";

/// @title InterestMath library
/// @author CloudWalk Inc. (See https://cloudwalk.io)
/// @notice Defines interest calculation functions
library InterestMath {
    // -------------------------------------------- //
    //  Constants                                   //
    // -------------------------------------------- //

    /*
     * Minimum value that a signed 64.64 bit fixed point number may contain.
     */
    int128 private constant MIN_64x64_VALUE = -0x80000000000000000000000000000000;

    /*
     * Maximum value that a signed 64.64 bit fixed point number may contain.
     */
    int128 private constant MAX_64x64_VALUE = 0x7FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF;

    // -------------------------------------------- //
    //  Errors                                      //
    // -------------------------------------------- //

    /// @notice Thrown when the specified interest formula is not implemented
    error InterestFormulaNotImplemented();

    /// @notice Thrown when the zero amount was passed as a denominator
    error ZeroDenominator();

    /// @notice Thrown when an overflow or underflow occurs during mathematical operations
    error MathOperationError();

    // -------------------------------------------- //
    //  Functions                                   //
    // -------------------------------------------- //

    /// @notice Calculates the outstanding balance of a loan
    /// @param originalBalance The original balance of the loan
    /// @param numberOfPeriods The number of periods since the loan was taken
    /// @param interestRate The interest rate applied to the loan
    /// @param interestRateFactor The interest rate factor
    /// @param interestFormula The interest formula
    function calculateOutstandingBalance(
        uint256 originalBalance,
        uint256 numberOfPeriods,
        uint256 interestRate,
        uint256 interestRateFactor,
        Interest.Formula interestFormula
    ) internal pure returns (uint256 remainingBalance) {
        if (interestFormula == Interest.Formula.Compound) {
            return
                _calculateOutstandingBalanceRounded(originalBalance, numberOfPeriods, interestRate, interestRateFactor);
        } else {
            revert InterestFormulaNotImplemented();
        }
    }

    function _calculateOutstandingBalanceLoop(
        uint256 originalBalance,
        uint256 numberOfPeriods,
        uint256 interestRate,
        uint256 interestRateFactor
    ) private pure returns (uint256) {
        uint256 outstandingBalance = originalBalance;
        for (uint256 i = 0; i < numberOfPeriods; i++) {
            outstandingBalance += outstandingBalance * interestRate / interestRateFactor;
        }
        return outstandingBalance;
    }

    function _calculateOutstandingBalanceRounded(
        uint256 originalBalance,
        uint256 numberOfPeriods,
        uint256 interestRate,
        uint256 interestRateFactor
    ) private pure returns (uint256) {
        /*
         * The equivalent formula: round(originalBalance * (1 + interestRate / interestRateFactor)^numberOfPeriods)
         * Where division operator `/` and power operator `^` take into account the fractional part and
         * the `round()` function returns an integer rounded according to standard mathematical rules.
         */
        int128 onePlusRateValue = divide(interestRateFactor + interestRate, interestRateFactor);
        int128 powValue = power(onePlusRateValue, numberOfPeriods);
        uint256 unroundedResult = uint256(uint128(multiply(powValue, int128(int256(originalBalance << 64)))));
        uint256 result = unroundedResult >> 64;
        if ((unroundedResult - (result << 64)) >= (1 << 63)) {
            result += 1;
        }
        return result;
    }

    /**
     * @dev Calculates the division of unsigned 256-bit integer `numerator`
     *      by non-zero unsigned 256-bit integer `denominator` with rounding towards zero.
     * @dev Reverts if `denominator` is zero or in case of arithmetic overflow.
     *
     * @param numerator The unsigned 256-bit integer numerator.
     * @param denominator The non-zero unsigned 256-bit integer denominator.
     *
     * @return The result as a 64.64-bit fixed-point number.
     */
    function divide(uint256 numerator, uint256 denominator) internal pure returns (int128) {
        if (denominator == 0) {
            revert ZeroDenominator();
        }
        unchecked {
            uint128 remainder = _divide(numerator, denominator);
            if (remainder > uint128(MAX_64x64_VALUE)) {
                revert MathOperationError();
            }
            return int128(remainder);
        }
    }

    /**
     * @dev Calculates the raising a signed 64.64 fixed-point number to the power of an unsigned 256-bit integer.
     * @dev Reverts in case of arithmetic overflow.
     *
     * @param base The signed 64.64 fixed-point base number.
     * @param exponent The unsigned 256-bit integer power.
     *
     * @return The result as a signed 64.64 fixed-point number.
     */
    function power(int128 base, uint256 exponent) internal pure returns (int128) {
        unchecked {
            bool isNegative;
            if (base < 0 && exponent & 1 == 1) {
                isNegative = true;
            }

            uint256 absoluteBase = uint128(base < 0 ? -base : base);
            uint256 absoluteResult;
            absoluteResult = 0x100000000000000000000000000000000;

            if (absoluteBase <= 0x10000000000000000) {
                absoluteBase <<= 63;
                while (exponent != 0) {
                    if (exponent & 0x1 != 0) {
                        absoluteResult = (absoluteResult * absoluteBase) >> 127;
                    }
                    absoluteBase = (absoluteBase * absoluteBase) >> 127;

                    if (exponent & 0x2 != 0) {
                        absoluteResult = (absoluteResult * absoluteBase) >> 127;
                    }
                    absoluteBase = (absoluteBase * absoluteBase) >> 127;

                    if (exponent & 0x4 != 0) {
                        absoluteResult = (absoluteResult * absoluteBase) >> 127;
                    }
                    absoluteBase = (absoluteBase * absoluteBase) >> 127;

                    if (exponent & 0x8 != 0) {
                        absoluteResult = (absoluteResult * absoluteBase) >> 127;
                    }
                    absoluteBase = (absoluteBase * absoluteBase) >> 127;

                    exponent >>= 4;
                }
                absoluteResult >>= 64;
            } else {
                uint256 absoluteBaseShift = 63;
                if (absoluteBase < 0x1000000000000000000000000) {
                    absoluteBase <<= 32;
                    absoluteBaseShift -= 32;
                }
                if (absoluteBase < 0x10000000000000000000000000000) {
                    absoluteBase <<= 16;
                    absoluteBaseShift -= 16;
                }
                if (absoluteBase < 0x1000000000000000000000000000000) {
                    absoluteBase <<= 8;
                    absoluteBaseShift -= 8;
                }
                if (absoluteBase < 0x10000000000000000000000000000000) {
                    absoluteBase <<= 4;
                    absoluteBaseShift -= 4;
                }
                if (absoluteBase < 0x40000000000000000000000000000000) {
                    absoluteBase <<= 2;
                    absoluteBaseShift -= 2;
                }
                if (absoluteBase < 0x80000000000000000000000000000000) {
                    absoluteBase <<= 1;
                    absoluteBaseShift -= 1;
                }

                uint256 resultShift = 0;
                while (exponent != 0) {
                    if (absoluteBaseShift >= 64) {
                        revert MathOperationError();
                    }

                    if (exponent & 0x1 != 0) {
                        absoluteResult = (absoluteResult * absoluteBase) >> 127;
                        resultShift += absoluteBaseShift;
                        if (absoluteResult > 0x100000000000000000000000000000000) {
                            absoluteResult >>= 1;
                            resultShift += 1;
                        }
                    }
                    absoluteBase = (absoluteBase * absoluteBase) >> 127;
                    absoluteBaseShift <<= 1;
                    if (absoluteBase >= 0x100000000000000000000000000000000) {
                        absoluteBase >>= 1;
                        absoluteBaseShift += 1;
                    }

                    exponent >>= 1;
                }

                if (resultShift >= 64) {
                    revert MathOperationError();
                }
                absoluteResult >>= 64 - resultShift;
            }
            int256 result = isNegative ? -int256(absoluteResult) : int256(absoluteResult);
            if (result < MIN_64x64_VALUE || result > MAX_64x64_VALUE) {
                revert MathOperationError();
            }
            return int128(result);
        }
    }

    /**
     * @dev Calculates the multiplication of two signed 64.64 fixed-point numbers with rounding down.
     * @dev Reverts in case of arithmetic overflow.
     *
     * @param multiplicand The first signed 64.64-bit fixed-point number.
     * @param multiplier The second signed 64.64-bit fixed-point number.
     *
     * @return The result as a signed 64.64-bit fixed-point number.
     */
    function multiply(int128 multiplicand, int128 multiplier) internal pure returns (int128) {
        unchecked {
            int256 product = (int256(multiplicand) * multiplier) >> 64;
            if (product < MIN_64x64_VALUE || product > MAX_64x64_VALUE) {
                revert MathOperationError();
            }
            return int128(product);
        }
    }

    /**
     * @dev Calculates the division of unsigned 256-bit integer `numerator`
     *      by non-zero unsigned 256-bit integer `denominator` with rounding towards zero.
     * @dev Reverts if `denominator` is zero or in case of arithmetic overflow.
     *
     * @param numerator The unsigned 256-bit integer numerator.
     * @param denominator The non-zero unsigned 256-bit integer denominator.
     *
     * @return The result as an unsigned 64.64-bit fixed-point number.
     */
    function _divide(uint256 numerator, uint256 denominator) internal pure returns (uint128) {
        unchecked {
            if (denominator == 0) {
                revert ZeroDenominator();
            }

            uint256 remainder;

            if (numerator <= 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF) {
                remainder = (numerator << 64) / denominator;
            } else {
                uint256 msb = 192;
                uint256 numeratorShifted = numerator >> 192;
                if (numeratorShifted >= 0x100000000) {
                    numeratorShifted >>= 32;
                    msb += 32;
                }
                if (numeratorShifted >= 0x10000) {
                    numeratorShifted >>= 16;
                    msb += 16;
                }
                if (numeratorShifted >= 0x100) {
                    numeratorShifted >>= 8;
                    msb += 8;
                }
                if (numeratorShifted >= 0x10) {
                    numeratorShifted >>= 4;
                    msb += 4;
                }
                if (numeratorShifted >= 0x4) {
                    numeratorShifted >>= 2;
                    msb += 2;
                }
                if (numeratorShifted >= 0x2) {
                    msb += 1;
                }

                remainder = (numerator << (255 - msb)) / (((denominator - 1) >> (msb - 191)) + 1);
                if (remainder > 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF) {
                    revert MathOperationError();
                }

                uint256 high = remainder * (denominator >> 128);
                uint256 low = remainder * (denominator & 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF);

                uint256 numeratorHigh = numerator >> 192;
                uint256 numeratorLow = numerator << 64;

                if (numeratorLow < low) {
                    numeratorHigh -= 1;
                }
                numeratorLow -= low;
                low = high << 128;
                if (numeratorLow < low) {
                    numeratorHigh -= 1;
                }
                numeratorLow -= low;

                remainder += numeratorHigh == high >> 128 ? numeratorLow / denominator : 1;
            }

            if (remainder > 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF) {
                revert MathOperationError();
            }
            return uint128(remainder);
        }
    }
}
