// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "../src/VestingWallet.sol";

/// @notice Faux token ERC20 déployé pour le testnet
/// (version minimale suffisante pour le vesting)
contract MockERC20 {
    string public name = "Mock Token";
    string public symbol = "MOCK";
    uint8 public decimals = 18;

    mapping(address => uint256) public balanceOf;

    function mint(address to, uint256 amount) external {
        balanceOf[to] += amount;
    }

    function transfer(address to, uint256 amount) external returns (bool) {
        require(balanceOf[msg.sender] >= amount, "Insufficient balance");
        balanceOf[msg.sender] -= amount;
        balanceOf[to] += amount;
        return true;
    }

    function approve(address, uint256) external pure returns (bool) {
        return true;
    }

    function transferFrom(address from, address to, uint256 amount) external returns (bool) {
        require(balanceOf[from] >= amount, "Insufficient balance");
        balanceOf[from] -= amount;
        balanceOf[to] += amount;
        return true;
    }
}

contract DeployVestingWallet is Script {
    function run() external {
        vm.startBroadcast();

        // 1️⃣ Déploiement du token ERC20
        MockERC20 token = new MockERC20();

        // 2️⃣ Déploiement du VestingWallet avec l'adresse du token
        VestingWallet vestingWallet = new VestingWallet(address(token));

        // 3️⃣ Mint de tokens pour le deployer (optionnel mais utile)
        token.mint(msg.sender, 1_000_000 ether);

        vm.stopBroadcast();

        console.log("MockERC20 deployed at:", address(token));
        console.log("VestingWallet deployed at:", address(vestingWallet));
    }
}
