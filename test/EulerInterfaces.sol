
interface EulerLike {
    /// @notice Params for 1Inch trade
    /// @param subAccountIdIn subaccount id to trade from
    /// @param subAccountIdOut subaccount id to trade to
    /// @param underlyingIn sold token address
    /// @param underlyingOut bought token address
    /// @param amount amount of token to sell
    /// @param amountOutMinimum minimum amount of bought token
    /// @param payload call data passed to 1Inch contract
    struct Swap1InchParams {
        uint subAccountIdIn;
        uint subAccountIdOut;
        address underlyingIn;
        address underlyingOut;
        uint amount;
        uint amountOutMinimum;
        bytes payload;
    }
    function swap1Inch(Swap1InchParams memory params) external;
}

interface ETokenLike {
    function deposit(uint subAccountId, uint amount) external;
    function balanceOfUnderlying(address account) external view returns (uint);
    function withdraw(uint subAccountId, uint amount) external;
}

interface DTokenLike {
    function borrow(uint subAccountId, uint amount) external;
}

interface PTokenLike {
    function wrap(uint amount) external;
    function unwrap(uint amount) external;
}

interface MarketsLike {
    function underlyingToEToken(address underlying) external view returns (address);
    function underlyingToDToken(address underlying) external view returns (address);
    function enterMarket(uint subAccountId, address newMarket) external;
    function activatePToken(address underlying) external returns(address);
}
