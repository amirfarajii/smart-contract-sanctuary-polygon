// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.7.0) (access/AccessControl.sol)

pragma solidity ^0.8.0;

import "./IAccessControl.sol";
import "../utils/Context.sol";
import "../utils/Strings.sol";
import "../utils/introspection/ERC165.sol";

/**
 * @dev Contract module that allows children to implement role-based access
 * control mechanisms. This is a lightweight version that doesn't allow enumerating role
 * members except through off-chain means by accessing the contract event logs. Some
 * applications may benefit from on-chain enumerability, for those cases see
 * {AccessControlEnumerable}.
 *
 * Roles are referred to by their `bytes32` identifier. These should be exposed
 * in the external API and be unique. The best way to achieve this is by
 * using `public constant` hash digests:
 *
 * ```
 * bytes32 public constant MY_ROLE = keccak256("MY_ROLE");
 * ```
 *
 * Roles can be used to represent a set of permissions. To restrict access to a
 * function call, use {hasRole}:
 *
 * ```
 * function foo() public {
 *     require(hasRole(MY_ROLE, msg.sender));
 *     ...
 * }
 * ```
 *
 * Roles can be granted and revoked dynamically via the {grantRole} and
 * {revokeRole} functions. Each role has an associated admin role, and only
 * accounts that have a role's admin role can call {grantRole} and {revokeRole}.
 *
 * By default, the admin role for all roles is `DEFAULT_ADMIN_ROLE`, which means
 * that only accounts with this role will be able to grant or revoke other
 * roles. More complex role relationships can be created by using
 * {_setRoleAdmin}.
 *
 * WARNING: The `DEFAULT_ADMIN_ROLE` is also its own admin: it has permission to
 * grant and revoke this role. Extra precautions should be taken to secure
 * accounts that have been granted it.
 */
