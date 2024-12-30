// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {Script} from "forge-std/Script.sol";
import {SmartDisperse} from "../src/SmartDisperse.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ISuperchainERC20} from "optimism/packages/contracts-bedrock/src/L2/interfaces/ISuperchainERC20.sol";
import {console2} from "forge-std/console2.sol";
import {ISuperchainWETH} from "optimism/packages/contracts-bedrock/src/L2/interfaces/ISuperchainWETH.sol";

contract TestnetDeploy is Script {
    function run() external {
        vm.startBroadcast();
        SmartDisperse disperse = new SmartDisperse{salt: "SmartDisperse"}();
        vm.stopBroadcast();

        console2.log("SmartDisperse deployed at:", address(disperse));
    }
}
