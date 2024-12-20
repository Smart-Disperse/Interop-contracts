// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {Script} from "forge-std/Script.sol";
import {SmartDisperse} from "../src/SmartDisperse.sol";
import {console2} from "forge-std/console2.sol";

contract DeployContract is Script {
    function deploy(string memory chain) external {
        uint256 forkId = vm.createSelectFork(
            vm.envString(
                keccak256(bytes(chain)) == keccak256("OP1")
                    ? "OP1_RPC"
                    : "OP2_RPC"
            )
        );
        console2.log(
            "Deploying on",
            keccak256(bytes(chain)) == keccak256("OP1")
                ? "Chain 901"
                : "Chain 902"
        );

        vm.startBroadcast(vm.envUint("PRIVATE_KEY"));
        SmartDisperse disperse = new SmartDisperse{salt: "SmartDisperse"}();
        console2.log("SmartDisperse contract deployed at:", address(disperse));
    }
}

// For deployment on Chain 901 //
// forge script script/deploy.s.sol --sig "deploy(string)" "OP1" --broadcast

// For deployment on Chain 902 //
// forge script script/deploy.s.sol --sig "deploy(string)" "OP2" --broadcast
