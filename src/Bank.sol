// SPDX-License-Identifier: MIT
pragma solidity ^0.8.2;

import "@chainlink/contracts/src/v0.8/AutomationCompatible.sol";

contract Bank is AutomationCompatibleInterface {
    mapping(address => uint) public depositeAccount;
    address[3] public topAccount;
    address public owner;
    uint constant DEPOSITE_LIMIT = 0.001 ether;
    bool public rept = false;
    uint public upperLimit;
    uint public depositeTotal;
    error withdrawFail();
    event WithdrawSuccess(address user,uint amount);

    constructor() {
        owner = msg.sender;
    }

    // 接收eth
    receive() external payable {}

    modifier checkAmount(uint amount){
        require(amount >=  DEPOSITE_LIMIT,"Deposits should be greater than 0.001ether");
        _;
    }

    /**
      存款合约
    **/
    function deposite() public payable checkAmount(msg.value) virtual returns (bool) {
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

    function checkUpkeep(bytes calldata) external view returns (bool overLimit, bytes memory ) {
        overLimit = depositeTotal > upperLimit;
    }

    function performUpkeep(bytes calldata /* performData */) external  {
        uint transferAmount = depositeTotal / 2;
        (bool success,) = owner.call{value: transferAmount}("");
        if (!success) {
            revert withdrawFail();
        }
        depositeTotal -= transferAmount;
        emit WithdrawSuccess(owner, transferAmount);
    }
}
