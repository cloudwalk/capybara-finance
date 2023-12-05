// SPDX-License-Identifier: MIT

pragma solidity 0.8.23;

import {Error} from "../libraries/Error.sol";
import {ILiquidityPoolFactory} from "../interfaces/ILiquidityPoolFactory.sol";

/// @title LiquidityPoolFactoryMock contract
/// @notice LiquidityPoolFactory mock contract used for testing
/// @author CloudWalk Inc. (See https://cloudwalk.io)
contract LiquidityPoolFactoryMock is ILiquidityPoolFactory {
    /************************************************
     *  Events
     ***********************************************/

    event CreateLiquidityPoolCalled(address indexed market, address indexed lender, uint16 indexed kind, bytes data);

    /************************************************
     *  Storage variables
     ***********************************************/

    address _liquidityPoolAddress;

    /************************************************
     *  ILiquidityPoolFactory functions
     ***********************************************/

    function createLiquidityPool(address market, address lender, uint16 kind, bytes calldata data)
        external
        returns (address)
    {
        emit CreateLiquidityPoolCalled(market, lender, kind, data);
        return _liquidityPoolAddress;
    }

    function supportedKinds() external pure override returns (uint16[] memory) {
        revert Error.NotImplemented();
    }

    /************************************************
     *  Mock functions
     ***********************************************/

    function mockLiquidityPoolAddress(address liquidityPoolAddress) external {
        _liquidityPoolAddress = liquidityPoolAddress;
    }
}
