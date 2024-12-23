// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import { Script } from "forge-std/Script.sol";
import { SmartDisperse } from "../src/SmartDisperse.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { ISuperchainERC20 } from "optimism/packages/contracts-bedrock/src/L2/interfaces/ISuperchainERC20.sol";
import { console2 } from "forge-std/console2.sol";
import { ISuperchainWETH } from "optimism/packages/contracts-bedrock/src/L2/interfaces/ISuperchainWETH.sol";

contract DeployAndTransferMultiChain is Script {
    address payable constant SUPERCHAIN_WETH_TOKEN = payable(0x4200000000000000000000000000000000000024);
    address public constant SMART_DISPERSE_CONTRACT = 0xBaeD153B8081feE1648bBD55A11749a00e462b99;
;
    
    function logBalances(uint256 chainId, ISuperchainWETH token, address[] memory recipients) internal view {
        console2.log("\nBalances on Chain", chainId);
        console2.log("----------------------------------------");
        for (uint i = 0; i < recipients.length; i++) {
            console2.log(
                string.concat("Address ", vm.toString(recipients[i]), ": "),
                token.balanceOf(recipients[i])
            );
        }
        console2.log("----------------------------------------\n");
    }

    function run() external {
        uint256 privateKey = vm.envUint("PRIVATE_KEY");
        
        // Deploy on source chain (OP)
        uint256 opFork = vm.createSelectFork("http://127.0.0.1:9545"); // OP RPC from supersim
        console2.log("Deploying on Optimism...");
        vm.startBroadcast(privateKey);

        SmartDisperse disperseOP = SmartDisperse(SMART_DISPERSE_CONTRACT);
        // SmartDisperse disperseOP = new SmartDisperse{salt: "SmartDisperse"}();
        console2.log("Deployed SmartDisperse on Optimism:", address(disperseOP));

        // Create CrossChainTransfer array
        SmartDisperse.CrossChainTransfer[] memory transfers = new SmartDisperse.CrossChainTransfer[](2);
        
        // Base transfer
        transfers[0] = SmartDisperse.CrossChainTransfer({
            chainId: 8453,
            recipients: new address[](2),
            amounts: new uint256[](2)
        });
        transfers[0].recipients[0] = 0x90F79bf6EB2c4f870365E785982E1f101E93b906;
        transfers[0].recipients[1] = 0x15d34AAf54267DB7D7c367839AAf71A00a2C6A65;
        transfers[0].amounts[0] = 1.5 ether;
        transfers[0].amounts[1] = 2.5 ether;
        
        // Zora transfer
        transfers[1] = SmartDisperse.CrossChainTransfer({
            chainId: 7777777,
            recipients: new address[](2),
            amounts: new uint256[](2)
        });
        transfers[1].recipients[0] = 0x9965507D1a55bcC2695C58ba16FB37d819B0A4dc;
        transfers[1].recipients[1] = 0x976EA74026E726554dB657fA54763abd0C3a0aa9;
        transfers[1].amounts[0] = 1 ether;
        transfers[1].amounts[1] = 3 ether;

        // Calculate total amount
        uint256 totalAmount = 0;
        for (uint i = 0; i < transfers.length; i++) {
            for (uint j = 0; j < transfers[i].amounts.length; j++) {
                totalAmount += transfers[i].amounts[j];
            }
        }

        // Log initial balances
        ISuperchainWETH tokenOP = ISuperchainWETH(SUPERCHAIN_WETH_TOKEN);
        console2.log("\nInitial balances on OP:");
        vm.stopBroadcast();

        // Check Base balances
        uint256 baseFork = vm.createSelectFork("http://127.0.0.1:9546");
        vm.startBroadcast(privateKey);

        SmartDisperse disperseBase = SmartDisperse(SMART_DISPERSE_CONTRACT);
        // SmartDisperse disperseBase = new SmartDisperse{salt: "SmartDisperse"}();
        ISuperchainWETH tokenBase = ISuperchainWETH(SUPERCHAIN_WETH_TOKEN);
        console2.log("\nInitial balances on Base:");
        logBalances(8453, tokenBase, transfers[0].recipients);
        vm.stopBroadcast();

        // Check Zora balances
        uint256 zoraFork = vm.createSelectFork("http://127.0.0.1:9547");
        vm.startBroadcast(privateKey);

        SmartDisperse disperseZora = SmartDisperse(SMART_DISPERSE_CONTRACT);
        // SmartDisperse disperseZora = new SmartDisperse{salt: "SmartDisperse"}();
        ISuperchainWETH tokenZora = ISuperchainWETH(SUPERCHAIN_WETH_TOKEN);
        console2.log("\nInitial balances on Zora:");
        logBalances(7777777, tokenZora, transfers[1].recipients);
        vm.stopBroadcast();

        // Switch back to OP to initiate transfer
        vm.selectFork(opFork);
        vm.startBroadcast(privateKey);

        console2.log("\nInitiating multi-chain transfer from Optimism...");
        
        // Initiate multi-chain transfer with new interface
        disperseOP.crossChainDisperseNativeMultiChain{value: totalAmount}(
            transfers,
            SUPERCHAIN_WETH_TOKEN
        );

        vm.roll(block.number + 1);

        vm.stopBroadcast();
        console2.log("Multi-chain transfer initiated");

        // Log final balances
        vm.selectFork(baseFork);
        console2.log("\nFinal balances on Base:");
        logBalances(8453, tokenBase, transfers[0].recipients);

        vm.selectFork(zoraFork);
        console2.log("\nFinal balances on Zora:");
        logBalances(7777777, tokenZora, transfers[1].recipients);
    }
}