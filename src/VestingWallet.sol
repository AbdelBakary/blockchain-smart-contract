// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

contract VestingWallet is Ownable, ReentrancyGuard {

    struct VestingSchedule {
        address beneficiary;
        uint256 cliff;          // timestamp Unix
        uint256 duration;       // en secondes
        uint256 totalAmount;    // total de tokens à libérer
        uint256 releasedAmount; // déjà réclamé
    }

    IERC20 public immutable token;
    mapping(address => VestingSchedule) public vestingSchedules;

    constructor(address tokenAddress) Ownable(msg.sender) {
        require(tokenAddress != address(0), "Invalid token address");
        token = IERC20(tokenAddress);
    }

    function createVestingSchedule(
        address _beneficiary,
        uint256 _totalAmount,
        uint256 _cliff,
        uint256 _duration
    ) public onlyOwner {

        require(_beneficiary != address(0), "Invalid beneficiary");
        require(_totalAmount > 0, "Amount must be > 0");
        require(_duration > 0, "Duration must be > 0");
        require(_cliff >= block.timestamp, "Cliff must be in the future");
        require(
            vestingSchedules[_beneficiary].totalAmount == 0,
            "Vesting already exists"
        );

        // Enregistrement du vesting
        vestingSchedules[_beneficiary] = VestingSchedule({
            beneficiary: _beneficiary,
            cliff: _cliff,
            duration: _duration,
            totalAmount: _totalAmount,
            releasedAmount: 0
        });

        // Transfert des tokens vers le contrat
        bool success = token.transferFrom(
            msg.sender,
            address(this),
            _totalAmount
        );
        require(success, "Token transfer failed");
    }

    function getVestedAmount(address _beneficiary)
        public
        view
        returns (uint256)
    {
        VestingSchedule memory schedule = vestingSchedules[_beneficiary];

        if (schedule.totalAmount == 0) {
            return 0;
        }

        if (block.timestamp < schedule.cliff) {
            return 0;
        }

        uint256 elapsedTime = block.timestamp - schedule.cliff;

        if (elapsedTime >= schedule.duration) {
            return schedule.totalAmount;
        }

        return (schedule.totalAmount * elapsedTime) / schedule.duration;
    }

    function claimVestedTokens() public nonReentrant {
        VestingSchedule storage schedule = vestingSchedules[msg.sender];
        require(schedule.totalAmount > 0, "No vesting schedule");

        uint256 vested = getVestedAmount(msg.sender);
        uint256 releasable = vested - schedule.releasedAmount;

        require(releasable > 0, "No tokens available");

        schedule.releasedAmount += releasable;

        bool success = token.transfer(msg.sender, releasable);
        require(success, "Token transfer failed");
    }
}
