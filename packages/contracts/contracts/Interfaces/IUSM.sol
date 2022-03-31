// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.6.11;
pragma experimental ABIEncoderV2;

import "../Dependencies/IERC20.sol";
import "./IFUM.sol";
import "./Oracle.sol";

interface IUSM is IERC20, Oracle {
    event UnderwaterStatusChanged(bool underwater);
    event BidAskAdjustmentChanged(uint adjustment);
    event PriceChanged(uint price, uint oraclePrice);

    enum Side {Buy, Sell}

    struct LoadedState {
        uint timeSystemWentUnderwater;
        uint ethUsdPrice;                   // This one is in WADs, not millionths
        uint oracleEthUsdPrice;             // WADs, not millionths
        uint bidAskAdjustmentTimestamp;
        uint bidAskAdjustment;              // WADs, not millionths
        uint ethPool;
        uint usmTotalSupply;
    }

    // ____________________ External transactional functions ____________________

    /**
     * @notice Mint new USM, sending it to the given address, and only if the amount minted >= `minUsmOut`.  The amount of ETH
     * is passed in as `msg.value`.
     * @param to address to send the USM to.
     * @param minUsmOut Minimum accepted USM for a successful mint.
     */
    function mint(address to, uint minUsmOut) external payable returns (uint usmOut);

    /**
     * @dev Burn USM in exchange for ETH.
     * @param to address to send the ETH to.
     * @param usmToBurn Amount of USM to burn.
     * @param minEthOut Minimum accepted ETH for a successful burn.
     */
    function burn(address payable to, uint usmToBurn, uint minEthOut) external returns (uint ethOut);

    /**
     * @notice Funds the pool with ETH, minting new FUM and sending it to the given address, but only if the amount minted >=
     * `minFumOut`.  The amount of ETH is passed in as `msg.value`.
     * @param to address to send the FUM to.
     * @param minFumOut Minimum accepted FUM for a successful fund.
     */
    function fund(address to, uint minFumOut) external payable returns (uint fumOut);

    /**
     * @notice Defunds the pool by redeeming FUM in exchange for equivalent ETH from the pool.
     * @param to address to send the ETH to.
     * @param fumToBurn Amount of FUM to burn.
     * @param minEthOut Minimum accepted ETH for a successful defund.
     */
    function defund(address payable to, uint fumToBurn, uint minEthOut) external returns (uint ethOut);

    /**
     * @notice Defunds the pool by redeeming FUM in exchange for equivalent ETH from the pool. Usable only by FUM.
     * @param from address to deduct the FUM from.
     * @param to address to send the ETH to.
     * @param fumToBurn Amount of FUM to burn.
     * @param minEthOut Minimum accepted ETH for a successful defund.
     */
    function defundFrom(address from, address payable to, uint fumToBurn, uint minEthOut) external returns (uint ethOut);

    // ____________________ External informational view functions ____________________

    /**
     * @return fum_ The FUM instance
     */
    function fum() external view returns (IFUM fum_);

    /**
     * @notice Total amount of ETH in the pool (ie, in the contract).
     * @return pool ETH pool
     */
    function ethPool() external view returns (uint pool);

    /**
     * @notice Total amount of ETH in the pool (ie, in the contract).
     * @return supply the total supply of FUM.  Users of this `IUSM` interface, like `USMView`, need to call this rather than
     * `usm.fum().totalSupply()` directly, because `IUSM` doesn't (and shouldn't) know about the `FUM` type.
     */
    function fumTotalSupply() external view returns (uint supply);

    /**
     * @notice The current bid/ask adjustment, equal to the stored value decayed over time towards its stable value, 1.  This
     * adjustment is intended as a measure of "how long-ETH recent user activity has been", so that we can slide price
     * accordingly: if recent activity was mostly long-ETH (`fund()` and `burn()`), raise FUM buy price/reduce USM sell price;
     * if recent activity was short-ETH (`defund()` and `mint()`), reduce FUM sell price/raise USM buy price.
     * @return adjustment The sliding-price bid/ask adjustment
     */
    function bidAskAdjustment() external view returns (uint adjustment);

    function timeSystemWentUnderwater() external view returns (uint timestamp);

    function isDuringPrefund() external view returns (bool duringPrefund);

    // ____________________ External helper pure functions (for functions above) ____________________

    /**
     * @notice Calculate the amount of ETH in the buffer.
     * @return buffer ETH buffer
     */
    function ethBuffer(uint ethUsdPrice, uint ethInPool, uint usmSupply, bool roundUp) external pure returns (int buffer);

    /**
     * @notice Calculate debt ratio for a given eth to USM price: ratio of the outstanding USM (amount of USM in total supply),
     * to the current ETH pool value in USD (ETH qty * ETH/USD price).
     * @return ratio Debt ratio (or 0 if there's currently 0 ETH in the pool/price = 0: these should never happen after launch)
     */
    function debtRatio(uint ethUsdPrice, uint ethInPool, uint usmSupply) external pure returns (uint ratio);

    /**
     * @notice Convert ETH amount to USM using a ETH/USD price.
     * @param ethAmount The amount of ETH to convert
     * @return usmOut The amount of USM
     */
    function ethToUsm(uint ethUsdPrice, uint ethAmount, bool roundUp) external pure returns (uint usmOut);

    /**
     * @notice Convert USM amount to ETH using a ETH/USD price.
     * @param usmAmount The amount of USM to convert
     * @return ethOut The amount of ETH
     */
    function usmToEth(uint ethUsdPrice, uint usmAmount, bool roundUp) external pure returns (uint ethOut);

