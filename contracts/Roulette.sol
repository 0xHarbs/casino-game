// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "@chainlink/contracts/src/v0.8/VRFConsumerBase.sol";
import "hardhat/console.sol";

contract Roulette is VRFConsumerBase, Ownable {
    string public name = "Roulette";
    uint256 public fee;
    bytes32 public keyHash;
    uint256 public randNum;
    uint256 public gameId;
    uint256 public nextGame;
    uint256 public balanceRequired;
    uint256 public betAmount;
    uint8[] betType;

    struct Bet {
        address player;
        uint256 betType;
        uint256 number;
    }

    Bet[] public bets;

    mapping(address => uint256) public balance;

    modifier gameReady() {
        require(block.timestamp > nextGame);
        _;
    }

    event GameStarted(uint256 gameId, uint8 maxPlayers, uint256 entryFee);
    event PlayerJoined(uint256 gameId, address player);
    event GameEnded(uint256 gameId, bytes32 requestId);

    constructor(
        address vrfCoordinator,
        address linkToken,
        bytes32 vrfKeyHash
    ) VRFConsumerBase(vrfCoordinator, linkToken) {
        keyHash = vrfKeyHash;
        fee = 0.1 * 10**18; // 0.1 LINK
        betAmount = 100000000000000000;
        betType = [36, 2, 2, 3, 3, 2];
        nextGame = block.timestamp + 2 minutes;
    }

    function fulfillRandomness(bytes32 requestId, uint256 randomness)
        internal
        virtual
        override
    {
        randNum = randomness % 36;
        emit GameEnded(gameId, requestId);
    }

    function getRandomNumber() private returns (bytes32 requestId) {
        require(LINK.balanceOf(address(this)) >= fee, "Not enough LINK");
        return requestRandomness(keyHash, fee);
    }

    function betOnSpin(uint256 _betType, uint256 _number) public {
        require(balance[msg.sender] > betAmount, "Balance must exceed bet");
        require(_betType >= 0 && _betType <= 5, "Bet type invalid");
        require(_number >= 0 && _number <= 36, "Bet number invalid");
        uint256 expectedPayout = betAmount * betType[_betType];
        // require(address(this).balance > balanceRequired + expectedPayout, "Address balance insufficient");
        balanceRequired += expectedPayout;
        bets.push(Bet(msg.sender, _betType, _number));
        emit PlayerJoined(gameId, msg.sender);
    }

    function spinWheel() public gameReady {
        getRandomNumber();

        gameId++;
        nextGame = block.timestamp + 2 minutes;

        for (uint256 i; i < bets.length; i++) {
            Bet storage bet = bets[i];
            bool winner = false;
            if (randNum == 0 && bet.betType == 0 && bet.number == 0) {
                winner = true;
            } else if (bet.betType == 0 && bet.number == randNum) {
                winner = true;
            } else if (bet.betType == 1) {
                if (bet.number == 0 && randNum % 2 == 0) winner = true; // Even bet wins
                if (bet.number == 1 && randNum % 2 == 1) winner = true; // Odd bet wins
            } else if (bet.betType == 2) {
                if (bet.number == 0 && randNum <= 18) winner = true; // First 18 wins
                if (bet.number == 1 && randNum >= 19) winner = true; // Next 18 wins
            } else if (bet.betType == 3) {
                if (bet.number == 0 && randNum <= 12) winner = true; // First dozen wins
                if (bet.number == 1 && randNum > 12 && randNum <= 24)
                    winner = true; // Second dozen wins
                if (bet.number == 2 && randNum > 24 && randNum <= 36)
                    winner = true; // Third dozen wins
            } else if (bet.betType == 4) {
                if (bet.number == 0) {
                    // Bet on red
                    if (randNum <= 10 || (randNum >= 19 && randNum <= 28)) {
                        winner = (randNum % 2 == 1);
                    } else if (
                        (randNum > 10 && randNum <= 18) ||
                        (randNum > 28 && randNum <= 26)
                    ) {
                        winner = (randNum % 2 == 0);
                    }
                } else {
                    // Bet on black
                    if (randNum <= 10 || (randNum >= 19 && randNum <= 28)) {
                        winner = (randNum % 2 == 0);
                    } else if (
                        (randNum > 10 && randNum <= 18) ||
                        (randNum > 28 && randNum <= 26)
                    ) {
                        winner = (randNum % 2 == 1);
                    }
                }
            }
            if (winner) {
                balance[bet.player] += betAmount * betType[bet.betType];
            }
        }

        delete bets;
        balanceRequired = 0;
    }

    function playerWithdraw(uint256 _amount) public {
        require(balance[msg.sender] > _amount);
        require(address(this).balance > _amount);
        balance[msg.sender] -= _amount;
        payable(msg.sender).transfer(_amount);
    }

    function addBalance() public payable {
        uint256 amount = msg.value;
        balance[msg.sender] += amount;
    }

    function withdraw(uint256 _amount) public onlyOwner {
        address _owner = msg.sender;
        balance[msg.sender] -= _amount;
        (bool success, ) = _owner.call{value: _amount}("");
        require(success, "Failed to send funds");
    }

    receive() external payable {}

    fallback() external payable {}
}
