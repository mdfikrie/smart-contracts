// SPDX-License-Identifier: MIT
pragma solidity >=0.8.2 <0.9.0;
import "./IERC721.sol";
import "./IERC20.sol";
import "./Context.sol";
import "./Ownable.sol";
import "./ERC721Holder.sol";
import "./IERC721Receiver.sol";
import "./ECDSA.sol";
import "./SafeERC20.sol";

/// @title A Iztar Marketplace
/// @author Iztar Dev
contract IztarMarketplace is Context, Ownable, ERC721Holder {
    // ========== LIB ========== //
    using SafeERC20 for IERC20;

    // ========== STATE VARIABLES ========== //
    mapping(address => bool) private admins;
    address private signer;

    struct NFTSold {
        address owner;
        uint256 price;
    }

    mapping(address => mapping(uint256 => NFTSold)) private _sellingById;
    uint256 public transactionFee;
    address public feeRecipient;
    address public paymentContract;
    uint256 private maxFeeTransaction = 1000;
    mapping(address => mapping(uint256 => bool)) public usedNonces;
    bool private _notEntered;

    // ============= EVENTs ============== //
    event SuccessfullSell(
        uint256 indexed tokenId,
        address seller,
        uint256 price,
        address nftAddress
    );
    event SuccessfullBuy(
        uint256 indexed tokenId,
        address seller,
        address buyer,
        uint256 price,
        uint256 fee,
        address nftAddress
    );
    event CancelSell(uint256 indexed tokenId, address nftAddress);
    event SetAdminAddress(address indexed account, bool value);
    event SetSigner(address indexed account);
    event SetTransactionFee(address indexed account, uint256 fee);
    event SetFeeRecipient(address indexed account, address recipient);

    constructor(
        address _paymentContract,
        address _admin,
        address _feeRecipient,
        address _signer,
        uint256 _transactionFee
    ) {
        admins[_admin] = true;
        paymentContract = _paymentContract;
        feeRecipient = _feeRecipient;
        signer = _signer;
        transactionFee = _transactionFee;
        _notEntered = true;
    }

    modifier nonReentrant() {
        require(_notEntered, "ReentrancyGuard: reentrant call");
        _notEntered = false;
        _;
        _notEntered = true;
    }

    /**
     * @dev Sets the address as an admin.
     * @param account The address to be set as an admin.
     */
    function setAdminAddress(address account) public onlyOwner {
        require(account != address(0), "Cannot zero address!");
        admins[account] = true;
        emit SetAdminAddress(account, true);
    }

    /**
     * @dev Removes the address as an admin.
     * @param account The address to be removed as an admin.
     */
    function removeAdminAddress(address account) public onlyOwner {
        require(account != address(0), "Cannot zero address!");
        admins[account] = false;
        emit SetAdminAddress(account, false);
    }

    /**
     * @dev Check if the specified account is an admin.
     * @param account The address of the account to check.
     * @return True if the account is an admin, false otherwise.
     */
    function isAdmin(address account) public view returns (bool) {
        return admins[account];
    }

    /**
     * @dev Sets the signer address for the marketplace.
     * @param account The address to be set as the signer.
     * Requirements:
     * - The caller must be an admin.
     * - The provided account address cannot be zero.
     */
    function setSigner(address account) public onlyOwner {
        signer = account;
        emit SetSigner(account);
    }

    /**
     * @dev Function to get the signer address
     *
     * This function retrieves and returns the address of the signer used for verification.
     * The signer address is set by an admin using the setSigner function.
     *
     * @return The address of the signer
     */
    function getSigner() public view returns (address) {
        return signer;
    }

    /**
     * @dev Sets the transaction fee for the marketplace.
     * @param _fee The transaction fee amount to be set.
     * Requirements:
     * - The caller must be an admin.
     * - The provided transaction fee amount must be less than the maximum fee transaction amount.
     */
    function setTransactionFee(uint256 _fee) public {
        require(
            isAdmin(_msgSender()),
            "You're not admin to set fee transaction"
        );
        require(_fee < maxFeeTransaction, "Amount exceeds max fee transaction");
        transactionFee = _fee;
        emit SetTransactionFee(_msgSender(), _fee);
    }

    /**
     * @dev Sets the recipient address for the transaction fee.
     *
     * @param _recipient The address to set as the recipient of the transaction fee.
     * A boolean indicating whether the recipient address was successfully set.
     * Requirements:
     * - The caller must be an admin.
     * - The provided recipient address cannot be zero.
     */
    function setFeeRecipient(address _recipient) public {
        require(isAdmin(_msgSender()), "You're not admin to set fee recipient");
        require(_recipient != address(0), "Recipient cannot zero address");
        feeRecipient = _recipient;
        emit SetFeeRecipient(_msgSender(), _recipient);
    }

    /**
     * @dev Check if an NFT is being sold.
     * @param tokenAddress The address of the NFT contract.
     * @param tokenId The ID of the NFT token.
     * @return A boolean indicating whether the NFT is being sold.
     */
    function isSell(
        address tokenAddress,
        uint256 tokenId
    ) external view returns (bool) {
        if (_sellingById[tokenAddress][tokenId].owner != address(0)) {
            return true;
        }
        return false;
    }

    /**
     * @dev Retrieves information about an NFT that is being sold.
     *
     * @param tokenAddress The address of the NFT contract.
     * @param id The ID of the NFT token.
     * @return A struct containing the details of the NFT being sold.
     */
    function getSellingById(
        address tokenAddress,
        uint256 id
    ) external view returns (NFTSold memory) {
        return _sellingById[tokenAddress][id];
    }

    /**
     * @dev Allows a user to list an NFT for sale on the marketplace.
     * @param _tokenId The ID of the NFT token to be listed for sale.
     * @param _owner The address of the owner of the NFT token.
     * @param _price The price at which the NFT token is listed for sale.
     * @param _tokenAddress The address of the NFT contract.
     * @param _expiredAt The timestamp until which the signature is valid.
     * @param signature The signature for verifying the listing.
     * Requirements:
     * - The NFT contract address cannot be zero.
     * - The signer address must be set.
     * - The provided NFT token must not already be listed for sale.
     * - The signature must be valid and not expired.
     * - The caller must be the owner of the NFT token.
     * Effects:
     * - Marks the NFT token as listed for sale in the marketplace.
     * - Transfers the ownership of the NFT token to the marketplace contract.
     * Events:
     * - Emits a SuccessfullSell event upon successful listing of the NFT token for sale.
     */
    function sell(
        uint256 _tokenId,
        address _owner,
        uint256 _price,
        address _tokenAddress,
        uint256 _expiredAt,
        uint256 _nonce,
        uint256 _chainId,
        bytes calldata signature
    ) external nonReentrant {
        require(_tokenAddress != address(0), "NFT contract invalid!");
        require(signer != address(0), "Signer has not been set!");
        require(_owner != address(0), "Owner cannot zero address!");
        require(
            _sellingById[_tokenAddress][_tokenId].owner == address(0),
            "Nft token already selling"
        );
        require(_expiredAt > block.timestamp, "The signature is expired");

        require(
            verifySignature(
                _tokenId,
                _owner,
                _price,
                _tokenAddress,
                _expiredAt,
                _nonce,
                _chainId,
                signature
            ),
            "Invalid signature!"
        );

        IERC721 nft = IERC721(_tokenAddress);
        require(
            nft.ownerOf(_tokenId) == _msgSender(),
            "You're not token's owner!"
        );

        _sellingById[_tokenAddress][_tokenId] = NFTSold({
            owner: _owner,
            price: _price
        });

        nft.safeTransferFrom(_owner, address(this), _tokenId);

        emit SuccessfullSell(_tokenId, _owner, _price, _tokenAddress);
    }

    /**
     * @dev Allows a user to buy an NFT listed for sale on the marketplace.
     *
     * @param _tokenAddress The address of the NFT contract from which the NFT is being bought.
     * @param _tokenId The ID of the NFT token being bought.
     * @param _price The price at which the NFT token is being bought.
     *
     * @return A boolean indicating whether the NFT purchase was successful.
     *
     * Requirements:
     * - The NFT token must be listed for sale.
     * - The buyer must have sufficient funds in the payment token to purchase the NFT.
     * - The buyer must have approved the marketplace to spend the specified amount in the payment token.
     *
     * Effects:
     * - Transfers the payment amount from the buyer to the seller.
     * - Transfers the ownership of the NFT token from the seller to the buyer.
     * - Updates the marketplace data to reflect the successful purchase.
     *
     * Emits a `SuccessfullBuy` event upon successful purchase of the NFT token.
     */
    function buy(
        address _tokenAddress,
        uint256 _tokenId,
        uint256 _price
    ) external nonReentrant returns (bool) {
        NFTSold memory nft = _sellingById[_tokenAddress][_tokenId];
        require(nft.owner != address(0), "Nft token not exist!");
        require(_price == nft.price, "Invalid nft price!");

        IERC20 token = IERC20(paymentContract);
        IERC721 nftToken = IERC721(_tokenAddress);

        require(
            token.balanceOf(_msgSender()) >= _price,
            "buyer doesn't have enough token to buy this item"
        );

        require(
            token.allowance(_msgSender(), address(this)) >= nft.price,
            "buyer doesn't approve marketplace to spend payment amount"
        );

        uint256 _fee = (transactionFee * nft.price) / 10000;
        uint256 payAmount = nft.price - _fee;
        delete _sellingById[_tokenAddress][_tokenId];

        nftToken.safeTransferFrom(address(this), _msgSender(), _tokenId);
        token.safeTransferFrom(_msgSender(), nft.owner, payAmount);
        if (_fee > 0) {
            token.safeTransferFrom(_msgSender(), feeRecipient, _fee);
        }

        emit SuccessfullBuy(
            _tokenId,
            nft.owner,
            _msgSender(),
            nft.price,
            _fee,
            _tokenAddress
        );

        return true;
    }

    /**
     * @dev Allows a user to cancel the listing of an NFT token for sale on the marketplace.
     *
     * @param _tokenAddress The address of the NFT contract from which the NFT token is being cancelled for sale.
     * @param _tokenId The ID of the NFT token being cancelled for sale.
     *
     * @return A boolean indicating whether the cancellation of the NFT token listing was successful.
     *
     * Requirements:
     * - The caller must be the owner of the NFT token.
     *
     * Effects:
     * - Transfers the ownership of the NFT token back to the owner.
     * - Removes the NFT token from the marketplace listing.
     *
     * Emits a `CancelSell` event upon successful cancellation of the NFT token listing.
     */
    function cancelSell(
        address _tokenAddress,
        uint256 _tokenId
    ) external nonReentrant returns (bool) {
        require(
            _sellingById[_tokenAddress][_tokenId].owner == _msgSender(),
            "You're not owner this nft token."
        );
        _cancelSell(_tokenAddress, _tokenId);
        return true;
    }

    /**
     * @dev Allows an admin to cancel the listing of an NFT token for sale on the marketplace.
     *
     * @param _tokenAddress The address of the NFT contract from which the NFT token is being cancelled for sale.
     * @param _tokenId The ID of the NFT token being cancelled for sale.
     *
     * @return A boolean indicating whether the cancellation of the NFT token listing was successful.
     *
     * Requirements:
     * - The caller must be an admin.
     *
     * Effects:
     * - Transfers the ownership of the NFT token back to the owner.
     * - Removes the NFT token from the marketplace listing.
     *
     * Emits a CancelSell event upon successful cancellation of the NFT token listing.
     */
    function cancelSellByAdmin(
        address _tokenAddress,
        uint256 _tokenId
    ) external nonReentrant returns (bool) {
        require(
            isAdmin(_msgSender()),
            "You're not admin to set cancel selling"
        );
        _cancelSell(_tokenAddress, _tokenId);
        return true;
    }

    /**
     * @dev Allows to cancel the listing of an NFT token for sale on the marketplace.
     */
    function _cancelSell(address _tokenAddress, uint256 _tokenId) internal {
        NFTSold memory nft = _sellingById[_tokenAddress][_tokenId];
        require(nft.owner != address(0), "Token nft not exist.");

        IERC721 _nftAddress = IERC721(_tokenAddress);
        delete _sellingById[_tokenAddress][_tokenId];

        _nftAddress.safeTransferFrom(address(this), nft.owner, _tokenId);

        emit CancelSell(_tokenId, _tokenAddress);
    }

    function getMessageHash(
        uint256 _tokenId,
        address _owner,
        uint256 _price,
        address _nftAddress,
        uint256 _expiredAt,
        uint256 _nonce,
        uint256 _chainId
    ) public pure returns (bytes32) {
        return
            keccak256(
                abi.encodePacked(
                    _tokenId,
                    _owner,
                    _price,
                    _nftAddress,
                    _expiredAt,
                    _nonce,
                    _chainId
                )
            );
    }

    function verifySignature(
        uint256 _tokenId,
        address _owner,
        uint256 _price,
        address _nftAddress,
        uint256 _expiredAt,
        uint256 _nonce,
        uint256 _chainId,
        bytes memory signature
    ) public returns (bool) {
        require(!usedNonces[_owner][_nonce], "Nonce already used");
        uint256 chainId = block.chainid;
        require(chainId == _chainId, "Invalid chainId!");
        bytes32 criteriaMessageHash = getMessageHash(
            _tokenId,
            _owner,
            _price,
            _nftAddress,
            _expiredAt,
            _nonce,
            _chainId
        );
        bytes32 ethMessageHash = ECDSA.toEthSignedMessageHash(
            criteriaMessageHash
        );
        usedNonces[_owner][_nonce] = true;
        return ECDSA.recover(ethMessageHash, signature) == signer;
    }
}
