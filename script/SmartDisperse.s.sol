// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import { Script } from "forge-std/Script.sol";
import { SmartDisperse } from "../src/SmartDisperse.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { ISuperchainERC20 } from "optimism/packages/contracts-bedrock/src/L2/interfaces/ISuperchainERC20.sol";
import { console2 } from "forge-std/console2.sol";
import { ISuperchainWETH } from "optimism/packages/contracts-bedrock/src/L2/interfaces/ISuperchainWETH.sol";

struct CrossChainTransfer {
    uint256 chainId;
    address[] recipients;
    uint256[] amounts;
}

/// @notice Structure to hold transfer details for cross-chain token distribution
struct TransferMessage {
    address[] recipients; // Addresses of the recipients
    uint256[] amounts;    // Amounts to be sent to each recipient
    address tokenAddress;  // Address of the token being transferred
    uint256 totalAmount;   // Total amount of tokens to be distributed
}


contract DeployAndTransfer is Script {
    address payable constant SUPERCHAIN_WETH_TOKEN = payable(0x4200000000000000000000000000000000000024);
    address public constant SMART_DISPERSE_CONTRACT = 0xBaeD153B8081feE1648bBD55A11749a00e462b99;
    
    
    // Test addresses (replace with actual addresses)
    address[] recipients = [
        0x70997970C51812dc3A010C7d01b50e0d17dc79C8,
        0x3C44CdDdB6a900fa2b585dd299e03d12FA4293BC
    ];
    uint256[] amounts = [1 ether, 2 ether]; // Using ether for decimal conversion

    function logBalances(uint256 chainId, ISuperchainWETH token) internal view {
        console2.log("\nBalances on Chain", chainId);
        console2.log("----------------------------------------");
        for (uint i = 0; i < recipients.length; i++) {
            console2.log(
                token.balanceOf(recipients[i])
            );
        }
        console2.log("----------------------------------------\n");
    }

    function run() external {
        uint256 privateKey = vm.envUint("PRIVATE_KEY");
        
        // Deploy and check balances on Chain 901
        uint256 op1Fork = vm.createSelectFork(vm.envString("OP1_RPC"));
        console2.log("Deploying on Chain 901...");
        vm.startBroadcast(privateKey);

        SmartDisperse disperse901 = SmartDisperse(SMART_DISPERSE_CONTRACT);
        // SmartDisperse disperse901 = new SmartDisperse{salt: "SmartDisperse"}();

        // Mint WETH by sending ETH to the WETH contract
        (bool success, ) = SUPERCHAIN_WETH_TOKEN.call{value: 10 ether}("");
        require(success, "WETH minting failed!");
        uint256 userBalanceOfWETH = ISuperchainWETH(SUPERCHAIN_WETH_TOKEN).balanceOf(vm.addr(privateKey));
        console2.log("WETH balance: ", userBalanceOfWETH);

        vm.stopBroadcast();
        console2.log("SmartDisperse deployed on Chain 901 at:", address(disperse901));
        
        ISuperchainWETH token901 = ISuperchainWETH(SUPERCHAIN_WETH_TOKEN);
        console2.log("\nInitial balances on Chain 901:");
        logBalances(901, token901);

        // Deploy and check balances on Chain 902
        uint256 op2Fork = vm.createSelectFork(vm.envString("OP2_RPC"));
        console2.log("Deploying on Chain 902...");
        vm.startBroadcast(privateKey);
        SmartDisperse disperse902 = SmartDisperse(SMART_DISPERSE_CONTRACT);
        // SmartDisperse disperse902 = new SmartDisperse{salt: "SmartDisperse"}();
        console2.log("SmartDisperse deployed on Chain 902 at:", address(disperse902));
        vm.stopBroadcast();

        ISuperchainWETH token902 = ISuperchainWETH(SUPERCHAIN_WETH_TOKEN);
        console2.log("\nInitial balances on Chain 902:");
        logBalances(902, token902);


        // Transfer tokens from Chain 901 to Chain 902
        vm.selectFork(op1Fork);
        console2.log("\nInitiating transfer from Chain 901 to Chain 902...");
        vm.startBroadcast(privateKey);
        
        // Calculate total amount needed
        uint256 totalAmount = 0;
        for (uint i = 0; i < amounts.length; i++) {
            totalAmount += amounts[i];
        }
        console2.log("Total amount to transfer:", totalAmount);
        
        disperse901.crossChainDisperseNative{value: totalAmount}(902, recipients, amounts);
        vm.roll(block.number + 1);
        vm.stopBroadcast();
        console2.log("Transfer initiated");

        // Wait for a few blocks to ensure transfer completion

        // Check final balances on Chain 902
        vm.selectFork(op2Fork);
        console2.log("\nFinal balances on Chain 902:");
        console2.log("Balance of contract 902 :", token901.balanceOf(address(disperse901)));
        logBalances(902, token902);
    }
}