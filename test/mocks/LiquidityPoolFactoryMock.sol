// SPDX-License-Identifier: MIT

pragma solidity 0.8.20;

import {ILiquidityPoolFactory} from "src/interfaces/ILiquidityPoolFactory.sol";

contract LiquidityPoolFactoryMock is ILiquidityPoolFactory {
    error NotImplemented();

    event CreateLiquidityPoolCalled(
        address indexed market,
        address indexed lender,
        uint16 indexed kind,
        bytes data
    );

    address _liquidityPoolAddress;

    function setLiquidityPoolAddress(address liquidityPoolAddress) external {
        _liquidityPoolAddress = liquidityPoolAddress;
    }

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
}
