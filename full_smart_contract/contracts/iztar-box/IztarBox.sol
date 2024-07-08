// SPDX-License-Identifier: MIT
pragma solidity >=0.8.2 <0.9.0;
import "./Ownable.sol";
import "./IBEP20.sol";
import "./ECDSA.sol";

/// @title A IztarBox
/// @author Iztar Dev
contract IztarBox is Ownable {
    // ========== STATE VARIABLES ========== //
    address public signer;
    address public recipientPaymentAddress;

    struct Box {
        string name;
        string description;
        bool isActive;
    }

    struct SaleInfo {
        address user;
        uint256 boxId;
        uint256 price;
    }

    mapping(uint256 => Box) private boxes;
    mapping(uint256 => SaleInfo) public saleInfo;
    mapping(uint256 => bool) public ids;

    // =========== EVENTS ============= //
    event BuyBox(
        uint256 indexed boxId,
        address buyer,
        uint256 price,
        address paymentAddress
    );
    event SetBox(
        address indexed account,
        uint256 boxId,
        string name,
        string description
    );

    event RemoveBox(address indexed account, uint256 boxId);
    event SetSigner(address indexed account, address signer);
    event SetRecipientPayment(address indexed account, address recipient);

    constructor(address _signer, address _recipientAddress) {
        signer = _signer;
        recipientPaymentAddress = _recipientAddress;
    }

    /**
     * @dev Sets the signer address for the marketplace.
     * @param account The address to be set as the signer.
     * Requirements:
     * - The caller must be an admin.
     * - The provided account address cannot be zero.
     */
    function setSigner(address account) public onlyOwner {
        require(account != address(0), "Signer cannot zero address!");
        signer = account;
        emit SetSigner(_msgSender(), account);
    }

    function setBox(
        uint256 id,
        string memory name,
        string memory description
    ) public onlyOwner {
        boxes[id] = Box({name: name, description: description, isActive: true});
        emit SetBox(_msgSender(), id, name, description);
    }

    function removeBox(uint256 id) public onlyOwner {
        delete boxes[id];
        emit RemoveBox(_msgSender(), id);
    }

    function getBox(uint256 id) public view returns (Box memory) {
        require(boxes[id].isActive == false, "Box id not found");
        return boxes[id];
    }

    function setRecipientPaymentAddress(address _recipient) public onlyOwner {
        require(_recipient != address(0), "Signer cannot zero address!");
        recipientPaymentAddress = _recipient;
        emit SetRecipientPayment(_msgSender(), _recipient);
    }

    function getBuyBoxMessage(
        uint256 id,
        uint256 boxId,
        address user,
        uint256 price,
        address paymentAddress,
        uint256 expiredAt,
        uint256 chainId
    ) public pure returns (bytes32) {
        return
            keccak256(
                abi.encodePacked(
                    id,
                    boxId,
                    user,
                    price,
                    paymentAddress,
                    expiredAt,
                    chainId
                )
            );
    }

    function buyPaidBox(
        uint256 id,
        uint256 boxId,
        address user,
        uint256 price,
        address paymentAddress,
        uint256 expiredAt,
        uint256 chainId,
        bytes calldata signature
    ) public {
        require(price > 0, "Price less than 0");
        require(
            verifySignature(
                id,
                boxId,
                user,
                price,
                paymentAddress,
                expiredAt,
                chainId,
                signature
            ),
            "Invalid signature!"
        );
        _buyBox(id, boxId, user, price, paymentAddress, expiredAt, chainId);
    }

    function buyFreeBox(
        uint256 id,
        uint256 boxId,
        address user,
        uint256 price,
        address paymentAddress,
        uint256 expiredAt,
        uint256 chainId,
        bytes calldata signature
    ) public {
        require(price == 0, "Price more than 0");
        require(
            verifySignature(
                id,
                boxId,
                user,
                price,
                paymentAddress,
                expiredAt,
                chainId,
                signature
            ),
            "Invalid signature!"
        );
        _buyBox(id, boxId, user, price, paymentAddress, expiredAt, chainId);
    }

    function verifySignature(
        uint256 _id,
        uint256 _boxId,
        address _buyer,
        uint256 _price,
        address _paymentAddress,
        uint256 _expiredAt,
        uint256 _chainId,
        bytes memory signature
    ) public view returns (bool) {
        uint256 chainId = block.chainid;
        require(chainId == _chainId, "Invalid chainId!");
        bytes32 criteriaMessage = getBuyBoxMessage(
            _id,
            _boxId,
            _buyer,
            _price,
            _paymentAddress,
            _expiredAt,
            _chainId
        );
        bytes32 ethMessageHash = ECDSA.toEthSignedMessageHash(criteriaMessage);
        return ECDSA.recover(ethMessageHash, signature) == signer;
    }

    function _buyBox(
        uint256 _id,
        uint256 _boxId,
        address _user,
        uint256 _price,
        address _paymentAddress,
        uint256 _expiredAt,
        uint256 _chainId
    ) internal {
        require(_paymentAddress != address(0), "Payment cannot zero address");
        require(_expiredAt >= block.timestamp, "The signature is expired!");
        require(ids[_id] == false, "Id is already in use");
        uint256 chainId = block.chainid;
        require(chainId == _chainId, "Invalid chain id");

        ids[_id] = true;
        saleInfo[_id] = SaleInfo({user: _user, boxId: _boxId, price: _price});

        // payment
        IBEP20 token = IBEP20(_paymentAddress);
        uint256 allowance = token.allowance(_user, address(this));
        require(allowance >= _price, "Invalid token allowance");
        token.transferFrom(_user, recipientPaymentAddress, _price);
        emit BuyBox(_boxId, _user, _price, _paymentAddress);
    }
}
