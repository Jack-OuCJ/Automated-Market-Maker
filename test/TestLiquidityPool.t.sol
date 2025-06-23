// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import "../src/utils/Token.sol";
import "../src/LiquidityPool.sol";

contract LiquidityPoolTest is Test {
    LiquidityPool public dexPool;
    Token public uni;
    Token public dai;

    address public owner;
    address public supplier1;
    address public trader1;
    address public notOwner;

    uint256 constant ZERO = 0;
    uint256 constant ONE = 1 ether;
    uint256 constant FIVE = 5 ether;
    uint256 constant TEN = 10 ether;
    uint256 constant FEES = 2000;
    uint256 constant INITIAL_TOKENS = 100 ether;

    function setUp() public {
        owner     = address(this);
        supplier1 = address(1);
        trader1   = address(2);
        notOwner  = address(3);

        vm.label(supplier1, "supplier1");
        vm.label(trader1, "trader1");
        vm.label(notOwner, "notOwner");

        uni = new Token("Uniswap Token", "UNI");
        dai = new Token("DAI Token", "DAI");
        dexPool = new LiquidityPool();
    }

    function _initializePool() internal {
        // only owner can initialize
        dexPool.initPool(address(dai), address(uni), FEES);

        // distribute tokens
        dai.transfer(supplier1, INITIAL_TOKENS);
        uni.transfer(supplier1, INITIAL_TOKENS);
        dai.transfer(trader1, INITIAL_TOKENS);
        uni.transfer(trader1, INITIAL_TOKENS);

        // approve dexPool
        vm.prank(supplier1);
        dai.approve(address(dexPool), INITIAL_TOKENS);
        vm.prank(supplier1);
        uni.approve(address(dexPool), INITIAL_TOKENS);
        vm.prank(trader1);
        dai.approve(address(dexPool), INITIAL_TOKENS);
        vm.prank(trader1);
        uni.approve(address(dexPool), INITIAL_TOKENS);

        // initial liquidity deposit
        vm.prank(supplier1);
        dai.transfer(address(dexPool), FIVE);
        vm.prank(supplier1);
        uni.transfer(address(dexPool), TEN);
    }

    // Test setup and initialization
    function testOnlyOwnerCanInit() public {
        vm.prank(notOwner);
        vm.expectRevert(
            abi.encodeWithSignature(
                "OwnableUnauthorizedAccount(address)",
                notOwner
            )
        );
        dexPool.initPool(address(dai), address(uni), FEES);
    }

    function testCannotInitWithZeroAddresses() public {
        vm.expectRevert("zero address not allowed!");
        dexPool.initPool(address(0), address(uni), FEES);

        vm.expectRevert("zero address not allowed!");
        dexPool.initPool(address(dai), address(0), FEES);
    }

    function testValidateUsersFundsAfterInit() public {
        _initializePool();
        assertEq(dai.balanceOf(supplier1), INITIAL_TOKENS - FIVE);
        assertEq(uni.balanceOf(supplier1), INITIAL_TOKENS - TEN);
        assertEq(dai.balanceOf(address(dexPool)), FIVE);
        assertEq(uni.balanceOf(address(dexPool)), TEN);
    }

    function testCannotInitTwice() public {
        _initializePool();
        vm.expectRevert("initialization not allowed!");
        dexPool.initPool(address(dai), address(uni), FEES);
    }

    function testOwnerIsDeployer() public view {
        assertEq(dexPool.owner(), owner);
    }

    // Validate fee management
    function testSetZeroFees() public {
        _initializePool();
        dexPool.setPoolFees(ZERO);
        assertEq(dexPool.fees(), ZERO);
    }

    function testNonOwnerCannotSetFees() public {
        _initializePool();
        vm.prank(notOwner);
        vm.expectRevert(
            abi.encodeWithSignature(
                "OwnableUnauthorizedAccount(address)",
                notOwner
            )
        );
        dexPool.setPoolFees(1);
    }

    function testCannotSetSameFees() public {
        _initializePool();
        vm.expectRevert("fees should be different!");
        dexPool.setPoolFees(FEES);
    }

    // Test core pool functionality
    function testAddLiquidity() public {
        _initializePool();
        vm.prank(supplier1);
        dexPool.addLiquidity(supplier1);
    }

    function testSwapTokensNoRevert() public {
        _initializePool();
        vm.prank(supplier1);
        dexPool.addLiquidity(supplier1);

        uint256 tokensOut = dexPool.getAmountOut(address(uni), ONE);

        vm.prank(trader1);
        uni.transfer(address(dexPool), ONE);
        vm.prank(trader1);
        dexPool.swapTokens(tokensOut, trader1, address(uni));
    }

    function testSwapWithFeesChangesBalance() public {
        _initializePool();
        uint256 uniInit = uni.balanceOf(trader1);
        uint256 daiInit = dai.balanceOf(trader1);

        vm.prank(supplier1);
        dexPool.addLiquidity(supplier1);

        uint256 tokensOut = dexPool.getAmountOut(address(uni), ONE);
        vm.prank(trader1);
        uni.transfer(address(dexPool), ONE);
        vm.prank(trader1);
        dexPool.swapTokens(tokensOut, trader1, address(uni));

        assertEq(dai.balanceOf(trader1), tokensOut + daiInit);
        assertEq(uni.balanceOf(trader1), uniInit - ONE);

        uint256 shares = dexPool.balanceOf(supplier1);
        assertEq(dexPool.totalSupply(), shares);
    }

    function testValidateAmountsPostSwap() public {
        _initializePool();
        uint256 uniInit = uni.balanceOf(trader1);
        uint256 daiInit = dai.balanceOf(trader1);

        vm.prank(supplier1);
        dexPool.addLiquidity(supplier1);

        uint256 tokensOut = dexPool.getAmountOut(address(uni), ONE);
        vm.prank(trader1);
        uni.transfer(address(dexPool), ONE);
        vm.prank(trader1);
        dexPool.swapTokens(tokensOut, trader1, address(uni));

        assertEq(uni.balanceOf(trader1), uniInit - ONE);
        assertEq(dai.balanceOf(trader1) - daiInit, tokensOut);
    }

    function testRemoveAllLiquidity() public {
        _initializePool();

        vm.prank(supplier1);
        uint256 shares = dexPool.addLiquidity(supplier1);

        uint256 totalSupply = dexPool.totalSupply();
        assertEq(totalSupply, shares);

        vm.prank(supplier1);
        dexPool.approve(address(this), shares);
        vm.prank(address(this));
        dexPool.transferFrom(supplier1, address(dexPool), shares);

        vm.prank(supplier1);
        dexPool.removeLiquidity(supplier1);

        assertEq(dexPool.balanceOf(supplier1), ZERO);
        assertEq(dexPool.totalSupply(), ZERO);
    }
}
