// script/DeployCounter.s.sol
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "../src/Counter.sol";

contract DeployCounter is Script {
    function run() external {
        // charge la clé privée passée en CLI
        vm.startBroadcast();
        new Counter();
        vm.stopBroadcast();
    }
}
