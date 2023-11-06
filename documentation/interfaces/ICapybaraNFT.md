# Overview
The `ICapybaraNFT` interface defines the functions and events for the Capybara NFT token. This interface is used to interact with Capybara NFT tokens within the lending system.

- **Version**: Solidity 0.8.20
- **License**: MIT
- **Author**: CloudWalk Inc. (See [CloudWalk](https://cloudwalk.io))

## Functions

### safeMint
```solidity
function safeMint(address to) external returns (uint256);
```
Mints a new NFT representation of the loan and transfers it to the lender.

#### Parameters:

| Name	 | Type	   | Description                                    |
|-------|---------|------------------------------------------------|
| to    | address | The address to which the NFT will be assigned. |


#### Returns:

| Name	   | Type	   | Description                     |
|---------|---------|---------------------------------|
| tokenId | uint256 | The ID of the newly minted NFT. |

### market
```solidity
function market() external view returns (address);
```
Retrieves t

#### Returns:

| Name	  | Type	   | Description                                   |
|--------|---------|-----------------------------------------------|
| market | address | The address of the associated lending market. |

