// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./BoxOracle.sol";

contract Betting {

    event Debug(
       string message,
       uint256 value
    );

    event AddBet(
        address bettor,
        uint amount,
        uint player_id,
        uint betCoef
    );

    struct Player {
        uint8 id;
        string name;
        uint totalBetAmount;
        uint currCoef; 
    }
    struct Bet {
        address bettor;
        uint amount;
        uint player_id;
        uint betCoef;
    }

    address private betMaker;
    BoxOracle public oracle;
    uint public minBetAmount;
    uint public maxBetAmount;
    uint public totalBetAmount;
    uint public thresholdAmount;

    Bet[] private bets;
    Player public player_1;
    Player public player_2;

    bool private suspended = false;
    mapping (address => uint) public balances;
    
    constructor(
        address _betMaker,
        string memory _player_1,
        string memory _player_2,
        uint _minBetAmount,
        uint _maxBetAmount,
        uint _thresholdAmount,
        BoxOracle _oracle
    ) {
        betMaker = (_betMaker == address(0) ? msg.sender : _betMaker);
        player_1 = Player(1, _player_1, 0, 200); // boksaci
        player_2 = Player(2, _player_2, 0, 200);
        minBetAmount = _minBetAmount;
        maxBetAmount = _maxBetAmount;
        thresholdAmount = _thresholdAmount;
        oracle = _oracle;

        totalBetAmount = 0;
    }

    receive() external payable {}

    fallback() external payable {}

    function makeBet(uint8 _playerId) public payable {
        //TODO Your code here
        require(msg.value <= this.maxBetAmount());
        require(msg.value >= this.minBetAmount());
        require(msg.sender != address(betMaker));
        require(oracle.getWinner() == 0);

        Player memory targetPlayer;
        Player memory otherPlayer;
        if (_playerId == player_1.id) {
            targetPlayer = player_1;
            otherPlayer = player_2;
        } else if (_playerId == player_2.id) {
            targetPlayer = player_2;
            otherPlayer = player_1;
        } else {
            revert();
        }

        if (targetPlayer.totalBetAmount < thresholdAmount &&
            targetPlayer.totalBetAmount + msg.value > thresholdAmount &&
            (player_1.totalBetAmount == 0 || player_2.totalBetAmount == 0)) {
            suspended = true;
            return;
        }

        // add bet to list, coefficient must be recorded before changing it
        uint256 coef = totalBetAmount > thresholdAmount ? targetPlayer.currCoef : 200;

        bets.push(Bet(msg.sender, msg.value, _playerId, coef));
        emit AddBet(msg.sender, msg.value, _playerId, coef);
        // checks passed
        totalBetAmount += msg.value;
        balances[msg.sender] += msg.value;
        targetPlayer.totalBetAmount += msg.value;

        if (totalBetAmount > thresholdAmount) {
            uint256 numerator = (player_1.totalBetAmount + player_2.totalBetAmount) * 100;
            // uint256 remTarget = numerator % otherPlayer.totalBetAmount;
            // uint256 remOther = numerator % targetPlayer.totalBetAmount;
            // uint256 roundTarget = numerator % otherPlayer.totalBetAmount >= otherPlayer.totalBetAmount / 2 ? 1 : 0;
            // uint256 roundOther = numerator % targetPlayer.totalBetAmount >= targetPlayer.totalBetAmount / 2 ? 1 : 0;
            targetPlayer.currCoef = numerator / otherPlayer.totalBetAmount;// * 100 + remTarget + roundTarget;
            otherPlayer.currCoef = numerator / targetPlayer.totalBetAmount;// * 100 + remOther + roundOther;
            emit Debug("Target Player", targetPlayer.currCoef);
            emit Debug("Other Player", targetPlayer.currCoef);
        }

    }

    function claimSuspendedBets() public {
        require(suspended);
        payable(msg.sender).transfer(balances[msg.sender]);
    }

    function claimWinningBets() public {
        require(oracle.getWinner() != 0);

        uint winnerId = oracle.getWinner();
        Player memory winner;

        if (winnerId == player_1.id) {
            winner = player_1;
        } else if (winnerId == player_2.id) {
            winner = player_2;
        } else {
            revert();
        }

        uint256 payout = 0;
        for(uint i; i < bets.length; i++) {
            // if sender matches and player is winner
            if (bets[i].bettor == msg.sender && winner.id == bets[i].player_id) {
                // add to payout check
                payout += bets[i].amount * bets[i].betCoef / 100;
            }
        }
        emit Debug("Payout", payout);
        payable(msg.sender).transfer(payout);
    }

    function claimLosingBets() public {
        require(betMaker == msg.sender);
        require(oracle.getWinner() != 0);
        uint loserId = oracle.getWinner() == 1 ? 0 : 1;
        Player memory loser;

        if (loserId == player_1.id) {
            loser = player_1;
        } else if (loserId == player_2.id) {
            loser = player_2;
        } else {
            revert();
        }

        uint payout = 0;
        for(uint i; i < bets.length; i++) {
            if (loser.id == bets[i].player_id) {
                payout += bets[i].amount;
            }
        }
        payable(betMaker).transfer(payout);
    }
}