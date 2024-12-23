// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import { Script } from "forge-std/Script.sol";
import { SmartDisperse } from "../src/SmartDisperse.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { ISuperchainERC20 } from "optimism/packages/contracts-bedrock/src/L2/interfaces/ISuperchainERC20.sol";
import { console2 } from "forge-std/console2.sol";
import { ISuperchainWETH } from "optimism/packages/contracts-bedrock/src/L2/interfaces/ISuperchainWETH.sol";

contract DeployAndTransfer is Script {
    address payable constant SUPERCHAIN_WETH_TOKEN = payable(0x4200000000000000000000000000000000000024);
    
    // Test addresses for multiple chains
    address[][] chainRecipients = [
        // Chain 901 recipients
        [
            0x70997970C51812dc3A010C7d01b50e0d17dc79C8,
            0x3C44CdDdB6a900fa2b585dd299e03d12FA4293BC
        ],
        // Chain 902 recipients
        [
            0x90F79bf6EB2c4f870365E785982E1f101E93b906,
            0x15d34AAf54267DB7D7c367839AAf71A00a2C6A65
        ]
    ];

    uint256[][] chainAmounts = [
        // Chain 901 amounts
        [1 ether, 2 ether],
        // Chain 902 amounts
        [1.5 ether, 2.5 ether]
    ];

    uint256[] targetChainIds = [901, 902];

    function logBalances(uint256 chainId, ISuperchainWETH token, address[] memory recipients) internal view {
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
        
        // Deploy on Chain 901
        uint256 op1Fork = vm.createSelectFork(vm.envString("OP1_RPC"));
        console2.log("Deploying on Chain 901...");
        vm.startBroadcast(privateKey);

        SmartDisperse disperse901 = new SmartDisperse{salt: "SmartDisperse"}();

        // Mint WETH by sending ETH to the WETH contract
        uint256 totalAmount = 0;
        for (uint i = 0; i < chainAmounts.length; i++) {
            for (uint j = 0; j < chainAmounts[i].length; j++) {
                totalAmount += chainAmounts[i][j];
            }
        }

        (bool success, ) = SUPERCHAIN_WETH_TOKEN.call{value: totalAmount}("");
        require(success, "WETH minting failed!");
        uint256 userBalanceOfWETH = ISuperchainWETH(SUPERCHAIN_WETH_TOKEN).balanceOf(vm.addr(privateKey));
        console2.log("WETH balance: ", userBalanceOfWETH);

        vm.stopBroadcast();
        console2.log("SmartDisperse deployed on Chain 901 at:", address(disperse901));
        
        // Log initial balances for all chains
        for (uint i = 0; i < targetChainIds.length; i++) {
            uint256 fork = targetChainIds[i] == 901 ? op1Fork : vm.createSelectFork(vm.envString("OP2_RPC"));
            vm.selectFork(fork);
            ISuperchainWETH token = ISuperchainWETH(SUPERCHAIN_WETH_TOKEN);
            console2.log("\nInitial balances on Chain", targetChainIds[i]);
            logBalances(targetChainIds[i], token, chainRecipients[i]);
        }

        // Initiate multi-chain transfer from Chain 901
        vm.selectFork(op1Fork);
        console2.log("\nInitiating multi-chain transfer from Chain 901...");
        vm.startBroadcast(privateKey);
        
        console2.log("Total amount to transfer:", totalAmount);
        
        disperse901.crossChainDisperseNativeMultiChain{value: totalAmount}(
            targetChainIds,
            chainRecipients,
            chainAmounts,
            SUPERCHAIN_WETH_TOKEN
        );
        vm.stopBroadcast();
        console2.log("Multi-chain transfer initiated");

        // Log final balances for all chains
        for (uint i = 0; i < targetChainIds.length; i++) {
            uint256 fork = targetChainIds[i] == 901 ? op1Fork : vm.createSelectFork(vm.envString("OP2_RPC"));
            vm.selectFork(fork);
            ISuperchainWETH token = ISuperchainWETH(SUPERCHAIN_WETH_TOKEN);
            console2.log("\nFinal balances on Chain", targetChainIds[i]);
            console2.log("Balance of contract:", token.balanceOf(address(disperse901)));
            logBalances(targetChainIds[i], token, chainRecipients[i]);
        }
    }
}