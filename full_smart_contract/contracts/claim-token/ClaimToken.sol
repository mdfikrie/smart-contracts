// SPDX-License-Identifier: MIT
pragma solidity >=0.8.2 <0.9.9;
import "./Ownable.sol";
import "./Context.sol";
import "./IERC20.sol";
import "./ECDSA.sol";
import "./SafeERC20.sol";

contract ClaimToken is Context, Ownable {
    // ========== LIB ========== //
    using SafeERC20 for IERC20;

    // ========== STATE VARIABLES ========== //
    address private signer;
    mapping(address => bool) private admins;
    mapping(address => mapping(uint256 => bool)) public usedNonces;
    bool private _notEntered;

    // =========== EVENTS ============= //
    event ClaimedToken(address indexed _account, uint256 _amount);
    event WithDraw(address indexed _account, uint256 _amount);
    event SetSigner(address indexed _account, address signer);
    event SetPaymentAddress(address indexed _account, address _paymentAddress);
    event SetAdminAddress(
        address indexed _account,
        address _admin,
        bool _value
    );

    constructor(address _admin, address _signer) {
        signer = _signer;
        admins[_admin] = true;
        _notEntered = true;
    }

    modifier nonReentrant() {
        require(_notEntered, "ReentrancyGuard: reentrant call");
        _notEntered = false;
        _;
        _notEntered = true;
    }

    /**
     * @dev Returns the address of the signer.
     * @return The address of the signer.
     */
    function getSigner() public view returns (address) {
        return signer;
    }

    /**
     * @dev Sets the address of the signer.
     * @param _newSigner The new address of the signer.
     * Requirements:
     * - Caller must be the owner of the contract.
     */
    function setSigner(address _newSigner) public onlyOwner {
        signer = _newSigner;
        emit SetSigner(_msgSender(), signer);
    }

    /**
     * @dev Allows a user to claim tokens.
     * Requirements:
     * - Caller must not be the zero address.
     * - Signer address must be set.
     * - Signature must not be expired.
     * - Payment address must match the contract's payment address.
     * - Signature must be valid.
     * Effects:
     * - Transfers tokens to the user if claim is successful.
     * Emits ClaimedToken event upon successful claim.
     */
    function claimToken(
        address _account,
        uint256 _amount,
        address _paymentAddress,
        uint256 _expiredAt,
        uint256 _nonce,
        uint256 _chainId,
        bytes memory _signature
    ) external nonReentrant {
        require(_account != address(0), "Cannot zero address");
        require(signer != address(0), "Signer has not been set!");
        require(_expiredAt > block.timestamp, "The signature is expired!");
        require(_paymentAddress != address(0), "Payment cannot zero address");
        require(
            verifySignature(
                _account,
                _amount,
                _paymentAddress,
                _expiredAt,
                _nonce,
                _chainId,
                _signature
            ),
            "Invalid signature!"
        );
        IERC20 token = IERC20(_paymentAddress);
        token.safeTransfer(_account, _amount);
        emit ClaimedToken(_account, _amount);
    }

    /**
     * @dev Sets the address of an admin.
     *
     * @param _admin The address of the admin to be set.
     * @param value The boolean value indicating whether the admin is being added or removed.
     *
     * Requirements:
     * - Caller must be the owner of the contract.
     */
    function setAdminAddress(address _admin, bool value) public onlyOwner {
        require(_admin != address(0), "Admin cannot zero address");
        admins[_admin] = true;
        emit SetAdminAddress(_msgSender(), _admin, value);
    }

    /**
     * @dev Checks if the given address is an admin.
     *
     * @param _admin The address to be checked.
     * @return bool Returns true if the address is an admin, false otherwise.
     */
    function isAdmin(address _admin) public view returns (bool) {
        return admins[_admin];
    }

    /**
     * @dev Returns the balance of the contract.
     *
     * @return uint256 The balance of the contract.
     */
    function getBalance(
        address _paymentAddress
    ) external view returns (uint256) {
        IERC20 token = IERC20(_paymentAddress);
        return token.balanceOf(address(this));
    }

    /**
     * @dev Allows an admin to withdraw tokens from the contract balance.
     * Requirements:
     * - Caller must be an admin.
     *
     * Effects:
     * - Transfers tokens from the contract balance to the admin.
     *
     * Emits WithDraw event upon successful withdrawal.
     */
    function withDraw(
        address _paymentAddress,
        uint256 _amount
    ) external nonReentrant {
        require(isAdmin(_msgSender()), "You're not admin!");
        IERC20 token = IERC20(_paymentAddress);
        token.safeTransfer(_msgSender(), _amount);
        emit WithDraw(_msgSender(), _amount);
    }

    /**
     * @dev Returns the message hash for verifying the signature of a claim token request.
     *
     * @return bytes32 The keccak256 hash of the concatenated parameters.
     */
    function getMessageHash(
        address _account,
        uint256 _amount,
        address _paymentAddress,
        uint256 _expiredAt,
        uint256 _nonce,
        uint256 _chainId
    ) public pure returns (bytes32) {
        return
            keccak256(
                abi.encodePacked(
                    _account,
                    _amount,
                    _paymentAddress,
                    _expiredAt,
                    _nonce,
                    _chainId
                )
            );
    }

    /**
     * @dev Verifies the signature of a claim token request.
     *
     * @return bool Returns true if the signature is valid, false otherwise.
     *
     * Requirements:
     * - The nonce must not have been used before for the given account.
     */
    function verifySignature(
        address _account,
        uint256 _amount,
        address _paymentAddress,
        uint256 _expiredAt,
        uint256 _nonce,
        uint256 _chainId,
        bytes memory _signature
    ) public returns (bool) {
        require(!usedNonces[_account][_nonce], "Nonce already used");
        uint256 chainId = block.chainid;
        require(chainId == _chainId, "Invalid chainId!");
        bytes32 criteriaMessageHash = getMessageHash(
            _account,
            _amount,
            _paymentAddress,
            _expiredAt,
            _nonce,
            _chainId
        );
        bytes32 ethMessageHash = ECDSA.toEthSignedMessageHash(
            criteriaMessageHash
        );
        usedNonces[_account][_nonce] = true;
        return ECDSA.recover(ethMessageHash, _signature) == signer;
    }
}
