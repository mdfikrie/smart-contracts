// SPDX-License-Identifier: MIT
pragma solidity >=0.8.2 <0.9.0;
import "./Ownable.sol";
import "./Context.sol";
import "./IERC20.sol";
import "./ECDSA.sol";
import "./SafeERC20.sol";

/// @title A flexible staking for IZTAR TOKEN (IZR)
/// @author Iztar Dev
/// @notice This contract does not support rebase token.
contract FlexibleStaking is Context, Ownable {
    // ========== LIB ========== //
    using SafeERC20 for IERC20;

    // ========== STATE VARIABLES ========== //
    mapping(address => uint256) private totalStaked;
    mapping(address => uint256) private rewardPool;
    mapping(address => uint256) private minStake;
    mapping(address => uint256) private maxStake;
    mapping(address => uint256) private apr;
    uint256 public maxAPR = 450;
    address private signer;
    bool private _notEntered;

    mapping(address => bool) private admins;
    mapping(address => mapping(uint256 => bool)) public usedNonces;

    struct Stake {
        uint256 amount;
        uint256 startTime;
    }

    mapping(address => mapping(address => Stake)) private stakers;
    mapping(address => mapping(address => uint256)) private rewards;

    // =========== EVENTS ============= //
    event Staked(
        address indexed _staker,
        address _tokenAddress,
        uint256 _amount,
        uint256 _startTime
    );
    event Restake(
        address indexed _staker,
        address _tokenAddress,
        uint256 _amount,
        uint256 _startTime
    );
    event Unstaked(
        address indexed _staker,
        address _tokenAddress,
        uint256 _amount
    );
    event CancelStake(
        address indexed _account,
        address _tokenAddress,
        uint256 _amount
    );
    event WithDraw(
        address indexed _account,
        address _tokenAddress,
        uint256 _amount
    );
    event SetAdminAddress(address indexed _account, bool _value);
    event SetAPR(address indexed _account, address _tokenAddress, uint256 _apr);
    event SetMaxStake(
        address indexed _account,
        address _tokenAddress,
        uint256 _amount
    );
    event SetMinStake(
        address indexed _account,
        address _tokenAddress,
        uint256 _amount
    );
    event Claim(
        address indexed _account,
        address _tokenAddress,
        uint256 _amount
    );
    event SetSigner(address indexed account);
    event SetRewardPool(
        address indexed account,
        address _tokenAddress,
        uint256 _rewardPool
    );

    constructor(
        uint256 _apr,
        address _tokenAddress,
        uint256 _rewardPool,
        uint256 _minStake,
        uint256 _maxStake,
        address _admin,
        address _signer
    ) {
        admins[_admin] = true;
        rewardPool[_tokenAddress] = _rewardPool;
        setApr(_tokenAddress, _apr);
        setMinStake(_tokenAddress, _minStake);
        setMaxStake(_tokenAddress, _maxStake);
        setSigner(_signer);
        _notEntered = true;
    }

    modifier nonReentrant() {
        require(_notEntered, "ReentrancyGuard: reentrant call");
        _notEntered = false;
        _;
        _notEntered = true;
    }

    /**
     * @dev Sets the signer address for the marketplace.
     * @param account The address to be set as the signer.
     * Requirements:
     * - The caller must be an admin.
     * - The provided account address cannot be zero.
     */
    function setSigner(address account) public {
        require(isAdmin(_msgSender()), "You're not admin to set signer");
        require(account != address(0), "Signer cannot zero address");
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
     * @dev Function to set the reward pool for a specific token
     *
     * This function allows an admin to set the reward pool available for staking with a specific token.
     * The reward pool is the maximum amount of tokens that can be distributed as rewards to stakers.
     *
     * @param _tokenAddress The address of the token contract for which the reward pool is being set
     * @param _rewardPool The total amount of tokensR to be set as the reward
     *
     * Requirements:
     * - The caller must have admin privileges
     * - Balance more than total staked + rewardpool
     * - The token cannot address
     * - Reward pool cannot zero amount
     * - Reward pool must greather than total staked
     *
     * Emits a SetRewardPool event with details of the reward pool being set
     */
    function setRewardPool(address _tokenAddress, uint256 _rewardPool) public {
        require(isAdmin(_msgSender()), "You're not admin to set reward pool");
        require(_tokenAddress != address(0), "Invalid address");
        require(_rewardPool != 0, "Reward pool cannot zero");
        IERC20 token = IERC20(_tokenAddress);
        require(
            token.balanceOf(address(this)) >=
                totalStaked[_tokenAddress] + _rewardPool,
            "Balance is less than total staked + rewardPool"
        );
        rewardPool[_tokenAddress] = _rewardPool;

        emit SetRewardPool(_msgSender(), _tokenAddress, _rewardPool);
    }

    /**
     * @dev Function to get reward pool from this address
     *
     * @param _tokenAddress The address of the token contract
     *
     */
    function getRewardPool(
        address _tokenAddress
    ) public view returns (uint256) {
        require(
            rewardPool[_tokenAddress] != 0,
            "Total reward for token not set"
        );
        return rewardPool[_tokenAddress];
    }

    /**
     * @dev Function to set address to be an admin
     * @param account The address that will be set as an admin
     * @notice This function can only be called by the owner of the contract
     * @dev Emits a SetAdminAddress event
     */
    function setAdminAddress(address account) public onlyOwner {
        require(account != address(0), "Cannot zero address!");
        admins[account] = true;
        emit SetAdminAddress(account, true);
    }

    /**
     * @dev Function to remove address from admin
     * @param account The address that will be removed from admin
     * @notice This function can only be called by the owner of the contract
     * @dev Emits a SetAdminAddress event
     */
    function removeAdminAddress(address account) public onlyOwner {
        require(account != address(0), "Cannot zero address!");
        admins[account] = false;
        emit SetAdminAddress(account, false);
    }

    /**
     * @dev Function to cancel stake by admin
     *
     * This function allows an admin to cancel a stake for a specific account.
     *
     * @param _tokenAddress The address of the token contract
     * @param account The address of the account whose stake will be canceled
     * @param _amount The amount of tokens to be canceled from the stake
     *
     * Requirements:
     * - The caller must have admin privileges
     * - The amount to cancel must not exceed the current stake balance of the account
     *
     * Emits a CancelStake event
     */
    function cancelStakeByAdmin(
        address _tokenAddress,
        address account,
        uint256 _amount
    ) external {
        require(
            isAdmin(_msgSender()),
            "You must have admin role to cancel stake"
        );
        _cancelStake(_tokenAddress, account, _amount);
    }

    /**
     * @dev Function to check address is admin
     */
    function isAdmin(address account) public view returns (bool) {
        return admins[account];
    }

    /**
     * @dev Function to get minimal staking
     */
    function getMinStake(
        address _tokenAddress
    ) external view returns (uint256) {
        return minStake[_tokenAddress];
    }

    /**
     * @dev Function to get maximal staking
     */
    function getMaxStake(
        address _tokenAddress
    ) external view returns (uint256) {
        return maxStake[_tokenAddress];
    }

    /**
     * @dev Function to get APR staking
     */
    function getAPR(address _tokenAddress) external view returns (uint256) {
        return apr[_tokenAddress];
    }

    /**
     * @dev Function to get total staked amount
     */
    function getTotalStaked(
        address _tokenAddress
    ) external view returns (uint256) {
        return totalStaked[_tokenAddress];
    }

    /**
     * @dev Function to withdraw token from the contract
     *
     * This function allows an admin to withdraw tokens from the contract balance.
     *
     * Requirements:
     * - The caller must have admin privileges
     * - The total reward must be greater than or equal to the specified amount
     *
     * @param _tokenAddress The address of the token contract
     * @param _amount The amount of tokens to withdraw from the contract balance
     *
     * Emits a WithDraw event with details of the withdrawal transaction
     */
    function withDraw(
        address _tokenAddress,
        uint256 _amount
    ) external nonReentrant {
        require(
            isAdmin(_msgSender()),
            "You must have admin role to withdraw token"
        );
        IERC20 token = IERC20(_tokenAddress);

        uint256 balance = token.balanceOf(address(this)) -
            totalStaked[_tokenAddress];
        uint256 limitAmount = balance - rewardPool[_tokenAddress];

        require(
            limitAmount >= _amount,
            "Amount exceeds the balance limit for withdrawal"
        );
        token.safeTransfer(_msgSender(), _amount);

        emit WithDraw(_msgSender(), _tokenAddress, _amount);
    }

    /**
     * @dev Function to set the annual percentage rate (APR) for staking
     * This function allows an admin to set the APR for staking rewards.
     *
     * @param _apr The new APR value to be set
     *
     * Requirements:
     * - The caller must have admin privileges
     * - The APR value must be less than or equal to the maximum APR value
     *
     * Emits a SetAPR event with the updated APR value
     */
    function setApr(address _tokenAddress, uint256 _apr) public {
        require(isAdmin(_msgSender()), "You must have admin role to set APR");
        require(_apr <= maxAPR, "APR value greather than 450");
        apr[_tokenAddress] = _apr;
        emit SetAPR(_msgSender(), _tokenAddress, _apr);
    }

    /**
     * @dev Function to set the minimum amount of tokens that can be staked
     *
     * This function allows an admin to set the minimum amount of tokens that can be staked by users.
     *
     * @param _amount The new minimum amount of tokens to be set
     *
     * Requirements:
     * - The caller must have admin privileges
     *
     * Emits a SetMinStake event with the updated minimum stake amount
     */
    function setMinStake(address _tokenAddress, uint256 _amount) public {
        require(
            isAdmin(_msgSender()),
            "You must have admin role to set min stake"
        );
        minStake[_tokenAddress] = _amount;
        emit SetMinStake(_msgSender(), _tokenAddress, _amount);
    }

    /**
     * @dev Function to set max token to stake
     *
     * Requirements:
     * - Address must be an admin
     *
     * @param _amount The new maximum amount of tokens that can be staked
     *
     * Emits a SetMaxStake event with the updated maximum stake amount
     */
    function setMaxStake(address _tokenAddress, uint256 _amount) public {
        require(
            isAdmin(_msgSender()),
            "You must have admin role to set max stake"
        );
        maxStake[_tokenAddress] = _amount;
        emit SetMaxStake(_msgSender(), _tokenAddress, _amount);
    }

    /**
     * @dev Function to stake token
     *
     * @param _account The address of the account staking the tokens
     * @param _amount The amount of tokens to stake
     * @param _tokenAddress The address of the token contract
     * @param _expiredAt The expiration timestamp for the signature
     * @param _nonce The unique identifier for the signature
     * @param _signature The signature provided for verification
     *
     * Requirements:
     * - The signature must not be expired
     * - The signature must be verified
     * - The amount must be within the specified limits
     *
     * Emits a Staked event with details of the staking transaction
     */
    function stake(
        address _account,
        uint256 _amount,
        address _tokenAddress,
        uint256 _expiredAt,
        uint256 _nonce,
        uint256 _chainId,
        bytes calldata _signature
    ) external nonReentrant {
        require(_expiredAt > block.timestamp, "The signature is expired!");
        require(
            verifySignature(
                _account,
                _amount,
                _tokenAddress,
                _expiredAt,
                _nonce,
                _chainId,
                _signature
            ),
            "Invalid signature!"
        );
        _stake(_account, _amount, _tokenAddress);
    }

    /**
     * @dev Function to unstake tokens
     *
     * This function allows a user to unstake a certain amount of tokens from their staking balance.
     * If the staking has expired, any available rewards will be automatically claimed before unstaking.
     *
     * @param _tokenAddress The address of the token contract
     * @param _amount The amount of tokens to unstake
     *
     * Requirements:
     * - The user must have an existing staking balance
     * - Then if there is an avalable reward will be automatically claimed
     *
     * Emits an Unstaked event with details of the unstaking transaction
     */
    function unstake(
        address _tokenAddress,
        uint256 _amount
    ) external nonReentrant {
        // claim tokens when the staking time expires
        if (_stakeExpired(_tokenAddress, _msgSender())) {
            _claim(_tokenAddress);
        }
        _unstake(_tokenAddress, _amount);
    }

    /**
     * @dev Function to unstake tokens without reward
     *
     * This function allows a user to unstake a certain amount of tokens from their staking balance.
     * If the staking has expired, user cannot claim reward
     *
     * @param _tokenAddress The address of the token contract
     * @param _amount The amount of tokens to unstake
     *
     * Emits an Unstaked event with details of the unstaking transaction
     */
    function unstakeWithoutRewards(
        address _tokenAddress,
        uint256 _amount
    ) external nonReentrant {
        _unstake(_tokenAddress, _amount);
    }

    /**
     * @dev Function to claim reward
     *
     * This function allows a user to claim their staking rewards.
     * The rewards can only be claimed if the staking period has expired.
     * If the user has not claimed their rewards after the staking period has ended,
     * they can still claim the rewards at any time.
     *
     * @param _tokenAddress The address of the token contract
     *
     * Requirements:
     * - Staking period must have expired
     *
     * Emits a Claim event with details of the claimed rewards
     */
    function claimReward(address _tokenAddress) external nonReentrant {
        require(
            _stakeExpired(_tokenAddress, _msgSender()),
            "Your staking not expired!"
        );
        _claim(_tokenAddress);
    }

    /**
     * @dev Function to restake token
     *
     * This function allows a user to restake any available rewards they have earned.
     *
     * @param _tokenAddress The address of the token contract
     *
     * Requirements:
     * - The user must have rewards available
     * - The staking period must have expired
     *
     * Emits a Staked event with details of the restaked transaction
     */
    function restake(address _tokenAddress) external nonReentrant {
        require(
            _stakeExpired(_tokenAddress, _msgSender()),
            "Your staking not expired!"
        );
        uint256 _reward = rewardAvailable(_tokenAddress, _msgSender());
        uint256 totalAmount = stakers[_tokenAddress][_msgSender()].amount +
            _reward;
        require(
            totalAmount <= maxStake[_tokenAddress],
            "Total amount exceeds the maximum stake"
        );
        _restake(_tokenAddress, _reward);
    }

    /**
     * @dev Function to check balance user
     *
     * @param _tokenAddress The address of the token contract
     * @param account The address of the account for which the total reward claimed is checked
     *
     */
    function balanceOf(
        address _tokenAddress,
        address account
    ) external view returns (uint256) {
        return stakers[_tokenAddress][account].amount;
    }

    /**
     * @dev Function to check total reward token claimed
     *
     * This function allows external contracts or users to check the total reward
     * tokens claimed by a specific account.
     *
     * @param _tokenAddress The address of the token contract
     * @param account The address of the account for which the total reward claimed is checked
     *
     * @return The total amount of reward tokens claimed by the specified account
     */
    function rewardClaimed(
        address _tokenAddress,
        address account
    ) external view returns (uint256) {
        return rewards[_tokenAddress][account];
    }

    /**
     * @dev Function to check if there is a reward available for a specific account
     *
     * This function calculates the available reward for the specified account
     * based on the annual percentage rate (APR) and staking amount.
     *
     * @param _tokenAddress The address of the token contract
     * @param _account The address of the account for which the reward availability is checked
     *
     * @return The total amount of reward tokens available for claiming by the specified account
     */
    function rewardAvailable(
        address _tokenAddress,
        address _account
    ) public view returns (uint256) {
        if (_stakeExpired(_tokenAddress, _account)) {
            uint256 _rewardPerDay = ((apr[_tokenAddress] *
                stakers[_tokenAddress][_account].amount) / 365) / 100;
            uint256 _totalDay = (block.timestamp -
                stakers[_tokenAddress][_account].startTime) / 1 days;
            uint256 _totalReward = _rewardPerDay * _totalDay;
            return _totalReward;
        }
        return 0;
    }

    /**
     * @dev Function to check if the staking period has expired
     *
     * This function checks if the staking period has expired for a specific account by comparing the current block timestamp
     * with the start time of the staking plus the duration for claiming rewards.
     *
     * @return true if the staking period has expired, false otherwise
     */
    function _stakeExpired(
        address _tokenAddress,
        address _account
    ) internal view returns (bool) {
        if (
            block.timestamp >=
            stakers[_tokenAddress][_account].startTime + 1 days
        ) {
            return true;
        }
        return false;
    }

    /**
     * @dev Function cancel stake
     * Requirements:
     * - amount does not exceed the balance
     */
    function _cancelStake(
        address _tokenAddress,
        address _staker,
        uint256 _amount
    ) internal {
        require(
            stakers[_tokenAddress][_staker].amount >= _amount,
            "Amount exceed balances!"
        );

        stakers[_tokenAddress][_staker].amount -= _amount;
        totalStaked[_tokenAddress] -= _amount;

        // transfer token from contract to staker
        IERC20 token = IERC20(_tokenAddress);
        token.safeTransfer(_staker, _amount);

        emit CancelStake(_staker, _tokenAddress, _amount);
    }

    /**
     * @dev Function to stake token
     * Requirements:
     * - The amount to stake must not be zero
     * - The APR for the token contract must be greater than zero
     * - There must be total rewards available for staking
     * - The token contract address cannot be zero
     * - The token contract must not have a free transfer fee
     * - The total amount of tokens staked must be within the specified limits
     * - The token must free transfer fee
     */
    function _stake(
        address _staker,
        uint256 _amount,
        address _tokenAddress
    ) internal {
        require(_amount != 0, "Amount stake below zero");
        require(apr[_tokenAddress] > 0, "APR is not available");
        require(
            _tokenAddress != address(0),
            "Token contract cannot zero address"
        );

        Stake storage staker = stakers[_tokenAddress][_staker];

        uint256 totalAmount = staker.amount + _amount;
        require(
            totalAmount >= minStake[_tokenAddress] &&
                totalAmount <= maxStake[_tokenAddress],
            "Amount stake less than minStake or more than maxStake"
        );

        // if there is staking available
        if (staker.startTime != 0) {
            // claim tokens when the staking time expires
            if (_stakeExpired(_tokenAddress, _staker)) {
                _claim(_tokenAddress);
            }
        }

        IERC20 token = IERC20(_tokenAddress);

        // check initial balance
        uint256 initialContractBalance = token.balanceOf(address(this));

        uint256 _startTime = block.timestamp;

        staker.startTime = _startTime;
        staker.amount += _amount;
        totalStaked[_tokenAddress] += _amount;

        // transfer token from staker to contract
        token.safeTransferFrom(_staker, address(this), _amount);

        // check final balance
        uint256 finalContractBalance = token.balanceOf(address(this));
        uint256 actualReceived = finalContractBalance - initialContractBalance;

        // Calculate actual amount transferred after fee
        require(
            actualReceived == _amount,
            "Token transfer amount mismatch: possible transfer fee"
        );

        emit Staked(_staker, _tokenAddress, _amount, _startTime);
    }

    /**
     * @dev Function to unstake token
     * Requirements:
     * - must have existing staking
     */
    function _unstake(address _tokenAddress, uint256 _amount) internal {
        Stake storage staker = stakers[_tokenAddress][_msgSender()];

        require(staker.amount != 0, "You don't have an amount on staking");

        totalStaked[_tokenAddress] -= _amount;
        staker.amount -= _amount;

        // transfer token from contract to staker
        IERC20 token = IERC20(_tokenAddress);
        token.safeTransfer(_msgSender(), _amount);

        emit Unstaked(_msgSender(), _tokenAddress, _amount);
    }

    /**
     * @dev Function to claim reward
     */
    function _claim(address _tokenAddress) internal {
        uint256 _reward = rewardAvailable(_tokenAddress, _msgSender());

        IERC20 token = IERC20(_tokenAddress);

        require(
            token.balanceOf(address(this)) >= rewardPool[_tokenAddress],
            "The reward pool exceed balance"
        );
        require(
            rewardPool[_tokenAddress] >= _reward,
            "The reward exceeds reward pool"
        );

        rewards[_tokenAddress][_msgSender()] += _reward;
        rewardPool[_tokenAddress] -= _reward;
        stakers[_tokenAddress][_msgSender()].startTime = block.timestamp;

        // transfer reward
        token.safeTransfer(_msgSender(), _reward);

        emit Claim(_msgSender(), _tokenAddress, _reward);
    }

    /**
     * @dev Function to restake
     */
    function _restake(address _tokenAddress, uint256 _reward) internal {
        Stake storage staker = stakers[_tokenAddress][_msgSender()];
        totalStaked[_tokenAddress] += _reward;
        rewardPool[_tokenAddress] -= _reward;

        uint256 _startTime = block.timestamp;

        staker.amount += _reward;
        staker.startTime = _startTime;
        rewards[_tokenAddress][_msgSender()] += _reward;

        emit Restake(_msgSender(), _tokenAddress, _reward, _startTime);
    }

    function getMessageHash(
        address _account,
        uint256 _amount,
        address _tokenAddress,
        uint256 _expiredAt,
        uint256 _nonce,
        uint256 _chainId
    ) public pure returns (bytes32) {
        return
            keccak256(
                abi.encodePacked(
                    _account,
                    _amount,
                    _tokenAddress,
                    _expiredAt,
                    _nonce,
                    _chainId
                )
            );
    }

    /**
     * @dev Function to verify signature
     *
     * This function verifies the signature provided by a user against the message hash
     * generated using the account address, amount, token address, and expiration timestamp.
     *
     * @return true if the signature is valid and the signer is equal to the _msgSender(), false otherwise
     *
     * Requirements:
     * - The nonce provided must not have been used previously
     */
    function verifySignature(
        address _account,
        uint256 _amount,
        address _tokenAddress,
        uint256 _expiredAt,
        uint256 _nonce,
        uint256 _chainId,
        bytes calldata _signature
    ) public returns (bool) {
        require(!usedNonces[_account][_nonce], "Nonce already used");
        // Get the current chainId
        uint256 chainId = block.chainid;
        require(chainId == _chainId, "Invalid chainId!");
        bytes32 criteriaMessageHash = getMessageHash(
            _account,
            _amount,
            _tokenAddress,
            _expiredAt,
            _nonce,
            _chainId
        );
        bytes32 ethMessageHash = ECDSA.toEthSignedMessageHash(
            criteriaMessageHash
        );
        usedNonces[_account][_nonce] = true;
        address _signer = ECDSA.recover(ethMessageHash, _signature);
        return _signer == signer;
    }
}
