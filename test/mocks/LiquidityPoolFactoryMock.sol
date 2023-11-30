// SPDX-License-Identifier: MIT

pragma solidity 0.8.20;

import {ILiquidityPoolFactory} from "src/interfaces/ILiquidityPoolFactory.sol";

/// @title LiquidityPoolFactoryMock contract
/// @notice Liquidity pool factory mock contract used for testing
/// @author CloudWalk Inc. (See https://cloudwalk.io)
contract LiquidityPoolFactoryMock is ILiquidityPoolFactory {

    /************************************************
     *  Events
     ***********************************************/

    event CreateLiquidityPoolCalled(
        address indexed market,
        address indexed lender,
        uint16 indexed kind,
        bytes data
    );

    /************************************************
     *  Errors
     ***********************************************/

    error NotImplemented();

    /************************************************
     *  Storage variables
     ***********************************************/

    address _liquidityPoolAddress;

    /************************************************
     *  ILiquidityPoolFactory functions
     ***********************************************/

    function createLiquidityPool(
        address market,
        address lender,
        uint16 kind,
        bytes calldata data
    ) external returns (address) {
        emit CreateLiquidityPoolCalled(market, lender, kind, data);
        return _liquidityPoolAddress;
    }

    function supportedKinds() external pure override returns (uint16[] memory) {
        revert NotImplemented();
    }

    /************************************************
     *  Mock functions
     ***********************************************/

    function mockLiquidityPoolAddress(address liquidityPoolAddress) external {
        _liquidityPoolAddress = liquidityPoolAddress;
    }
}
