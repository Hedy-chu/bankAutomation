// SPDX-License-Identifier: MIT
pragma solidity ^0.8.2;

import "@chainlink/contracts/src/v0.8/AutomationCompatible.sol";
// 预言机的包 喂价
import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";

contract Bank is AutomationCompatibleInterface {
    mapping(address => uint) public depositeAccount;
    address[3] public topAccount;
    address public owner;
    uint constant DEPOSITE_LIMIT = 0.001 ether;
    bool public rept = false;
    uint public upperLimit = 0.002 ether;
    uint public depositeTotal;
    // 预言机
    AggregatorV3Interface internal dataFeed;
    error withdrawFail();
    event WithdrawSuccess(address user, uint amount);
    event Price(
        uint80 roundID,
        int answer,
        uint startedAt,
        uint timeStamp,
        uint80 answeredInRound
    );

    constructor() {
        owner = msg.sender;
        dataFeed = AggregatorV3Interface(
            0x694AA1769357215DE4FAC081bf1f309aDC325306
        );
    }

    // 接收eth
    receive() external payable {}

    modifier checkAmount(uint amount) {
        require(
            amount >= DEPOSITE_LIMIT,
            "Deposits should be greater than 0.001ether"
        );
        _;
    }

    /**
      存款合约
    **/
    function deposite()
        public
        payable
        virtual
        checkAmount(msg.value)
        returns (bool)
    {
        require(msg.value > 0, "The deposit should be greater than zero");
        depositeAccount[msg.sender] += msg.value;
        depositeTotal += msg.value;

        for (uint i = 0; i < 3; i++) {
            if (topAccount[i] == msg.sender) {
                rept = true;
                sort();
                break;
            }
        }
        if (rept == false) {
            topAccount[0] = msg.sender;
            sort();
        }
        return true;
    }

    function sort() public {
        uint256 n = topAccount.length;

        for (uint256 i = 0; i < n - 1; i++) {
            for (uint256 j = 0; j < n - i - 1; j++) {
                uint amount = depositeAccount[topAccount[j]];
                uint nextAmount = depositeAccount[topAccount[j + 1]];
                if (amount > nextAmount) {
                    (topAccount[j], topAccount[j + 1]) = (
                        topAccount[j + 1],
                        topAccount[j]
                    );
                }
            }
        }
    }

    function withdraw() public virtual {
        require(owner == msg.sender, "only owner can withdraw");
        require(address(this).balance > 0, "not sufficient funds");
        // address payable sender = payable (msg.sender);
        (bool success, ) = payable(msg.sender).call{
            value: address(this).balance
        }("");
        if (!success) {
            revert withdrawFail();
        }
    }

    function balance() public view returns (uint) {
        return address(this).balance;
    }

    function checkUpkeep(
        bytes calldata
    ) external view returns (bool overLimit, bytes memory) {
        overLimit = depositeTotal > upperLimit;
    }

    function performUpkeep(bytes calldata /* performData */) external {
        uint transferAmount = depositeTotal / 2;
        (bool success, ) = owner.call{value: transferAmount}("");
        if (!success) {
            revert withdrawFail();
        }
        depositeTotal -= transferAmount;
        // 获取ETH对usdt价格
        (uint80 roundID, int answer,uint startedAt, uint timeStamp, uint80 answeredInRound) =  
        dataFeed.latestRoundData();
        // emit WithdrawSuccess(owner, transferAmount);
        emit Price(roundID,answer,startedAt,timeStamp,answeredInRound);
    }
}
