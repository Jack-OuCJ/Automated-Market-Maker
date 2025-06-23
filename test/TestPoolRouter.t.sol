// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import "../src/utils/Token.sol";
import "../src/utils/WETH.sol";
import "../src/PoolFactory.sol";
import "../src/PoolRouter.sol";
import "../src/LiquidityPool.sol";

contract PoolRouterTest is Test {
    Token       public uni;
    Token       public dai;
    WETH9       public weth;
    PoolFactory public factory;
    PoolRouter  public router;
    LiquidityPool public pool;
    LiquidityPool public poolEther;

    address public owner;
    address public supplier1;
    address public supplier2;
    address public trader1;
    address public trader2;
    address public notOwner;

    uint256 constant ZERO          = 0;
    uint256 constant ONE           = 1 ether;
    uint256 constant FIVE          = 5 ether;
    uint256 constant TEN           = 10 ether;
    uint256 constant FACTOR        = 100000;
    uint256 constant FEES          = 2000;
    uint256 constant INITIAL_TOKENS= 100 ether;
    uint256 constant INITIAL_WETH_TOKENS = 10000 ether;

    function setUp() public {
        owner      = address(this);
        supplier1  = address(1);
        supplier2  = address(2);
        trader1    = address(3);
        trader2    = address(4);
        notOwner   = address(5);

        vm.label(supplier1, "supplier1");
        vm.label(supplier2, "supplier2");
        vm.label(trader1,   "trader1");
        vm.label(trader2,   "trader2");
        vm.label(notOwner,  "notOwner");

        uni     = new Token("Uniswap Token", "UNI");
        dai     = new Token("DAI Token", "DAI");
        weth    = new WETH9();
        factory = new PoolFactory();
        router  = new PoolRouter(address(factory), address(weth));

        // Distribute tokens to test accounts
        uni.transfer(supplier1, INITIAL_TOKENS);
        uni.transfer(supplier2, INITIAL_TOKENS);
        uni.transfer(trader1,   INITIAL_TOKENS);
        uni.transfer(trader2,   INITIAL_TOKENS);
        dai.transfer(supplier1, INITIAL_TOKENS);
        dai.transfer(supplier2, INITIAL_TOKENS);
        dai.transfer(trader1,   INITIAL_TOKENS);
        dai.transfer(trader2,   INITIAL_TOKENS);
        vm.deal(supplier1, INITIAL_WETH_TOKENS);
        vm.deal(supplier2, INITIAL_WETH_TOKENS);
        vm.deal(trader1, INITIAL_WETH_TOKENS);
        vm.deal(trader2, INITIAL_WETH_TOKENS);

        // Approve router to spend tokens on behalf of all accounts
        address rt = address(router);
        vm.prank(supplier1); uni.approve(rt, INITIAL_TOKENS); vm.prank(supplier1); dai.approve(rt, INITIAL_TOKENS);
        vm.prank(supplier2); uni.approve(rt, INITIAL_TOKENS); vm.prank(supplier2); dai.approve(rt, INITIAL_TOKENS);
        vm.prank(trader1);   uni.approve(rt, INITIAL_TOKENS); vm.prank(trader1);   dai.approve(rt, INITIAL_TOKENS);
        vm.prank(trader2);   uni.approve(rt, INITIAL_TOKENS); vm.prank(trader2);   dai.approve(rt, INITIAL_TOKENS);
    }

    /// @dev Creates a UNI-DAI pool and returns its instance
    function _beforeAddingLiquidity() internal returns (LiquidityPool) {
        factory.createPool(address(uni), address(dai), FEES);
        address poolAddr = factory.getPoolAddress(address(uni), address(dai));
        // add zero-liquidity placeholder: approvals done in setUp
        return LiquidityPool(poolAddr);
    }

    /// @dev Adds initial liquidity of 5 UNI and 10 DAI by supplier1
    function _beforeSwappingTokens() internal returns (LiquidityPool) {
        pool = _beforeAddingLiquidity();
        vm.prank(supplier1);
        router.addTokenToTokenLiquidity(address(uni), address(dai), FIVE, TEN, 0, 0);
        return pool;
    }

    //--- Setup and Initialization ---
    function testOwnerIsSet() public view {
        assertEq(factory.owner(), owner);
    }

    function testAddLiquidity() public {
        pool = _beforeAddingLiquidity();
        vm.prank(supplier1);
        router.addTokenToTokenLiquidity(address(uni), address(dai), FIVE, TEN, 0, 0);
    }

    function testAddLiquidityReverse() public {
        pool = _beforeAddingLiquidity();
        vm.prank(supplier1);
        router.addTokenToTokenLiquidity(address(dai), address(uni), TEN, FIVE, 0, 0);
    }

    function testZeroAmountsRevert() public {
        pool = _beforeAddingLiquidity();
        vm.prank(supplier1);
        vm.expectRevert("TokenA amount is zero!");
        router.addTokenToTokenLiquidity(address(dai), address(uni), ZERO, TEN, 0, 0);
        vm.prank(supplier1);
        vm.expectRevert("TokenB amount is zero!");
        router.addTokenToTokenLiquidity(address(dai), address(uni), FIVE, ZERO, 0, 0);
    }

    function testZeroAddressRevert() public {
        pool = _beforeAddingLiquidity();
        vm.prank(supplier1);
        vm.expectRevert("token address should not be zero!");
        router.addTokenToTokenLiquidity(address(0), address(dai), FIVE, TEN, 0, 0);
    }

    //--- Swap Token Tests ---
    function testAmountOutCalculation() public {
        pool = _beforeSwappingTokens();
        // check reserves
        (uint r0, uint r1,) = pool.getLatestReserves();
        assertEq(uint256(r0), FIVE);
        assertEq(uint256(r1), TEN);

        uint256 outRouter = router.getPoolAmountOut(address(uni), address(dai), ONE);
        (, uint256 amountIn) = router.getAmountIn(ONE);
        uint256 inWithFee = amountIn * (FACTOR - FEES) / FACTOR;
        uint256 manualOut = uint256(r1) * inWithFee / (uint256(r0) + inWithFee);
        assertEq(outRouter, manualOut);
    }

    function testSwapTokenToToken() public {
        pool = _beforeSwappingTokens();
        vm.prank(trader1);
        router.swapTokenToToken(address(uni), address(dai), ONE, ZERO);
    }

    function testSwapBothDirections() public {
        pool = _beforeSwappingTokens();
        vm.prank(trader1);
        router.swapTokenToToken(address(dai), address(uni), ONE, ZERO);
    }

    function testSwapChangesBalance() public {
        pool = _beforeSwappingTokens();
        uint256 initDai = dai.balanceOf(trader1);
        uint256 amountOut = router.getPoolAmountOut(address(uni), address(dai), ONE);
        vm.prank(trader1);
        router.swapTokenToToken(address(uni), address(dai), ONE, ZERO);
        assertEq(dai.balanceOf(trader1) - initDai, amountOut);
    }

    function testOwnerReceivesFees() public {
        pool = _beforeSwappingTokens();
        uint256 totalTrade = ONE + FIVE + TEN;
        uint256 ownerFeeRate = router.ownerFees();
        uint256 expected = totalTrade * ownerFeeRate / FACTOR;

        uint256 beforeBal = dai.balanceOf(owner);
        // perform three swaps dai->uni
        vm.prank(trader1);
        router.swapTokenToToken(address(dai), address(uni), ONE, ZERO);
        vm.prank(trader2);
        router.swapTokenToToken(address(dai), address(uni), FIVE, ZERO);
        vm.prank(trader1);
        router.swapTokenToToken(address(dai), address(uni), TEN, ZERO);
        uint256 afterBal = dai.balanceOf(owner);
        assertEq(afterBal - beforeBal, expected);
    }

    //--- ETH <> Token Tests ---
    function _initEtherDaiPool() internal {
        // create a WETH-DAI pool
        factory.createPool(address(weth), address(dai), FEES);
        address p = factory.getPoolAddress(address(weth), address(dai));
        poolEther = LiquidityPool(p);

        // supplier1 funds WETH
        vm.prank(supplier1);
        weth.deposit{value: INITIAL_TOKENS}();
        vm.prank(supplier1);
        weth.approve(address(router), INITIAL_TOKENS);

        // add ETH+DAI liquidity: 10 ETH and 5 DAI
        vm.prank(supplier1);
        router.addLiquidityETH{value: TEN}(address(dai), FIVE, 0, 0);
    }

    function testSwapEthForTokens() public {
        _initEtherDaiPool();
        uint256 amountOut = router.getPoolAmountOut(address(weth), address(dai), ONE);
        uint256 balBefore = trader1.balance;
        vm.prank(trader1);
        router.swapETHForTokens{value: ONE}(address(dai), amountOut);
        uint256 balAfter = trader1.balance;

        assertEq(balBefore - balAfter, ONE);
    }

    function testValidateSharesAfterEthLiquidity() public {
        _initEtherDaiPool();
        // second supplier
        vm.prank(supplier2);
        weth.deposit{value: TEN}();
        vm.prank(supplier2);
        weth.approve(address(router), INITIAL_TOKENS);
        vm.prank(supplier2);
        router.addLiquidityETH{value: TEN}(address(dai), FIVE, 0, 0);

        uint256 s1 = poolEther.balanceOf(supplier1);
        uint256 s2 = poolEther.balanceOf(supplier2);
        uint256 total = poolEther.totalSupply();
        assertEq(total, s1 + s2);
    }

    function testSwapTokensForEth() public {
        _initEtherDaiPool();
        // trader1 needs DAI
        uint256 amountOut = router.getPoolAmountOut(address(dai), address(weth), FIVE);
        vm.prank(trader1);
        dai.approve(address(router), FIVE);
        uint256 balBefore = trader1.balance;
        vm.prank(trader1);
        router.swapTokensForETH(address(dai), FIVE, amountOut);
        uint256 balAfter = trader1.balance;
        assertEq(balAfter - balBefore, amountOut);
    }
}
