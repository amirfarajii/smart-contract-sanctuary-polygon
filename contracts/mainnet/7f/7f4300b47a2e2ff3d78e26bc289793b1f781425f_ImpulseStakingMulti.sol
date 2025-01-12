/**
 *Submitted for verification at polygonscan.com on 2022-08-23
*/

// SPDX-License-Identifier: MIT
pragma solidity 0.8.6;

// File: Address.sol

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
     */
    function isContract(address account) internal view returns (bool) {
        // This method relies on extcodesize, which returns 0 for contracts in
        // construction, since the code is only stored at the end of the
        // constructor execution.

        uint256 size;
        assembly {
            size := extcodesize(account)
        }
        return size > 0;
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
        return _verifyCallResult(success, returndata, errorMessage);
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
        return _verifyCallResult(success, returndata, errorMessage);
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
        return _verifyCallResult(success, returndata, errorMessage);
    }

    function _verifyCallResult(
        bool success,
        bytes memory returndata,
        string memory errorMessage
    ) private pure returns (bytes memory) {
        if (success) {
            return returndata;
        } else {
            // Look for revert reason and bubble it up if present
            if (returndata.length > 0) {
                // The easiest way to bubble the revert reason is using memory via assembly

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

// File: IERC165Upgradeable.sol

/**
 * @dev Interface of the ERC165 standard, as defined in the
 * https://eips.ethereum.org/EIPS/eip-165[EIP].
 *
 * Implementers can declare support of contract interfaces, which can then be
 * queried by others ({ERC165Checker}).
 *
 * For an implementation, see {ERC165}.
 */
interface IERC165Upgradeable {
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

// File: IERC20.sol

/**
 * @dev Interface of the ERC20 standard as defined in the EIP.
 */
interface IERC20 {
    /**
     * @dev Returns the amount of tokens in existence.
     */
    function totalSupply() external view returns (uint256);

    /**
     * @dev Returns the amount of tokens owned by `account`.
     */
    function balanceOf(address account) external view returns (uint256);

    /**
     * @dev Moves `amount` tokens from the caller's account to `recipient`.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a {Transfer} event.
     */
    function transfer(address recipient, uint256 amount) external returns (bool);

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
     * @dev Moves `amount` tokens from `sender` to `recipient` using the
     * allowance mechanism. `amount` is then deducted from the caller's
     * allowance.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a {Transfer} event.
     */
    function transferFrom(
        address sender,
        address recipient,
        uint256 amount
    ) external returns (bool);

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
}

// File: IImpulseMultiStrategy.sol

interface IImpulseMultiStrategy {
    // List underlying tokens managed by strategy
    function listUnderlying() external view returns (address[] memory);

    // Total want tokens managed by strategy
    function wantLockedTotal() external view returns (uint256);

    // Sum of all shares of users to wantLockedTotal
    function sharesTotal() external view returns (uint256);

    // Main want token compounding function
    function earn() external;

    // Transfer want tokens autoFarm -> strategy
    function depositInWant(uint256 _wantAmt) external returns (uint256);

    // Transfer want tokens autoFarm -> strategy
    function depositInUnderlying(uint256[] calldata amounts) external returns (uint256);

    // Transfer want tokens strategy -> autoFarm
    function withdrawInWant(uint256 _wantAmt) external returns (uint256);

    // Transfer want tokens strategy -> autoFarm
    function withdrawInUnderlying(uint256 _wantAmt) external returns (uint256);

    function withdrawInOneUnderlying(uint256 _wantAmt, address _underlying) external returns (uint256);

    // Calculate current price in underlying for want(LP token of pair)
    function wantPriceInUnderlying(uint256 _wantAmt) external view returns (uint256[] memory);

    // Calculate current price in usd for want(LP token of pair)
    function wantPriceInUsd(uint256 _wantAmt) external view returns (uint256);
}

// File: IImpulseMultiStrategyQuick.sol

interface IImpulseMultiStrategyQuick {
    // Total want locked tokens balances managed by strategy
    function wantLockedTotalForEach() external view returns (uint256[] memory);

    // Calculate current price in usd for want(LP token of pair)
    function wantPriceInUsd(uint256[] memory _wantAmounts) external view returns (uint256);
}

// File: Initializable.sol

/**
 * @dev This is a base contract to aid in writing upgradeable contracts, or any kind of contract that will be deployed
 * behind a proxy. Since a proxied contract can't have a constructor, it's common to move constructor logic to an
 * external initializer function, usually called `initialize`. It then becomes necessary to protect this initializer
 * function so it can only be called once. The {initializer} modifier provided by this contract will have this effect.
 *
 * TIP: To avoid leaving the proxy in an uninitialized state, the initializer function should be called as early as
 * possible by providing the encoded function call as the `_data` argument to {ERC1967Proxy-constructor}.
 *
 * CAUTION: When used with inheritance, manual care must be taken to not invoke a parent initializer twice, or to ensure
 * that all initializers are idempotent. This is not verified automatically as constructors are by Solidity.
 */
abstract contract Initializable {
    /**
     * @dev Indicates that the contract has been initialized.
     */
    bool private _initialized;

    /**
     * @dev Indicates that the contract is in the process of being initialized.
     */
    bool private _initializing;

    /**
     * @dev Modifier to protect an initializer function from being invoked twice.
     */
    modifier initializer() {
        require(_initializing || !_initialized, "Initializable: contract is already initialized");

        bool isTopLevelCall = !_initializing;
        if (isTopLevelCall) {
            _initializing = true;
            _initialized = true;
        }

        _;

        if (isTopLevelCall) {
            _initializing = false;
        }
    }
}

// File: StringsUpgradeable.sol

/**
 * @dev String operations.
 */
library StringsUpgradeable {
    bytes16 private constant _HEX_SYMBOLS = "0123456789abcdef";

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
}

// File: ContextUpgradeable.sol

/*
 * @dev Provides information about the current execution context, including the
 * sender of the transaction and its data. While these are generally available
 * via msg.sender and msg.data, they should not be accessed in such a direct
 * manner, since when dealing with meta-transactions the account sending and
 * paying for execution may not be the actual sender (as far as an application
 * is concerned).
 *
 * This contract is only required for intermediate, library-like contracts.
 */
abstract contract ContextUpgradeable is Initializable {
    function __Context_init() internal initializer {
        __Context_init_unchained();
    }

    function __Context_init_unchained() internal initializer {
    }
    function _msgSender() internal view virtual returns (address) {
        return msg.sender;
    }

    function _msgData() internal view virtual returns (bytes calldata) {
        return msg.data;
    }
    uint256[50] private __gap;
}

// File: ERC165Upgradeable.sol

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
abstract contract ERC165Upgradeable is Initializable, IERC165Upgradeable {
    function __ERC165_init() internal initializer {
        __ERC165_init_unchained();
    }

    function __ERC165_init_unchained() internal initializer {
    }
    /**
     * @dev See {IERC165-supportsInterface}.
     */
    function supportsInterface(bytes4 interfaceId) public view virtual override returns (bool) {
        return interfaceId == type(IERC165Upgradeable).interfaceId;
    }
    uint256[50] private __gap;
}

// File: IERC20Metadata.sol

/**
 * @dev Interface for the optional metadata functions from the ERC20 standard.
 *
 * _Available since v4.1._
 */
interface IERC20Metadata is IERC20 {
    /**
     * @dev Returns the name of the token.
     */
    function name() external view returns (string memory);

    /**
     * @dev Returns the symbol of the token.
     */
    function symbol() external view returns (string memory);

    /**
     * @dev Returns the decimals places of the token.
     */
    function decimals() external view returns (uint8);
}

// File: ReentrancyGuardUpgradeable.sol

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
abstract contract ReentrancyGuardUpgradeable is Initializable {
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

    function __ReentrancyGuard_init() internal initializer {
        __ReentrancyGuard_init_unchained();
    }

    function __ReentrancyGuard_init_unchained() internal initializer {
        _status = _NOT_ENTERED;
    }

    /**
     * @dev Prevents a contract from calling itself, directly or indirectly.
     * Calling a `nonReentrant` function from another `nonReentrant`
     * function is not supported. It is possible to prevent this from happening
     * by making the `nonReentrant` function external, and make it call a
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
    uint256[49] private __gap;
}

// File: SafeERC20.sol

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

// File: AccessControlUpgradeable.sol

/**
 * @dev External interface of AccessControl declared to support ERC165 detection.
 */
interface IAccessControlUpgradeable {
    function hasRole(bytes32 role, address account) external view returns (bool);

    function getRoleAdmin(bytes32 role) external view returns (bytes32);

    function grantRole(bytes32 role, address account) external;

    function revokeRole(bytes32 role, address account) external;

    function renounceRole(bytes32 role, address account) external;
}

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
abstract contract AccessControlUpgradeable is Initializable, ContextUpgradeable, IAccessControlUpgradeable, ERC165Upgradeable {
    function __AccessControl_init() internal initializer {
        __Context_init_unchained();
        __ERC165_init_unchained();
        __AccessControl_init_unchained();
    }

    function __AccessControl_init_unchained() internal initializer {
    }
    struct RoleData {
        mapping(address => bool) members;
        bytes32 adminRole;
    }

    mapping(bytes32 => RoleData) private _roles;

    bytes32 public constant DEFAULT_ADMIN_ROLE = 0x00;

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
     * bearer except when using {_setupRole}.
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
     * @dev Modifier that checks that an account has a specific role. Reverts
     * with a standardized message including the required role.
     *
     * The format of the revert reason is given by the following regular expression:
     *
     *  /^AccessControl: account (0x[0-9a-f]{20}) is missing role (0x[0-9a-f]{32})$/
     *
     * _Available since v4.1._
     */
    modifier onlyRole(bytes32 role) {
        _checkRole(role, _msgSender());
        _;
    }

    /**
     * @dev See {IERC165-supportsInterface}.
     */
    function supportsInterface(bytes4 interfaceId) public view virtual override returns (bool) {
        return interfaceId == type(IAccessControlUpgradeable).interfaceId || super.supportsInterface(interfaceId);
    }

    /**
     * @dev Returns `true` if `account` has been granted `role`.
     */
    function hasRole(bytes32 role, address account) public view override returns (bool) {
        return _roles[role].members[account];
    }

    /**
     * @dev Revert with a standard message if `account` is missing `role`.
     *
     * The format of the revert reason is given by the following regular expression:
     *
     *  /^AccessControl: account (0x[0-9a-f]{20}) is missing role (0x[0-9a-f]{32})$/
     */
    function _checkRole(bytes32 role, address account) internal view {
        if (!hasRole(role, account)) {
            revert(
                string(
                    abi.encodePacked(
                        "AccessControl: account ",
                        StringsUpgradeable.toHexString(uint160(account), 20),
                        " is missing role ",
                        StringsUpgradeable.toHexString(uint256(role), 32)
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
    function getRoleAdmin(bytes32 role) public view override returns (bytes32) {
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
     * If the calling account had been granted `role`, emits a {RoleRevoked}
     * event.
     *
     * Requirements:
     *
     * - the caller must be `account`.
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
     * [WARNING]
     * ====
     * This function should only be called from the constructor when setting
     * up the initial roles for the system.
     *
     * Using this function in any other way is effectively circumventing the admin
     * system imposed by {AccessControl}.
     * ====
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
        emit RoleAdminChanged(role, getRoleAdmin(role), adminRole);
        _roles[role].adminRole = adminRole;
    }

    function _grantRole(bytes32 role, address account) private {
        if (!hasRole(role, account)) {
            _roles[role].members[account] = true;
            emit RoleGranted(role, account, _msgSender());
        }
    }

    function _revokeRole(bytes32 role, address account) private {
        if (hasRole(role, account)) {
            _roles[role].members[account] = false;
            emit RoleRevoked(role, account, _msgSender());
        }
    }
    uint256[49] private __gap;
}

// File: ImpulseStakingMulti.sol

contract ImpulseStakingMulti is AccessControlUpgradeable, ReentrancyGuardUpgradeable {
    using SafeERC20 for IERC20;

    /**********
     * DATA INTERFACE
     **********/

    // Info of each user.
    struct UserInfo {
        uint256 shares; // How many Shares the user has.
        uint256 depositInWant; // How many ASSET tokens the user has provided.
        uint256[] rewardsDebts; // Order like in AssetInfo rewardsTokens
        // Reward debt. See explanation below.
        //
        // We do some fancy math here. Basically, any point in time, the amount of rewards
        // entitled to a user but is pending to be distributed is:
        //
        //   pending reward = (user.shares * asset.accumulatedPerShare) - user.rewardDebt
        //
        // Whenever a user deposits or withdraws ASSET tokensens to a asset. Here's what happens:
        //   1. The assets `accumulatedPerShare` (and `lastRewardBlock`) gets updated.
        //   2. User receives the pending reward sent to the address.
        //   3. User's `amount` gets updated.
        //   4. User's `rewardDebt` gets updated.
    }
    // Info of each asset.
    struct PoolInfo {
        address assetToken; // Addresses of LP tokens contracts.
        uint256 lastRewardBlock; // Last block number that DHVs distribution occurs.
        uint256[] accumulatedPerShare; // Accumulated token per share, times token decimals. See below.
        address[] rewardsTokens; // Must be constant.
        uint256[] rewardsPerBlock; // Tokens to distribute per block.
        uint256[] accuracy; // Tokens accuracy.
        uint256 poolSupply; // Total amount of deposits by users.
        bool paused; // Flag that displays the pool on pause or not.
        address strategy; // Strategy address that will auto compound want tokens.
    }

    /**********
     * STORAGE
     **********/

    /// @notice pid => pool info
    mapping(uint256 => PoolInfo) public poolInfo;
    /// @notice pid => user address => UserInfo
    mapping(uint256 => mapping(address => UserInfo)) public userInfo;

    address public treasury;
    /// @notice pid => comission
    /// 100% = 10000, 1% = 100, 0.3% = 30
    mapping(uint256 => uint256) public commission;
    uint256 public constant PERCENT_DIVIDER = 10000;

    /// Shows withdraw in shares
    event Withdraw(address indexed user, uint256 indexed poolId, uint256 amount, uint256 totalAmount);
    /// Shows withdraw in tokens
    event WithdrawUnderlying(address indexed user, uint256 indexed poolId, address underlying, uint256 amount);

    event Deposit(address indexed user, uint256 indexed poolId, uint256 amount);
    event ClaimRewards(address indexed user, uint256 indexed poolId, address[] tokens, uint256[] amounts);
    event UpdateCommission(uint256 pid, uint256 commission);

    /**********
     * MODIFIERS
     **********/

    modifier hasPool(uint256 _pid) {
        require(poolExist(_pid), "Pool not exist");
        _;
    }

    modifier poolRunning(uint256 _pid) {
        require(!poolInfo[_pid].paused, "Pool on pause");
        _;
    }

    /**********
     * ADMIN INTERFACE
     **********/

    function initialize() public virtual initializer {
        _setupRole(DEFAULT_ADMIN_ROLE, _msgSender());
        __ReentrancyGuard_init();
    }

    /// @notice Add staking pool to the chief contract.
    /// @param _pid New pool id.
    /// @param _assetAddress Staked tokens.
    /// @param _rewardsTokens Addresses of the reward tokens.
    /// @param _rewardsPerBlock Amount of rewards distributed to the pool every block.
    function addPool(
        uint256 _pid,
        address _assetAddress,
        address[] calldata _rewardsTokens,
        uint256[] calldata _rewardsPerBlock,
        address _strategy
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(!poolExist(_pid), "Pool exist");
        require(_assetAddress != address(0), "Wrong asset address");
        require(_strategy != address(0), "Wrong strategy address");
        require(_rewardsTokens.length == _rewardsPerBlock.length, "Wrong rewards tokens");

        poolInfo[_pid] = PoolInfo({
            assetToken: _assetAddress,
            lastRewardBlock: block.number,
            accumulatedPerShare: new uint256[](_rewardsTokens.length),
            rewardsTokens: _rewardsTokens,
            accuracy: new uint256[](_rewardsTokens.length),
            rewardsPerBlock: _rewardsPerBlock,
            poolSupply: 0,
            paused: false,
            strategy: _strategy
        });
        for (uint256 i = 0; i < _rewardsTokens.length; i++) {
            poolInfo[_pid].accuracy[i] = 10**IERC20Metadata(_rewardsTokens[i]).decimals();
        }
    }

    /// @notice Add reward token to pool's rewards tokens.
    /// @param _pid Id to which pool want to add new reward token.
    /// @param _rewardsPerBlock Amount of rewards distributed to the pool every block.
    /// @param _withUpdate Update current rewards before changing rewardsTokens of pool.
    function addRewardToken(
        uint256 _pid,
        address _newRewardToken,
        uint256 _rewardsPerBlock,
        bool _withUpdate
    ) external onlyRole(DEFAULT_ADMIN_ROLE) hasPool(_pid) {
        if (_withUpdate) {
            updatePool(_pid);
        }
        PoolInfo storage pool = poolInfo[_pid];

        pool.rewardsTokens.push(_newRewardToken);
        pool.rewardsPerBlock.push(_rewardsPerBlock);

        require(pool.rewardsTokens.length == pool.rewardsPerBlock.length, "Wrong rewards tokens");

        pool.accuracy.push(10**IERC20Metadata(_newRewardToken).decimals());
        pool.accumulatedPerShare.push(0);
    }

    /// @notice Update rewards distribution speed.
    /// @param _pid New pool id.
    /// @param _rewardsPerBlock Amount of rewards distributed to the pool every block.
    /// @param _withUpdate Update current rewards before changing the coefficients.
    function updatePoolSettings(
        uint256 _pid,
        uint256[] calldata _rewardsPerBlock,
        bool _withUpdate
    ) external onlyRole(DEFAULT_ADMIN_ROLE) hasPool(_pid) {
        if (_withUpdate) {
            updatePool(_pid);
        }

        require(poolInfo[_pid].rewardsTokens.length == _rewardsPerBlock.length, "Wrong rewards tokens");
        poolInfo[_pid].rewardsPerBlock = _rewardsPerBlock;
    }

    /// @notice Pauses/unpauses the pool.
    /// @param _pid Pool's id.
    /// @param _paused True to pause, False to unpause.
    function setOnPause(uint256 _pid, bool _paused) external hasPool(_pid) onlyRole(DEFAULT_ADMIN_ROLE) {
        poolInfo[_pid].paused = _paused;
    }

    /// @notice Admin method for set treasury address.
    /// @param _treasury New treasury address.
    function setTreasury(address _treasury) external onlyRole(DEFAULT_ADMIN_ROLE) {
        treasury = _treasury;
    }

    /// @notice Admin method for set treasury address.
    /// @param _pid PID of the pool.
    /// @param _commission New commission, 0 - without commission.
    function setCommission(uint256 _pid, uint256 _commission) external hasPool(_pid) onlyRole(DEFAULT_ADMIN_ROLE) {
        require(_commission <= PERCENT_DIVIDER, "Incorrect commission");
        commission[_pid] = _commission;
        emit UpdateCommission(_pid, _commission);
    }

    ///@notice Admin method for set asset address.
    /// @param _pid PID of the pool.
    /// @param _assetAddress New asset address.
    function setAsset(uint256 _pid, address _assetAddress) external onlyRole(DEFAULT_ADMIN_ROLE) {
        poolInfo[_pid].assetToken = _assetAddress;
    }

    /**********
     * USER INTERFACE
     **********/

    /// @notice Update reward variables of the given asset to be up-to-date.
    /// @param _pid Pool's id.
    function updatePool(uint256 _pid) public hasPool(_pid) {
        PoolInfo storage pool = poolInfo[_pid];
        if (block.number <= pool.lastRewardBlock) {
            return;
        }
        if (pool.poolSupply == 0) {
            pool.lastRewardBlock = block.number;
            return;
        }
        uint256 blocks = block.number - pool.lastRewardBlock;
        for (uint256 i = 0; i < pool.rewardsTokens.length; i++) {
            uint256 unaccountedReward = pool.rewardsPerBlock[i] * blocks;
            pool.accumulatedPerShare[i] = pool.accumulatedPerShare[i] + (unaccountedReward * pool.accuracy[i]) / pool.poolSupply;
        }
        pool.lastRewardBlock = block.number;
    }

    /// @notice Deposit (stake) ASSET tokens
    /// @param _pid Pool's id
    /// @param _wantAmt Amount to stake
    function depositInWant(uint256 _pid, uint256 _wantAmt) public virtual nonReentrant hasPool(_pid) poolRunning(_pid) {
        updatePool(_pid);
        PoolInfo memory pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][_msgSender()];

        if (user.rewardsDebts.length == 0 && pool.rewardsTokens.length > 0) {
            user.rewardsDebts = new uint256[](pool.rewardsTokens.length);
        } else if (user.rewardsDebts.length < pool.rewardsTokens.length) {
            uint256 diff = pool.rewardsTokens.length - user.rewardsDebts.length;
            for (uint256 i = 0; i < diff; i++) {
                user.rewardsDebts.push(0);
            }
        }

        uint256 poolAmountBefore = user.shares;
        IERC20(pool.assetToken).safeTransferFrom(_msgSender(), address(this), _wantAmt);
        IImpulseMultiStrategy strategy = IImpulseMultiStrategy(pool.strategy);
        IERC20(pool.assetToken).safeApprove(pool.strategy, 0);
        IERC20(pool.assetToken).safeApprove(pool.strategy, _wantAmt);
        uint256 sharesAmount = strategy.depositInWant(_wantAmt);
        user.shares += sharesAmount;
        user.depositInWant += _wantAmt;

        for (uint256 i = 0; i < pool.rewardsTokens.length; i++) {
            _updateUserInfo(pool, user, i, poolAmountBefore);
        }
        poolInfo[_pid].poolSupply += sharesAmount;

        emit Deposit(_msgSender(), _pid, _wantAmt);
    }

    /// @notice Deposit (stake) ASSET tokens.
    /// @param _pid Pool's id.
    /// @param _amounts Amounts in underlyings to stake.
    /// @dev Amounts must be in this order: USDC, USDT, DAI, MAI.
    function depositInUnderlying(uint256 _pid, uint256[] calldata _amounts) public virtual nonReentrant hasPool(_pid) poolRunning(_pid) {
        updatePool(_pid);

        PoolInfo memory pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][_msgSender()];

        IImpulseMultiStrategy strategy = IImpulseMultiStrategy(pool.strategy);

        address[] memory listUnderlying = strategy.listUnderlying();
        require(_amounts.length == listUnderlying.length, "wrong amounts");

        if (user.rewardsDebts.length == 0 && pool.rewardsTokens.length > 0) {
            user.rewardsDebts = new uint256[](pool.rewardsTokens.length);
        } else if (user.rewardsDebts.length < pool.rewardsTokens.length) {
            uint256 diff = pool.rewardsTokens.length - user.rewardsDebts.length;
            for (uint256 i = 0; i < diff; i++) {
                user.rewardsDebts.push(0);
            }
        }

        uint256 poolAmountBefore = user.shares;
        for (uint256 u = 0; u < listUnderlying.length; u++) {
            address asset = listUnderlying[u];
            if (_amounts[u] != 0) {
                IERC20(asset).safeTransferFrom(_msgSender(), address(this), _amounts[u]);
                IERC20(asset).safeApprove(pool.strategy, 0);
                IERC20(asset).safeApprove(pool.strategy, _amounts[u]);
            }
        }

        uint256 sharesAmount = strategy.depositInUnderlying(_amounts);
        user.shares += sharesAmount;
        uint256 wantAmt = ((user.shares * strategy.wantLockedTotal()) / strategy.sharesTotal());
        user.depositInWant = wantAmt;

        for (uint256 i = 0; i < pool.rewardsTokens.length; i++) {
            _updateUserInfo(pool, user, i, poolAmountBefore);
        }
        poolInfo[_pid].poolSupply += sharesAmount;

        emit Deposit(_msgSender(), _pid, wantAmt);
    }

    /// @notice Withdraw shares amount from staking protocol in one of the underlying tokens.
    /// @param _pid PID of the pool.
    /// @param _wantAmt Amount of shares to withdraw.
    /// @param _underlying Token to withdraw in.
    function withdrawInOneUnderlying(
        uint256 _pid,
        uint256 _wantAmt,
        address _underlying
    ) public virtual nonReentrant hasPool(_pid) poolRunning(_pid) {
        updatePool(_pid);
        PoolInfo memory pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][_msgSender()];

        if (user.rewardsDebts.length == 0 && pool.rewardsTokens.length > 0) {
            user.rewardsDebts = new uint256[](pool.rewardsTokens.length);
        } else if (user.rewardsDebts.length < pool.rewardsTokens.length) {
            uint256 diff = pool.rewardsTokens.length - user.rewardsDebts.length;
            for (uint256 i = 0; i < diff; i++) {
                user.rewardsDebts.push(0);
            }
        }

        require(user.shares > 0 && user.depositInWant >= _wantAmt, "withdraw: wrong amount");
        uint256 poolAmountBefore = user.shares;
        uint256 sharesAmount = _withdrawFromStrategy(_pid, _wantAmt, _underlying);

        user.shares -= sharesAmount;

        IImpulseMultiStrategy strategy = IImpulseMultiStrategy(pool.strategy);
        uint256 sharesTotal = strategy.sharesTotal();

        if (sharesTotal == 0) user.depositInWant -= _wantAmt;
        else user.depositInWant = ((user.shares * strategy.wantLockedTotal()) / sharesTotal);

        (uint256 underlyingBalance, uint256 withdrawCommissions) = _transferCommission(_pid, _underlying);

        IERC20(_underlying).safeTransfer(_msgSender(), underlyingBalance - withdrawCommissions);

        for (uint256 i = 0; i < pool.rewardsTokens.length; i++) {
            _updateUserInfo(pool, user, i, poolAmountBefore);
        }

        poolInfo[_pid].poolSupply -= sharesAmount;

        emit WithdrawUnderlying(_msgSender(), _pid, _underlying, underlyingBalance);
    }

    function _withdrawFromStrategy(
        uint256 _pid,
        uint256 _wantAmt,
        address _underlying
    ) internal returns (uint256 sharesAmount) {
        UserInfo storage user = userInfo[_pid][_msgSender()];
        IImpulseMultiStrategy strategy = IImpulseMultiStrategy(poolInfo[_pid].strategy);

        uint256 userTotalAmount = ((user.shares * strategy.wantLockedTotal()) / strategy.sharesTotal());
        uint256 withdrawTotalAmount = (_wantAmt * userTotalAmount) / user.depositInWant;

        sharesAmount = strategy.withdrawInOneUnderlying(withdrawTotalAmount, _underlying);

        emit Withdraw(_msgSender(), _pid, _wantAmt, withdrawTotalAmount);
    }

    /// @notice Internal function to calculate and withdraw the commission.
    /// @param _pid PID of the pool.
    /// @param _underlying Token to calculate comission in.
    /// @return underlyingBalance Initial amount of the token to calculate from.
    /// @return withdrawCommissions Commission amount in the same token.
    function _transferCommission(uint256 _pid, address _underlying) internal returns (uint256 underlyingBalance, uint256 withdrawCommissions) {
        underlyingBalance = IERC20(_underlying).balanceOf(address(this));
        if (treasury != address(0) && commission[_pid] > 0) {
            withdrawCommissions = (underlyingBalance * commission[_pid]) / PERCENT_DIVIDER;
            IERC20(_underlying).safeTransfer(treasury, withdrawCommissions);
        }
    }

    /// @notice Update pool and claim pending rewards for the user.
    /// @param _pid Pool's id.
    function claimRewards(uint256 _pid) external nonReentrant poolRunning(_pid) {
        _claimRewards(_pid, _msgSender());
    }

    /// @notice Transfer pending rewards for the user.
    /// @dev Update user's info about rewards.
    function _updateUserInfo(
        PoolInfo memory pool,
        UserInfo storage user,
        uint256 _tokenNum,
        uint256 _amount
    ) internal returns (uint256 pending) {
        uint256 accumulatedPerShare = pool.accumulatedPerShare[_tokenNum];

        if (user.rewardsDebts.length < pool.rewardsTokens.length) {
            user.rewardsDebts.push(0);
        }

        if (_amount > 0) {
            pending = (_amount * accumulatedPerShare) / pool.accuracy[_tokenNum] - user.rewardsDebts[_tokenNum];
            if (pending > 0) {
                IERC20(pool.rewardsTokens[_tokenNum]).safeTransfer(_msgSender(), pending);
            }
        }
        user.rewardsDebts[_tokenNum] = (user.shares * accumulatedPerShare) / pool.accuracy[_tokenNum];
    }

    /**********
     * VIEW INTERFACE
     **********/

    /// @notice Getter for reward token address.
    /// @param _pid Pool's id.
    /// @param _index Index of the reward token.
    /// @return reward token address.
    function rewardToken(uint256 _pid, uint256 _index) external view returns (address) {
        PoolInfo memory pool = poolInfo[_pid];
        return pool.rewardsTokens[_index];
    }

    /// @notice Getter for reward token rate.
    /// @param _pid Pool's id.
    /// @param _index Index of the reward token.
    /// @return reward token rate.
    function rewardTokenRate(uint256 _pid, uint256 _index) external view returns (uint256) {
        PoolInfo memory pool = poolInfo[_pid];
        return pool.rewardsPerBlock[_index];
    }

    /// @notice Getter for reward tokens addresses.
    /// @param _pid Pool's id.
    /// @return reward token addresses.
    function rewardTokens(uint256 _pid) external view returns (address[] memory) {
        return poolInfo[_pid].rewardsTokens;
    }

    /// @notice Getter for reward token rates array.
    /// @param _pid Pool's id.
    /// @return reward token rates.
    function rewardRates(uint256 _pid) external view returns (uint256[] memory) {
        return poolInfo[_pid].rewardsPerBlock;
    }

    /// @notice Getter for reward tokens count in pool.
    /// @param _pid Pool's id.
    /// @return reward tokens counts.
    function rewardTokensLength(uint256 _pid) external view returns (uint256) {
        return poolInfo[_pid].rewardsTokens.length;
    }

    /// @notice View function to see pending DHVs on frontend.
    /// @param _pid Pool's id
    /// @param _user Address to check
    /// @return amounts Amounts of reward tokens available to claim
    function pendingRewards(uint256 _pid, address _user) external view hasPool(_pid) returns (uint256[] memory amounts) {
        PoolInfo memory pool = poolInfo[_pid];
        UserInfo memory user = userInfo[_pid][_user];

        amounts = new uint256[](pool.rewardsTokens.length);
        for (uint256 i = 0; i < pool.rewardsTokens.length; i++) {
            uint256 accumulatedPerShare = pool.accumulatedPerShare[i];

            if (block.number > pool.lastRewardBlock && pool.poolSupply != 0) {
                uint256 blocks = block.number - pool.lastRewardBlock;
                uint256 unaccountedReward = pool.rewardsPerBlock[i] * blocks;
                accumulatedPerShare = accumulatedPerShare + (unaccountedReward * pool.accuracy[i]) / pool.poolSupply;
            }

            uint256 rewardsDebts = 0;
            if (i < user.rewardsDebts.length) {
                rewardsDebts = user.rewardsDebts[i];
            }

            amounts[i] = (user.shares * accumulatedPerShare) / pool.accuracy[i] - rewardsDebts;
        }
    }

    /// @notice Check if pool exists.
    /// @param _pid Pool's id.
    /// @return true if pool exists.
    function poolExist(uint256 _pid) public view returns (bool) {
        return poolInfo[_pid].assetToken != address(0);
    }

    /// @notice Check the user's staked amount in the pool.
    /// @param _pid Pool's id.
    /// @param _user Address to check.
    /// @return Staked amount in all asset tokens.
    function userPoolAmount(uint256 _pid, address _user) public view returns (uint256) {
        UserInfo memory user = userInfo[_pid][_user];
        return user.depositInWant;
    }

    /// @notice Check the user's staked amount in the pool in usd.
    /// @param _pid Pool's id.
    /// @param _user Address to check.
    /// @return Staked amounts for each asset token in usd.
    function userPoolAmountInUsd(uint256 _pid, address _user) public view returns (uint256) {
        PoolInfo memory pool = poolInfo[_pid];
        IImpulseMultiStrategy strategy = IImpulseMultiStrategy(pool.strategy);
        UserInfo memory user = userInfo[_pid][_user];

        if (_pid == 3) {
            uint256[] memory userTotalAmounts = new uint256[](3);
            for (uint256 i = 0; i < 3; i++) {
                userTotalAmounts[i] = ((user.shares * IImpulseMultiStrategyQuick(address(strategy)).wantLockedTotalForEach()[i]) /
                    strategy.sharesTotal());
            }
            return IImpulseMultiStrategyQuick(address(strategy)).wantPriceInUsd(userTotalAmounts);
        }

        uint256 userTotalAmount = ((user.shares * strategy.wantLockedTotal()) / strategy.sharesTotal());
        return strategy.wantPriceInUsd(userTotalAmount);
    }

    /// @notice Check the user's staked amount in the pool in underlying.
    /// @param _pid Pool's id.
    /// @param _user Address to check.
    /// @return Staked amount.
    function userPoolAmountInUnderlying(uint256 _pid, address _user) public view returns (uint256[] memory) {
        PoolInfo memory pool = poolInfo[_pid];
        IImpulseMultiStrategy strategy = IImpulseMultiStrategy(pool.strategy);
        UserInfo memory user = userInfo[_pid][_user];

        uint256 userTotalAmount = ((user.shares * strategy.wantLockedTotal()) / strategy.sharesTotal());

        return strategy.wantPriceInUnderlying(userTotalAmount);
    }

    /// @notice Returns yield balance for the user in Cluster tokens.
    /// @param _pid Cluster staking pool ID.
    function yieldBalance(uint256 _pid, address _user) external view virtual returns (uint256) {
        PoolInfo memory pool = poolInfo[_pid];
        IImpulseMultiStrategy strategy = IImpulseMultiStrategy(pool.strategy);
        if (strategy.sharesTotal() == 0) {
            return 0;
        }
        UserInfo memory user = userInfo[_pid][_user];
        return ((user.shares * strategy.wantLockedTotal()) / strategy.sharesTotal()) - user.depositInWant;
    }

    /**********
     * INTERNAL HELPERS
     **********/

    function _claimRewards(uint256 _pid, address _user) internal {
        updatePool(_pid);
        PoolInfo memory pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][_user];

        uint256[] memory amounts = new uint256[](pool.rewardsTokens.length);
        for (uint256 i = 0; i < pool.rewardsTokens.length; i++) {
            amounts[i] = _updateUserInfo(pool, user, i, user.shares);
        }
        emit ClaimRewards(_user, _pid, pool.rewardsTokens, amounts);
    }
}