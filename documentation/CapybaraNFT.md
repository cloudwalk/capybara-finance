# Overview
The CapybaraNFT is a Solidity contract that implements the CapybaraNFT token. It is an ERC-721 compliant non-fungible token (NFT) contract with additional features such as pausing and ownership management. This contract is designed to be upgradeable, allowing for potential future enhancements.

## Contract Details

- **Version**: Solidity 0.8.20
- **License**: MIT
- **Author**: CloudWalk Inc. (See [CloudWalk](https://cloudwalk.io))
- **Interface**: [ICapybaraNFT](./interfaces/ICapybaraNFT.md)

## Storage Variables
| Name	             | Type	   | Description                                   |
|-------------------|---------|-----------------------------------------------|
| _market           | address | The address of the associated lending market. |
| _tokenIdCounter 	 | uint256 | Counter for generating unique token IDs.      |

## Modifiers

### onlyMarket
```solidity
modifier onlyMarket();
```
Ensures that a function can only be called by the lending market associated with the contract.

## Initializer
```solidity
function initialize(string memory name_, string memory symbol_, address market_) external initializer;
```
Initializes the contract with the provided name, symbol, and associated lending market address.

#### Parameters:

| Name	   | Type	   | Description                                   |
|---------|---------|-----------------------------------------------|
| name_   | string  | The name of the NFT token.                    |
| symbol_ | string  | The symbol of the NFT token.                  |
| market_ | address | The address of the associated lending market. |

## Functions

### pause
```solidity
function pause() external onlyOwner;
```
Pauses the contract, preventing certain functions from being called.

#### Restrictions:
- Is reverted if caller is not the owner

### unpause
```solidity
function unpause() external onlyOwner;
```
Unpauses the contract, allowing paused functions to be called again.

#### Restrictions:
- Is reverted if caller is not the owner

### safeMint
```solidity
function safeMint(address to) external onlyMarket returns (uint256);
```
Safely mints a new NFT and assigns it to the specified address.

#### Restrictions:
- Is reverted if caller is not the market

#### Parameters:

| Name	 | Type	   | Description                                    |
|-------|---------|------------------------------------------------|
| to    | address | The address to which the NFT will be assigned. |


#### Returns:

| Name	   | Type	   | Description                     |
|---------|---------|---------------------------------|
| tokenId | uint256 | The ID of the newly minted NFT. |

## market
```solidity
function market() external view returns (address);
```
Returns the address of the associated lending market.