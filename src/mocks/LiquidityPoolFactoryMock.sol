// SPDX-License-Identifier: MIT

pragma solidity 0.8.23;

import { Error } from "../libraries/Error.sol";
import { ILiquidityPoolFactory } from "../interfaces/ILiquidityPoolFactory.sol";

/// @title LiquidityPoolFactoryMock contract
/// @author CloudWalk Inc. (See https://cloudwalk.io)
/// @notice Mock of the `LiquidityPoolFactory` contract used for testing.
contract LiquidityPoolFactoryMock is ILiquidityPoolFactory {
    // -------------------------------------------- //
    //  Events                                      //
    // -------------------------------------------- //

    event CreateLiquidityPoolCalled(address indexed market, address indexed lender, uint16 indexed kind, bytes data);

    // -------------------------------------------- //
    //  Storage variables                           //
    // -------------------------------------------- //

    address _createdLiquidityPoolAddress;

    // -------------------------------------------- //
    //  ILiquidityPoolFactory functions             //
    // -------------------------------------------- //

    function createLiquidityPool(
        address market,
        address lender,
        uint16 kind,
        bytes calldata data
    ) external returns (address) {
        emit CreateLiquidityPoolCalled(market, lender, kind, data);
        return _createdLiquidityPoolAddress;
    }

    function supportedKinds() external pure override returns (uint16[] memory) {
        revert Error.NotImplemented();
    }

    // -------------------------------------------- //
    //  Mock functions                              //
    // -------------------------------------------- //

    function mockCreatedLiquidityPoolAddress(address liquidityPoolAddress) external {
        _createdLiquidityPoolAddress = liquidityPoolAddress;
    }
}
