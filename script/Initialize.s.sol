// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Script.sol";
import { Token } from "../src/utils/Token.sol";
import { WETH9 } from "../src/utils/WETH.sol";
import { PoolFactory } from "../src/PoolFactory.sol";
import { PoolRouter } from "../src/PoolRouter.sol";
import { LiquidityPool } from "../src/LiquidityPool.sol";

// One-click authorization, pool creation, and liquidity addition script for Foundry
contract SetupLiquidityScript is Script {
    uint256 constant FEES = 2000;
    uint256 constant FIFTY = 50 ether;
    uint256 constant ONEHUNDRED = 100 ether;
    uint256 constant INITIAL_TOKENS = 10000 ether;

    function run() external {
        vm.startBroadcast();

        // Core addresses
        address factoryAddr = vm.envAddress("FACTORY_ADDR");
        address payable routerAddr = payable(vm.envAddress("ROUTER_ADDR"));

        // Tokens: [0]=DAI, [1]=BAT, [2]=UNI, [3]=WETH
        address payable[4] memory tks = [
            payable(vm.envAddress("DAI_ADDR")),
            payable(vm.envAddress("BAT_ADDR")),
            payable(vm.envAddress("UNI_ADDR")),
            payable(vm.envAddress("WETH_ADDR"))
        ];

        // Approve all tokens for router in a single loop
        for (uint i = 0; i < tks.length; ++i) {
            Token(tks[i]).approve(routerAddr, INITIAL_TOKENS);
        }
        console.log("Tokens approved");

        // Create UNI-DAI pool
        PoolFactory(factoryAddr).createPool(tks[2], tks[0], FEES);
        uint256 pools = PoolFactory(factoryAddr).allPoolsLength();
        console.log("Pools count:", pools);

        // Fetch and log new pool address
        address poolAddr = PoolFactory(factoryAddr).getPoolAddress(tks[2], tks[0]);
        console.log("New pool address:", poolAddr);

        // Add liquidity UNI → DAI
        PoolRouter(routerAddr).addTokenToTokenLiquidity(
            tks[2], tks[0], FIFTY, ONEHUNDRED, 0, 0
        );
        console.log("Liquidity added");

        vm.stopBroadcast();
    }
}