abstract contract AccessControl is Context, IAccessControl, ERC165 {
    struct RoleData {
        mapping(address => bool) members;
        bytes32 adminRole;
    }

    mapping(bytes32 => RoleData) private _roles;

    bytes32 public constant DEFAULT_ADMIN_ROLE = 0x00;

    /**
     * @dev Modifier that checks that an account has a specific role. Reverts
     * with a standardized message including the required role.
     *
     * The format of the revert reason is given by the following regular expression:
     *
     *  /^AccessControl: account (0x[0-9a-f]{40}) is missing role (0x[0-9a-f]{64})$/
     *
     * _Available since v4.1._
     */
    modifier onlyRole(bytes32 role) {
        _checkRole(role);
        _;
    }

    /**
     * @dev See {IERC165-supportsInterface}.
     */
    function supportsInterface(bytes4 interfaceId) public view virtual override returns (bool) {
        return interfaceId == type(IAccessControl).interfaceId || super.supportsInterface(interfaceId);
    }

    /**
     * @dev Returns `true` if `account` has been granted `role`.
     */
    function hasRole(bytes32 role, address account) public view virtual override returns (bool) {
        return _roles[role].members[account];
    }

    /**
     * @dev Revert with a standard message if `_msgSender()` is missing `role`.
     * Overriding this function changes the behavior of the {onlyRole} modifier.
     *
     * Format of the revert message is described in {_checkRole}.
     *
     * _Available since v4.6._
     */
    function _checkRole(bytes32 role) internal view virtual {
        _checkRole(role, _msgSender());
    }

    /**
     * @dev Revert with a standard message if `account` is missing `role`.
     *
     * The format of the revert reason is given by the following regular expression:
     *
     *  /^AccessControl: account (0x[0-9a-f]{40}) is missing role (0x[0-9a-f]{64})$/
     */
    function _checkRole(bytes32 role, address account) internal view virtual {
        if (!hasRole(role, account)) {
            revert(
                string(
                    abi.encodePacked(
                        "AccessControl: account ",
                        Strings.toHexString(uint160(account), 20),
                        " is missing role ",
                        Strings.toHexString(uint256(role), 32)
                    )
                )
            );
        }
    }

    /**
     * @dev Returns the admin role that controls `role`. See {grantRole} and
     * {revokeRole}.
     *
     * To change a role's admin, use {_setRoleAdmin}.
     */
    function getRoleAdmin(bytes32 role) public view virtual override returns (bytes32) {
        return _roles[role].adminRole;
    }

    /**
     * @dev Grants `role` to `account`.
     *
     * If `account` had not been already granted `role`, emits a {RoleGranted}
     * event.
     *
     * Requirements:
     *
     * - the caller must have ``role``'s admin role.
     *
     * May emit a {RoleGranted} event.
     */
    function grantRole(bytes32 role, address account) public virtual override onlyRole(getRoleAdmin(role)) {
        _grantRole(role, account);
    }

    /**
     * @dev Revokes `role` from `account`.
     *
     * If `account` had been granted `role`, emits a {RoleRevoked} event.
     *
     * Requirements:
     *
     * - the caller must have ``role``'s admin role.
     *
     * May emit a {RoleRevoked} event.
     */
    function revokeRole(bytes32 role, address account) public virtual override onlyRole(getRoleAdmin(role)) {
        _revokeRole(role, account);
    }

    /**
     * @dev Revokes `role` from the calling account.
     *
     * Roles are often managed via {grantRole} and {revokeRole}: this function's
     * purpose is to provide a mechanism for accounts to lose their privileges
     * if they are compromised (such as when a trusted device is misplaced).
     *
     * If the calling account had been revoked `role`, emits a {RoleRevoked}
     * event.
     *
     * Requirements:
     *
     * - the caller must be `account`.
     *
     * May emit a {RoleRevoked} event.
     */
    function renounceRole(bytes32 role, address account) public virtual override {
        require(account == _msgSender(), "AccessControl: can only renounce roles for self");

        _revokeRole(role, account);
    }

    /**
     * @dev Grants `role` to `account`.
     *
     * If `account` had not been already granted `role`, emits a {RoleGranted}
     * event. Note that unlike {grantRole}, this function doesn't perform any
     * checks on the calling account.
     *
     * May emit a {RoleGranted} event.
     *
     * [WARNING]
     * ====
     * This function should only be called from the constructor when setting
     * up the initial roles for the system.
     *
     * Using this function in any other way is effectively circumventing the admin
     * system imposed by {AccessControl}.
     * ====
     *
     * NOTE: This function is deprecated in favor of {_grantRole}.
     */
    function _setupRole(bytes32 role, address account) internal virtual {
        _grantRole(role, account);
    }

    /**
     * @dev Sets `adminRole` as ``role``'s admin role.
     *
     * Emits a {RoleAdminChanged} event.
     */
    function _setRoleAdmin(bytes32 role, bytes32 adminRole) internal virtual {
        bytes32 previousAdminRole = getRoleAdmin(role);
        _roles[role].adminRole = adminRole;
        emit RoleAdminChanged(role, previousAdminRole, adminRole);
    }

    /**
     * @dev Grants `role` to `account`.
     *
     * Internal function without access restriction.
     *
     * May emit a {RoleGranted} event.
     */
    function _grantRole(bytes32 role, address account) internal virtual {
        if (!hasRole(role, account)) {
            _roles[role].members[account] = true;
            emit RoleGranted(role, account, _msgSender());
        }
    }

    /**
     * @dev Revokes `role` from `account`.
     *
     * Internal function without access restriction.
     *
     * May emit a {RoleRevoked} event.
     */
    function _revokeRole(bytes32 role, address account) internal virtual {
        if (hasRole(role, account)) {
            _roles[role].members[account] = false;
            emit RoleRevoked(role, account, _msgSender());
        }
    }
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.1 (access/IAccessControl.sol)

pragma solidity ^0.8.0;

/**
 * @dev External interface of AccessControl declared to support ERC165 detection.
 */
interface IAccessControl {
    /**
     * @dev Emitted when `newAdminRole` is set as ``role``'s admin role, replacing `previousAdminRole`
     *
     * `DEFAULT_ADMIN_ROLE` is the starting admin for all roles, despite
     * {RoleAdminChanged} not being emitted signaling this.
     *
     * _Available since v3.1._
     */
    event RoleAdminChanged(bytes32 indexed role, bytes32 indexed previousAdminRole, bytes32 indexed newAdminRole);

    /**
     * @dev Emitted when `account` is granted `role`.
     *
     * `sender` is the account that originated the contract call, an admin role
     * bearer except when using {AccessControl-_setupRole}.
     */
    event RoleGranted(bytes32 indexed role, address indexed account, address indexed sender);

    /**
     * @dev Emitted when `account` is revoked `role`.
     *
     * `sender` is the account that originated the contract call:
     *   - if using `revokeRole`, it is the admin role bearer
     *   - if using `renounceRole`, it is the role bearer (i.e. `account`)
     */
    event RoleRevoked(bytes32 indexed role, address indexed account, address indexed sender);

    /**
     * @dev Returns `true` if `account` has been granted `role`.
     */
    function hasRole(bytes32 role, address account) external view returns (bool);

    /**
     * @dev Returns the admin role that controls `role`. See {grantRole} and
     * {revokeRole}.
     *
     * To change a role's admin, use {AccessControl-_setRoleAdmin}.
     */
    function getRoleAdmin(bytes32 role) external view returns (bytes32);

    /**
     * @dev Grants `role` to `account`.
     *
     * If `account` had not been already granted `role`, emits a {RoleGranted}
     * event.
     *
     * Requirements:
     *
     * - the caller must have ``role``'s admin role.
     */
    function grantRole(bytes32 role, address account) external;

    /**
     * @dev Revokes `role` from `account`.
     *
     * If `account` had been granted `role`, emits a {RoleRevoked} event.
     *
     * Requirements:
     *
     * - the caller must have ``role``'s admin role.
     */
    function revokeRole(bytes32 role, address account) external;

    /**
     * @dev Revokes `role` from the calling account.
     *
     * Roles are often managed via {grantRole} and {revokeRole}: this function's
     * purpose is to provide a mechanism for accounts to lose their privileges
     * if they are compromised (such as when a trusted device is misplaced).
     *
     * If the calling account had been granted `role`, emits a {RoleRevoked}
     * event.
     *
     * Requirements:
     *
     * - the caller must be `account`.
     */
    function renounceRole(bytes32 role, address account) external;
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.1 (security/ReentrancyGuard.sol)

pragma solidity ^0.8.0;

/**
 * @dev Contract module that helps prevent reentrant calls to a function.
 *
 * Inheriting from `ReentrancyGuard` will make the {nonReentrant} modifier
 * available, which can be applied to functions to make sure there are no nested
 * (reentrant) calls to them.
 *
 * Note that because there is a single `nonReentrant` guard, functions marked as
 * `nonReentrant` may not call one another. This can be worked around by making
 * those functions `private`, and then adding `external` `nonReentrant` entry
 * points to them.
 *
 * TIP: If you would like to learn more about reentrancy and alternative ways
 * to protect against it, check out our blog post
 * https://blog.openzeppelin.com/reentrancy-after-istanbul/[Reentrancy After Istanbul].
 */
abstract contract ReentrancyGuard {
    // Booleans are more expensive than uint256 or any type that takes up a full
    // word because each write operation emits an extra SLOAD to first read the
    // slot's contents, replace the bits taken up by the boolean, and then write
    // back. This is the compiler's defense against contract upgrades and
    // pointer aliasing, and it cannot be disabled.

    // The values being non-zero value makes deployment a bit more expensive,
    // but in exchange the refund on every call to nonReentrant will be lower in
    // amount. Since refunds are capped to a percentage of the total
    // transaction's gas, it is best to keep them low in cases like this one, to
    // increase the likelihood of the full refund coming into effect.
    uint256 private constant _NOT_ENTERED = 1;
    uint256 private constant _ENTERED = 2;

    uint256 private _status;

    constructor() {
        _status = _NOT_ENTERED;
    }

    /**
     * @dev Prevents a contract from calling itself, directly or indirectly.
     * Calling a `nonReentrant` function from another `nonReentrant`
     * function is not supported. It is possible to prevent this from happening
     * by making the `nonReentrant` function external, and making it call a
     * `private` function that does the actual work.
     */
    modifier nonReentrant() {
        // On the first call to nonReentrant, _notEntered will be true
        require(_status != _ENTERED, "ReentrancyGuard: reentrant call");

        // Any calls to nonReentrant after this point will fail
        _status = _ENTERED;

        _;

        // By storing the original value once again, a refund is triggered (see
        // https://eips.ethereum.org/EIPS/eip-2200)
        _status = _NOT_ENTERED;
    }
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.1 (token/ERC20/extensions/draft-IERC20Permit.sol)

pragma solidity ^0.8.0;

/**
 * @dev Interface of the ERC20 Permit extension allowing approvals to be made via signatures, as defined in
 * https://eips.ethereum.org/EIPS/eip-2612[EIP-2612].
 *
 * Adds the {permit} method, which can be used to change an account's ERC20 allowance (see {IERC20-allowance}) by
 * presenting a message signed by the account. By not relying on {IERC20-approve}, the token holder account doesn't
 * need to send a transaction, and thus is not required to hold Ether at all.
 */
interface IERC20Permit {
    /**
     * @dev Sets `value` as the allowance of `spender` over ``owner``'s tokens,
     * given ``owner``'s signed approval.
     *
     * IMPORTANT: The same issues {IERC20-approve} has related to transaction
     * ordering also apply here.
     *
     * Emits an {Approval} event.
     *
     * Requirements:
     *
     * - `spender` cannot be the zero address.
     * - `deadline` must be a timestamp in the future.
     * - `v`, `r` and `s` must be a valid `secp256k1` signature from `owner`
     * over the EIP712-formatted function arguments.
     * - the signature must use ``owner``'s current nonce (see {nonces}).
     *
     * For more information on the signature format, see the
     * https://eips.ethereum.org/EIPS/eip-2612#specification[relevant EIP
     * section].
     */
    function permit(
        address owner,
        address spender,
        uint256 value,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external;

    /**
     * @dev Returns the current nonce for `owner`. This value must be
     * included whenever a signature is generated for {permit}.
     *
     * Every successful call to {permit} increases ``owner``'s nonce by one. This
     * prevents a signature from being used multiple times.
     */
    function nonces(address owner) external view returns (uint256);

    /**
     * @dev Returns the domain separator used in the encoding of the signature for {permit}, as defined by {EIP712}.
     */
    // solhint-disable-next-line func-name-mixedcase
    function DOMAIN_SEPARATOR() external view returns (bytes32);
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.6.0) (token/ERC20/IERC20.sol)

pragma solidity ^0.8.0;

/**
 * @dev Interface of the ERC20 standard as defined in the EIP.
 */
interface IERC20 {
    /**
     * @dev Emitted when `value` tokens are moved from one account (`from`) to
     * another (`to`).
     *
     * Note that `value` may be zero.
     */
    event Transfer(address indexed from, address indexed to, uint256 value);

    /**
     * @dev Emitted when the allowance of a `spender` for an `owner` is set by
     * a call to {approve}. `value` is the new allowance.
     */
    event Approval(address indexed owner, address indexed spender, uint256 value);

    /**
     * @dev Returns the amount of tokens in existence.
     */
    function totalSupply() external view returns (uint256);

    /**
     * @dev Returns the amount of tokens owned by `account`.
     */
    function balanceOf(address account) external view returns (uint256);

    /**
     * @dev Moves `amount` tokens from the caller's account to `to`.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a {Transfer} event.
     */
    function transfer(address to, uint256 amount) external returns (bool);

    /**
     * @dev Returns the remaining number of tokens that `spender` will be
     * allowed to spend on behalf of `owner` through {transferFrom}. This is
     * zero by default.
     *
     * This value changes when {approve} or {transferFrom} are called.
     */
    function allowance(address owner, address spender) external view returns (uint256);

    /**
     * @dev Sets `amount` as the allowance of `spender` over the caller's tokens.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * IMPORTANT: Beware that changing an allowance with this method brings the risk
     * that someone may use both the old and the new allowance by unfortunate
     * transaction ordering. One possible solution to mitigate this race
     * condition is to first reduce the spender's allowance to 0 and set the
     * desired value afterwards:
     * https://github.com/ethereum/EIPs/issues/20#issuecomment-263524729
     *
     * Emits an {Approval} event.
     */
    function approve(address spender, uint256 amount) external returns (bool);

    /**
     * @dev Moves `amount` tokens from `from` to `to` using the
     * allowance mechanism. `amount` is then deducted from the caller's
     * allowance.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a {Transfer} event.
     */
    function transferFrom(
        address from,
        address to,
        uint256 amount
    ) external returns (bool);
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.7.0) (token/ERC20/utils/SafeERC20.sol)

pragma solidity ^0.8.0;

import "../IERC20.sol";
import "../extensions/draft-IERC20Permit.sol";
import "../../../utils/Address.sol";

/**
 * @title SafeERC20
 * @dev Wrappers around ERC20 operations that throw on failure (when the token
 * contract returns false). Tokens that return no value (and instead revert or
 * throw on failure) are also supported, non-reverting calls are assumed to be
 * successful.
 * To use this library you can add a `using SafeERC20 for IERC20;` statement to your contract,
 * which allows you to call the safe operations as `token.safeTransfer(...)`, etc.
 */
library SafeERC20 {
    using Address for address;

    function safeTransfer(
        IERC20 token,
        address to,
        uint256 value
    ) internal {
        _callOptionalReturn(token, abi.encodeWithSelector(token.transfer.selector, to, value));
    }

    function safeTransferFrom(
        IERC20 token,
        address from,
        address to,
        uint256 value
    ) internal {
        _callOptionalReturn(token, abi.encodeWithSelector(token.transferFrom.selector, from, to, value));
    }

    /**
     * @dev Deprecated. This function has issues similar to the ones found in
     * {IERC20-approve}, and its usage is discouraged.
     *
     * Whenever possible, use {safeIncreaseAllowance} and
     * {safeDecreaseAllowance} instead.
     */
    function safeApprove(
        IERC20 token,
        address spender,
        uint256 value
    ) internal {
        // safeApprove should only be called when setting an initial allowance,
        // or when resetting it to zero. To increase and decrease it, use
        // 'safeIncreaseAllowance' and 'safeDecreaseAllowance'
        require(
            (value == 0) || (token.allowance(address(this), spender) == 0),
            "SafeERC20: approve from non-zero to non-zero allowance"
        );
        _callOptionalReturn(token, abi.encodeWithSelector(token.approve.selector, spender, value));
    }

    function safeIncreaseAllowance(
        IERC20 token,
        address spender,
        uint256 value
    ) internal {
        uint256 newAllowance = token.allowance(address(this), spender) + value;
        _callOptionalReturn(token, abi.encodeWithSelector(token.approve.selector, spender, newAllowance));
    }

    function safeDecreaseAllowance(
        IERC20 token,
        address spender,
        uint256 value
    ) internal {
        unchecked {
            uint256 oldAllowance = token.allowance(address(this), spender);
            require(oldAllowance >= value, "SafeERC20: decreased allowance below zero");
            uint256 newAllowance = oldAllowance - value;
            _callOptionalReturn(token, abi.encodeWithSelector(token.approve.selector, spender, newAllowance));
        }
    }

    function safePermit(
        IERC20Permit token,
        address owner,
        address spender,
        uint256 value,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) internal {
        uint256 nonceBefore = token.nonces(owner);
        token.permit(owner, spender, value, deadline, v, r, s);
        uint256 nonceAfter = token.nonces(owner);
        require(nonceAfter == nonceBefore + 1, "SafeERC20: permit did not succeed");
    }

    /**
     * @dev Imitates a Solidity high-level call (i.e. a regular function call to a contract), relaxing the requirement
     * on the return value: the return value is optional (but if data is returned, it must not be false).
     * @param token The token targeted by the call.
     * @param data The call data (encoded using abi.encode or one of its variants).
     */
    function _callOptionalReturn(IERC20 token, bytes memory data) private {
        // We need to perform a low level call here, to bypass Solidity's return data size checking mechanism, since
        // we're implementing it ourselves. We use {Address.functionCall} to perform this call, which verifies that
        // the target address contains contract code and also asserts for success in the low-level call.

        bytes memory returndata = address(token).functionCall(data, "SafeERC20: low-level call failed");
        if (returndata.length > 0) {
            // Return data is optional
            require(abi.decode(returndata, (bool)), "SafeERC20: ERC20 operation did not succeed");
        }
    }
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.7.0) (utils/Address.sol)

pragma solidity ^0.8.1;

/**
 * @dev Collection of functions related to the address type
 */
library Address {
    /**
     * @dev Returns true if `account` is a contract.
     *
     * [IMPORTANT]
     * ====
     * It is unsafe to assume that an address for which this function returns
     * false is an externally-owned account (EOA) and not a contract.
     *
     * Among others, `isContract` will return false for the following
     * types of addresses:
     *
     *  - an externally-owned account
     *  - a contract in construction
     *  - an address where a contract will be created
     *  - an address where a contract lived, but was destroyed
     * ====
     *
     * [IMPORTANT]
     * ====
     * You shouldn't rely on `isContract` to protect against flash loan attacks!
     *
     * Preventing calls from contracts is highly discouraged. It breaks composability, breaks support for smart wallets
     * like Gnosis Safe, and does not provide security since it can be circumvented by calling from a contract
     * constructor.
     * ====
     */
    function isContract(address account) internal view returns (bool) {
        // This method relies on extcodesize/address.code.length, which returns 0
        // for contracts in construction, since the code is only stored at the end
        // of the constructor execution.

        return account.code.length > 0;
    }

    /**
     * @dev Replacement for Solidity's `transfer`: sends `amount` wei to
     * `recipient`, forwarding all available gas and reverting on errors.
     *
     * https://eips.ethereum.org/EIPS/eip-1884[EIP1884] increases the gas cost
     * of certain opcodes, possibly making contracts go over the 2300 gas limit
     * imposed by `transfer`, making them unable to receive funds via
     * `transfer`. {sendValue} removes this limitation.
     *
     * https://diligence.consensys.net/posts/2019/09/stop-using-soliditys-transfer-now/[Learn more].
     *
     * IMPORTANT: because control is transferred to `recipient`, care must be
     * taken to not create reentrancy vulnerabilities. Consider using
     * {ReentrancyGuard} or the
     * https://solidity.readthedocs.io/en/v0.5.11/security-considerations.html#use-the-checks-effects-interactions-pattern[checks-effects-interactions pattern].
     */
    function sendValue(address payable recipient, uint256 amount) internal {
        require(address(this).balance >= amount, "Address: insufficient balance");

        (bool success, ) = recipient.call{value: amount}("");
        require(success, "Address: unable to send value, recipient may have reverted");
    }

    /**
     * @dev Performs a Solidity function call using a low level `call`. A
     * plain `call` is an unsafe replacement for a function call: use this
     * function instead.
     *
     * If `target` reverts with a revert reason, it is bubbled up by this
     * function (like regular Solidity function calls).
     *
     * Returns the raw returned data. To convert to the expected return value,
     * use https://solidity.readthedocs.io/en/latest/units-and-global-variables.html?highlight=abi.decode#abi-encoding-and-decoding-functions[`abi.decode`].
     *
     * Requirements:
     *
     * - `target` must be a contract.
     * - calling `target` with `data` must not revert.
     *
     * _Available since v3.1._
     */
    function functionCall(address target, bytes memory data) internal returns (bytes memory) {
        return functionCall(target, data, "Address: low-level call failed");
    }

    /**
     * @dev Same as {xref-Address-functionCall-address-bytes-}[`functionCall`], but with
     * `errorMessage` as a fallback revert reason when `target` reverts.
     *
     * _Available since v3.1._
     */
    function functionCall(
        address target,
        bytes memory data,
        string memory errorMessage
    ) internal returns (bytes memory) {
        return functionCallWithValue(target, data, 0, errorMessage);
    }

    /**
     * @dev Same as {xref-Address-functionCall-address-bytes-}[`functionCall`],
     * but also transferring `value` wei to `target`.
     *
     * Requirements:
     *
     * - the calling contract must have an ETH balance of at least `value`.
     * - the called Solidity function must be `payable`.
     *
     * _Available since v3.1._
     */
    function functionCallWithValue(
        address target,
        bytes memory data,
        uint256 value
    ) internal returns (bytes memory) {
        return functionCallWithValue(target, data, value, "Address: low-level call with value failed");
    }

    /**
     * @dev Same as {xref-Address-functionCallWithValue-address-bytes-uint256-}[`functionCallWithValue`], but
     * with `errorMessage` as a fallback revert reason when `target` reverts.
     *
     * _Available since v3.1._
     */
    function functionCallWithValue(
        address target,
        bytes memory data,
        uint256 value,
        string memory errorMessage
    ) internal returns (bytes memory) {
        require(address(this).balance >= value, "Address: insufficient balance for call");
        require(isContract(target), "Address: call to non-contract");

        (bool success, bytes memory returndata) = target.call{value: value}(data);
        return verifyCallResult(success, returndata, errorMessage);
    }

    /**
     * @dev Same as {xref-Address-functionCall-address-bytes-}[`functionCall`],
     * but performing a static call.
     *
     * _Available since v3.3._
     */
    function functionStaticCall(address target, bytes memory data) internal view returns (bytes memory) {
        return functionStaticCall(target, data, "Address: low-level static call failed");
    }

    /**
     * @dev Same as {xref-Address-functionCall-address-bytes-string-}[`functionCall`],
     * but performing a static call.
     *
     * _Available since v3.3._
     */
    function functionStaticCall(
        address target,
        bytes memory data,
        string memory errorMessage
    ) internal view returns (bytes memory) {
        require(isContract(target), "Address: static call to non-contract");

        (bool success, bytes memory returndata) = target.staticcall(data);
        return verifyCallResult(success, returndata, errorMessage);
    }

    /**
     * @dev Same as {xref-Address-functionCall-address-bytes-}[`functionCall`],
     * but performing a delegate call.
     *
     * _Available since v3.4._
     */
    function functionDelegateCall(address target, bytes memory data) internal returns (bytes memory) {
        return functionDelegateCall(target, data, "Address: low-level delegate call failed");
    }

    /**
     * @dev Same as {xref-Address-functionCall-address-bytes-string-}[`functionCall`],
     * but performing a delegate call.
     *
     * _Available since v3.4._
     */
    function functionDelegateCall(
        address target,
        bytes memory data,
        string memory errorMessage
    ) internal returns (bytes memory) {
        require(isContract(target), "Address: delegate call to non-contract");

        (bool success, bytes memory returndata) = target.delegatecall(data);
        return verifyCallResult(success, returndata, errorMessage);
    }

    /**
     * @dev Tool to verifies that a low level call was successful, and revert if it wasn't, either by bubbling the
     * revert reason using the provided one.
     *
     * _Available since v4.3._
     */
    function verifyCallResult(
        bool success,
        bytes memory returndata,
        string memory errorMessage
    ) internal pure returns (bytes memory) {
        if (success) {
            return returndata;
        } else {
            // Look for revert reason and bubble it up if present
            if (returndata.length > 0) {
                // The easiest way to bubble the revert reason is using memory via assembly
                /// @solidity memory-safe-assembly
                assembly {
                    let returndata_size := mload(returndata)
                    revert(add(32, returndata), returndata_size)
                }
            } else {
                revert(errorMessage);
            }
        }
    }
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.1 (utils/Context.sol)

pragma solidity ^0.8.0;

/**
 * @dev Provides information about the current execution context, including the
 * sender of the transaction and its data. While these are generally available
 * via msg.sender and msg.data, they should not be accessed in such a direct
 * manner, since when dealing with meta-transactions the account sending and
 * paying for execution may not be the actual sender (as far as an application
 * is concerned).
 *
 * This contract is only required for intermediate, library-like contracts.
 */
abstract contract Context {
    function _msgSender() internal view virtual returns (address) {
        return msg.sender;
    }

    function _msgData() internal view virtual returns (bytes calldata) {
        return msg.data;
    }
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.1 (utils/introspection/ERC165.sol)

pragma solidity ^0.8.0;

import "./IERC165.sol";

/**
 * @dev Implementation of the {IERC165} interface.
 *
 * Contracts that want to implement ERC165 should inherit from this contract and override {supportsInterface} to check
 * for the additional interface id that will be supported. For example:
 *
 * ```solidity
 * function supportsInterface(bytes4 interfaceId) public view virtual override returns (bool) {
 *     return interfaceId == type(MyInterface).interfaceId || super.supportsInterface(interfaceId);
 * }
 * ```
 *
 * Alternatively, {ERC165Storage} provides an easier to use but more expensive implementation.
 */
abstract contract ERC165 is IERC165 {
    /**
     * @dev See {IERC165-supportsInterface}.
     */
    function supportsInterface(bytes4 interfaceId) public view virtual override returns (bool) {
        return interfaceId == type(IERC165).interfaceId;
    }
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.1 (utils/introspection/IERC165.sol)

pragma solidity ^0.8.0;

/**
 * @dev Interface of the ERC165 standard, as defined in the
 * https://eips.ethereum.org/EIPS/eip-165[EIP].
 *
 * Implementers can declare support of contract interfaces, which can then be
 * queried by others ({ERC165Checker}).
 *
 * For an implementation, see {ERC165}.
 */
interface IERC165 {
    /**
     * @dev Returns true if this contract implements the interface defined by
     * `interfaceId`. See the corresponding
     * https://eips.ethereum.org/EIPS/eip-165#how-interfaces-are-identified[EIP section]
     * to learn more about how these ids are created.
     *
     * This function call must use less than 30 000 gas.
     */
    function supportsInterface(bytes4 interfaceId) external view returns (bool);
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.7.0) (utils/Strings.sol)

pragma solidity ^0.8.0;

/**
 * @dev String operations.
 */
library Strings {
    bytes16 private constant _HEX_SYMBOLS = "0123456789abcdef";
    uint8 private constant _ADDRESS_LENGTH = 20;

    /**
     * @dev Converts a `uint256` to its ASCII `string` decimal representation.
     */
    function toString(uint256 value) internal pure returns (string memory) {
        // Inspired by OraclizeAPI's implementation - MIT licence
        // https://github.com/oraclize/ethereum-api/blob/b42146b063c7d6ee1358846c198246239e9360e8/oraclizeAPI_0.4.25.sol

        if (value == 0) {
            return "0";
        }
        uint256 temp = value;
        uint256 digits;
        while (temp != 0) {
            digits++;
            temp /= 10;
        }
        bytes memory buffer = new bytes(digits);
        while (value != 0) {
            digits -= 1;
            buffer[digits] = bytes1(uint8(48 + uint256(value % 10)));
            value /= 10;
        }
        return string(buffer);
    }

    /**
     * @dev Converts a `uint256` to its ASCII `string` hexadecimal representation.
     */
    function toHexString(uint256 value) internal pure returns (string memory) {
        if (value == 0) {
            return "0x00";
        }
        uint256 temp = value;
        uint256 length = 0;
        while (temp != 0) {
            length++;
            temp >>= 8;
        }
        return toHexString(value, length);
    }

    /**
     * @dev Converts a `uint256` to its ASCII `string` hexadecimal representation with fixed length.
     */
    function toHexString(uint256 value, uint256 length) internal pure returns (string memory) {
        bytes memory buffer = new bytes(2 * length + 2);
        buffer[0] = "0";
        buffer[1] = "x";
        for (uint256 i = 2 * length + 1; i > 1; --i) {
            buffer[i] = _HEX_SYMBOLS[value & 0xf];
            value >>= 4;
        }
        require(value == 0, "Strings: hex length insufficient");
        return string(buffer);
    }

    /**
     * @dev Converts an `address` with fixed length of 20 bytes to its not checksummed ASCII `string` hexadecimal representation.
     */
    function toHexString(address addr) internal pure returns (string memory) {
        return toHexString(uint256(uint160(addr)), _ADDRESS_LENGTH);
    }
}

/*
          ___
      _.-'___'-._
    .'--.`   `.--'.
   /.'   \   /   `.\
  | /'-._/```\_.-'\ |
  |/    |     |    \|
  | \ .''-._.-''. / |
   \ |     |     | /
    '.'._.-'-._.'.'
      '-:_____;-
                DEGOVERSE.BET - WORLD CUP 2022 EDITION
*/
// SPDX-License-Identifier: MIT

pragma solidity ^0.8.9;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";

interface IDegoVerseFactoryNFT {
    function playerSkill(uint256 tokenId) external view returns (uint256, uint256, uint256, uint256, uint256);
    function playerAbout(uint256 tokenId) external view returns (uint256, uint256, uint256, uint256);
    function ownerOf(uint256 tokenId) external view returns (address);
}

interface IPlayerOperator {
    function setExperience(uint256 tokenId, uint256 newExperience) external;
}

contract WorldCupGame is AccessControl, ReentrancyGuard {
    using SafeERC20 for IERC20;

    error InvalidBatchLength();
    error InvalidTime();
    error DepositFeeTooHigh();
    error InvalidAmount();
    error WithdrawNotAvailable();
    error NotOwner();
    error InvalidAddress();
    error AlreadyClaimed();
    error InvalidTotalAmount();
    error InvalidClaim();
    error MatchAlreadyEnded();
    error InvalidBetOption();
    error TreasuryAlreadyClaimed(uint256 pid);

    struct BetInfo {
        uint256 claimedAmount;
        uint256 amount;
        uint256 powerAmount;
        uint256[] playerIds;
    }

    mapping(uint256 => mapping(address => mapping(BetOption => BetInfo))) public betData;

    // Info of each match.
    struct MatchStatus {
        uint256 totalAmount;
        uint256 localWinAmount;
        uint256 localWinPowerAmount;
        uint256 visitorWinAmount;
        uint256 visitorWinPowerAmount;
        uint256 tieAmount;
        uint256 tiePowerAmount;
        BetOption bet;
        bool treasuryClaimed;
    }

    struct MatchInfo {
        uint256 localTeamId;
        uint256 visitorTeamId;
        uint256 startTime;
        uint256 treasuryFee;
        uint256 experienceRate;
        address stakedToken;
        MatchType matchType;
    }

    MatchStatus[] public matchStatuses;
    MatchInfo[] public matchData;

    address public feeAddress;
    uint256 public totalUsdLockup;

    // NFT Factories
    address public playerNFT;

    // Player Operator
    address public playerOperator;

    // Roles
    bytes32 public constant OPERATOR_ROLE = keccak256("OPERATOR");

    // Events definitions
    event MatchAdded(
        uint256 indexed pid,
        uint256 localTeamId,
        uint256 visitorTeamId,
        uint256 startTime,
        uint256 treasuryFee,
        uint256 experienceRate,
        address stakedToken,
        MatchType matchType
    );

    event BatchMatchesAdded(
        uint256[] indexed pids,
        uint256[] localTeamIds,
        uint256[] visitorTeamIds,
        uint256[] startTimes,
        uint256 treasuryFee,
        uint256 experienceRate,
        address stakedToken,
        MatchType matchType
    );

    event MatchUpdated(
        uint256 indexed pid,
        uint256 localTeamId,
        uint256 visitorTeamId,
        uint256 startTime,
        uint256 treasuryFee,
        address stakedToken,
        MatchType matchType
    );

    event BetOnMatchAdded(address indexed user, uint256 indexed pid, uint256 amount, BetOption bet);

    event FeeAddressUpdated(address indexed user, address indexed newAddress);

    event PlayersAdded(address indexed user, uint256 indexed pid, uint256[] playerIds);

    event MatchEnded(uint256 indexed pid, BetOption bet);

    event Claimed(address indexed user, uint256 indexed pid, uint256 amount);

    event TreasuryClaimed(address indexed user, uint256 indexed pid, uint256 amount);

    enum BetOption {
        Unknown,
        LocalWin,
        VisitorWin,
        Tie
    }

    enum MatchType {
        GroupStage,
        KnockOut
    }

    constructor(
        address _playerNFT,
        address _playerOperator,
        address _feeAddress
    ) {
        playerNFT = _playerNFT;
        playerOperator = _playerOperator;
        feeAddress = _feeAddress;

        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _setupRole(OPERATOR_ROLE, msg.sender);
    }

    // External functions //

    /// Add a new match. Can only be called by the owner.
    /// @param _localTeamId Local Team Identifier
    /// @param _visitorTeamId Visitor Team Identifier
    /// @param _startTime Start timemestamp
    /// @param _treasuryFee Treasury Fee (e.g: 400 = 4%)
    /// @param _experienceRate Experience to assign to players (e.g: 1000 = 10% over rewards)
    /// @param _stakedToken  Token address to stake
    /// @param _matchType Kind of Match: 0-Group Stage, 1-KnockOut
    function addMatch(
        uint256 _localTeamId,
        uint256 _visitorTeamId,
        uint256 _startTime,
        uint256 _treasuryFee,
        uint256 _experienceRate,
        address _stakedToken,
        MatchType _matchType
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        if (_startTime < block.timestamp) revert InvalidTime();
        if (_treasuryFee > 10_000) revert DepositFeeTooHigh();

        matchData.push(
            MatchInfo({
                localTeamId: _localTeamId,
                visitorTeamId: _visitorTeamId,
                startTime: _startTime,
                treasuryFee: _treasuryFee,
                experienceRate: _experienceRate,
                stakedToken: _stakedToken,
                matchType: _matchType
            })
        );

        matchStatuses.push(
            MatchStatus({
                totalAmount: 0,
                localWinAmount: 0,
                localWinPowerAmount: 0,
                visitorWinAmount: 0,
                visitorWinPowerAmount: 0,
                tieAmount: 0,
                tiePowerAmount: 0,
                treasuryClaimed: false,
                bet: BetOption.Unknown
            })
        );

        emit MatchAdded(
            matchData.length - 1,
            _localTeamId,
            _visitorTeamId,
            _startTime,
            _treasuryFee,
            _experienceRate,
            _stakedToken,
            _matchType
        );
    }

    /// Add a matches in Batch. Can only be called by the owner.
    /// @param _localTeamIds Local Team Identifiers array
    /// @param _visitorTeamIds Visitor Team Identifiers array
    /// @param _startTimes Start timemestamps array
    /// @param _treasuryFee Treasury Fee (e.g: 400 = 4%)
    /// @param _experienceRate Experience to assign to players (e.g: 1000 = 10% over rewards)
    /// @param _stakedToken  Token address to stake
    /// @param _matchType Kind of Match: 0-Group Stage, 1-KnockOut
    function addBatchMatches(
        uint256[] memory _localTeamIds,
        uint256[] memory _visitorTeamIds,
        uint256[] memory _startTimes,
        uint256 _treasuryFee,
        uint256 _experienceRate,
        address _stakedToken,
        MatchType _matchType
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        if (_localTeamIds.length != _visitorTeamIds.length || _localTeamIds.length != _startTimes.length)
            revert InvalidBatchLength();

        uint256[] memory ids = new uint256[](_localTeamIds.length);

        for (uint i = 0; i < _localTeamIds.length; i++) {
            if (_startTimes[i] < block.timestamp) revert InvalidTime();
            if (_treasuryFee > 10_000) revert DepositFeeTooHigh();

            ids[i] = matchData.length;

            matchData.push(
                MatchInfo({
                    localTeamId: _localTeamIds[i],
                    visitorTeamId: _visitorTeamIds[i],
                    startTime: _startTimes[i],
                    treasuryFee: _treasuryFee,
                    experienceRate: _experienceRate,
                    stakedToken: _stakedToken,
                    matchType: _matchType
                })
            );

            matchStatuses.push(
                MatchStatus({
                    totalAmount: 0,
                    localWinAmount: 0,
                    localWinPowerAmount: 0,
                    visitorWinAmount: 0,
                    visitorWinPowerAmount: 0,
                    tieAmount: 0,
                    tiePowerAmount: 0,
                    treasuryClaimed: false,
                    bet: BetOption.Unknown
                })
            );
        }

        emit BatchMatchesAdded(
            ids,
            _localTeamIds,
            _visitorTeamIds,
            _startTimes,
            _treasuryFee,
            _experienceRate,
            _stakedToken,
            _matchType
        );
    }
    /// Updates the given match's info. Can only be called by the Owner.
    /// @param _pid Match info Identifier
    /// @param _localTeamId Local Team Identifier
    /// @param _visitorTeamId Visitor Team Identifier
    /// @param _startTime Start timemestamp
    /// @param _treasuryFee Treasury Fee (e.g: 400 = 4%)
    /// @param _experienceRate Experience to assign to players (e.g: 1000 = 10% over rewards)
    /// @param _stakedToken Token address to stake
    /// @param _matchType Kind of match: 0-GroupStage, 1-KnockOut
    function setMatch(
        uint256 _pid,
        uint256 _localTeamId,
        uint256 _visitorTeamId,
        uint256 _startTime,
        uint256 _treasuryFee,
        uint256 _experienceRate,
        address _stakedToken,
        MatchType _matchType
    )
        external onlyRole(DEFAULT_ADMIN_ROLE)
    {
        if (_startTime < block.timestamp) revert InvalidTime();
        if (_treasuryFee > 10_000) revert DepositFeeTooHigh();

        matchData[_pid].localTeamId = _localTeamId;
        matchData[_pid].visitorTeamId = _visitorTeamId;
        matchData[_pid].startTime = _startTime;
        matchData[_pid].treasuryFee = _treasuryFee;
        matchData[_pid].experienceRate = _experienceRate;
        matchData[_pid].stakedToken = _stakedToken;
        matchData[_pid].matchType = _matchType;
        emit MatchUpdated(_pid, _localTeamId, _visitorTeamId, _startTime, _treasuryFee, _stakedToken, _matchType);
    }

    /// Close the Match with the final result. Can only be called by the Owner.
    /// @param _pid Match Identifier
    /// @param _bet BetOption
    function endMatch(uint256 _pid, BetOption _bet) external onlyRole(DEFAULT_ADMIN_ROLE) {
        MatchStatus storage matchStatus = matchStatuses[_pid];
        MatchInfo storage matchInfo = matchData[_pid];
        if (matchStatus.bet != BetOption.Unknown) revert MatchAlreadyEnded();
        if (_bet == BetOption.Unknown) revert InvalidBetOption();
        if (matchInfo.matchType == MatchType.KnockOut && _bet == BetOption.Tie)
            revert InvalidBetOption();

        matchStatus.bet = _bet;

        emit MatchEnded(_pid, _bet);
    }

    /// Claims Treasury on Match. Can only be called by the Owner.
    /// @param _pid Match Identifier
    function claimTreasury(uint256 _pid) external nonReentrant onlyRole(DEFAULT_ADMIN_ROLE) {
        MatchInfo storage matchInfo = matchData[_pid];
        MatchStatus storage matchStatus = matchStatuses[_pid];

        if (matchStatus.bet == BetOption.Unknown)
            revert InvalidBetOption();
        if (matchStatus.treasuryClaimed)
            revert TreasuryAlreadyClaimed(_pid);

        (, , uint256 treasuryAmount) = calculateRewards(_pid);
        if (treasuryAmount > 0)
            IERC20(matchInfo.stakedToken).safeTransfer(msg.sender, treasuryAmount);

        matchStatus.treasuryClaimed = true;
        emit TreasuryClaimed(msg.sender, _pid, treasuryAmount);
    }

    /// Set fee address. Can only be called by the Owner.
    function setFeeAddress(address newFeeAddress) external onlyRole(DEFAULT_ADMIN_ROLE) {
        if (newFeeAddress != address(0)) revert InvalidAddress();

        feeAddress = newFeeAddress;
        emit FeeAddressUpdated(msg.sender, newFeeAddress);
    }

    /// Bet on the match.
    /// @param _pid Match Identifier
    /// @param _amount How much is the player going to bet
    /// @param _bet Bet Option: 1-winLocal, 2-winVisitor, 3-Tie (only available for GroupStage)
    function betOnMatch(uint256 _pid, uint256 _amount, BetOption _bet) external nonReentrant {
        MatchInfo storage matchInfo = matchData[_pid];
        MatchStatus storage matchStatus = matchStatuses[_pid];
        BetInfo storage user = betData[_pid][msg.sender][_bet];

        // Validations
        if (_amount < 0) revert InvalidAmount();
        if (_bet == BetOption.Unknown) revert InvalidBetOption();
        if (matchInfo.matchType == MatchType.KnockOut && _bet == BetOption.Tie)
            revert InvalidBetOption();
        if (IERC20(matchInfo.stakedToken).balanceOf(msg.sender) < _amount) revert InvalidAmount();
        if (block.timestamp < matchInfo.startTime || matchStatus.bet != BetOption.Unknown)
            revert InvalidTime();

        // Transfer token to this contract
        IERC20(matchInfo.stakedToken).safeTransferFrom(address(msg.sender), address(this), _amount);

        totalUsdLockup += _amount;

        user.amount += _amount;
        uint256 power = _getPower(_pid, _bet);
        _setTotals(_pid, _amount, _bet, user.powerAmount, power);
        user.powerAmount = power;

        emit BetOnMatchAdded(msg.sender, _pid, _amount, _bet);
    }

    /// Add Players to your bet
    /// @param _pid Match Identifier
    /// @param _playerIds array with your players
    /// @param _bet BetOption where you will add the players
    function addPlayers(
        uint256 _pid, 
        uint256[] memory _playerIds,
        BetOption _bet
    )
        external nonReentrant
    {
        MatchInfo storage matchInfo = matchData[_pid];

        if (_bet == BetOption.Unknown) revert InvalidBetOption();
        if (matchInfo.matchType == MatchType.KnockOut && _bet == BetOption.Tie)
            revert InvalidBetOption();

        BetInfo storage user = betData[_pid][msg.sender][_bet];

        uint256[] memory ids;
        for (uint256 i = 0; i < _playerIds.length; i++) {
            if (IDegoVerseFactoryNFT(playerNFT).ownerOf(_playerIds[i]) != msg.sender) revert NotOwner();
            ids[i] = _playerIds[i];
        }

        user.playerIds = ids;
        uint256 power = _getPower(_pid, _bet);
        _setTotals(_pid, 0, _bet, user.powerAmount, power);
        user.powerAmount = power;

        emit PlayersAdded(msg.sender, _pid, _playerIds);
    }

    /// Claims rewards
    /// @param _pid Match Identifier
    function claim(uint256 _pid) external nonReentrant {
        if (!isClaimable(_pid, msg.sender)) revert InvalidClaim();

        MatchInfo storage matchInfo = matchData[_pid];
        MatchStatus storage matchStatus = matchStatuses[_pid];
        BetInfo storage user = betData[_pid][msg.sender][matchStatus.bet];

        (uint256 rewardBaseCalAmount, uint256 rewardAmount, ) = calculateRewards(_pid);

        uint256 reward = ((user.amount + user.powerAmount) * rewardAmount) / rewardBaseCalAmount;
        if (reward > 0) {
            user.claimedAmount = reward;
            // Transfer reward
            IERC20(matchInfo.stakedToken).safeTransfer(msg.sender, reward);
            // Set players
            for (uint i = 0; i < user.playerIds.length; i++) {
                (, , , , uint256 experience) = IDegoVerseFactoryNFT(playerNFT).playerSkill(user.playerIds[i]);
                uint256 increase = ((experience * matchInfo.experienceRate) / 10_000);
                IPlayerOperator(playerNFT).setExperience(user.playerIds[i], experience + increase);
            }
        }

        emit Claimed(msg.sender, _pid, reward);
    }

    // External functions that are view //

    /// return user Bets (matchIds + bet options)
    function betDataByUser(address _user) external view returns (uint256[] memory, BetOption[] memory) {
        uint256[] memory matchIds;
        BetOption[] memory bets;

        BetOption[] memory betOptions = new BetOption[](3);
        betOptions[0] = BetOption.LocalWin;
        betOptions[1] = BetOption.VisitorWin;
        betOptions[2] = BetOption.Tie;

        for (uint i = 0; i < matchData.length; i++) {
            for (uint j = 0; j < betOptions.length; j++) {
                if (betData[i][_user][betOptions[j]].amount > 0) {
                    uint k = matchIds.length;
                    matchIds[k] = i;
                    bets[k] = betOptions[j];
                }
            }
        }

        return (matchIds, bets);
    }

    /// Retrieves matches Length
    function matchesLength() external view returns (uint256) {
        return matchData.length;
    }

    /// Retrieves active matches (Playing now)
    /// @return Matches Identifiers
    function activeMatches() external view returns (uint256[] memory) {
        uint256[] memory ids;
        uint j;
        for (uint i = 0; i < matchData.length; i++) {
            if (matchData[i].startTime > block.timestamp && matchStatuses[i].bet == BetOption.Unknown) {
                ids[j] = i;
                j += 1;
            }
        }

        return ids;
    }

    /// Retrieves pending reward for the userAddress by betOption
    /// @param _pid Match identifier
    /// @param _userAddress user address
    /// @param _bet Bet option
    /// @return pending Reward on match by selected bet.
    function pendingReward(
        uint256 _pid,
        address _userAddress,
        BetOption _bet
    )
        external view returns (uint256)
    {
        BetInfo storage user = betData[_pid][_userAddress][_bet];
        if (user.amount == 0)
            return 0;

        MatchStatus storage matchStatus = matchStatuses[_pid];
        MatchInfo storage matchInfo = matchData[_pid];
        if (matchStatus.totalAmount < 0) revert InvalidTotalAmount();

        uint256 treasuryAmount = (matchStatus.totalAmount * matchInfo.treasuryFee) / 10_000;
        uint256 rewardAmount = matchStatus.totalAmount - treasuryAmount;
        uint256 rewardBaseCalAmount;

        if (_bet == BetOption.LocalWin) {
            rewardBaseCalAmount = matchStatus.localWinAmount + matchStatus.localWinPowerAmount;
        } else if (_bet == BetOption.VisitorWin) {
            rewardBaseCalAmount = matchStatus.visitorWinAmount + matchStatus.visitorWinPowerAmount;
        } else {
            rewardBaseCalAmount = matchStatus.tieAmount + matchStatus.tiePowerAmount;
        }

        return ((user.amount + user.powerAmount) * rewardAmount) / rewardBaseCalAmount;
    }

    /// Get Player IDs in a match by user + betOption
    /// @param _pid Match identifier
    /// @param _user User address
    /// @param _bet BetOption
    /// @return players identifier
    function getPlayerIds(
        uint256 _pid,
        address _user,
        BetOption _bet
    )
        external view returns (uint256[] memory)
    {
        BetInfo storage user = betData[_pid][_user][_bet];
        return user.playerIds;
    }

    // External functions that are pure //
    // ...

    // Public functions

    /// Check if user is able to claim in Match
    /// @param _pid Match identifier
    /// @param _user User address to check
    /// @return if user is able to claim in this match
    function isClaimable(uint256 _pid, address _user) public view returns (bool) {
        MatchStatus storage matchStatus = matchStatuses[_pid];

        if (matchStatus.bet == BetOption.Unknown || matchStatus.totalAmount == 0)
            return false;

        BetInfo storage user = betData[_pid][_user][matchStatus.bet];

        return user.claimedAmount == 0 && user.amount > 0;
    }

    /// Calculates reward Variables
    /// @param _pid Match Identifier
    /// @return rewardBaseCalAmount, treasuryAmmount, and rewardAmount
    function calculateRewards(uint256 _pid) public view returns (uint256, uint256, uint256) {
        MatchInfo storage matchInfo = matchData[_pid];
        MatchStatus storage matchStatus = matchStatuses[_pid];

        uint256 rewardBaseCalAmount;
        uint256 treasuryAmmount;
        uint256 rewardAmount;

        // LocalWin option wins
        if (matchStatus.bet == BetOption.LocalWin) {
            rewardBaseCalAmount = matchStatus.localWinAmount + matchStatus.localWinPowerAmount;
            treasuryAmmount = (matchStatus.totalAmount * matchInfo.treasuryFee) / 10_000;
            rewardAmount = matchStatus.totalAmount - treasuryAmmount;
        }
        // VisitorWin option wins
        else if (matchStatus.bet == BetOption.VisitorWin) {
            rewardBaseCalAmount = matchStatus.visitorWinAmount + matchStatus.visitorWinPowerAmount;
            treasuryAmmount = (matchStatus.totalAmount * matchInfo.treasuryFee) / 10_000;
            rewardAmount = matchStatus.totalAmount - treasuryAmmount;
        }
        // Tie 
        else if (matchStatus.bet == BetOption.Tie) {
            rewardBaseCalAmount = matchStatus.tieAmount + matchStatus.tiePowerAmount;
            treasuryAmmount = (matchStatus.totalAmount * matchInfo.treasuryFee) / 10_000;
            rewardAmount = matchStatus.totalAmount - treasuryAmmount;
        }
        // House wins
        else {
            rewardBaseCalAmount = 0;
            rewardAmount = 0;
            treasuryAmmount = matchStatus.totalAmount;
        }

        return (rewardBaseCalAmount, rewardAmount, treasuryAmmount);
    }

    // Internal functions //

    /// Sets matchStatus Totals
    /// @param _pid Match Identifier
    /// @param _amount amount added
    /// @param _bet BetOption selected
    /// @param _oldPower power applied before transaction
    /// @param _newPower power applied after transaction
    function _setTotals(
        uint256 _pid,
        uint256 _amount,
        BetOption _bet,
        uint256 _oldPower,
        uint256 _newPower
    )
        internal
    {
        MatchStatus storage matchStatus = matchStatuses[_pid];

        matchStatus.totalAmount += _amount;

        if (_bet == BetOption.LocalWin) {
            matchStatus.localWinAmount = matchStatus.localWinAmount + _amount;

            matchStatus.localWinPowerAmount += _newPower;
            if (matchStatus.localWinPowerAmount > _oldPower) {
                matchStatus.localWinPowerAmount -= _oldPower;
            } else {
                matchStatus.localWinPowerAmount = 0;
            }
        } else if (_bet == BetOption.VisitorWin) {
            matchStatus.visitorWinAmount = matchStatus.visitorWinAmount + _amount;

            matchStatus.visitorWinPowerAmount += _newPower;
            if (matchStatus.visitorWinPowerAmount > _oldPower) {
                matchStatus.visitorWinPowerAmount -= _oldPower;
            } else {
                matchStatus.visitorWinPowerAmount = 0;
            }
        } else {
            matchStatus.tieAmount = matchStatus.tieAmount + _amount;

            matchStatus.tiePowerAmount += _newPower;
            if (matchStatus.tiePowerAmount > _oldPower) {
                matchStatus.tiePowerAmount -= _oldPower;
            } else {
                matchStatus.tiePowerAmount = 0;
            }
        }
    }

    // Internal function that are view //

    /// Get Bet powered by Players selected
    /// @return bet amount + % of power
    function _getPower(uint256 _pid, BetOption _bet) internal view returns (uint256) {
        BetInfo storage user = betData[_pid][msg.sender][_bet];
        uint256 power;

        for (uint i = 0; i < user.playerIds.length; i++) {
            power += _getPlayerPower(user.playerIds[i], user.amount);
        }

        return power;
    }

    /// Get Player Power
    /// @param _playerId Player Identifier
    /// @param _amount bet amount
    /// @return the bet amount powered by the user power boost
    function _getPlayerPower(
        uint256 _playerId,
        uint256 _amount
    )
        internal view returns (uint256)
    {
        (, , uint256 position, ) = IDegoVerseFactoryNFT(playerNFT).playerAbout(_playerId);
        (
            uint256 defense,
            uint256 attack,
            uint256 physical,
            uint256 morale,
            uint256 experience
        ) = IDegoVerseFactoryNFT(playerNFT).playerSkill(_playerId);

        uint256 defenseFactor = 10_000; // 100%
        uint256 attackFactor = 10_000; // 100%
        // Midifielder
        if (position == 3) {
            defenseFactor = 7_500; // 75%
            attackFactor = 7_500; // 75%
        // Goalkeeper or defense
        } else if (position == 1 || position == 2) {
            attackFactor = 5_000; // 50%
        // Forward
        } else if (position == 4) {
            defenseFactor = 5_000; // 50%
        }

        return (
            (
                (
                    (
                        (defense * defenseFactor) +
                        (attack * attackFactor) +
                        (physical * 5_000) + // 50%
                        (morale * 1_000) + // 10%
                        (experience * 1_000) // 10%
                    ) / 10_000
                ) * _amount
            ) / 10_000
        );
    }

    // Private functions //
    // ...
}