    /**
     * @return price The ETH/USD price, adjusted by the `bidAskAdjustment` (if applicable) for the given buy/sell side.
     */
    function adjustedEthUsdPrice(Side side, uint ethUsdPrice, uint adjustment) external pure returns (uint price);

    /**
     * @notice Calculate the *marginal* price of USM (in ETH terms): that is, of the next unit, before the price start sliding.
     * @return price USM price in ETH terms
     */
    function usmPrice(Side side, uint ethUsdPrice) external pure returns (uint price);

    /**
     * @notice Calculate the *marginal* price of FUM (in ETH terms): that is, of the next unit, before the price starts rising.
     * @param usmEffectiveSupply should be either the actual current USM supply, or, when calculating the FUM *buy* price, the
     * return value of `usmSupplyForFumBuys()`.
     * @return price FUM price in ETH terms
     */
    function fumPrice(Side side, uint ethUsdPrice, uint ethInPool, uint usmEffectiveSupply, uint fumSupply, bool prefund) external pure returns (uint price);

    /**
     * @return timeSystemWentUnderwater_ The time at which we first detected the system was underwater (debt ratio >
     * `MAX_DEBT_RATIO`), based on the current oracle price and pool ETH and USM; or 0 if we're not currently underwater.
     * @return usmSupplyForFumBuys The current supply of USM *for purposes of calculating the FUM buy price,* and therefore
     * for `fumFromFund()`.  The "supply for FUM buys" is the *lesser* of the actual current USM supply, and the USM amount
     * that would make debt ratio = `MAX_DEBT_RATIO`.  Example:
     *
     * 1. Suppose the system currently contains 50 ETH at price $1,000 (total pool value: $50,000), with an actual USM supply
     *    of 30,000 USM.  Then debt ratio = 30,000 / $50,000 = 60%: < MAX 80%, so `usmSupplyForFumBuys` = 30,000.
     * 2. Now suppose ETH/USD halves to $500.  Then pool value halves to $25,000, and debt ratio doubles to 120%.  Now
     *    `usmSupplyForFumBuys` instead = 20,000: the USM quantity at which debt ratio would equal 80% (20,000 / $25,000).
     *    (Call this the "80% supply".)
     * 3. ...Except, we also gradually increase the supply over time while we remain underwater.  This has the effect of
     *    *reducing* the FUM buy price inferred from that supply (higher JacobUSM supply -> smaller buffer -> lower FUM price).
     *    The math we use gradually increases the supply from its initial "80% supply" value, where debt ratio =
     *    `MAX_DEBT_RATIO` (20,000 above), to a theoretical maximum "100% supply" value, where debt ratio = 100% (in the $500
     *    example above, this would be 25,000).  (Or the actual supply, whichever is lower: we never increase
     *    `usmSupplyForFumBuys` above `usmActualSupply`.)  The climb from the initial 80% supply (20,000) to the 100% supply
     *    (25,000) is at a rate that brings it "halfway closer per `MIN_FUM_BUY_PRICE_HALF_LIFE` (eg, 1 day)": so three days
     *    after going underwater, the supply returned will be 25,000 - 0.5**3 * (25,000 - 20,000) = 24,375.
     */
    function checkIfUnderwater(uint usmActualSupply, uint ethPool_, uint ethUsdPrice, uint oldTimeUnderwater, uint currentTime) external pure returns (uint timeSystemWentUnderwater_, uint usmSupplyForFumBuys, uint debtRatio_);

    
    /**
     * @notice Get the current state data like current market price etc.
     * @return ls LoadedState
     */
    function loadState() external view returns (LoadedState memory ls);

    /**
     * @notice How much FUM a funder currently gets back for `ethIn` ETH, accounting for `bidAskAdjustment` and sliding prices.
     * @param ethIn The amount of ETH passed to `fund()`
     * @return fumOut The amount of FUM to receive in exchange
     */
    function fumFromFund(LoadedState memory ls, uint fumSupply, uint ethIn, uint debtRatio_, bool prefund) external pure returns (uint fumOut, uint adjGrowthFactor);

    function ethFromDefund(LoadedState memory ls, uint fumSupply, uint fumIn) external pure returns (uint ethOut, uint adjShrinkFactor);

    function checkForFreshOraclePrice(LoadedState memory ls) external view returns (uint price, uint oraclePrice, uint adjustment);

    function usmFromMint(LoadedState memory ls, uint ethIn) external pure returns (uint usmOut, uint adjShrinkFactor);

    function ethFromBurn(LoadedState memory ls, uint usmIn) external pure returns (uint ethOut, uint adjGrowthFactor);

    function getUSDAOMintFee(uint256 tokenAmount) external view returns (uint256);

    function getUSDAOBurnFee(uint256 ethAmount) external view returns (uint256);

    function getTransferFee(uint256 tokenAmount) external view returns (uint256);

    function getAssetMintFee(uint256 tokenAmount) external view returns (uint256);

    function getAssetBurnFee(uint256 ethAmount) external view returns (uint256); 
    

    // function transferFrom(address from, address to,uint256 amount) external returns (bool); 

    // function allowance(address owner, address spender) external view returns (uint256);

    // function approve(address spender, uint256 amount) external returns (bool);

    // function transfer(address to, uint256 amount) external returns (bool);

    function returnFromPool(address poolAddress, address user, uint256 _amount ) external;

    function sendToPool(address _sender,  address poolAddress, uint256 _amount) external;

    function onVaultMint(address to, uint amount) external;
}