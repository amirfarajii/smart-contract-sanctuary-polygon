/**
 *Submitted for verification at polygonscan.com on 2022-08-11
*/

// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.6;

abstract contract Context {
    function _msgSender() internal view virtual returns (address) {
        return msg.sender;
    }

    function _msgData() internal view virtual returns (bytes calldata) {
        return msg.data;
    }
}


abstract contract Ownable is Context {
    address private _owner;

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    /**
     * @dev Initializes the contract setting the deployer as the initial owner.
     */
    constructor() {
        _setOwner(_msgSender());
    }

    /**
     * @dev Returns the address of the current owner.
     */
    function owner() public view virtual returns (address) {
        return _owner;
    }

    /**
     * @dev Throws if called by any account other than the owner.
     */
    modifier onlyOwner() {
        require(owner() == _msgSender(), "Ownable: caller is not the owner");
        _;
    }

    /**
     * @dev Leaves the contract without owner. It will not be possible to call
     * `onlyOwner` functions anymore. Can only be called by the current owner.
     *
     * NOTE: Renouncing ownership will leave the contract without an owner,
     * thereby removing any functionality that is only available to the owner.
     */
    function renounceOwnership() public virtual onlyOwner {
        _setOwner(address(0));
    }

    /**
     * @dev Transfers ownership of the contract to a new account (`newOwner`).
     * Can only be called by the current owner.
     */
    function transferOwnership(address newOwner) public virtual onlyOwner {
        require(newOwner != address(0), "Ownable: new owner is the zero address");
        _setOwner(newOwner);
    }

    function _setOwner(address newOwner) private {
        address oldOwner = _owner;
        _owner = newOwner;
        emit OwnershipTransferred(oldOwner, newOwner);
    }
}

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


/**
 * @dev Interface of the ERC20 standard as defined in the EIP.
 */
interface IERC20 {
    /**
     * @dev Returns the amount of tokens in existence.
     */
    function totalSupply() external view returns (uint256);

    function decimals() external view returns (uint256);

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
    function transfer(address recipient, uint256 amount)
        external
        returns (bool);

    /**
     * @dev Returns the remaining number of tokens that `spender` will be
     * allowed to spend on behalf of `owner` through {transferFrom}. This is
     * zero by default.
     *
     * This value changes when {approve} or {transferFrom} are called.
     */
    function allowance(address owner, address spender)
        external
        view
        returns (uint256);

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
    event Approval(
        address indexed owner,
        address indexed spender,
        uint256 value
    );
}

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
}


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
        _callOptionalReturn(
            token,
            abi.encodeWithSelector(token.transfer.selector, to, value)
        );
    }

    function safeTransferFrom(
        IERC20 token,
        address from,
        address to,
        uint256 value
    ) internal {
        _callOptionalReturn(
            token,
            abi.encodeWithSelector(token.transferFrom.selector, from, to, value)
        );
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
        _callOptionalReturn(
            token,
            abi.encodeWithSelector(token.approve.selector, spender, value)
        );
    }

    function safeIncreaseAllowance(
        IERC20 token,
        address spender,
        uint256 value
    ) internal {
        uint256 newAllowance = token.allowance(address(this), spender) + value;
        _callOptionalReturn(
            token,
            abi.encodeWithSelector(
                token.approve.selector,
                spender,
                newAllowance
            )
        );
    }

    function safeDecreaseAllowance(
        IERC20 token,
        address spender,
        uint256 value
    ) internal {
        unchecked {
            uint256 oldAllowance = token.allowance(address(this), spender);
            require(
                oldAllowance >= value,
                "SafeERC20: decreased allowance below zero"
            );
            uint256 newAllowance = oldAllowance - value;
            _callOptionalReturn(
                token,
                abi.encodeWithSelector(
                    token.approve.selector,
                    spender,
                    newAllowance
                )
            );
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

        bytes memory returndata = address(token).functionCall(
            data,
            "SafeERC20: low-level call failed"
        );
        if (returndata.length > 0) {
            // Return data is optional
            require(
                abi.decode(returndata, (bool)),
                "SafeERC20: ERC20 operation did not succeed"
            );
        }
    }
}

interface IUniswapV2Router01 {
    function factory() external pure returns (address);

    function WETH() external pure returns (address);

    function addLiquidityETH(
        address token,
        uint256 amountTokenDesired,
        uint256 amountTokenMin,
        uint256 amountETHMin,
        address to,
        uint256 deadline
    )
        external
        payable
        returns (
            uint256 amountToken,
            uint256 amountETH,
            uint256 liquidity
        );

    function addLiquidity(
        address tokenA,
        address tokenB,
        uint256 amountADesired,
        uint256 amountBDesired,
        uint256 amountAMin,
        uint256 amountBMin,
        address to,
        uint256 deadline
    )
        external
        returns (
            uint256 amountA,
            uint256 amountB,
            uint256 liquidity
        );
}

interface IUniswapV2Factory {
    function getPair(address token0, address token1)
        external
        view
        returns (address pair);
}

