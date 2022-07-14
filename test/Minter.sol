import { Script } from "forge-std/Script.sol";

interface DSTokenLike {
    function mint(address,uint) external;
    function burn(address,uint) external;
}

interface USDCLike {
    function masterMinter() view external returns(address);
    function configureMinter(address minter, uint256 minterAllowedAmount) external returns (bool);
    function mint(address _to, uint256 _amount) external returns (bool);
}

interface USDTLike {
    function owner() view external returns(address);
    function transfer(address to, uint value) external;
    function issue(uint amount) external;
}

contract Minter is Script {
    //     w3.provider.make_request('hardhat_impersonateAccount', [MCD])
    // w3.provider.make_request('hardhat_setBalance', [MCD, hex(10**18)])
    // dai.functions.mint(user, amount).transact({'from': MCD})
    address internal constant MCD = 0x9759A6Ac90977b93B58547b4A71c78317f391A28;
    address internal minter = address(0x1005);

    address public constant usdt = 0xdAC17F958D2ee523a2206206994597C13D831ec7;
    address public constant dai = 0x6B175474E89094C44Da98b954EedeAC495271d0F;
    address public constant usdc = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;

    function mintUsdt(address receiver, uint256 amount) public {
        address _owner = USDTLike(usdt).owner();
        vm.deal(_owner, 1 ether);
        vm.startPrank(_owner);
        USDTLike(usdt).issue(amount);
        USDTLike(usdt).transfer(receiver, amount);
        vm.stopPrank();
    }

    function mintDai(address receiver, uint256 amount) public {
        vm.deal(MCD, 1 ether);
        vm.prank(MCD);
        DSTokenLike(dai).mint(receiver, amount);
    }

    function mintUsdc(address receiver, uint256 amount) public {

        address masterMinter = USDCLike(usdc).masterMinter();
        vm.deal(masterMinter, 1 ether);
        vm.prank(masterMinter);
        USDCLike(usdc).configureMinter(minter, amount);

        vm.deal(minter, 1 ether);
        vm.prank(minter);
        USDCLike(usdc).mint(receiver, amount);
    }
}