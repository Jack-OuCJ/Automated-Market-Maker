// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Script.sol";
import { Token } from "../src/utils/Token.sol";
import { WETH9 } from "../src/utils/WETH.sol";
import { PoolFactory } from "../src/PoolFactory.sol";
import { PoolRouter } from "../src/PoolRouter.sol";

// Used for one-click deployment of Token, WETH9, PoolFactory, and PoolRouter on Foundry, and printing their addresses.
contract DeployScript is Script {
    function run() external {
        vm.startBroadcast();

        Token dai     = new Token("DAI Token", "DAI");
        Token bat     = new Token("BAT Token", "BAT");
        Token uni     = new Token("UNI Token", "UNI");
        WETH9 weth    = new WETH9();
        PoolFactory factory = new PoolFactory();
        PoolRouter router   = new PoolRouter(address(factory), address(weth));

        vm.stopBroadcast();

        console.log("const daiAddress     = \"%s\";", vm.toString(address(dai)));
        console.log("const batAddress     = \"%s\";", vm.toString(address(bat)));
        console.log("const uniAddress     = \"%s\";", vm.toString(address(uni)));
        console.log("const wethAddress    = \"%s\";", vm.toString(address(weth)));
        console.log("const factoryAddress = \"%s\";", vm.toString(address(factory)));
        console.log("const routerAddress  = \"%s\";", vm.toString(address(router)));
    }
}