interface IMasterChef {
    function userInfo(uint256 poolId, address user)
        external
        view
        returns (uint256 amount, uint256 rewardDept);
}

interface IAutoVault {
    function userInfo(address user)
        external
        view
        returns (
            uint256 shares,
            uint256 lastDepositTime,
            uint256 balanceAtLastAction,
            uint256 lastActionTime
        );
}

interface IWETH {
    function balanceOf(address _user) external view returns (uint256 balance);

    function deposit() external payable;

    function transfer(address to, uint256 value) external returns (bool);

    function withdraw(uint256) external;

    function approve(address spender, uint256 amount) external returns (bool);
}

contract PresaleSupportOtherToken is Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;
    using SafeMath for uint256;
    mapping(uint256 => uint256) public minContributeRate;
    mapping(uint256 => uint256) public maxContributeRate;
    mapping(uint256 => address) presaleTokens;
    mapping(uint256 => uint256) public startTime;
    mapping(uint256 => uint256) public tier1Time;
    mapping(uint256 => uint256) public tier2Time;
    mapping(uint256 => uint256) public endTime;
    mapping(uint256 => uint256) public presaleEndTime;
    mapping(uint256 => uint256) public liquidityLockTime;
    mapping(address => bool) public routers;
    mapping(uint256 => address) public routerId;
    mapping(uint256 => uint256) defaultRouterRate;
    mapping(uint256 => uint256) routerRate;
    mapping(uint256 => uint256) public tier1Rate;
    mapping(uint256 => uint256) public tier2Rate;
    mapping(uint256 => uint256) public liquidityRate;
    mapping(uint256 => uint256) public publicRate;
    mapping(uint256 => uint256) public softCap;
    mapping(uint256 => uint256) public hardCap;
    mapping(uint256 => bool) public isGold;
    mapping(uint256 => mapping(address => uint256)) userContribution;
    mapping(uint256 => mapping(address => bool)) public whitelist1;
    mapping(uint256 => mapping(address => bool)) public whitelist2;
    mapping(address => bool) public basewhitelist;
    mapping(uint256 => bool) public iswhitelist;
    mapping(uint256 => bool) public iswhitelist1;
    mapping(uint256 => bool) public iswhitelist2;
    mapping(uint256 => mapping(address => uint256)) public userContributionBNB;
    mapping(uint256 => uint256) public totalContributionBNB;
    mapping(uint256 => uint256) public totalContributionToken;
    mapping(uint256 => mapping(address => uint256))
        public userContributionToken;
    mapping(uint256 => mapping(address => uint256)) public userClaimedToken;
    mapping(uint256 => bool) public isVestingToken;
    mapping(uint256 => uint256) public firstVestingAmount;
    mapping(uint256 => uint256) public vestingPeriods;
    mapping(uint256 => uint256) public vestingPercents;
    mapping(uint256 => bool) public ifCollectOtherToken;
    mapping(uint256 => address) public collectOtherToken;
    mapping(uint256 => bool) public withdrawFlag;
    mapping(uint256 => bool) public presaleStatus;
    mapping(uint256 => address) presaleOwner;
    mapping(uint256 => mapping(address => uint256)) liquidityAmount;
    mapping(uint256 => bool) public isDeposited;
    mapping(uint256 => mapping(address => bool)) public isClaimed;
    mapping(uint256 => bool) public isClosed;
    mapping(address => uint256[]) outsideContribution;
    mapping(uint256 => mapping(address => bool)) balanceContribute;
    uint256 public outsideContributionBalance;
    address payable public feeWallet;
    address payable public raiseFeeWallet;
    address payable public raiseFeeWalletForToken;
    address public defaultRouter;
    uint256 public currentFee;
    uint256 public performanceFee = 175; //1.75% of BNB raised
    uint256 public performanceFeeForToken = 0; //0% of token sold
    uint256 public whitelistFee;
    uint256 public currentPresaleId;
    uint256 public outsideContributionCount = 5;
    uint256 public contributionPeriod = 60 * 60 * 24 * 30; // 1 month
    uint256 public maxPresaleLength = 60 * 60 * 24 * 30; // 30 days
    uint256 public minLiquidityLock = 60 * 60 * 24 * 90; // 3 months
    address public masterChef;
    address public autoVault;
    address public withdrawTxWallet;
    IERC20 sphynxToken;
    mapping(address => bool) signers;
    mapping(uint256 => address) signersArray;
    mapping(address => mapping(address => bool)) withdrawTxWalletSign;
    modifier onlySigner() {
        require(signers[msg.sender], "not-a-signer");
        _;
    }

    // events
    event SaleCreated(
        uint256 saleId,
        uint256 startTime,
        uint256 endTime,
        address token
    );

    event SaleClosed(uint256 saleId);

    constructor(uint256 _fee, address _sphynx) {
        currentFee = _fee;
        feeWallet = payable(msg.sender);
        raiseFeeWallet = payable(msg.sender);
        raiseFeeWalletForToken = payable(msg.sender);
        sphynxToken = IERC20(_sphynx);

        //multi-sign-wallets
        signers[0x35BfE8dA53F94d6711F111790643D2D403992b56] = true;
        signers[0x96C463B615228981A2c30B842E8A8e4e933CEc46] = true;
        signers[0x7278fC9C49A2B6bd072b9d47E3c903ef0e12bb83] = true;
        signersArray[0] = 0x35BfE8dA53F94d6711F111790643D2D403992b56;
        signersArray[1] = 0x96C463B615228981A2c30B842E8A8e4e933CEc46;
        signersArray[2] = 0x7278fC9C49A2B6bd072b9d47E3c903ef0e12bb83;
    }

    function updateSignerWallet(address _signer) external onlySigner {
        signers[msg.sender] = false;
        signers[_signer] = true;
        for (uint256 i = 0; i < 3; i++) {
            if (signersArray[i] == msg.sender) {
                signersArray[i] = _signer;
            }
        }
    }

    function updateSphynx(address _sphynx) external onlyOwner {
        sphynxToken = IERC20(_sphynx);
    }

    function updateFeeWallet(address _feewallet) external onlyOwner {
        feeWallet = payable(_feewallet);
    }

    function updateRaiseFeeWallet(address _raiseFeeWallet) external onlyOwner {
        raiseFeeWallet = payable(_raiseFeeWallet);
    }

    function updateRaiseFeeWalletToken(address _raiseFeeWalletForToken)
        external
        onlyOwner
    {
        raiseFeeWalletForToken = payable(_raiseFeeWalletForToken);
    }

    function setStaticFee(uint256 _fee) external onlyOwner {
        currentFee = _fee;
    }

    function updatePerformanceFee(uint256 _performanceFee) external onlyOwner {
        performanceFee = _performanceFee;
    }

    function updatePerformanceFeeToken(uint256 _performanceFeeForToken)
        external
        onlyOwner
    {
        performanceFeeForToken = _performanceFeeForToken;
    }

    function updatewhitelistFee(uint256 _whitelistFee) external onlyOwner {
        whitelistFee = _whitelistFee;
    }

    function updateBasewhitelist(address[] memory _whitelists, bool _value)
        external
        onlyOwner
    {
        for (uint256 i = 0; i < _whitelists.length; i++) {
            address _whitelist = _whitelists[i];
            basewhitelist[_whitelist] = _value;
        }
    }

    function updateMaxPresaleLength(uint256 _value) external onlyOwner {
        maxPresaleLength = _value;
    }

    function updateMinLiquidityLock(uint256 _value) external onlyOwner {
        minLiquidityLock = _value;
    }

    function updateMasterChef(address _masterChef) external onlyOwner {
        masterChef = _masterChef;
    }

    function updateAutoVault(address _autoVault) external onlyOwner {
        autoVault = _autoVault;
    }

    function updateOutsideContributionCount(uint256 _count) external onlyOwner {
        outsideContributionCount = _count;
    }

    function updateContributionPeriod(uint256 _period) external onlyOwner {
        contributionPeriod = _period;
    }

    function enablewhitelist(uint256 _saleId, bool value) external payable {
        require(presaleOwner[_saleId] == msg.sender, "not-presale-owner");
        require(msg.value >= whitelistFee || value == false, "fee-not-enough");
        iswhitelist[_saleId] = value;
    }

    function updatewhitelist(
        uint256 _saleId,
        address[] memory _whitelists,
        uint256 _class
    ) external {
        require(presaleOwner[_saleId] == msg.sender, "not-presale-owner");
        require(iswhitelist[_saleId], "whitelist-not-enabled");
        if (_class == 1) {
            iswhitelist1[_saleId] = true;
            for (uint256 i = 0; i < _whitelists.length; i++) {
                address _whitelist = _whitelists[i];
                whitelist1[_saleId][_whitelist] = true;
            }
        } else if (_class == 2) {
            iswhitelist2[_saleId] = true;
            for (uint256 i = 0; i < _whitelists.length; i++) {
                address _whitelist = _whitelists[i];
                whitelist2[_saleId][_whitelist] = true;
            }
        } else {
            for (uint256 i = 0; i < _whitelists.length; i++) {
                address _whitelist = _whitelists[i];
                whitelist1[_saleId][_whitelist] = false;
                whitelist2[_saleId][_whitelist] = false;
            }
        }
    }

    function setOutsideContributionBalance(uint256 _balance)
        external
        onlyOwner
    {
        outsideContributionBalance = _balance;
    }

    struct PresaleInfo {
        uint256 saleId;
        address token;
        uint256 minContributeRate;
        uint256 maxContributeRate;
        uint256 startTime;
        uint256 tier1Time;
        uint256 tier2Time;
        uint256 endTime;
        uint256 liquidityLockTime;
        address routerId;
        uint256 tier1Rate;
        uint256 tier2Rate;
        uint256 publicRate;
        uint256 liquidityRate;
        uint256 softCap;
        uint256 hardCap;
        uint256 defaultRouterRate;
        uint256 routerRate;
        bool isGold;
        bool isVesting;
        uint256 firstReleaseAmount;
        uint256 vestingCyclePeriods;
        uint256 vestingCyclePercents;
        bool ifCollectOtherToken;
        address otherToken;
    }

    function createPresale(PresaleInfo calldata pInfo)
        external
        payable
        nonReentrant
    {
        require(pInfo.saleId == currentPresaleId, "presale-already-exist");
        require(routers[pInfo.routerId], "not-router-address");
        require(msg.value >= currentFee, "not-enough-fee");
        require(
            pInfo.startTime <= pInfo.tier1Time &&
                pInfo.tier1Time <= pInfo.tier2Time &&
                pInfo.tier2Time <= pInfo.endTime,
            "time-incorrect"
        );
        require(
            pInfo.endTime.sub(pInfo.startTime) <= maxPresaleLength,
            "presale-length-reach-limit"
        );
        require(
            pInfo.liquidityLockTime.sub(pInfo.endTime) >= minLiquidityLock,
            "liquidity-lock-time-limit"
        );
        require(pInfo.tier1Rate >= pInfo.tier2Rate, "tier1-rate");
        require(pInfo.tier2Rate >= pInfo.publicRate, "tier2-rate");
        require(pInfo.firstReleaseAmount <= 10000, "over-max-amount");
        presaleTokens[currentPresaleId] = pInfo.token;
        minContributeRate[currentPresaleId] = pInfo.minContributeRate;
        maxContributeRate[currentPresaleId] = pInfo.maxContributeRate;
        startTime[currentPresaleId] = pInfo.startTime;
        tier1Time[currentPresaleId] = pInfo.tier1Time;
        tier2Time[currentPresaleId] = pInfo.tier2Time;
        endTime[currentPresaleId] = pInfo.endTime;
        liquidityLockTime[currentPresaleId] = pInfo.liquidityLockTime;
        routerId[currentPresaleId] = pInfo.routerId;
        tier1Rate[currentPresaleId] = pInfo.tier1Rate;
        tier2Rate[currentPresaleId] = pInfo.tier2Rate;
        publicRate[currentPresaleId] = pInfo.publicRate;
        liquidityRate[currentPresaleId] = pInfo.liquidityRate;
        softCap[currentPresaleId] = pInfo.softCap;
        hardCap[currentPresaleId] = pInfo.hardCap;
        presaleOwner[currentPresaleId] = msg.sender;
        defaultRouterRate[currentPresaleId] = pInfo.defaultRouterRate;
        routerRate[currentPresaleId] = pInfo.routerRate;
        isGold[currentPresaleId] = pInfo.isGold;
        isVestingToken[currentPresaleId] = pInfo.isVesting;
        firstVestingAmount[currentPresaleId] = pInfo.firstReleaseAmount;
        vestingPeriods[currentPresaleId] = pInfo.vestingCyclePeriods;
        vestingPercents[currentPresaleId] = pInfo.vestingCyclePercents;
        ifCollectOtherToken[currentPresaleId] = pInfo.ifCollectOtherToken;
        collectOtherToken[currentPresaleId] = pInfo.otherToken;
        emit SaleCreated(
            currentPresaleId,
            pInfo.startTime,
            pInfo.endTime,
            pInfo.token
        );
        currentPresaleId = currentPresaleId.add(1);
        feeWallet.transfer(currentFee);
    }

    function closePresale(uint256 _saleId) external {
        require(presaleOwner[_saleId] == msg.sender, "not-presale-owenr");
        require(block.timestamp <= startTime[_saleId], "presale-active");
        require(isClosed[_saleId], "already-closed");
        if (isDeposited[_saleId]) {
            uint256 _amount = getDepositAmount(_saleId);
            IERC20(presaleTokens[_saleId]).safeTransfer(msg.sender, _amount);
        }

        isClosed[_saleId] = true;

        emit SaleClosed(_saleId);
    }

    function getDepositAmount(uint256 _saleId)
        public
        view
        returns (uint256 amount)
    {
        uint256 _hardCap = hardCap[_saleId];
        uint256 _tier1Rate = tier1Rate[_saleId];
        uint256 _routerRate = routerRate[_saleId];
        uint256 _defaultRouterRate = defaultRouterRate[_saleId];
        uint256 _liquidityRate = liquidityRate[_saleId];
        amount = _hardCap.mul(_tier1Rate);
        uint256 _routerAmount = _hardCap
            .mul(_routerRate.add(_defaultRouterRate))
            .mul(_liquidityRate)
            .div(100);
        amount = amount.add(_routerAmount);
        if (!ifCollectOtherToken[_saleId]) {
            amount = amount.mul(10000 + performanceFeeForToken).div(10000).div(
                10**18
            );
        } else {
            uint256 decimals = IERC20(collectOtherToken[_saleId]).decimals();
            amount = amount.mul(10000 + performanceFeeForToken).div(10000).div(
                10**decimals
            );
        }
    }

    function tier1Sale(uint256 _saleId, uint256 _amount) internal {
        bool _outsideContributionAvailable = basewhitelist[msg.sender] &&
            (outsideContribution[msg.sender].length <=
                outsideContributionCount ||
                block.timestamp.sub(
                    outsideContribution[msg.sender][
                        outsideContribution[msg.sender].length -
                            outsideContributionCount
                    ]
                ) >=
                contributionPeriod);
        require(
            whitelist1[_saleId][msg.sender] == true ||
                (outsideContributionBalance != 0 &&
                    sphynxToken.balanceOf(msg.sender).add(getStakedAmount()) >=
                    outsideContributionBalance &&
                    balanceContribute[_saleId][msg.sender] == false &&
                    isGold[_saleId]) ||
                _outsideContributionAvailable,
            "permission-denied"
        );
        if (!whitelist1[_saleId][msg.sender]) {
            balanceContribute[_saleId][msg.sender] = true;
        }
        uint256 rate = tier1Rate[_saleId];
        if (!ifCollectOtherToken[_saleId]) {
            userContributionToken[_saleId][msg.sender] += rate
                .mul(msg.value)
                .div(10**18);
            totalContributionToken[_saleId] += rate.mul(msg.value).div(10**18);
        } else {
            uint256 decimals = IERC20(collectOtherToken[_saleId]).decimals();
            userContributionToken[_saleId][msg.sender] += rate.mul(_amount).div(
                10**decimals
            );
            totalContributionToken[_saleId] += rate.mul(_amount).div(
                10**decimals
            );
        }
    }

    function tier2Sale(uint256 _saleId, uint256 _amount) internal {
        bool _balanceContributionAvailable = sphynxToken
            .balanceOf(msg.sender)
            .add(getStakedAmount()) >=
            outsideContributionBalance &&
            !balanceContribute[_saleId][msg.sender] &&
            isGold[_saleId] &&
            outsideContributionBalance != 0;
        bool _outsideContributionAvailable = basewhitelist[msg.sender] &&
            (outsideContribution[msg.sender].length <=
                outsideContributionCount ||
                block.timestamp.sub(
                    outsideContribution[msg.sender][
                        outsideContribution[msg.sender].length -
                            outsideContributionCount
                    ]
                ) >=
                contributionPeriod);
        require(
            whitelist2[_saleId][msg.sender] == true ||
                _balanceContributionAvailable ||
                _outsideContributionAvailable,
            "permission-denied"
        );
        if (!whitelist2[_saleId][msg.sender]) {
            if (_balanceContributionAvailable) {
                balanceContribute[_saleId][msg.sender] = true;
            } else {
                outsideContribution[msg.sender].push(block.timestamp);
            }
        }
        uint256 rate = tier2Rate[_saleId];
        if (!ifCollectOtherToken[_saleId]) {
            userContributionToken[_saleId][msg.sender] += rate
                .mul(msg.value)
                .div(10**18);
            totalContributionToken[_saleId] += rate.mul(msg.value).div(10**18);
        } else {
            uint256 decimals = IERC20(collectOtherToken[_saleId]).decimals();
            userContributionToken[_saleId][msg.sender] += rate.mul(_amount).div(
                10**decimals
            );
            totalContributionToken[_saleId] += rate.mul(_amount).div(
                10**decimals
            );
        }
    }

    function publicSale(uint256 _saleId, uint256 _amount) internal {
        uint256 rate = publicRate[_saleId];
        if (!ifCollectOtherToken[_saleId]) {
            userContributionToken[_saleId][msg.sender] += rate
                .mul(msg.value)
                .div(10**18);
            totalContributionToken[_saleId] += rate.mul(msg.value).div(10**18);
        } else {
            uint256 decimals = IERC20(collectOtherToken[_saleId]).decimals();
            userContributionToken[_saleId][msg.sender] += rate.mul(_amount).div(
                10**decimals
            );
            totalContributionToken[_saleId] += rate.mul(_amount).div(
                10**decimals
            );
        }
    }

    function getStakedAmount() internal view returns (uint256 amount) {
        if (masterChef != address(0)) {
            (amount, ) = IMasterChef(masterChef).userInfo(0, msg.sender);
        }
        if (autoVault != address(0)) {
            (uint256 _vaultAmount, , , ) = IAutoVault(autoVault).userInfo(
                msg.sender
            );
            amount = amount.add(_vaultAmount);
        }
    }

    function contribute(uint256 _saleId, uint256 _amount)
        external
        payable
        nonReentrant
    {
        require(presaleTokens[_saleId] != address(0), "presale-not-exist");
        require(!isClosed[_saleId], "presale-canceled");
        require(isDeposited[_saleId], "token-not-deposited-yet");
        require(
            block.timestamp >= startTime[_saleId] &&
                block.timestamp <= endTime[_saleId],
            "presale-not-active"
        );
        if (!ifCollectOtherToken[_saleId]) {
            require(msg.value == _amount, "not-equal-contribution-amount");
        } else {
            IERC20 contributeToken = IERC20(collectOtherToken[_saleId]);
            contributeToken.safeTransferFrom(
                msg.sender,
                address(this),
                _amount
            );
        }
        userContributionBNB[_saleId][msg.sender] += _amount;
        totalContributionBNB[_saleId] += _amount;
        require(
            userContributionBNB[_saleId][msg.sender] <=
                maxContributeRate[_saleId],
            "over-max-contrubution-amount"
        );
        require(
            userContributionBNB[_saleId][msg.sender] >=
                minContributeRate[_saleId],
            "less-than-min-contrubution-amount"
        );
        require(
            totalContributionBNB[_saleId] <= hardCap[_saleId],
            "over-hardcap-amount"
        );
        if (iswhitelist[_saleId]) {
            if (block.timestamp < tier1Time[_saleId]) {
                tier1Sale(_saleId, _amount);
            } else if (
                tier1Time[_saleId] <= block.timestamp &&
                block.timestamp <= tier2Time[_saleId]
            ) {
                tier2Sale(_saleId, _amount);
            } else {
                publicSale(_saleId, _amount);
            }
        } else {
            publicSale(_saleId, _amount);
        }
    }

    function getAvailableAmount(uint256 _saleId, address _contributor)
        public
        view
        returns (uint256 availableAmount)
    {
        if (isVestingToken[_saleId]) {
            uint256 periodsPercent = block
                .timestamp
                .sub(presaleEndTime[_saleId])
                .div(vestingPeriods[_saleId])
                .mul(vestingPercents[_saleId]);
            uint256 availablePercent = firstVestingAmount[_saleId].add(
                periodsPercent
            );
            if (availablePercent > 10000) {
                availableAmount = userContributionToken[_saleId][_contributor];
            } else {
                availableAmount = userContributionToken[_saleId][_contributor]
                    .mul(availablePercent)
                    .div(10000);
            }
        } else {
            availableAmount = userContributionToken[_saleId][_contributor];
        }
    }

    function claimToken(uint256 _saleId) external payable nonReentrant {
        require(
            presaleStatus[_saleId] ||
                ((endTime[_saleId] < block.timestamp) &&
                    (totalContributionBNB[_saleId] <= softCap[_saleId])),
            "presale-not-end"
        );
        require(
            userContributionBNB[_saleId][msg.sender] > 0,
            "did-not-contribute-this-presale"
        );
        require(!isClaimed[_saleId][msg.sender], "already-claimed");
        address _token = presaleTokens[_saleId];
        bool isSuccess = totalContributionBNB[_saleId] >= softCap[_saleId];
        IERC20 token = IERC20(_token);
        if (isSuccess) {
            require(presaleStatus[_saleId], "not-finalized-yet");
            uint256 availableAmount = getAvailableAmount(_saleId, msg.sender);
            uint256 transferAmount = availableAmount.sub(
                userClaimedToken[_saleId][msg.sender]
            );
            require(transferAmount > 0, "no-token-to-claim");
            token.safeTransfer(msg.sender, transferAmount);
            userClaimedToken[_saleId][msg.sender] = availableAmount;
        } else {
            address payable msgSender = payable(msg.sender);
            if (!ifCollectOtherToken[_saleId]) {
                msgSender.transfer(userContributionBNB[_saleId][msg.sender]);
            } else {
                IERC20 collectTokenContract = IERC20(
                    collectOtherToken[_saleId]
                );
                collectTokenContract.safeTransfer(
                    msg.sender,
                    userContributionBNB[_saleId][msg.sender]
                );
            }
            isClaimed[_saleId][msg.sender] = true;
            userContributionBNB[_saleId][msg.sender] = 0;
            userContributionToken[_saleId][msg.sender] = 0;
        }
    }

    function depositToken(uint256 _saleId) external {
        require(presaleOwner[_saleId] == msg.sender, "not-presale-owner");
        require(!isClosed[_saleId], "presale-canceled");
        address _token = presaleTokens[_saleId];
        IERC20 token = IERC20(_token);
        uint256 requiredAmount = getDepositAmount(_saleId);
        uint256 originBalance = token.balanceOf(address(this));
        token.safeTransferFrom(msg.sender, address(this), requiredAmount);
        uint256 balance = token.balanceOf(address(this));
        require(
            balance.sub(originBalance) == requiredAmount,
            "amount-not-equal"
        );
        isDeposited[_saleId] = true;
    }

    function _liquidityAdd(
        IERC20 token,
        address routerAddr,
        bool isDefault,
        uint256 routerBNB,
        uint256 defaultRouterBNB,
        uint256 _tokenFeeAmount,
        uint256 _saleId
    ) internal {
        uint256 routerTokenAmount = liquidityRate[_saleId].mul(routerBNB).div(
            10**18
        );
        uint256 defaultRouterTokenAmount = liquidityRate[_saleId]
            .mul(defaultRouterBNB)
            .div(10**18);
        if (routerBNB != 0) {
            token.approve(routerAddr, routerTokenAmount);
            IUniswapV2Router01 router = IUniswapV2Router01(routerAddr);
            uint256 deadline = block.timestamp.add(20 * 60);
            if (!ifCollectOtherToken[_saleId]) {
                IWETH(router.WETH()).deposit{value: routerBNB}();
                IWETH(router.WETH()).approve(routerAddr, routerBNB);
                (, , uint256 liquidity) = router.addLiquidity(
                    router.WETH(),
                    address(token),
                    routerBNB,
                    routerTokenAmount,
                    0,
                    0,
                    address(this),
                    deadline
                );
                liquidityAmount[_saleId][routerAddr] = liquidity;
            } else {
                IERC20 collectedToken = IERC20(collectOtherToken[_saleId]);
                collectedToken.approve(routerAddr, routerBNB);
                (, , uint256 liquidity) = router.addLiquidity(
                    collectOtherToken[_saleId],
                    address(token),
                    routerBNB,
                    routerTokenAmount,
                    0,
                    0,
                    address(this),
                    deadline
                );
                liquidityAmount[_saleId][routerAddr] = liquidity;
            }
        }
        if (defaultRouterBNB != 0) {
            token.approve(defaultRouter, defaultRouterTokenAmount);
            IUniswapV2Router01 router1 = IUniswapV2Router01(defaultRouter);
            uint256 deadline = block.timestamp.add(20 * 60);
            if (!ifCollectOtherToken[_saleId]) {
                IWETH(router1.WETH()).deposit{value: defaultRouterBNB}();
                IWETH(router1.WETH()).approve(defaultRouter, defaultRouterBNB);
                (, , uint256 liquidity) = router1.addLiquidity(
                    router1.WETH(),
                    address(token),
                    defaultRouterBNB,
                    defaultRouterTokenAmount,
                    0,
                    0,
                    address(this),
                    deadline
                );
                liquidityAmount[_saleId][defaultRouter] = liquidity;
            } else {
                IERC20 collectedToken = IERC20(collectOtherToken[_saleId]);
                collectedToken.approve(defaultRouter, defaultRouterBNB);
                (, , uint256 liquidity) = router1.addLiquidity(
                    collectOtherToken[_saleId],
                    address(token),
                    defaultRouterBNB,
                    defaultRouterTokenAmount,
                    0,
                    0,
                    address(this),
                    deadline
                );
                liquidityAmount[_saleId][defaultRouter] = liquidity;
            }
        }

        uint256 tokenAmount = getDepositAmount(_saleId)
            .sub(routerTokenAmount)
            .sub(defaultRouterTokenAmount)
            .sub(totalContributionToken[_saleId])
            .sub(_tokenFeeAmount);
        token.safeTransfer(msg.sender, tokenAmount);
    }

    function addLiquidity(
        uint256 realAmount,
        uint256 _saleId,
        uint256 _tokenFeeAmount
    ) internal {
        address _token = presaleTokens[_saleId];
        address routerAddr = routerId[_saleId];
        bool isDefaultRouter = defaultRouter == address(0) ||
            defaultRouter == routerAddr;
        uint256 realRate = routerRate[_saleId];
        uint256 routerBNB = realAmount.mul(realRate).div(100);
        uint256 defaultRouterBNB = realAmount
            .mul(defaultRouterRate[_saleId])
            .div(100);
        uint256 remainAmount = realAmount.sub(routerBNB).sub(defaultRouterBNB);
        _liquidityAdd(
            IERC20(_token),
            routerAddr,
            isDefaultRouter,
            routerBNB,
            defaultRouterBNB,
            _tokenFeeAmount,
            _saleId
        );
        address payable msgSender = payable(msg.sender);
        if (!ifCollectOtherToken[_saleId]) {
            msgSender.transfer(remainAmount);
        } else {
            IERC20 collectToken = IERC20(collectOtherToken[_saleId]);
            collectToken.safeTransfer(msgSender, remainAmount);
        }
    }

    function withdrawLiquidity(uint256 _saleId) external nonReentrant {
        require(presaleOwner[_saleId] == msg.sender, "not-presale-owner");
        require(
            block.timestamp > liquidityLockTime[_saleId],
            "liquidity-locked"
        );
        require(!withdrawFlag[_saleId], "already-withdraw");
        address routerAddr = routerId[_saleId];
        address _token = presaleTokens[_saleId];
        IUniswapV2Router01 router = IUniswapV2Router01(routerAddr);
        address wrappedToken = router.WETH();
        IUniswapV2Factory factory = IUniswapV2Factory(router.factory());
        IERC20 pair = IERC20(factory.getPair(_token, wrappedToken));
        pair.safeTransfer(msg.sender, liquidityAmount[_saleId][routerAddr]);
        if (
            liquidityAmount[_saleId][defaultRouter] != 0 &&
            routerAddr != defaultRouter
        ) {
            IUniswapV2Router01 router1 = IUniswapV2Router01(defaultRouter);
            IUniswapV2Factory factory1 = IUniswapV2Factory(router1.factory());
            IERC20 pair1 = IERC20(factory1.getPair(_token, wrappedToken));
            pair1.safeTransfer(
                msg.sender,
                liquidityAmount[_saleId][defaultRouter]
            );
        }
        withdrawFlag[_saleId] = true;
    }

    function emergencyWithdraw(uint256 _saleId) external payable nonReentrant {
        require(!presaleStatus[_saleId], "presale-already-end");
        address payable msgSender = payable(msg.sender);
        uint256 _bnbAmount = userContributionBNB[_saleId][msg.sender];
        uint256 _tokenAmount = userContributionToken[_saleId][msg.sender];
        if (!ifCollectOtherToken[_saleId]) {
            msgSender.transfer(_bnbAmount);
        } else {
            IERC20 collectTokenContract = IERC20(collectOtherToken[_saleId]);
            collectTokenContract.safeTransfer(msg.sender, _bnbAmount);
        }
        userContributionBNB[_saleId][msg.sender] = 0;
        userContributionToken[_saleId][msg.sender] = 0;
        totalContributionBNB[_saleId] = totalContributionBNB[_saleId].sub(
            _bnbAmount
        );
        totalContributionToken[_saleId] = totalContributionToken[_saleId].sub(
            _tokenAmount
        );
    }

    function finalize(uint256 _saleId) external nonReentrant {
        require(presaleOwner[_saleId] == msg.sender, "not-presale-owner");
        require(!isClosed[_saleId], "presale-canceled");
        require(
            endTime[_saleId] <= block.timestamp ||
                (hardCap[_saleId].sub(minContributeRate[_saleId]) <=
                    totalContributionBNB[_saleId]),
            "presale-active"
        );
        require(!presaleStatus[_saleId], "already-finilize");
        presaleStatus[_saleId] = true;
        bool isSuccess = totalContributionBNB[_saleId] >= softCap[_saleId];
        presaleEndTime[_saleId] = block.timestamp;
        if (isSuccess) {
            uint256 fee = totalContributionBNB[_saleId].mul(performanceFee).div(
                10000
            );
            if (!ifCollectOtherToken[_saleId]) {
                raiseFeeWallet.transfer(fee);
            } else {
                IERC20 collectTokenContract = IERC20(
                    collectOtherToken[_saleId]
                );
                collectTokenContract.safeTransfer(raiseFeeWallet, fee);
            }
            uint256 realAmount = totalContributionBNB[_saleId].sub(fee);
            address _token = presaleTokens[_saleId];
            IERC20 token = IERC20(_token);
            uint256 tokenFee = totalContributionToken[_saleId]
                .mul(performanceFeeForToken)
                .div(10000);
            if (tokenFee > 0) {
                uint256 originalBalance = token.balanceOf(
                    raiseFeeWalletForToken
                );
                token.safeTransfer(raiseFeeWalletForToken, tokenFee);
                uint256 currentBalance = token.balanceOf(
                    raiseFeeWalletForToken
                );
                require(
                    originalBalance + tokenFee == currentBalance,
                    "should-exclude-fee"
                );
            }
            addLiquidity(realAmount, _saleId, tokenFee);
        } else {
            uint256 tokenAmount = getDepositAmount(_saleId);
            address _token = presaleTokens[_saleId];
            IERC20 token = IERC20(_token);
            token.safeTransfer(msg.sender, tokenAmount);
        }
    }

    function addRouter(address _newRouter) external onlyOwner {
        routers[_newRouter] = true;
    }

    function setDefaultRouter(address _defaultRouter) external onlyOwner {
        defaultRouter = _defaultRouter;
    }

    function updateWithdrawTxWallet(address _value) external onlySigner {
        require(withdrawTxWallet != _value, "already-set");
        require(withdrawTxWalletSign[msg.sender][withdrawTxWallet], "already-sign");
        withdrawTxWalletSign[msg.sender][withdrawTxWallet] = true;
        if (
            withdrawTxWalletSign[signersArray[0]][withdrawTxWallet] &&
            withdrawTxWalletSign[signersArray[1]][withdrawTxWallet] &&
            withdrawTxWalletSign[signersArray[2]][withdrawTxWallet]
        ) {
            withdrawTxWallet = _value;
            withdrawTxWalletSign[signersArray[0]][withdrawTxWallet] = false;
            withdrawTxWalletSign[signersArray[1]][withdrawTxWallet] = false;
            withdrawTxWalletSign[signersArray[2]][withdrawTxWallet] = false;
        }
    }

    function emergencyWithdrawNativeToken(uint256 _balance) external onlySigner {
        require(msg.sender == withdrawTxWallet, "not-withdraw-wallet");
        address payable msgSender = payable(msg.sender);
        msgSender.transfer(_balance);
        withdrawTxWallet = address(0);
    }

    function emergencyWithdrawToken(address _token, uint256 _amount) external onlyOwner {
        require(msg.sender == withdrawTxWallet, "not-withdraw-wallet");
        IERC20 token = IERC20(_token);
        token.safeTransfer(msg.sender, _amount);
        withdrawTxWallet = address(0);
    }
}