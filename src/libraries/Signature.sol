// SPDX-License-Identifier: MIT

pragma solidity 0.8.20;

import {Interest} from "./Interest.sol";

/// @title Signature library
/// @notice Defines Signature-related actions
/// @author CloudWalk Inc. (See https://cloudwalk.io)
library Signature {
    error InvalidSignature();

    function getBorrowMesageHash(uint256 amount, address borrower, address creditLine) public pure returns (bytes32) {
        return keccak256(abi.encodePacked(amount, borrower, creditLine));
    }

    function getRepayMesageHash(address borrower, uint256 loanId, uint256 amount) public pure returns (bytes32) {
        return keccak256(abi.encodePacked(borrower, loanId, amount));
    }

    function getEthSignedMessageHash(bytes32 messageHash) public pure returns (bytes32) {
        bytes memory prefix = "\x19Ethereum Signed Message:\n32";
        return keccak256(abi.encodePacked(prefix, messageHash));
    }

    function verifyBorrow(uint256 amount, address borrower, address creditLine, bytes memory signature)
        public
        pure
        returns (bool)
    {
        bytes32 messageHash = getBorrowMesageHash(amount, borrower, creditLine);
        bytes32 ethSignedMessageHash = getEthSignedMessageHash(messageHash);

        return recoverSigner(ethSignedMessageHash, signature) == borrower;
    }

    function verifyRepay(address signer, uint256 amount, address borrower, uint256 loanId, bytes memory signature)
        public
        pure
        returns (bool)
    {
        bytes32 messageHash = getRepayMesageHash(borrower, loanId, amount);
        bytes32 ethSignedMessageHash = getEthSignedMessageHash(messageHash);

        return recoverSigner(ethSignedMessageHash, signature) == signer;
    }

    /**
     * @dev Splits given signature to r, s and v in assembly.
     * @param signature Signature to split.
     * @return uint8, bytes32, bytes32 The split bytes from the signature.
     */
    function _splitSignature(bytes memory signature) internal pure returns (uint8, bytes32, bytes32) {
        if (signature.length != 65) {
            revert InvalidSignature();
        }

        bytes32 r;
        bytes32 s;
        uint8 v;

        assembly {
            // first 32 bytes, after the length prefix
            r := mload(add(signature, 32))
            // second 32 bytes
            s := mload(add(signature, 64))
            // final byte (first byte of the next 32 bytes)
            v := byte(0, mload(add(signature, 96)))
        }
        return (v, r, s);
    }

    /**
     * @dev Returns the address that signed a {message} with signature {sig}.
     * @param message The hash of a message to check the signer of.
     * @param signature The signature used to sign a {message}.
     * @return Address that signed a {message}.
     */
    function recoverSigner(bytes32 message, bytes memory signature) public pure returns (address) {
        if (signature.length != 65) {
            return (address(0));
        }

        uint8 v;
        bytes32 r;
        bytes32 s;

        (v, r, s) = _splitSignature(signature);

        if (uint256(s) > 0x7FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF5D576E7357A4501DDFE92F46681B20A0) {
            return (address(0));
        }

        if (v < 27) {
            v += 27;
        }

        if (v != 27 && v != 28) {
            return (address(0));
        }

        message = getEthSignedMessageHash(message);

        return ecrecover(message, v, r, s);
    }
}
