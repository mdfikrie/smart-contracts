// SPDX-License-Identifier: MIT
pragma solidity >= 0.8.2 <0.9.0;

import "./Context.sol";

contract Ownable is Context {
    address private _owner;

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    constructor(){
        _owner = _msgSender();
        emit OwnershipTransferred(address(0), _owner);
    }

    function owner()public view returns(address){
        return _owner;
    }

    modifier onlyOwner(){
        require( _owner == _msgSender(), "Ownable: caller is not the owner");
        _;
    }

    function renounceOwnership()public onlyOwner {
        emit OwnershipTransferred(_owner, address(0));
        _owner = address(0);
    }

    function transferOwnership(address newOwner)public onlyOwner {
        require(newOwner != address(0), "Ownable: new owner is zero address");
        emit OwnershipTransferred(_owner, newOwner);
        _owner = newOwner;
    }
}