// SPDX-License-Identifier: MIT
pragma solidity >=0.8.2 <0.9.0;
import "./MathLibrary.sol";
import "./IBEP20.sol";
import "./Context.sol";
import "./Ownable.sol";
import "./Pausable.sol";

/// @title IZTAR TOKEN (IZTAR)
/// @author Iztar Dev
contract IztarToken is Context, Pausable, Ownable, IBEP20 {
    // ========== LIB =========== //
    using MathLibrary for uint256;

    // ========== STATE VARIABLES ========== //
    uint256 private _totalSupply;
    uint8 private immutable _decimals;
    uint256 private _totalBurned;
    string private _symbol;
    string private _name;
    uint256 private immutable _maxSupply = 500 * 1e6 * 1e18;
    mapping(address => uint256) private _balances;
    mapping(address => mapping(address => uint256)) private _allowance;

    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    bytes32 public constant PAUSE_ROLE = keccak256("PAUSE_ROLE");

    mapping(bytes32 => mapping(address => bool)) private _roleMembers;

    // ========== EVENT ========== //
    event SetupRole(address indexed account, bytes32 role, bool value);

    constructor() {
        _decimals = 18;
        _symbol = "IZTAR";
        _name = "IZTAR";
        _totalBurned = 0;
        _balances[_msgSender()] = _totalSupply;
        setupRole(MINTER_ROLE, _msgSender());
        setupRole(PAUSE_ROLE, _msgSender());
    }

    /**
     * @dev Function to set up a role for a specific account.
     *
     * Requirements:
     * - Only the owner of the contract can call this function.
     */
    function setupRole(bytes32 role, address account) public onlyOwner {
        _roleMembers[role][account] = true;
        emit SetupRole(account, role, true);
    }

    /**
     * @dev Function to remove a role from a specific account.
     *
     * This function allows the owner of the contract to remove a role from a designated account.
     * After calling this function, the specified account will no longer have the designated role.
     *
     * Requirements:
     * - Only the owner of the contract can call this function.
     */
    function removeRole(bytes32 role, address account) public onlyOwner {
        _roleMembers[role][account] = false;
        emit SetupRole(account, role, false);
    }

    /**
     * @dev Function to check whether the account has a role
     * Returns a boolean value indicating whether the operation succeeded.
     */
    function hasRole(bytes32 role, address account) public view returns (bool) {
        return _roleMembers[role][account];
    }

    /**
     * @dev Function to pause contract functionality.
     *
     * Requirements:
     * - The caller must have the `PAUSE_ROLE`.
     */
    function pause() external {
        require(
            hasRole(PAUSE_ROLE, _msgSender()),
            "You must have pauser role to pause!"
        );
        _pause();
    }

    /**
     * @dev Function to unpause contract functionality.
     *
     * Requirements:
     * - The caller must have the `PAUSE_ROLE`.
     */
    function unpause() external {
        require(
            hasRole(PAUSE_ROLE, _msgSender()),
            "You must have unpauser role to pause!"
        );
        _unpause();
    }

    /**
     * @dev Function to check whether the contract is paused.
     *
     * @return A boolean value indicating whether the contract is paused.
     */
    function isPaused() external view returns (bool) {
        return paused();
    }

    /**
     * @dev Returns the total supply.
     */
    function totalSupply() external view override returns (uint256) {
        return _totalSupply;
    }

    /**
     * @dev Returns the total burned.
     */
    function totalBurned() external view override returns (uint256) {
        return _totalBurned;
    }

    /**
     * @dev Returns the token decimals.
     */
    function decimals() external view override returns (uint8) {
        return _decimals;
    }

    /**
     * @dev Returns the token symbol.
     */
    function symbol() external view override returns (string memory) {
        return _symbol;
    }

    /**
     * @dev Returns the token name.
     */
    function name() external view override returns (string memory) {
        return _name;
    }

    /**
     * @dev Function to get owner.
     */
    function getOwner() external view override returns (address) {
        return owner();
    }

    /**
     * @dev Function to get balance from account.
     * Returns the amount of tokens owned by `account`.
     */
    function balanceOf(
        address account
    ) external view override returns (uint256) {
        return _balances[account];
    }

    /**
     * @dev Function to transfer token
     * Returns a boolean value indicating whether the operation succeeded.
     */
    function transfer(
        address recipient,
        uint256 amount
    ) external override returns (bool) {
        _transfer(_msgSender(), recipient, amount);
        return true;
    }

    /**
     * @dev Returns the remaining number of tokens that `spender` will be
     * allowed to spend on behalf of `owner` through {transferFrom}. This is
     * zero by default.
     *
     * This value changes when {approve} or {transferFrom} are called.
     */
    function allowance(
        address owner,
        address spender
    ) external view override returns (uint256) {
        return _allowance[owner][spender];
    }

    /**
     * @dev Sets `amount` as the allowance of `spender` over the caller's tokens.
     * Returns a boolean value indicating whether the operation succeeded.
     */
    function approve(
        address spender,
        uint256 amount
    ) external override returns (bool) {
        _approve(_msgSender(), spender, amount);
        return true;
    }

    /**
     * @dev Moves `amount` tokens from `sender` to `recipient` using the
     * allowance mechanism. `amount` is then deducted from the caller's
     * allowance.
     * Returns a boolean value indicating whether the operation succeeded.
     */
    function transferFrom(
        address sender,
        address recipient,
        uint256 amount
    ) external override returns (bool) {
        _transfer(sender, recipient, amount);
        _approve(
            sender,
            _msgSender(),
            _allowance[sender][_msgSender()].sub(
                amount,
                "BEP20: transfer amount exceeds allowances"
            )
        );
        return true;
    }

    /**
     * @dev Atomically increases the allowance granted to `spender` by the caller.
     * This is an alternative to {approve} that can be used as a mitigation for
     * problems described in {BEP20-approve}.
     */
    function increaseAllowance(
        address spender,
        uint256 amount
    ) external returns (bool) {
        _approve(
            _msgSender(),
            spender,
            _allowance[_msgSender()][spender].add(amount)
        );
        return true;
    }

    /**
     * @dev Atomically decreases the allowance granted to `spender` by the caller.
     * This is an alternative to {approve} that can be used as a mitigation for
     * problems described in {BEP20-approve}.
     */
    function decreaseAllowance(
        address spender,
        uint256 amount
    ) external returns (bool) {
        _approve(
            _msgSender(),
            spender,
            _allowance[_msgSender()][spender].sub(
                amount,
                "BEP20: decrease allowance below zero"
            )
        );
        return true;
    }

    /**
     * @dev Burn `amount` tokens and decreasing the total supply.
     */
    function burn(uint amount) external returns (bool) {
        _burn(_msgSender(), amount);
        return true;
    }

    /**
     * @dev Burn `amount` tokens from `sender` using the
     * allowance mechanism.
     * Returns a boolean value indicating whether the operation succeeded.
     */
    function burnFrom(address account, uint256 amount) external returns (bool) {
        require(
            _allowance[account][_msgSender()] >= amount,
            "BEP20: burn amount exceed allowance"
        );
        _burn(account, amount);
        _approve(
            account,
            _msgSender(),
            _allowance[account][_msgSender()].sub(amount)
        );
        return true;
    }

    /**
     * @dev Creates `_amount` token to `_to`. Must only be called by account that has the MINTER_ROLE
     */
    function mint(address to, uint256 amount) external {
        require(
            hasRole(MINTER_ROLE, _msgSender()),
            "You must have minter role to mint"
        );
        _mint(to, amount);
    }

    /**
     * @dev Internal function to mint new tokens and assign them to an account.
     *
     * Requirements:
     * - `account` cannot be the zero address.
     * - Total supply + amount + total burned must not exceed the maximum supply limit.
     */
    function _mint(address account, uint256 amount) internal {
        require(account != address(0), "BEP20: mint to zero address");
        require(
            _totalSupply + amount + _totalBurned <= _maxSupply,
            "BEP20: (Total supply + amount - total burned) > max supply"
        );
        _totalSupply = _totalSupply.add(amount);
        _balances[account] = _balances[account].add(amount);
        emit Transfer(address(0), account, amount);
    }

    /**
     * @dev Internal function to transfer tokens from one account to another.
     *
     * Requirements:
     * - Sender and recipient cannot be the zero address.
     * - Sender must have sufficient balance to transfer.
     * - Contract must not be paused.
     */
    function _transfer(
        address sender,
        address recipient,
        uint256 amount
    ) internal whenNotPaused {
        require(sender != address(0), "BEP20: transfer from the zero address");
        require(recipient != address(0), "BEP20: transfer to the zero address");

        _balances[sender] = _balances[sender].sub(
            amount,
            "BEP20: transfer amount exceeds balance"
        );

        _balances[recipient] = _balances[recipient].add(amount);
        emit Transfer(sender, recipient, amount);
    }

    /**
     * @dev Internal function to burn a specific amount of tokens.
     *
     * Requirements:
     * - Account cannot be the zero address.
     * - Account must have sufficient balance to burn.
     */
    function _burn(address account, uint256 amount) internal {
        require(account != address(0), "BEP20: burn from the zero address");
        require(
            _balances[account] >= amount,
            "BEP20: burn amount exceed balances"
        );

        _balances[account] = _balances[account].sub(amount);
        _totalSupply = _totalSupply.sub(amount);

        _totalBurned = _totalBurned.add(amount);
        emit Transfer(account, address(0), amount);
    }

    /**
     * @dev Internal function to approve the transfer of tokens from one account to another.
     *
     * Requirements:
     * - Sender and spender cannot be the zero address.
     * - Sender must have sufficient balance to approve.
     */
    function _approve(
        address sender,
        address spender,
        uint256 amount
    ) internal {
        require(sender != address(0), "BEP20: address from the zero address");
        require(spender != address(0), "BEP20: address to the zero address");
        require(_balances[sender] >= amount, "BEP: amount exceeds the balance");
        _allowance[sender][spender] = amount;
        emit Approval(sender, spender, amount);
    }
}
