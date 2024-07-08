// SPDX-License-Identifier: MIT
pragma solidity >= 0.8.2 <0.9.0;

import "./Ownable.sol";
import "./ERC721.sol";
import "./ERC721Enumerable.sol";

contract IztarShip is
    ERC721,
    ERC721Enumerable,
    Ownable
{
    mapping(address => bool) public approvalWhitelists;
    mapping(uint256 => bool) public lockedTokens;
    string private _baseTokenURI;
    bytes32 public constant  ADMIN_ROLE = keccak256("ADMIN_ROLE");
    mapping(bytes32 => mapping(address=> bool)) private _roleMembers;

    constructor() ERC721("Iztar Ship", "IZS") {
        setupRole(ADMIN_ROLE, _msgSender());
    }

    function setupRole(bytes32 _hashRole, address account) public onlyOwner {
        require(account != address(0), "Cannot zero address!");
        _roleMembers[_hashRole][account] = true;
    }

    function hasRole(bytes32 _hashRole, address account) public view returns(bool) {
        return _roleMembers[_hashRole][account];
    }

    function _baseURI() internal view virtual override returns (string memory) {
        return _baseTokenURI;
    }

    function mint(address to, uint256 tokenId, string memory uri) public {
        require(hasRole(ADMIN_ROLE, _msgSender()), "You're not admin to mint nft");
        require(!_exists(tokenId), "Must have unique tokenId");
        _mint(to, tokenId, uri);
    }
 
    function isApprovedForAll(address owner, address operator)
        public
        view
        override(ERC721, IERC721)
        returns (bool)
    {
        if (approvalWhitelists[operator] == true) {
            return true;
        }

        return super.isApprovedForAll(owner, operator);
    }

    function addApprovalWhitelist(address proxy) public {
        require(hasRole(ADMIN_ROLE, _msgSender()), "You're not admin to add approve whitelist");
        require(approvalWhitelists[proxy] == false, "Invalid proxy address");

        approvalWhitelists[proxy] = true;
    }

    function removeApprovalWhitelist(address proxy) public {
        require(hasRole(ADMIN_ROLE, _msgSender()), "You're not admin to remove approve whitelist");
        approvalWhitelists[proxy] = false;
    }

    function lock(uint256 tokenId) public {
        require(
            approvalWhitelists[_msgSender()],
            "Must be valid approval whitelist"
        );
        require(_exists(tokenId), "Must be valid tokenId");
        require(!lockedTokens[tokenId], "Token has already locked");
        lockedTokens[tokenId] = true;
    }

    function unlock(uint256 tokenId) public {
        require(
            approvalWhitelists[_msgSender()],
            "Must be valid approval whitelist"
        );
        require(_exists(tokenId), "Must be valid tokenId");
        require(lockedTokens[tokenId], "Token has already unlocked");
        lockedTokens[tokenId] = false;
    }

    function isLocked(uint256 tokenId) public view returns (bool) {
        return lockedTokens[tokenId];
    }

    function updateBaseURI(string calldata baseTokenURI) public {
        require(hasRole(ADMIN_ROLE, _msgSender()), "You're not admin to update base uri");
        _baseTokenURI = baseTokenURI;
    }

    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 tokenId
    ) internal virtual override(ERC721, ERC721Enumerable) {
        require(!lockedTokens[tokenId], "Can not transfer locked token");
        super._beforeTokenTransfer(from, to, tokenId);
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        virtual
        override(ERC721, ERC721Enumerable)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }
}