// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {Script} from "forge-std/Script.sol";
import {SmartDisperse} from "../src/SmartDisperse.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ISuperchainERC20} from "optimism/packages/contracts-bedrock/src/L2/interfaces/ISuperchainERC20.sol";
import {console2} from "forge-std/console2.sol";
import {ISuperchainWETH} from "optimism/packages/contracts-bedrock/src/L2/interfaces/ISuperchainWETH.sol";

contract DeployAndTransfer is Script {
    address payable constant SUPERCHAIN_WETH_TOKEN =
        payable(0x4200000000000000000000000000000000000024);

    function mintWeth(string memory chain) external {
        uint256 privateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(privateKey);

        vm.createSelectFork(
            vm.envString(
                keccak256(bytes(chain)) == keccak256("OP1")
                    ? "OP1_RPC"
                    : "OP2_RPC"
            )
        );
        console2.log(
            "Minting on",
            keccak256(bytes(chain)) == keccak256("OP1")
                ? "Chain 901"
                : "Chain 902"
        );

        vm.startBroadcast(privateKey);

        // Mint WETH by sending ETH to the WETH contract
        (bool success, ) = SUPERCHAIN_WETH_TOKEN.call{value: 10 ether}("");
        require(success, "WETH minting failed!");

        uint256 userBalanceOfWETH = ISuperchainWETH(SUPERCHAIN_WETH_TOKEN)
            .balanceOf(vm.addr(privateKey));
        console2.log("WETH balance: ", userBalanceOfWETH);

        vm.stopBroadcast();
    }
}

// For minting on Chain 901 //
//forge script script/MintWeth.s.sol --sig "mintWeth(string)" "OP1" --broadcast

// For minting on Chain 902 //
//forge script script/MintWeth.s.sol --sig "mintWeth(string)" "OP2" --broadcast
