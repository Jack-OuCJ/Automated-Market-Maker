# Automated Market Maker (AMM) Project
This repository contains a sample of an Automated Market Maker (AMM) developed to show my skills as a Smart Contract developer with Solidity. The architecture of the project is based on the UniswapV2 protocol and implements the constant product model. The project was developed using Foundry, Openzeppelin-contracts.<br />

These are the addresses of the contracts deployed on the **Sepolia** test network:

**PoolRouter**: [0x812bc3a9c9E931Ecf4dfC206e4b5251D373A056f](https://sepolia.etherscan.io/address/0x812bc3a9c9E931Ecf4dfC206e4b5251D373A056f#code)

**PoolFactory**: [0xC2Dd5C339c51dD4DDE011D7903b819C4a6a1D985](https://sepolia.etherscan.io/address/0xC2Dd5C339c51dD4DDE011D7903b819C4a6a1D985#code)

## Smart Contracts ##
1.**LiquidityPool**: This smart contract represents a generic liquidity pool. <br />

2.**PoolFactory**: The pool factory manage and creates different liquidity pools. <br />

3.**PoolRouter**: The router is the contract designed to interact with the pool factory and the liquidity pools. <br />

## Installation and Deployment ##
To execute the project run the following commands:
```
forge build
```
Remeber that you need to modify .env file and configure smart contract addresses for the Sepolia Network. [Alchemy](https://www.alchemy.com/) and [Infura](https://www.infura.io/) are very popular service providers. To deploy the contracts to the Sepolia test network follow the next steps:

```
forge script script/Deploy.s.sol --rpc-url=$Sepolia-RPC-URL --broadcast --private-key $key
```
Now copy the smart contract addresses into the .env file. To create a sample liquidity pool and initialize it execute the following command:

```
forge script script/Initialize.s.sol --rpc-url=$Sepolia-RPC-URL --broadcast --private-key $key
```
After this step you created a new pool and you also added liquidity.

If you want to run tests based on the existing deployment, you can enter the following command.
```aiignore
forge test --fork-url $Sepolia-RPC-URL
```
These are the [transaction details](https://sepolia.etherscan.io/tx/0xc58b99c41893ab118e02cd71c21bc87b685f4778033f442d3e33b63658ccb885) of swapping Uni and Dai test tokens on the Sepolia network.

## Features ##
These are some of the most important features implemented:
* Swapping Token to Token  
* Swapping Ether to Token.
* Create new pools.
* Add and remove liquidity.
* Manage shares.
* Implements the constant product model of UniswapV2.
* Allows swap of tokens with different number of decimals.
* Testing

> [!NOTE]
> Please observe that these contracts are not ready for a production environment. It is necessary to add more functionality and testing.