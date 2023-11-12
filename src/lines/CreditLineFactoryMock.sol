// SPDX-License-Identifier: MIT

pragma solidity 0.8.20;

import {ICreditLineFactory} from "../interfaces/ICreditLineFactory.sol";


contract CreditLineFactoryMock is ICreditLineFactory {

    error NotImplemented();

    event CreateCreditLineCalled(
        address indexed market,
        address indexed lender,
        uint16 indexed kind,
        bytes data
    );

    address _creditLineAddress;

    function setCreditLineAddress(address creditLineAddress) external {
        _creditLineAddress = creditLineAddress;
    }

    function createCreditLine(address market, address lender, uint16 kind, bytes calldata data)
        external
        returns (address creditLine)
    {
        emit CreateCreditLineCalled(market, lender, kind, data);
        return _creditLineAddress;
    }

    function supportedKinds() external pure override returns (uint16[] memory) {
        revert NotImplemented();
    }
}
