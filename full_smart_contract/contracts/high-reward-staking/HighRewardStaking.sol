// SPDX-License-Identifier: MIT
pragma solidity >=0.8.2 <0.9.0;

import "./Ownable.sol";
import "./Context.sol";
import "./IERC20.sol";
import "./IERC721.sol";
import "./ERC721Holder.sol";
import "./ECDSA.sol";
import "./SafeERC20.sol";
import "./SafeMath.sol";

contract HighRewardStaking is Context, Ownable, ERC721Holder {
    // ========== LIB ========== //
    using SafeERC20 for IERC20;
    using SafeMath for uint256;

    // ========== STATE VARIABLES ========== //
    struct Plan {
        uint256 duration;
        uint256 apr;
        address nftAddress;
    }

    struct Stake {
        uint256[] nftIds;
        uint256 amount;
        uint256 startAt;
        bool isClaimed;
        Plan plan;
    }

    mapping(uint256 => Plan) private plans;
    mapping(uint256 => mapping(address => Stake)) private stakers;
    mapping(address => bool) private admins;
    mapping(address => mapping(uint256 => bool)) public usedNonces;

    uint256 public tokenPairPerShip;
    uint256 public maxShip;
    address public signer;
    bool private _notEntered;

    // =========== EVENTS ============= //
    event Staked(
        address indexed account,
        uint256[] _nftIds,
        uint256 _amount,
        address _nftAddress,
        address _paymentAddress,
        uint256 id
    );
    event Unstaked(
        address indexed account,
        uint256[] _nftIds,
        address _nftAddress,
        uint256 _amount,
        address _paymentAddress,
        uint256 id
    );
    event SetPlan(
        address indexed account,
        uint256 _duration,
        uint256 _apr,
        uint256 id,
        address _nftAddress
    );
    event RemovePlan(address indexed account, uint256 idPlan);
    event ClaimReward(
        address indexed account,
        uint256 id,
        uint256 _amount,
        address _paymentAddress
    );
    event CancelStake(address indexed account, uint256 id);
    event SetSigner(address indexed account, address signer);
    event WithDraw(
        address indexed account,
        uint256 value,
        address _paymentAddress
    );
    event SetAdminAddress(address indexed account, address admin, bool value);
    event SetTokenPairPerShip(address indexed account, uint256 amount);
    event SetMaxShip(address indexed account, uint256 _maxShip);

    constructor(
        address _admin,
        address _signer,
        uint256 _tokenPairPerShip,
        uint256 _maxShip
    ) {
        admins[_admin] = true;
        signer = _signer;
        tokenPairPerShip = _tokenPairPerShip;
        maxShip = _maxShip;
        _notEntered = true;
    }

    modifier nonReentrant() {
        require(_notEntered, "ReentrancyGuard: reentrant call");
        _notEntered = false;
        _;
        _notEntered = true;
    }

    /**
     * @dev Set the signer address for signature verification.
     * @param _account The address of the new signer.
     */
    function setSigner(address _account) public {
        require(
            isAdmin(_msgSender()),
            "You must have admin role to set signer"
        );
        require(_account != address(0), "Signer cannot zero address");
        signer = _account;
        emit SetSigner(_msgSender(), _account);
    }

    /**
     * @dev Get the total reward of the staking contract.
     * @return The balance of the staking contract.
     */
    function getTotalReward(
        address _paymentAddress
    ) public view returns (uint256) {
        IERC20 token = IERC20(_paymentAddress);
        return token.balanceOf(address(this));
    }

    /**
     * @dev Allows an admin to withdraw a specified amount of tokens from the contract balance.
     *
     * @param _amount The amount of tokens to withdraw.
     *
     * Requirements:
     * - The caller must have the admin role.
     * - The contract must have enough balance to fulfill the withdrawal.
     *
     * Emits a `WithDraw` event with information about the withdrawal.
     */
    function withDraw(
        uint256 _amount,
        address _paymentAddress
    ) public nonReentrant {
        require(isAdmin(_msgSender()), "You must have admin role to withdraw");
        IERC20 token = IERC20(_paymentAddress);
        require(
            token.balanceOf(address(this)) >= _amount,
            "Amount exceeds balances"
        );
        token.safeTransfer(_msgSender(), _amount);
        emit WithDraw(_msgSender(), _amount, _paymentAddress);
    }

    /**
     * @dev Get the staking plan details for a specific plan ID.
     * @param _id The ID of the staking plan to retrieve.
     * @return The staking plan details including duration and annual percentage rate (APR).
     */
    function getPlan(uint256 _id) external view returns (Plan memory) {
        return plans[_id];
    }

    /**
     * @dev Get the staking details for a specific account and staking plan.
     *
     * @param _account The address of the account for which staking details are retrieved.
     * @param _idPlan The ID of the staking plan for which details are retrieved.
     *
     * @return A `Stake` struct containing the staking details including NFT IDs, staked amount, NFT address,
     * payment address, start timestamp, claim status, and staking plan.
     */
    function getStaking(
        address _account,
        uint256 _idPlan
    ) external view returns (Stake memory) {
        return stakers[_idPlan][_account];
    }

    /**
     * @dev Allows the contract owner to set or revoke the admin role for a specific address.
     *
     * @param _account The address for which the admin role will be set or revoked.
     * @param _value A boolean value indicating whether to set (true) or revoke (false) the admin role.
     *
     * Requirements:
     * - The caller must be the contract owner.
     *
     * Emits a `SetAdminAddress` event with information about the address and the admin role status.
     */
    function setAdminAddress(address _account, bool _value) public onlyOwner {
        require(_account != address(0), "Cannot zero address!");
        admins[_account] = _value;
        emit SetAdminAddress(_msgSender(), _account, _value);
    }

    /**
     * @dev Allows an admin to cancel a staking for a specific account and staking plan.
     *
     * @param _account The address of the account for which the staking will be canceled.
     * @param _idPlan The ID of the staking plan to be canceled.
     *
     * Requirements:
     * - The caller must have admin role.
     *
     * Emits a `CancelStake` event with information about the canceled stake.
     */
    function cancelStakeByAdmin(
        address _account,
        uint256 _idPlan,
        address _paymentAddress
    ) external nonReentrant {
        require(
            isAdmin(_msgSender()),
            "You must have admin role to cancel stake"
        );
        _cancelStake(_account, _idPlan, _paymentAddress);
    }

    /**
     * @dev Check if the given address has admin role.
     *
     * @param _account The address to check for admin role.
     * @return true if the address has admin role, false otherwise.
     */
    function isAdmin(address _account) public view returns (bool) {
        return admins[_account];
    }

    /**
     * @dev Set the amount of token pairs per ship.
     * This function allows an admin to set the amount of token pairs that are required for each ship staked in the contract.
     */
    function setTokenPairPerShip(uint256 _amount) public {
        require(
            isAdmin(_msgSender()),
            "You must have admin role to set token pair pership"
        );
        tokenPairPerShip = _amount;
        emit SetTokenPairPerShip(_msgSender(), _amount);
    }

    /**
     * @dev Allows an admin to set the maximum number of ships that can be staked.
     */
    function setMaxShip(uint256 _maxShip) public {
        require(
            isAdmin(_msgSender()),
            "You must have admin role to set max ship"
        );
        maxShip = _maxShip;
        emit SetMaxShip(_msgSender(), _maxShip);
    }

    /**
     * @dev Set a new staking plan with the specified duration and annual percentage rate (APR).
     *
     * This function allows an admin to add a new staking plan with the specified duration and APR.
     *
     * @param _idPlan The ID of the new staking plan.
     * @param _duration The duration of the staking plan in seconds.
     * @param _apr The annual percentage rate (APR) for the staking plan.
     *
     * Requirements:
     * - The caller must have admin role.
     * - The specified plan ID must not have been used before.
     *
     * Emits an `SetPlan` event with information about the new staking plan.
     */
    function setPlan(
        uint256 _idPlan,
        uint256 _duration,
        uint256 _apr,
        address _nftAddress
    ) public {
        require(
            isAdmin(_msgSender()),
            "You must have admin role to set staking plan"
        );
        require(plans[_idPlan].duration == 0, "This index already been used");
        plans[_idPlan] = Plan(_duration, _apr, _nftAddress);
        emit SetPlan(_msgSender(), _duration, _apr, _idPlan, _nftAddress);
    }

    /**
     * @dev Removes a staking plan with the specified ID.
     *
     * This function allows an admin to remove a staking plan with the specified ID.±≠
     *
     * @param _idPlan The ID of the staking plan to be removed.
     *
     * Requirements:
     * - The caller must have admin role.
     *
     * Emits a `RemovePlan` event with information about the removed staking plan.
     */
    function removePlan(uint256 _idPlan) external {
        require(
            isAdmin(_msgSender()),
            "You must have admin role to set staking plan"
        );
        delete plans[_idPlan];
        emit RemovePlan(_msgSender(), _idPlan);
    }

    /**
     * @dev Stakes the specified amount of NFTs and tokens for the specified duration and APR.
     *
     * This function allows a user to stake a specified amount of NFTs and tokens for the specified
     * duration and APR, according to the staking plan identified by '_idPlan'.
     *
     * Requirements:
     * - '_expiredAt' must be greater than the current block timestamp.
     * - 'signer' must be set to a non-zero address.
     * - The signature must be valid using the 'verifySignature' function.
     *
     * Emits a 'Staked' event with information about the stake transaction.
     */
    function stake(
        address _account,
        uint256[] memory _nftIds,
        uint256 _amount,
        address _nftAddress,
        address _paymentAddress,
        uint256 _idPlan,
        uint256 _expiredAt,
        uint256 _nonce,
        uint256 _chainId,
        bytes memory _signature
    ) external nonReentrant {
        require(_expiredAt > block.timestamp, "The signature is expired!");
        require(signer != address(0), "Signer has not been set!");
        require(_account != address(0), "Account cannot zero address!");
        require(_paymentAddress != address(0), "Payment cannot zero address");
        require(
            plans[_idPlan].nftAddress == _nftAddress,
            "NFT address invalid"
        );
        require(
            verifySignature(
                _account,
                _nftIds,
                _amount,
                _nftAddress,
                _paymentAddress,
                _idPlan,
                _expiredAt,
                _nonce,
                _chainId,
                _signature
            ),
            "Invalid signature!"
        );
        _stake(
            _account,
            _nftIds,
            _amount,
            _nftAddress,
            _paymentAddress,
            _idPlan
        );
    }

    /**
     * @dev Allows a user to unstake their NFTs and tokens.
     *
     * This function allows a user to unstake their NFTs and tokens from the specified staking plan. It transfers the NFTs
     * back to the user and the staked tokens back to the user's payment address. Additionally, it deletes the staking record
     * for the user.
     *
     * @param _idPlan The ID of the staking plan from which the user wants to unstake.
     *
     * Requirements:
     * - The user must have an active staking for the specified staking plan.
     * - The current timestamp must be greater than or equal to the start time of the staking plan plus its duration.
     *
     * Emits an `Unstaked` event with information about the unstake transaction, including the user's address,
     * the NFT IDs unstaked, the amount of tokens unstaked, and the staking plan ID.
     */
    function unstake(
        uint256 _idPlan,
        address _paymentAddress
    ) external nonReentrant {
        _unstake(_idPlan, _paymentAddress);
    }

    /**
     * @dev Allows a user to claim their reward after the staking period has ended.
     *
     * This function allows a user to claim their reward after the staking period has ended. The reward is calculated based on the staked amount, APR, and duration of the staking plan. The reward is transferred from the contract to the user's address, and the staking record is updated to mark the reward as claimed.
     *
     * Requirements:
     * - The staking period for the user must have ended.
     * - The user must have a staked amount.
     * - The user must not have already claimed their reward.
     *
     * Emits a `ClaimReward` event with information about the user, the staking plan ID, and the amount of the claimed reward.
     */
    function claimReward(
        uint256 _idPlan,
        address _paymentAddress
    ) public nonReentrant {
        Stake memory staker = stakers[_idPlan][_msgSender()];
        require(
            block.timestamp >= staker.startAt + staker.plan.duration,
            "You're staking not expired!"
        );
        require(staker.amount != 0, "You don't have a staked amount!");
        require(staker.isClaimed == false, "You have claimed your reward!");

        // reward = stakedAmount * apr * duration / (360 days * 100)
        uint256 daysOfDuration = staker.plan.duration / 1 days;
        uint256 totalReward = (staker.amount *
            staker.plan.apr *
            daysOfDuration) / (360 * 100);
        staker.isClaimed = true;

        // transfer from owner to user
        IERC20 token = IERC20(_paymentAddress);
        token.safeTransfer(_msgSender(), totalReward);

        emit ClaimReward(_msgSender(), _idPlan, totalReward, _paymentAddress);
    }

    /**
     * @dev Stake NFTs and tokens for the specified duration and APR.
     */
    function _stake(
        address account,
        uint256[] memory _nftIds,
        uint256 _amount,
        address _nftAddress,
        address _paymentAddress,
        uint256 _idPlan
    ) internal {
        require(
            stakers[_idPlan][account].amount == 0,
            "You're already on staking!"
        );
        require(plans[_idPlan].duration != 0, "Staking plan not found!");

        uint256 requireAmount = _nftIds.length * tokenPairPerShip;
        require(
            _amount == requireAmount,
            "Your staking amount does not match the required amount!"
        );

        stakers[_idPlan][account] = Stake(
            _nftIds,
            _amount,
            block.timestamp,
            false,
            plans[_idPlan]
        );

        // transfer token from user to staking
        IERC20 token = IERC20(_paymentAddress);
        require(
            token.balanceOf(account) >= _amount,
            "Staking amount exceed your balances!"
        );

        // transfer nft from user to staking
        IERC721 nft = IERC721(_nftAddress);
        for (uint i = 0; i < _nftIds.length; i++) {
            nft.safeTransferFrom(account, address(this), _nftIds[i]);
        }
        token.safeTransferFrom(account, address(this), _amount);

        emit Staked(
            account,
            _nftIds,
            _amount,
            _nftAddress,
            _paymentAddress,
            _idPlan
        );
    }

    /**
     * @dev Allows a user to unstake their NFTs and tokens.
     */
    function _unstake(uint256 _idPlan, address _paymentAddress) internal {
        Stake memory staker = stakers[_idPlan][_msgSender()];
        require(staker.amount != 0, "You don't have a staking!");
        require(
            block.timestamp >= staker.startAt + staker.plan.duration,
            "Your staking not expired!"
        );

        delete stakers[_idPlan][_msgSender()];

        // transfer from staking to user
        IERC721 nft = IERC721(staker.plan.nftAddress);
        for (uint i = 0; i < staker.nftIds.length; i++) {
            nft.safeTransferFrom(address(this), _msgSender(), staker.nftIds[i]);
        }

        // transfer token from user to staking
        IERC20 token = IERC20(_paymentAddress);
        token.safeTransfer(_msgSender(), staker.amount);

        emit Unstaked(
            _msgSender(),
            staker.nftIds,
            staker.plan.nftAddress,
            staker.amount,
            _paymentAddress,
            _idPlan
        );
    }

    /**
     * @dev Cancels a staking for a specific account and staking plan.
     */
    function _cancelStake(
        address _account,
        uint256 _idPlan,
        address _paymentAddress
    ) internal {
        Stake memory staker = stakers[_idPlan][_account];
        require(staker.amount != 0, "Account don't have a staking!");

        delete stakers[_idPlan][_account];

        // transfer from staking to user
        IERC721 nft = IERC721(staker.plan.nftAddress);
        for (uint i = 0; i < staker.nftIds.length; i++) {
            nft.safeTransferFrom(address(this), _account, staker.nftIds[i]);
        }

        // transfer token from user to staking
        IERC20 token = IERC20(_paymentAddress);
        token.safeTransfer(_account, staker.amount);

        emit CancelStake(_account, _idPlan);
    }

    /**
     * @dev Calculates the message hash for the provided parameters.
     */
    function getMessageHash(
        address account,
        uint256[] memory _nftIds,
        uint256 _amount,
        address _nftAddress,
        address _paymentAddress,
        uint256 _idPlan,
        uint256 _expiredAt,
        uint256 _nonce,
        uint256 _chainId
    ) public pure returns (bytes32) {
        return
            keccak256(
                abi.encodePacked(
                    account,
                    _nftIds,
                    _amount,
                    _nftAddress,
                    _paymentAddress,
                    _idPlan,
                    _expiredAt,
                    _nonce,
                    _chainId
                )
            );
    }

    /**
     * @dev Verifies the signature for the provided parameters.
     * @return true if the signature is valid, false otherwise.
     */
    function verifySignature(
        address _account,
        uint256[] memory _nftIds,
        uint256 _amount,
        address _nftAddress,
        address _paymentAddress,
        uint256 _idPlan,
        uint256 _expiredAt,
        uint256 _nonce,
        uint256 _chainId,
        bytes memory _signature
    ) public returns (bool) {
        require(!usedNonces[_account][_nonce], "Nonce already used");
        // Get the current chainId
        uint256 chainId = block.chainid;
        require(chainId == _chainId, "Invalid chainId!");
        usedNonces[_account][_nonce] = true;
        bytes32 criteriaMessageHash = getMessageHash(
            _account,
            _nftIds,
            _amount,
            _nftAddress,
            _paymentAddress,
            _idPlan,
            _expiredAt,
            _nonce,
            _chainId
        );
        bytes32 ethMessageHash = ECDSA.toEthSignedMessageHash(
            criteriaMessageHash
        );
        return ECDSA.recover(ethMessageHash, _signature) == signer;
    }

    /**
     * @dev Function to check if the token transfer is fee-free
     *
     * This function checks if transferring a token incurs a fee by performing a test transfer of 1 token
     * and comparing the balance before and after the transfer.
     *
     * @param _tokenAddress The address of the token contract to be tested
     *
     * @return true if the token transfer is fee-free, false otherwise
     */
    function isTransferFeeFree(address _tokenAddress) internal returns (bool) {
        IERC20 token = IERC20(_tokenAddress);

        uint256 initialBalance = token.balanceOf(address(this));
        token.safeTransfer(address(this), 1);
        uint256 finalBalance = token.balanceOf(address(this));
        bool feeFree = finalBalance == initialBalance.sub(1);

        return feeFree;
    }
}
