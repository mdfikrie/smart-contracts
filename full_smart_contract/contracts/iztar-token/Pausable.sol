// SPDX-License-Identifier: MIT
pragma solidity >= 0.8.2 <0.9.0;
import "./Context.sol";

contract Pausable is Context {
    bool private _paused;
    event Paused(address indexed account);
    event Unpaused(address indexed account);
    constructor(){
        _paused = false;
    }

    function paused() internal virtual view returns(bool){
        return _paused;
    }

    function _pause() internal virtual whenNotPaused{
        _paused = true;
        emit Paused(_msgSender());
    }

    function _unpause() internal virtual whenPaused{
        _paused = false;
        emit Unpaused(_msgSender());
    }

    modifier whenPaused(){
        require(paused(),"Pausable: Paused");
        _;
    }

    modifier whenNotPaused(){
        require(!paused(),"Pausable: Not Paused");
        _;
    }
}