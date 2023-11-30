// // SPDX-License-Identifier: MIT

// pragma solidity 0.8.20;

// import "forge-std/Test.sol";

// import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
// import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
// import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
// import {PausableUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";

// import {LiquidityPoolAccountable} from "src/pools/LiquidityPoolAccountable.sol";
// import {CreditLineConfigurable} from "src/lines/CreditLineConfigurable.sol";
// import {CapybaraNFT} from "src/CapybaraNFT.sol";
// import {LendingRegistry} from "src/LendingRegistry.sol";
// import {ERC20Test} from "./mocks/ERC20Test.sol";
// import {LendingMarket} from "src/LendingMarket.sol";

// import {Error} from "src/libraries/Error.sol";

// contract CapybaraNftTest is Test {
//     string public constant TOKEN_NAME = "CapybaraFinance";
//     string public constant TOKEN_SYMBOL = "CAPY";
//     address public constant ATTACKER = 0x447a8BAfc4747Aa92583d6a5ddB839DA91ded5A5;

//     bytes4 public constant ERC721_INTERFACE_ID = 0x80ac58cd;
//     uint256 public constant MINT_AMOUNT = 1000000;

//     LiquidityPoolAccountable public pool;
//     CreditLineConfigurable public line;
//     ERC20Test public token;
//     LendingMarket public marketLogic;
//     LendingMarket public market;
//     CapybaraNFT public nftLogic;
//     CapybaraNFT public nft;
//     LendingRegistry public registryLogic;
//     LendingRegistry public registry;

//     function setUp() public {
//         token = new ERC20Test(MINT_AMOUNT);
//         nftLogic = new CapybaraNFT();
//         marketLogic = new LendingMarket();
//         registryLogic = new LendingRegistry();

//         ERC1967Proxy marketProxy = new ERC1967Proxy(address(marketLogic), "");
//         ERC1967Proxy nftProxy = new ERC1967Proxy(address(nftLogic), "");
//         ERC1967Proxy registryProxy = new ERC1967Proxy(address(registryLogic), "");

//         market = LendingMarket(address(marketProxy));

//         nft = CapybaraNFT(address(nftProxy));
//         nft.initialize(TOKEN_NAME, TOKEN_SYMBOL, address(market));

//         market.initialize(address(nft));

//         registry = LendingRegistry(address(registryProxy));
//         registry.initialize(address(market));

//         pool = new LiquidityPoolAccountable(address(market), address(this));
//         line = new CreditLineConfigurable(address(market), address(this));

//         token.approve(address(pool), type(uint256).max);
//         token.approve(address(market), type(uint256).max);

//         vm.prank(address(pool));
//         token.approve(address(market), type(uint256).max);
//     }

//     function test_initialize() public {
//         CapybaraNFT nftLogic;
//         CapybaraNFT nft;
//         nftLogic = new CapybaraNFT();

//         ERC1967Proxy proxy = new ERC1967Proxy(address(nftLogic), "");

//         nft = CapybaraNFT(address(proxy));
//         nft.initialize(TOKEN_NAME, TOKEN_SYMBOL, address(market));

//         assertEq(nft.name(), TOKEN_NAME);
//         assertEq(nft.symbol(), TOKEN_SYMBOL);
//     }

//     function test_initialize_Revert_IfMarketZeroAddress() public {
//         CapybaraNFT nftLogic;
//         CapybaraNFT nft;
//         nftLogic = new CapybaraNFT();

//         ERC1967Proxy proxy = new ERC1967Proxy(address(nftLogic), "");

//         nft = CapybaraNFT(address(proxy));
//         vm.expectRevert(Error.ZeroAddress.selector);
//         nft.initialize(TOKEN_NAME, TOKEN_SYMBOL, address(0));
//     }

//     function test_initialize_Revert_IfCalledSecondTime() public {
//         vm.expectRevert(Initializable.InvalidInitialization.selector);
//         nft.initialize(TOKEN_NAME, TOKEN_SYMBOL, address(market));
//     }

//     function test_pause() public {
//         assertEq(nft.paused(), false);
//         nft.pause();
//         assertEq(nft.paused(), true);
//     }

//     function test_pause_Revert_IfCallerNotOwner() public {
//         vm.expectRevert(
//             abi.encodeWithSelector(OwnableUpgradeable.OwnableUnauthorizedAccount.selector, ATTACKER)
//         );
//         vm.prank(ATTACKER);
//         nft.pause();
//     }

//     function test_pause_Revert_IfContractPaused() public {
//         nft.pause();
//         assertEq(nft.paused(), true);
//         vm.expectRevert(PausableUpgradeable.EnforcedPause.selector);
//         nft.pause();
//     }

//     function test_unpause() public {
//         assertEq(nft.paused(), false);
//         nft.pause();
//         assertEq(nft.paused(), true);
//         nft.unpause();
//         assertEq(nft.paused(), false);
//     }

//     function test_unpause_Revert_IfCallerNotOwner() public {
//         nft.pause();
//         vm.expectRevert(
//             abi.encodeWithSelector(OwnableUpgradeable.OwnableUnauthorizedAccount.selector, ATTACKER)
//         );
//         vm.prank(ATTACKER);
//         nft.unpause();
//     }

//     function test_unpause_Revert_IfContractNotPaused() public {
//         assertEq(nft.paused(), false);
//         vm.expectRevert(PausableUpgradeable.ExpectedPause.selector);
//         nft.unpause();
//     }

//     function test_safeMint() public {
//         vm.prank(address(market));
//         uint256 id = nft.safeMint(address(this));
//         assertEq(nft.ownerOf(id), address(this));
//     }

//     function test_safeMint_Revert_IfCallerNotMarket() public {
//         vm.expectRevert(Error.Unauthorized.selector);
//         nft.safeMint(address(this));
//     }

//     function test_market() public {
//         assertEq(nft.market(), address(market));
//     }

//     function test_supportsInterface() public {
//         bool res = nft.supportsInterface(ERC721_INTERFACE_ID);
//         assertEq(res, true);
//     }

//     function onERC721Received(address operator, address from, uint256 tokenId, bytes calldata data)
//         external
//         pure
//         returns (bytes4)
//     {
//         return bytes4(keccak256("onERC721Received(address,address,uint256,bytes)"));
//     }
// }
