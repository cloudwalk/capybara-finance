// SPDX-License-Identifier: MIT

pragma solidity 0.8.20;

import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {PausableUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import {ERC721Upgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC721/ERC721Upgradeable.sol";
import {ERC721BurnableUpgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC721/extensions/ERC721BurnableUpgradeable.sol";
import {ERC721EnumerableUpgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC721/extensions/ERC721EnumerableUpgradeable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

import {Error} from "./libraries/Error.sol";
import {ICapybaraNFT} from "./interfaces/core/ICapybaraNFT.sol";
import {CapybaraNFTStorage} from "./CapybaraNFTStorage.sol";

/// @title CapybaraNFT token
/// @notice Implementation of the CapybaraNFT token contract
/// @author CloudWalk Inc. (See https://cloudwalk.io)
contract CapybaraNFT is
    CapybaraNFTStorage,
    Initializable,
    OwnableUpgradeable,
    PausableUpgradeable,
    ERC721Upgradeable,
    ERC721BurnableUpgradeable,
    ERC721EnumerableUpgradeable,
    UUPSUpgradeable,
    ICapybaraNFT
{
    /************************************************
     *  MODIFIERS
     ***********************************************/

    /// @notice Throws if called by any account other than the market
    modifier onlyMarket() {
        if (msg.sender != _market) {
            revert Error.Unauthorized();
        }
        _;
    }

    /************************************************
     *  CONSTRUCTOR
     ***********************************************/

    /// @dev Constructor that prohibits the initialization of the implementation of the upgradable contract
    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /************************************************
     *  INITIALIZERS
     ***********************************************/

    /// @notice Initializer of the upgradable contract
    /// @param name_ The name of the nft token
    /// @param symbol_ The symbol of the nft token
    /// @param market_ The address of the associated lending market
    function initialize(string memory name_, string memory symbol_, address market_) external initializer {
        __CapybaraNFT_init(name_, symbol_, market_);
    }

    /// @notice Internal initializer of the upgradable contract
    /// @param name_ The name of the nft token
    /// @param symbol_ The symbol of the nft token
    /// @param market_ The address of the associated lending market
    function __CapybaraNFT_init(string memory name_, string memory symbol_, address market_)
        internal
        onlyInitializing
    {
        __ERC721_init_unchained(name_, symbol_);
        __ERC721Enumerable_init_unchained();
        __ERC721Burnable_init_unchained();
        __Ownable_init_unchained(msg.sender);
        __Pausable_init_unchained();
        __UUPSUpgradeable_init_unchained();
        __CapybaraNFT_init_unchained(market_);
    }

    /// @notice Internal unchained initializer of the upgradable contract
    /// @param market_ The address of the associated lending market
    function __CapybaraNFT_init_unchained(address market_) internal onlyInitializing {
        if (market_ == address(0)) {
            revert Error.ZeroAddress();
        }

        _market = market_;
    }

    /************************************************
     *  OWNER FUNCTIONS
     ***********************************************/

    /// @notice Pauses the contract
    function pause() external onlyOwner {
        _pause();
    }

    /// @notice Unpauses the contract
    function unpause() external onlyOwner {
        _unpause();
    }

    /************************************************
     *  MARKET FUNCTIONS
     ***********************************************/

    /// @inheritdoc ICapybaraNFT
    function safeMint(address to) external onlyMarket returns (uint256) {
        uint256 tokenId = _tokenIdCounter;
        _tokenIdCounter++;

        _safeMint(to, tokenId);
        _approve(_market, tokenId, address(0));

        return tokenId;
    }

    /************************************************
     *  VIEW FUNCTIONS
     ***********************************************/

    /// @inheritdoc ICapybaraNFT
    function market() external view returns (address) {
        return _market;
    }

    /************************************************
     *  INTERNAL FUNCTIONS
     ***********************************************/

    /// @inheritdoc ERC721Upgradeable
    function _update(address to, uint256 tokenId, address auth)
        internal
        override(ERC721Upgradeable, ERC721EnumerableUpgradeable)
        whenNotPaused
        returns (address)
    {
        return super._update(to, tokenId, auth);
    }

    /// @inheritdoc ERC721Upgradeable
    function _increaseBalance(address account, uint128 value)
        internal
        override(ERC721Upgradeable, ERC721EnumerableUpgradeable)
    {
        super._increaseBalance(account, value);
    }

    /// @inheritdoc ERC721Upgradeable
    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(ERC721Upgradeable, ERC721EnumerableUpgradeable)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }

    /// @inheritdoc UUPSUpgradeable
    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}
}
