// SPDX-License-Identifier: MIT
pragma solidity >= 0.8.2 <0.9.0;

abstract contract Context {
    function _msgSender() internal view returns(address){
        return msg.sender;
    }

    function _msgData() internal view returns(bytes calldata){
        this; // silence state mutability warning without generating bytecode
        return msg.data;
    }
}