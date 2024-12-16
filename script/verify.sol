// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { Script, console2 } from "forge-std/Script.sol";
import { ISuperchainWETH } from "optimism/packages/contracts-bedrock/src/L2/interfaces/ISuperchainWETH.sol";

contract VerifyWETHBalanceScript is Script {
    address public constant SUPERCHAIN_WETH_TOKEN = 0x4200000000000000000000000000000000000024;
    address public constant SMART_DISPERSE_CONTRACT = 0xbD51694e536310631ab0163B94e5C509b4aC8C8F;
    
    address[] public recipients = [
        0x70997970C51812dc3A010C7d01b50e0d17dc79C8,
        0x3C44CdDdB6a900fa2b585dd299e03d12FA4293BC
    ];

    function run() external {
        // Select the OP2 (Chain 902) fork
        vm.createSelectFork(vm.envString("OP2_RPC"));
        
        // Create WETH token interface
        ISuperchainWETH wethToken = ISuperchainWETH(payable(SUPERCHAIN_WETH_TOKEN));
        
        // Log contract and recipient balances
        console2.log("WETH Token Address:", SUPERCHAIN_WETH_TOKEN);
        console2.log("Smart Disperse Contract:", SMART_DISPERSE_CONTRACT);
        
        console2.log("\nSmart Disperse Contract WETH Balance:");
        console2.log(wethToken.balanceOf(SMART_DISPERSE_CONTRACT));
        
        console2.log("\nRecipient Balances:");
        for (uint i = 0; i < recipients.length; i++) {
            console2.log("Recipient %s:", vm.toString(recipients[i]));
            console2.log(wethToken.balanceOf(recipients[i]));
        }
    }
}