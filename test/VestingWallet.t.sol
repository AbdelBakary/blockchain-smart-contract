// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/VestingWallet.sol";

/// @notice Faux token ERC20 pour les tests
contract MockERC20 {
    string public name = "Mock Token";
    string public symbol = "MOCK";
    uint8 public decimals = 18;

    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

    function mint(address to, uint256 amount) external {
        balanceOf[to] += amount;
    }

    function approve(address spender, uint256 amount) external returns (bool) {
        allowance[msg.sender][spender] = amount;
        return true;
    }

    function transfer(address to, uint256 amount) external returns (bool) {
        require(balanceOf[msg.sender] >= amount, "Insufficient balance");
        balanceOf[msg.sender] -= amount;
        balanceOf[to] += amount;
        return true;
    }

    function transferFrom(
        address from,
        address to,
        uint256 amount
    ) external returns (bool) {
        require(balanceOf[from] >= amount, "Insufficient balance");
        require(allowance[from][msg.sender] >= amount, "Not allowed");

        allowance[from][msg.sender] -= amount;
        balanceOf[from] -= amount;
        balanceOf[to] += amount;
        return true;
    }
}

contract VestingWalletTest is Test {
    VestingWallet vestingWallet;
    MockERC20 token;

    address owner = address(this);
    address beneficiary = address(0xBEEF);

    uint256 constant TOTAL_AMOUNT = 1000 ether;
    uint256 cliff;
    uint256 duration;

    function setUp() public {
        token = new MockERC20();
        vestingWallet = new VestingWallet(address(token));

        token.mint(owner, TOTAL_AMOUNT);
        token.approve(address(vestingWallet), TOTAL_AMOUNT);

        cliff = block.timestamp + 10;
        duration = 100;
    }

    /// Création du vesting
    function testCreateVestingSchedule() public {
        vestingWallet.createVestingSchedule(
            beneficiary,
            TOTAL_AMOUNT,
            cliff,
            duration
        );

        (
            address storedBeneficiary,
            uint256 storedCliff,
            uint256 storedDuration,
            uint256 storedTotal,
            uint256 released
        ) = vestingWallet.vestingSchedules(beneficiary);

        assertEq(storedBeneficiary, beneficiary);
        assertEq(storedCliff, cliff);
        assertEq(storedDuration, duration);
        assertEq(storedTotal, TOTAL_AMOUNT);
        assertEq(released, 0);
    }

    /// Réclamer avant le cliff → revert attendu
    function test_RevertIf_ClaimBeforeCliff() public {
        vestingWallet.createVestingSchedule(
            beneficiary,
            TOTAL_AMOUNT,
            cliff,
            duration
        );

        vm.warp(cliff - 1);
        vm.prank(beneficiary);

        vm.expectRevert("No tokens available");
        vestingWallet.claimVestedTokens();
    }

    /// Réclamer pendant le vesting
    function testClaimDuringVesting() public {
        vestingWallet.createVestingSchedule(
            beneficiary,
            TOTAL_AMOUNT,
            cliff,
            duration
        );

        vm.warp(cliff + duration / 2);
        vm.prank(beneficiary);
        vestingWallet.claimVestedTokens();

        uint256 balance = token.balanceOf(beneficiary);
        assertApproxEqAbs(balance, TOTAL_AMOUNT / 2, 1);
    }

    /// Réclamer après la fin du vesting
    function testClaimAfterVestingEnd() public {
        vestingWallet.createVestingSchedule(
            beneficiary,
            TOTAL_AMOUNT,
            cliff,
            duration
        );

        vm.warp(cliff + duration + 1);
        vm.prank(beneficiary);
        vestingWallet.claimVestedTokens();

        uint256 balance = token.balanceOf(beneficiary);
        assertEq(balance, TOTAL_AMOUNT);
    }
}
