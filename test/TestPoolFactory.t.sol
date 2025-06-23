// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import "../src/utils/Token.sol";
import "../src/PoolFactory.sol";
import "../src/LiquidityPool.sol";

contract PoolFactoryTest is Test {
    Token public uni;
    Token public dai;
    PoolFactory public factory;

    address public owner;
    address public supplier1;
    address public trader1;
    address public notOwner;

    uint256 constant ZERO = 0;
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

        uni     = new Token("Uniswap Token", "UNI");
        dai     = new Token("DAI Token", "DAI");
        factory = new PoolFactory();
    }

    function _initializePool() internal {
        dai.transfer(supplier1, INITIAL_TOKENS);
        uni.transfer(supplier1, INITIAL_TOKENS);
        dai.transfer(trader1, INITIAL_TOKENS);
        uni.transfer(trader1, INITIAL_TOKENS);
    }

    // 1. Test contract owner is set correctly
    function testOwnerIsSet() public view {
        assertEq(factory.owner(), owner);
    }

    // 2. Test creating a new trading pair
    function testCreatePair() public {
        _initializePool(); // Not required for factory, but keeps consistency
        assertEq(factory.allPoolsLength(), ZERO);
        assertFalse(factory.poolExists(address(uni), address(dai)));

        factory.createPool(address(uni), address(dai), FEES);

        assertEq(factory.allPoolsLength(), 1);
        assertTrue(factory.poolExists(address(uni), address(dai)));
        assertTrue(factory.poolExists(address(dai), address(uni)));
    }

    // 3. Test pool contract initialization status
    function testInitializeDexPool() public {
        _initializePool();
        factory.createPool(address(uni), address(dai), FEES);

        address poolAddr = factory.getPoolAddress(address(uni), address(dai));
        LiquidityPool lp = LiquidityPool(poolAddr);

        assertTrue(lp.initialized());
        assertEq(lp.owner(), owner);
    }

    // 4. Validate initial getPoolAddress and token0/token1
    function testValidatePairAddress() public {
        _initializePool();
        address initialAddr = factory.getPoolAddress(address(uni), address(dai));
        assertEq(initialAddr, address(0));
        assertFalse(factory.poolExists(address(uni), address(dai)));

        factory.createPool(address(uni), address(dai), FEES);
        address poolAddr = factory.getPoolAddress(address(uni), address(dai));
        LiquidityPool lp = LiquidityPool(poolAddr);

        assertEq(address(lp.token0()), address(uni));
        assertEq(address(lp.token1()), address(dai));
    }

    // 5. Ensure bidirectional retrieval returns the same pool
    function testPoolCreationBothWays() public {
        _initializePool();
        factory.createPool(address(uni), address(dai), FEES);

        address r = factory.getPoolAddress(address(uni), address(dai));
        address l = factory.getPoolAddress(address(dai), address(uni));

        assertEq(r, l);
    }
}
