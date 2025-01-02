# Smart-Disperse

Smart-Disperse is a cross-chain token dispersal solution that enables the seamless transfer of tokens between different chains using custom interoperability contracts.

---

## Table of Contents

1. [Overview](#overview)  
2. [Prerequisites](#prerequisites)  
3. [Setup](#setup)  
   - [Setting Up Interop Contracts](#setting-up-interop-contracts)  
4. [Testing and Using the Application](#testing-and-using-the-application)  
5. [Additional Information](#additional-information)  

---

## Overview

This project consists of custom interoperability contracts enabling cross-chain token operations.

---

## Prerequisites

Ensure the following are installed on your system:

- [Foundry](https://book.getfoundry.sh/getting-started/installation)  
- [Supersim](https://supersim.pages.dev/getting-started/installation) 

---

## Setup

### Cloning the Repository

Start by cloning the repository:

```bash
git clone https://github.com/Smart-Disperse/Interop-contracts
```

---

### Setting Up Interop Contracts

1. **Install Foundry and Supersim**:  
   - Follow the respective documentation to install Foundry and Supersim.

2. **Install Dependencies**:  
   Navigate to the `Interop-contracts` directory and run:  

   ```bash
   forge install
   ```

3. **Run Supersim**:  
   Open a new terminal, navigate to the project directory, and run:

   ```bash
   supersim --interop.autorelay
   ```

4. **Set Environment Variables**:  
   - Copy `.env-example` to `.env`.  
   - Modify the `.env` file with your configurations.

   Source the environment variables:

   ```bash
   source .env
   ```

5. **Deploy the Contracts**:  
   Deploy contracts to the respective chains:

   ```bash
   forge script script/deploy.s.sol --sig "deploy(string)" "OP1" --broadcast
   forge script script/deploy.s.sol --sig "deploy(string)" "OP2" --broadcast
   ```

   Copy the contract addresses generated during deployment and save them for later use. Do **not** close the terminal running the Supersim node.

---

## Testing and Using the Application

1. **WETH Token Setup**:  
   Import WETH into Metamask using the following address:  

   ```text
   0x4200000000000000000000000000000000000024
   ```

2. **Token Transfer Across Chains**:  
   When ETH is transferred cross-chain, WETH will be sent to the recipient on the destination chain.

3. **Mint WETH**:  
   To mint WETH to a specific address, set the private key of the desired address in your `.env` file and run:

   ```bash
   forge script script/MintWeth.s.sol --sig "mintWeth(string)" "OP1" --broadcast
   ```

   Replace `"OP1"` with `"OP2"` based on the target chain.

---

## Additional Information

- Keep the terminal running the Supersim node active at all times.  
- Test functionalities thoroughly to ensure smooth operation.  

---

Feel free to contribute or raise issues in the repository! 😊
