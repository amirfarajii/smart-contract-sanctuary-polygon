// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.1 (access/AccessControl.sol)

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
        _checkRole(role, _msgSender());
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
    function hasRole(bytes32 role, address account) public view override returns (bool) {
        return _roles[role].members[account];
    }

    /**
     * @dev Revert with a standard message if `account` is missing `role`.
     *
     * The format of the revert reason is given by the following regular expression:
     *
     *  /^AccessControl: account (0x[0-9a-f]{40}) is missing role (0x[0-9a-f]{64})$/
     */
    function _checkRole(bytes32 role, address account) internal view {
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
     * If the calling account had been revoked `role`, emits a {RoleRevoked}
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
// OpenZeppelin Contracts v4.4.1 (utils/Strings.sol)

pragma solidity ^0.8.0;

/**
 * @dev String operations.
 */
library Strings {
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
// OpenZeppelin Contracts v4.4.1 (utils/math/SafeMath.sol)

pragma solidity ^0.8.0;

// CAUTION
// This version of SafeMath should only be used with Solidity 0.8 or later,
// because it relies on the compiler's built in overflow checks.

/**
 * @dev Wrappers over Solidity's arithmetic operations.
 *
 * NOTE: `SafeMath` is generally not needed starting with Solidity 0.8, since the compiler
 * now has built in overflow checking.
 */
library SafeMath {
    /**
     * @dev Returns the addition of two unsigned integers, with an overflow flag.
     *
     * _Available since v3.4._
     */
    function tryAdd(uint256 a, uint256 b) internal pure returns (bool, uint256) {
        unchecked {
            uint256 c = a + b;
            if (c < a) return (false, 0);
            return (true, c);
        }
    }

    /**
     * @dev Returns the substraction of two unsigned integers, with an overflow flag.
     *
     * _Available since v3.4._
     */
    function trySub(uint256 a, uint256 b) internal pure returns (bool, uint256) {
        unchecked {
            if (b > a) return (false, 0);
            return (true, a - b);
        }
    }

    /**
     * @dev Returns the multiplication of two unsigned integers, with an overflow flag.
     *
     * _Available since v3.4._
     */
    function tryMul(uint256 a, uint256 b) internal pure returns (bool, uint256) {
        unchecked {
            // Gas optimization: this is cheaper than requiring 'a' not being zero, but the
            // benefit is lost if 'b' is also tested.
            // See: https://github.com/OpenZeppelin/openzeppelin-contracts/pull/522
            if (a == 0) return (true, 0);
            uint256 c = a * b;
            if (c / a != b) return (false, 0);
            return (true, c);
        }
    }

    /**
     * @dev Returns the division of two unsigned integers, with a division by zero flag.
     *
     * _Available since v3.4._
     */
    function tryDiv(uint256 a, uint256 b) internal pure returns (bool, uint256) {
        unchecked {
            if (b == 0) return (false, 0);
            return (true, a / b);
        }
    }

    /**
     * @dev Returns the remainder of dividing two unsigned integers, with a division by zero flag.
     *
     * _Available since v3.4._
     */
    function tryMod(uint256 a, uint256 b) internal pure returns (bool, uint256) {
        unchecked {
            if (b == 0) return (false, 0);
            return (true, a % b);
        }
    }

    /**
     * @dev Returns the addition of two unsigned integers, reverting on
     * overflow.
     *
     * Counterpart to Solidity's `+` operator.
     *
     * Requirements:
     *
     * - Addition cannot overflow.
     */
    function add(uint256 a, uint256 b) internal pure returns (uint256) {
        return a + b;
    }

    /**
     * @dev Returns the subtraction of two unsigned integers, reverting on
     * overflow (when the result is negative).
     *
     * Counterpart to Solidity's `-` operator.
     *
     * Requirements:
     *
     * - Subtraction cannot overflow.
     */
    function sub(uint256 a, uint256 b) internal pure returns (uint256) {
        return a - b;
    }

    /**
     * @dev Returns the multiplication of two unsigned integers, reverting on
     * overflow.
     *
     * Counterpart to Solidity's `*` operator.
     *
     * Requirements:
     *
     * - Multiplication cannot overflow.
     */
    function mul(uint256 a, uint256 b) internal pure returns (uint256) {
        return a * b;
    }

    /**
     * @dev Returns the integer division of two unsigned integers, reverting on
     * division by zero. The result is rounded towards zero.
     *
     * Counterpart to Solidity's `/` operator.
     *
     * Requirements:
     *
     * - The divisor cannot be zero.
     */
    function div(uint256 a, uint256 b) internal pure returns (uint256) {
        return a / b;
    }

    /**
     * @dev Returns the remainder of dividing two unsigned integers. (unsigned integer modulo),
     * reverting when dividing by zero.
     *
     * Counterpart to Solidity's `%` operator. This function uses a `revert`
     * opcode (which leaves remaining gas untouched) while Solidity uses an
     * invalid opcode to revert (consuming all remaining gas).
     *
     * Requirements:
     *
     * - The divisor cannot be zero.
     */
    function mod(uint256 a, uint256 b) internal pure returns (uint256) {
        return a % b;
    }

    /**
     * @dev Returns the subtraction of two unsigned integers, reverting with custom message on
     * overflow (when the result is negative).
     *
     * CAUTION: This function is deprecated because it requires allocating memory for the error
     * message unnecessarily. For custom revert reasons use {trySub}.
     *
     * Counterpart to Solidity's `-` operator.
     *
     * Requirements:
     *
     * - Subtraction cannot overflow.
     */
    function sub(
        uint256 a,
        uint256 b,
        string memory errorMessage
    ) internal pure returns (uint256) {
        unchecked {
            require(b <= a, errorMessage);
            return a - b;
        }
    }

    /**
     * @dev Returns the integer division of two unsigned integers, reverting with custom message on
     * division by zero. The result is rounded towards zero.
     *
     * Counterpart to Solidity's `/` operator. Note: this function uses a
     * `revert` opcode (which leaves remaining gas untouched) while Solidity
     * uses an invalid opcode to revert (consuming all remaining gas).
     *
     * Requirements:
     *
     * - The divisor cannot be zero.
     */
    function div(
        uint256 a,
        uint256 b,
        string memory errorMessage
    ) internal pure returns (uint256) {
        unchecked {
            require(b > 0, errorMessage);
            return a / b;
        }
    }

    /**
     * @dev Returns the remainder of dividing two unsigned integers. (unsigned integer modulo),
     * reverting with custom message when dividing by zero.
     *
     * CAUTION: This function is deprecated because it requires allocating memory for the error
     * message unnecessarily. For custom revert reasons use {tryMod}.
     *
     * Counterpart to Solidity's `%` operator. This function uses a `revert`
     * opcode (which leaves remaining gas untouched) while Solidity uses an
     * invalid opcode to revert (consuming all remaining gas).
     *
     * Requirements:
     *
     * - The divisor cannot be zero.
     */
    function mod(
        uint256 a,
        uint256 b,
        string memory errorMessage
    ) internal pure returns (uint256) {
        unchecked {
            require(b > 0, errorMessage);
            return a % b;
        }
    }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.2;

string constant FREE_STATUS = "On the loose";
string constant CAPTURED_STATUS = "Captured";

enum AvatarStatus {
    Free,
    Captured
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "./PirateAvatar.sol";
import "../traits/TokenTrait.sol";
import "./AvatarStatus.sol";

interface IPirateAvatarMetadata {
    
    function pirateAvatarExists(uint256 tokenId) external view returns (bool);

    function addPirateAvatar(uint256 pirateAvatarTokenId, PirateAvatar calldata pirateAvatar, TokenTrait[] calldata tokenTraits) external;

    function updatePirateAvatar(uint256 tokenId, PirateAvatar calldata pirateAvatar, TokenTrait[] calldata traits) external;

    function addToNumberTraitType(uint256 tokenId, uint256 amount, string memory traitTypeName) external;

    function getTraitTypeValue(uint256 tokenId, string memory traitTypeName) external view returns(string memory);

    function setTraitTypeValue(uint256 tokenId, string memory traitValue, string memory traitTypeName) external;
    
    function getPirateAvatar(uint256 tokenId) external view returns (PirateAvatar memory);

    function getTokenTraits(uint256 tokenId) external view returns (TokenTrait[] memory);

    function tokenURI(uint256 tokenId) external view returns (string memory);

    function getNotorietyLevel(uint256 tokenId, string memory notorietyTraitTypeName) external view returns(uint8 level);
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

struct PirateAvatar {
    string name; // required
    string imageUri;
    bool isGovernor;
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

import "./IPirateAvatarMetadata.sol";
import "./PirateAvatar.sol";
import "../traits/TokenTrait.sol";

import "../../roles/Roles.sol";

//import "hardhat/console.sol";

contract PirateAvatarMetadata is 
    AccessControl,
    IPirateAvatarMetadata 
{
    using Strings for uint256;
    using SafeMath for uint;
    using SafeMath for uint256;

    mapping(uint256 => PirateAvatar) private tokenIdToPirateAvatar;
    mapping(uint256 => TokenTrait[]) private tokenIdToTokenTraits;

    modifier avatarExists(uint256 tokenId) {
        require(pirateAvatarExists(tokenId), "Avatar not found");
        _;
    }

    constructor() {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(AVATAR_MANAGER_ROLE, msg.sender);
    }

    function pirateAvatarExists(uint256 tokenId) override public view returns (bool) {
        return bytes(tokenIdToPirateAvatar[tokenId].name).length != 0;
    }

    function addPirateAvatar(uint256 pirateAvatarTokenId, PirateAvatar calldata pirateAvatar, TokenTrait[] calldata traits) 
        override 
        external 
    {
        require(hasRole(AVATAR_MANAGER_ROLE, msg.sender), "Not in role");        
        require(!pirateAvatarExists(pirateAvatarTokenId), "Avatar exists");
        require(bytes(pirateAvatar.name).length != 0, "Avatar not set");

        tokenIdToPirateAvatar[pirateAvatarTokenId] = PirateAvatar(pirateAvatar.name, pirateAvatar.imageUri, pirateAvatar.isGovernor);

        for (uint8 i = 0; i < traits.length; i++) {
            tokenIdToTokenTraits[pirateAvatarTokenId].push(
                TokenTrait(traits[i].traitType, traits[i].traitValue, traits[i].displayType)
            );
        }
    }

    function updatePirateAvatar(uint256 tokenId, PirateAvatar calldata pirateAvatar, TokenTrait[] calldata traits) 
        override 
        external 
        avatarExists(tokenId)
    {
        require(hasRole(AVATAR_MANAGER_ROLE, msg.sender), "Not in role");
        require(bytes(pirateAvatar.name).length != 0, "Avatar not set");

        tokenIdToPirateAvatar[tokenId] = PirateAvatar(pirateAvatar.name, pirateAvatar.imageUri, pirateAvatar.isGovernor);

        delete tokenIdToTokenTraits[tokenId];

        for (uint8 i = 0; i < traits.length; i++) {
            tokenIdToTokenTraits[tokenId].push(
                TokenTrait(traits[i].traitType, traits[i].traitValue, traits[i].displayType)
            );
        }
    }

    function getTraitTypeValue(uint256 tokenId, string memory traitTypeName) override external view returns(string memory) {
        require(hasRole(AVATAR_MANAGER_ROLE, msg.sender), "Not in role");

        for (uint8 i = 0; i < tokenIdToTokenTraits[tokenId].length; i++) {
            if (keccak256(bytes(tokenIdToTokenTraits[tokenId][i].traitType)) == keccak256(bytes(traitTypeName)))
            {
                return tokenIdToTokenTraits[tokenId][i].traitValue;
            }
        }
        return "";
    }

    function setTraitTypeValue(uint256 tokenId, string memory traitValue, string memory traitTypeName) override external {
        require(hasRole(AVATAR_MANAGER_ROLE, msg.sender), "Not in role");

        for (uint8 i = 0; i < tokenIdToTokenTraits[tokenId].length; i++) {
            if (keccak256(bytes(tokenIdToTokenTraits[tokenId][i].traitType)) == keccak256(bytes(traitTypeName)))
            {
                tokenIdToTokenTraits[tokenId][i].traitValue = traitValue;
                break;
            }
        }
    }

    function addToNumberTraitType(uint256 tokenId, uint256 amount, string memory traitTypeName) 
        override 
        external 
        avatarExists(tokenId)
    {
        require(hasRole(AVATAR_MANAGER_ROLE, msg.sender), "Not in role");

        for (uint8 i = 0; i < tokenIdToTokenTraits[tokenId].length; i++) {
            if (keccak256(bytes(tokenIdToTokenTraits[tokenId][i].traitType)) == keccak256(bytes(traitTypeName)))
            {
                uint _newValue = st2num(tokenIdToTokenTraits[tokenId][i].traitValue).add(amount);

                tokenIdToTokenTraits[tokenId][i].traitValue = _newValue.toString();
                break;
            }
        }
    }

    function removePirateAvatar(uint256 tokenId) public avatarExists(tokenId) {
        require(hasRole(AVATAR_MANAGER_ROLE, msg.sender), "Not in role");

        PirateAvatar memory pirateAvatar;
        tokenIdToPirateAvatar[tokenId] = pirateAvatar;
        
        delete tokenIdToTokenTraits[tokenId];
    }

    function getPirateAvatar(uint256 tokenId) override public view avatarExists(tokenId) returns (PirateAvatar memory) {
        return tokenIdToPirateAvatar[tokenId];
    }

    function getTokenTraits(uint256 tokenId) override public view avatarExists(tokenId) returns (TokenTrait[] memory) {
        return tokenIdToTokenTraits[tokenId];
    }

    function tokenURI(uint256 tokenId) external view override returns (string memory) {
        return buildPirateAvatarTokenUri(tokenId);
    }

    function buildPirateAvatarTokenUri(uint256 tokenId) private view returns (string memory) {

        PirateAvatar memory pirateAvatar = getPirateAvatar(tokenId);
        TokenTrait[] memory tokenTraits = getTokenTraits(tokenId);

        string memory metadata = 
            string(
                abi.encodePacked('{"name":"', pirateAvatar.name, 
                    '", "description":"Avatar for MVPS Pirate #', tokenId.toString(), 
                    '", "image":"', pirateAvatar.imageUri, '", "attributes":[', compileAttributes(tokenTraits), ']}'
                )
            );

        return metadata;
    }

    function getNotorietyLevel(uint256 tokenId, string memory notorietyTraitTypeName) external view returns(uint8 level) {
        for (uint8 i = 0; i < tokenIdToTokenTraits[tokenId].length; i++) {
            if (keccak256(bytes(tokenIdToTokenTraits[tokenId][i].traitType)) == keccak256(bytes(notorietyTraitTypeName)))
            {
                uint notorietyPoints = st2num(tokenIdToTokenTraits[tokenId][i].traitValue);

                if (notorietyPoints < 300) return 1;
                if (notorietyPoints < 900) return 2;
                if (notorietyPoints < 2700) return 3;
                if (notorietyPoints < 6500) return 4;
                if (notorietyPoints < 14000) return 5;
                if (notorietyPoints < 23000) return 6;
                if (notorietyPoints < 34000) return 7;
                if (notorietyPoints < 48000) return 8;

                if (notorietyPoints < 64000) return 9;
                if (notorietyPoints < 88000) return 10;
                if (notorietyPoints < 105000) return 11;
                if (notorietyPoints < 120000) return 12;
                if (notorietyPoints < 140000) return 13;

                if (notorietyPoints < 165000) return 14;
                if (notorietyPoints < 195000) return 15;
                if (notorietyPoints < 225000) return 16;
                if (notorietyPoints < 260000) return 17;
                if (notorietyPoints < 300000) return 18;
                if (notorietyPoints < 350000) return 19;
                
                return 20;
            }
        }
        return 1;
    }

    function bytes32ToStr(bytes32 _bytes32) public pure returns (string memory) {

        // string memory str = string(_bytes32);
        // TypeError: Explicit type conversion not allowed from "bytes32" to "string storage pointer"
        // thus we should fist convert bytes32 to bytes (to dynamically-sized byte array)

        bytes memory bytesArray = new bytes(32);
        for (uint256 i; i < 32; i++) {
            bytesArray[i] = _bytes32[i];
        }
        return string(bytesArray);
    }

    function compileAttributes(TokenTrait[] memory tokenTraits) private pure returns (string memory) {
        
        string memory attributes;

        for (uint256 i = 0; i < tokenTraits.length; i++) {
            
            attributes = string(
                abi.encodePacked(attributes, 
                    string(
                        abi.encodePacked(
                            '{"value":"',
                            tokenTraits[i].traitValue,
                            
                            uint8(tokenTraits[i].displayType) != 0 ?
                                string(abi.encodePacked('","display_type":"',
                                getDisplayTypeName(tokenTraits[i].displayType))) : '',

                            '","trait_type":"',
                            tokenTraits[i].traitType,
                            '"}',

                            i < tokenTraits.length -1 ? "," : ''
                        )
                    )
                )
            );
        }

        return attributes;
    }

    function getDisplayTypeName(TraitDisplayType traitDisplayType) private pure returns (string memory)
    {
        if (traitDisplayType == TraitDisplayType.Number)
        {
            return "number";
        }
        return "string";
    } 

    function st2num(string memory numString) public pure returns(uint) {
        uint  val=0;
        bytes   memory stringBytes = bytes(numString);
        for (uint  i =  0; i<stringBytes.length; i++) {
            uint exp = stringBytes.length - i;
            bytes1 ival = stringBytes[i];
            uint8 uval = uint8(ival);
            uint jval = uval - uint(0x30);
   
            val +=  (uint(jval) * (10**(exp-1))); 
        }
        return val;
    }

    string internal constant TABLE =
        "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";

    function base64(bytes memory data) internal pure returns (string memory) {
        if (data.length == 0) return "";

        // load the table into memory
        string memory table = TABLE;

        // multiply by 4/3 rounded up
        uint256 encodedLen = 4 * ((data.length + 2) / 3);

        // add some extra buffer at the end required for the writing
        string memory result = new string(encodedLen + 32);

        assembly {
            // set the actual output length
            mstore(result, encodedLen)

            // prepare the lookup table
            let tablePtr := add(table, 1)

            // input ptr
            let dataPtr := data
            let endPtr := add(dataPtr, mload(data))

            // result ptr, jump over length
            let resultPtr := add(result, 32)

            // run over the input, 3 bytes at a time
            for {

            } lt(dataPtr, endPtr) {

            } {
                dataPtr := add(dataPtr, 3)

                // read 3 bytes
                let input := mload(dataPtr)

                // write 4 characters
                mstore(
                    resultPtr,
                    shl(248, mload(add(tablePtr, and(shr(18, input), 0x3F))))
                )
                resultPtr := add(resultPtr, 1)
                mstore(
                    resultPtr,
                    shl(248, mload(add(tablePtr, and(shr(12, input), 0x3F))))
                )
                resultPtr := add(resultPtr, 1)
                mstore(
                    resultPtr,
                    shl(248, mload(add(tablePtr, and(shr(6, input), 0x3F))))
                )
                resultPtr := add(resultPtr, 1)
                mstore(
                    resultPtr,
                    shl(248, mload(add(tablePtr, and(input, 0x3F))))
                )
                resultPtr := add(resultPtr, 1)
            }

            // padding with '='
            switch mod(mload(data), 3)
            case 1 {
                mstore(sub(resultPtr, 2), shl(240, 0x3d3d))
            }
            case 2 {
                mstore(sub(resultPtr, 1), shl(248, 0x3d))
            }
        }

        return result;
    }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "./TraitDisplayType.sol";

string constant NOTORIETY_POINTS_TRAIT_NAME = "Notoriety Points";
string constant PIRATE_TYPE_NAME = "Pirate Type";
string constant STATUS_TYPE_NAME = "Status";
string constant PROFICIENCY_TRAIT_NAME = "Proficiency";
string constant SHIP_TYPE_NAME = "Ship Type";

string constant PROFICIENCY_BONUS_TRAIT_NAME = "Proficiency Bonus";
string constant VALUE_TRAIT_NAME = "Value";

struct TokenTrait {
    string traitType; // required
    string traitValue;
    TraitDisplayType displayType;
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

enum TraitDisplayType {
    String,
    Number
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

bytes32 constant AVATAR_MANAGER_ROLE = keccak256("AVATAR_MANAGER_ROLE");
bytes32 constant AVATAR_MINTER_ROLE = keccak256("AVATAR_MINTER_ROLE");
bytes32 constant PIRATE_ITEM_MANAGER_ROLE = keccak256("PIRATE_ITEM_MANAGER_ROLE");
bytes32 constant SHIP_MANAGER_ROLE = keccak256("SHIP_MANAGER_ROLE");
bytes32 constant STAKING_ROLE = keccak256("STAKING_ROLE");
bytes32 constant REWARD_MANAGER_ROLE = keccak256("REWARD_MANAGER_ROLE");