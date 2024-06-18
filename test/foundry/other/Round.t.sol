// SPDX-License-Identifier: MIT

pragma solidity 0.8.24;

import { Test } from "forge-std/Test.sol";
import { Round } from "src/common/libraries/Round.sol";

/// @title RoundTest contract
/// @author CloudWalk Inc. (See https://cloudwalk.io)
/// @dev Contains tests for the `Round` library.
contract RoundTest is Test {
    function test_roundUp() public {
        uint256 precision = 10000;
        uint256 inputValue = 10000;
        uint256 outputValue = 10000;
        assertEq(Round.roundUp(inputValue, precision), precision);

        inputValue = 10001;
        outputValue = 20000;
        assertEq(Round.roundUp(inputValue, precision), outputValue);

        inputValue = 9999;
        outputValue = 10000;
        assertEq(Round.roundUp(inputValue, precision), outputValue);
    }

    function test_roundDown() public {
        uint256 precision = 10000;
        uint256 inputValue = 10000;
        uint256 outputValue = 10000;
        assertEq(Round.roundDown(inputValue, precision), outputValue);

        inputValue = 10001;
        outputValue = 10000;
        assertEq(Round.roundDown(inputValue, precision), outputValue);

        inputValue = 9999;
        outputValue = 0;
        assertEq(Round.roundDown(inputValue, precision), outputValue);
    }
}
