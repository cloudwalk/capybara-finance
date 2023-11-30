// SPDX-License-Identifier: MIT

pragma solidity 0.8.20;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

import {ICreditLine} from "../interfaces/core/ICreditLine.sol";
import {ICreditLineFactory} from "../interfaces/ICreditLineFactory.sol";

import {CreditLineConfigurable} from "./CreditLineConfigurable.sol";

/// @title CreditLineFactory contract
/// @notice Implementation of the credit line factory contract
/// @author CloudWalk Inc. (See https://cloudwalk.io)
contract CreditLineFactory is Ownable, ICreditLineFactory {
    /************************************************
     *  Errors
     ***********************************************/

    /// @notice Thrown when the requested credit line kind is not supported
    /// @param kind The kind of credit line that is not supported
    error UnsupportedKind(uint16 kind);

    /************************************************
     *  Constructor
     ***********************************************/

    /// @notice Contract constructor
    /// @param registry_ The address of the associated lending market
    constructor(address registry_) Ownable(registry_) {}

    /************************************************
     *  Functions
     ***********************************************/

    /// @inheritdoc ICreditLineFactory
    function createCreditLine(address market, address lender, uint16 kind, bytes calldata data)
        external
        onlyOwner
        returns (address)
    {
        if (kind != 1) {
            revert UnsupportedKind(kind);
        }

        CreditLineConfigurable creditLine = new CreditLineConfigurable();
        creditLine.initialize(market, lender);

        emit CreditLineCreated(market, lender, kind, address(creditLine));

        return address(creditLine);
    }

    /// @inheritdoc ICreditLineFactory
    function supportedKinds() external pure override returns (uint16[] memory) {
        uint16[] memory kinds = new uint16[](1);
        kinds[0] = 1;
        return kinds;
    }
}
