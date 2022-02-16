// SPDX-License-Identifier: MIT
pragma solidity 0.8.2;

import "./interfaces/IStakBank.sol";
import "./interfaces/IStoreStakingUsers.sol";
import "./interfaces/IJSTAK.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/math/MathUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

contract PolygonStakBank is
    ReentrancyGuardUpgradeable,
    PausableUpgradeable,
    OwnableUpgradeable
{
    using SafeERC20Upgradeable for IERC20Upgradeable;

    // -----------------------------------------
    // STATE VARIABLES
    // -----------------------------------------

    // Token being disitributed
    IERC20Upgradeable public rewardToken;

    // Token being staked
    IERC20Upgradeable public stakingToken;

    // JStak token address
    IJSTAK public jStak;

    // Staking Users
    IStoreStakingUsers public storeStakingUsers;

    // Address of factory contract
    address public factory;

    // Name of POOL
    string public name;

    // Timestamp when pool finish
    uint256 public periodFinish;

    // Distribution per second of tokens rate
    uint256 public rewardRate;

    // Last timestamp pool was updated
    uint256 public lastUpdateTime;

    // Amount of reward per token staked
    uint256 public rewardPerTokenStored;

    // Amount of tokens being distributed
    uint256 public totalReward;

    // Amount of tokens staked
    uint256 private _totalSupply;

    // time staking
    uint256 private _currentStakingTime;

    // User struct to store rewards
    struct UserInfo {
        uint256 rewards;
        uint256 userRewardPerTokenPaid;
        uint256 baseDate;
    }

    // User reward mapping
    mapping(address => UserInfo) public userInfo;

    // User stakes mapping
    mapping(address => uint256) private _balances;

    // -----------------------------------------
    // EVENTS
    // -----------------------------------------

    event PoolCreated(string name, address stakingToken, address rewardToken);
    event RewardAdded(uint256 reward);
    event Staked(address indexed user, uint256 amount);
    event Withdrawn(address indexed user, uint256 amount);
    event Composed(address indexed user, uint256 reward, uint256 jStakReward);
    event RewardPaid(address indexed user, uint256 reward, uint256 jStakReward);

    // -----------------------------------------
    // MODIFIER
    // -----------------------------------------

    /**
     * @notice Update user rewards when call mutative functions
     * @param _account Address to update user rewards
     */
    modifier updateReward(address _account) {
        rewardPerTokenStored = rewardPerToken();
        lastUpdateTime = lastTimeRewardApplicable();
        if (_account != address(0)) {
            userInfo[_account].rewards = earned(_account);
            userInfo[_account].userRewardPerTokenPaid = rewardPerTokenStored;
        }
        _;
    }

    // -----------------------------------------
    // CONSTRUCTOR
    // -----------------------------------------
    // constructor() {
    //     factory = _msgSender();
    // }

    /**
     * @param _name Name of POOL
     * @param _stakingToken Address of the token being staked
     * @param _rewardToken Address of the token being disitributed
     */
    function initialize(
        string calldata _name,
        IERC20Upgradeable _stakingToken,
        IERC20Upgradeable _rewardToken,
        IJSTAK _jStak
   //     IStoreStakingUsers _storeStakingUsers
    ) public initializer {
      //   require(_msgSender() == factory, "STAKBANK::UNAUTHORIZED");

        __Ownable_init();

        name = _name;
        stakingToken = _stakingToken;
        rewardToken = _rewardToken;
        jStak = _jStak;
      //  storeStakingUsers = _storeStakingUsers;

        emit PoolCreated(name, address(stakingToken), address(rewardToken));
    }

    // -----------------------------------------
    // VIEWS
    // -----------------------------------------

    /**
     * @notice Returns the last latest timestamp of reward applicable
     * @return Returns blocktimestamp if < periodFinish
     */
    function lastTimeRewardApplicable() public view returns (uint256) {
        return MathUpgradeable.min(block.timestamp, periodFinish);
    }

    /**
     * @notice Retunrs the reward per token staked rate in range of timestamp
     * @return Returns amount of tokens is distributed per token
     */
    function rewardPerToken() public view returns (uint256) {
        if (totalSupply() == 0) {
            return rewardPerTokenStored;
        }
        return
            rewardPerTokenStored +
            (lastTimeRewardApplicable() -
                (lastUpdateTime * rewardRate * 1e18) /
                totalSupply());
    }

    /**
     * @notice Returns the earned tokens of an address
     * @param _account Address to find the amount of tokens
     * @return Returns amount of tokens the user earned
     */
    function earned(address _account) public view returns (uint256) {
        return
            (balanceOf(_account) *
                (rewardPerToken() -
                    userInfo[_account].userRewardPerTokenPaid)) /
            1e18 +
            userInfo[_account].rewards;
    }

    /**
     * @notice Returns the total amount of tokens staked in the contract
     * @return Returns only a fixed number of supply
     */
    function totalSupply() public view returns (uint256) {
        return _totalSupply;
    }

    /**
     * @notice Returns the total amount of tokens of an address staked in the contract
     * @param _account Address to find the amount of tokens
     * @return Returns amount of tokens the user staked
     */
    function balanceOf(address _account) public view returns (uint256) {
        return _balances[_account];
    }

    /**
     * @notice Returns the multiplier of earns of an address
     * @param _account Address to find the multiplier
     * @return Returns the number of multiplier based on timestamp
     */
    function getMultiplier(address _account) public view returns (uint256) {
        uint256 multiplier;
        // get account base date
        uint256 baseDate = userInfo[_account].baseDate;
        // get elapsed seconds
        uint256 secondsElapsed = block.timestamp - baseDate;
        // transform to elaspsed months
        uint256 integerMonthsElapsed = secondsElapsed -
            ((secondsElapsed % (30 days)) / 30 days);

        // here we should match a uint256 month to a uint256 multiplier represented by a percentage
        if (integerMonthsElapsed == 2) {
            multiplier = 110;
        } else if (integerMonthsElapsed == 3) {
            multiplier = 120;
        } else if (integerMonthsElapsed == 4) {
            multiplier = 130;
        } else if (integerMonthsElapsed == 5) {
            multiplier = 140;
        } else if (integerMonthsElapsed == 6) {
            multiplier = 150;
        } else if (integerMonthsElapsed == 7) {
            multiplier = 160;
        } else if (integerMonthsElapsed == 8) {
            multiplier = 170;
        } else if (integerMonthsElapsed == 9) {
            multiplier = 180;
        } else if (integerMonthsElapsed == 10) {
            multiplier = 190;
        } else if (integerMonthsElapsed >= 11) {
            multiplier = 200;
        } else multiplier = 0;

        return multiplier;
    }

    /**
     * @notice Returns the base date of an address
     * @param _account Address to find the base date
     * @return Returns timestamp of base date of an address
     */
    function getBaseDate(address _account) external view returns (uint256) {
        return userInfo[_account].baseDate;
    }

    /**
     * @notice Returns the base date of an address
     * @param _account Address to find the base date
     * @return Returns timestamp of base date of an address
     */
    function getLongevity(address _account) external returns (uint256) {
         string memory msgSender = castAddressToStr(_account);
        return storeStakingUsers.getUsers(msgSender);
    }



    /**
     * @notice Returns the remaining tokens to reward
     * @return eturns amount of remaining tokens to be distributed
     */
    function getRemainingTotalReward() public view returns (uint256) {
        if (periodFinish >= block.timestamp) {
            uint256 remaining = periodFinish - block.timestamp;
            uint256 leftover = remaining * rewardRate;
            return leftover;
        } else {
            return 0;
        }
    }

    // -----------------------------------------
    // MUTATIVE FUNCTIONS
    // -----------------------------------------

    /**
     * @notice User can stake token by this function when available
     * @param _amount Value of tokens in wei involved in the staking
     */
    function stake(uint256 _amount)
        public
        whenNotPaused
        nonReentrant
        updateReward(_msgSender())
    {
        string memory msgSender = castAddressToStr(_msgSender());

        require(_amount > 0, "STAKBANK::EMPTY_AMOUNT");

        _totalSupply = _totalSupply + _amount;
        _balances[_msgSender()] = _balances[_msgSender()] + _amount;
        stakingToken.safeTransferFrom(_msgSender(), address(this), _amount);

            if(storeStakingUsers.getUsers(msgSender) > 0 )
        {
            uint _currStakingTime = storeStakingUsers.getUsers(msgSender);
            userInfo[_msgSender()].baseDate = _currStakingTime;
        }else{

        if (userInfo[_msgSender()].baseDate == 0) {
            
            userInfo[_msgSender()].baseDate = block.timestamp;
        } else {
            updateBaseDate(_amount, _msgSender());
        }

        }
        emit Staked(_msgSender(), _amount);
    }

    /**
     * @notice User can withdraw token by this function when available
     * @param _amount Value of tokens in wei involved in the withdraw
     */
    function withdraw(uint256 _amount)
        public
        whenNotPaused
        nonReentrant
        updateReward(_msgSender())
    {
        require(_amount > 0, "STAKBANK::EMPTY_AMOUNT");
        _totalSupply = _totalSupply - _amount;
        _balances[_msgSender()] = _balances[_msgSender()] - _amount;
        stakingToken.safeTransfer(_msgSender(), _amount);
        // reset user baseDate
        userInfo[_msgSender()].baseDate = block.timestamp;
        emit Withdrawn(_msgSender(), _amount);
    }

    /**
     * @notice User can exit from pool by withdrawing and getting reward by this function when available
     */
    function exit() external {
        withdraw(balanceOf(_msgSender()));
        getReward();
    }

    /**
     * @notice User can compound your tokens into the pool
     */
    function compound()
        public
        whenNotPaused
        nonReentrant
        updateReward(_msgSender())
    {
        uint256 reward = earned(_msgSender());
        uint256 jStakReward = (reward * getMultiplier(_msgSender())) / 100;
        require(reward > 0, "STAKBANK::ZERO_REWARD_AMOUNT");
        userInfo[_msgSender()].rewards = 0;
        _totalSupply = _totalSupply + reward;
        _balances[_msgSender()] = _balances[_msgSender()] + reward;
        jStak.mint(_msgSender(), jStakReward);
        updateBaseDate(reward, _msgSender());

        emit Composed(_msgSender(), reward, jStakReward);
    }

    /**
     * @notice User can get the reward by this function when available
     */
    function getReward()
        public
        whenNotPaused
        nonReentrant
        updateReward(_msgSender())
    {
        uint256 reward = earned(_msgSender());
        if (reward > 0) {
            uint256 jStakReward = (reward * getMultiplier(_msgSender())) / 100;
            userInfo[_msgSender()].rewards = 0;
            rewardToken.safeTransfer(_msgSender(), reward);
            jStak.mint(_msgSender(), jStakReward);
            emit RewardPaid(_msgSender(), reward, jStakReward);
        }
    }

    // -----------------------------------------
    // INTERNAL FUNCTIONS
    // -----------------------------------------

    /**
     * @notice Update the base date of an user
     * @param _amount Address performing the staking
     * @param _account Amount of token in wei involved in the staking
     */
    function updateBaseDate(uint256 _amount, address _account) internal {
        uint256 oldBaseDate = userInfo[_account].baseDate;
        uint256 oldStake = balanceOf(_account);
        // weighted average following: [(oldBaseDate * oldStake) + (now * deposit)]/(oldStake + deposit)
        uint256 newBaseDate = (oldBaseDate * oldStake) +
            (block.timestamp * _amount) /
            (oldStake + _amount);
        userInfo[_account].baseDate = newBaseDate;
    }

    function char(bytes1 b) public pure returns (bytes1 c) {
        if (uint8(b) < 10) return bytes1(uint8(b) + 0x30);
        else return bytes1(uint8(b) + 0x57);
    }

    function castAddressToStr(address acc) public pure returns (string memory) {
        bytes memory s = new bytes(40);
        for (uint256 i = 0; i < 20; i++) {
            bytes1 b = bytes1(
                uint8(uint256(uint160(acc)) / (2**(8 * (19 - i))))
            );
            bytes1 hi = bytes1(uint8(b) / 16);
            bytes1 lo = bytes1(uint8(b) - 16 * uint8(hi));
            s[2 * i] = char(hi);
            s[2 * i + 1] = char(lo);
        }
        return string(abi.encodePacked(acc));
    }

    // -----------------------------------------
    // RESTRICTED FUNCTIONS
    // -----------------------------------------

    /**
     * @notice Owner should call it after deposit the tokens in the contract and set duration.
     * @param _reward Amount of token in wei that will be distributed
     * @param _duration Value in uint256 determine the duration of the pool
     */
    function notifyRewardAmount(uint256 _reward, uint256 _duration)
        external
        onlyOwner
        updateReward(address(0))
    {
        if (block.timestamp >= periodFinish) {
            require(_duration > 0, "LPBANK::INVALID_DURATION");
            rewardRate = _reward / _duration;
            totalReward = _reward;
        } else if (_duration == 0) {
            uint256 remaining = periodFinish - block.timestamp;
            uint256 leftover = remaining * rewardRate;
            rewardRate = (_reward + leftover) / remaining;
            totalReward = totalReward + _reward;
        } else {
            uint256 remaining = periodFinish - block.timestamp;
            uint256 leftover = remaining * rewardRate;
            rewardRate = (_reward + leftover) / _duration;
            totalReward = totalReward + _reward;
        }

        periodFinish = block.timestamp + _duration;
        lastUpdateTime = block.timestamp;
        emit RewardAdded(_reward);
    }

    /**
     * @notice Owner can set the reward token contract(IERC20Upgradeable)
     * @param _token Address of the new reward token
     */
    function setRewardTokenContract(IERC20Upgradeable _token)
        external
        onlyOwner
    {
        rewardToken = _token;
    }

    /**
     * @notice Owner can set the staking token contract(IERC20Upgradeable)
     * @param _token Address of the new staking token
     */
    function setStakingTokenContract(IERC20Upgradeable _token)
        external
        onlyOwner
    {
        stakingToken = _token;
    }

    /**
     * @notice Owner can finish the pool and collect the remaining rewards
     */
    function endPoolAndCollectRemainingRewards() external onlyOwner {
        rewardToken.safeTransfer(owner(), getRemainingTotalReward());
        periodFinish = block.timestamp;
    }
}

// SPDX-License-Identifier: MIT
pragma solidity 0.8.2;

import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "./IJSTAK.sol";

interface IStakBank {
    function initialize(
        string memory _name,
        IERC20Upgradeable _lpToken,
        IERC20Upgradeable _rewardToken,
        IJSTAK _jStak
    ) external;
}

// SPDX-License-Identifier: MIT
pragma solidity 0.8.2;

interface IStoreStakingUsers {
    function getUsers(string memory _user) external returns (uint256);
}

// SPDX-License-Identifier: MIT
pragma solidity 0.8.2;

interface IJSTAK {
    function mint(address to, uint256 amount) external returns (bool);

    function grantJStakRole(address _address) external returns (bool);
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.1 (token/ERC20/IERC20.sol)

pragma solidity ^0.8.0;

/**
 * @dev Interface of the ERC20 standard as defined in the EIP.
 */
interface IERC20Upgradeable {
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

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.1 (security/ReentrancyGuard.sol)

pragma solidity ^0.8.0;
import "../proxy/utils/Initializable.sol";

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

    function __ReentrancyGuard_init() internal onlyInitializing {
        __ReentrancyGuard_init_unchained();
    }

    function __ReentrancyGuard_init_unchained() internal onlyInitializing {
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
    uint256[49] private __gap;
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.1 (security/Pausable.sol)

pragma solidity ^0.8.0;

import "../utils/ContextUpgradeable.sol";
import "../proxy/utils/Initializable.sol";

/**
 * @dev Contract module which allows children to implement an emergency stop
 * mechanism that can be triggered by an authorized account.
 *
 * This module is used through inheritance. It will make available the
 * modifiers `whenNotPaused` and `whenPaused`, which can be applied to
 * the functions of your contract. Note that they will not be pausable by
 * simply including this module, only once the modifiers are put in place.
 */
abstract contract PausableUpgradeable is Initializable, ContextUpgradeable {
    /**
     * @dev Emitted when the pause is triggered by `account`.
     */
    event Paused(address account);

    /**
     * @dev Emitted when the pause is lifted by `account`.
     */
    event Unpaused(address account);

    bool private _paused;

    /**
     * @dev Initializes the contract in unpaused state.
     */
    function __Pausable_init() internal onlyInitializing {
        __Context_init_unchained();
        __Pausable_init_unchained();
    }

    function __Pausable_init_unchained() internal onlyInitializing {
        _paused = false;
    }

    /**
     * @dev Returns true if the contract is paused, and false otherwise.
     */
    function paused() public view virtual returns (bool) {
        return _paused;
    }

    /**
     * @dev Modifier to make a function callable only when the contract is not paused.
     *
     * Requirements:
     *
     * - The contract must not be paused.
     */
    modifier whenNotPaused() {
        require(!paused(), "Pausable: paused");
        _;
    }

    /**
     * @dev Modifier to make a function callable only when the contract is paused.
     *
     * Requirements:
     *
     * - The contract must be paused.
     */
    modifier whenPaused() {
        require(paused(), "Pausable: not paused");
        _;
    }

    /**
     * @dev Triggers stopped state.
     *
     * Requirements:
     *
     * - The contract must not be paused.
     */
    function _pause() internal virtual whenNotPaused {
        _paused = true;
        emit Paused(_msgSender());
    }

    /**
     * @dev Returns to normal state.
     *
     * Requirements:
     *
     * - The contract must be paused.
     */
    function _unpause() internal virtual whenPaused {
        _paused = false;
        emit Unpaused(_msgSender());
    }
    uint256[49] private __gap;
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.1 (utils/math/Math.sol)

pragma solidity ^0.8.0;

/**
 * @dev Standard math utilities missing in the Solidity language.
 */
library MathUpgradeable {
    /**
     * @dev Returns the largest of two numbers.
     */
    function max(uint256 a, uint256 b) internal pure returns (uint256) {
        return a >= b ? a : b;
    }

    /**
     * @dev Returns the smallest of two numbers.
     */
    function min(uint256 a, uint256 b) internal pure returns (uint256) {
        return a < b ? a : b;
    }

    /**
     * @dev Returns the average of two numbers. The result is rounded towards
     * zero.
     */
    function average(uint256 a, uint256 b) internal pure returns (uint256) {
        // (a + b) / 2 can overflow.
        return (a & b) + (a ^ b) / 2;
    }

    /**
     * @dev Returns the ceiling of the division of two numbers.
     *
     * This differs from standard division with `/` in that it rounds up instead
     * of rounding down.
     */
    function ceilDiv(uint256 a, uint256 b) internal pure returns (uint256) {
        // (a + b - 1) / b can overflow on addition, so we distribute.
        return a / b + (a % b == 0 ? 0 : 1);
    }
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.1 (token/ERC20/utils/SafeERC20.sol)

pragma solidity ^0.8.0;

import "../IERC20Upgradeable.sol";
import "../../../utils/AddressUpgradeable.sol";

/**
 * @title SafeERC20
 * @dev Wrappers around ERC20 operations that throw on failure (when the token
 * contract returns false). Tokens that return no value (and instead revert or
 * throw on failure) are also supported, non-reverting calls are assumed to be
 * successful.
 * To use this library you can add a `using SafeERC20 for IERC20;` statement to your contract,
 * which allows you to call the safe operations as `token.safeTransfer(...)`, etc.
 */
library SafeERC20Upgradeable {
    using AddressUpgradeable for address;

    function safeTransfer(
        IERC20Upgradeable token,
        address to,
        uint256 value
    ) internal {
        _callOptionalReturn(token, abi.encodeWithSelector(token.transfer.selector, to, value));
    }

    function safeTransferFrom(
        IERC20Upgradeable token,
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
        IERC20Upgradeable token,
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
        IERC20Upgradeable token,
        address spender,
        uint256 value
    ) internal {
        uint256 newAllowance = token.allowance(address(this), spender) + value;
        _callOptionalReturn(token, abi.encodeWithSelector(token.approve.selector, spender, newAllowance));
    }

    function safeDecreaseAllowance(
        IERC20Upgradeable token,
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
    function _callOptionalReturn(IERC20Upgradeable token, bytes memory data) private {
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
// OpenZeppelin Contracts v4.4.1 (access/Ownable.sol)

pragma solidity ^0.8.0;

import "../utils/ContextUpgradeable.sol";
import "../proxy/utils/Initializable.sol";

/**
 * @dev Contract module which provides a basic access control mechanism, where
 * there is an account (an owner) that can be granted exclusive access to
 * specific functions.
 *
 * By default, the owner account will be the one that deploys the contract. This
 * can later be changed with {transferOwnership}.
 *
 * This module is used through inheritance. It will make available the modifier
 * `onlyOwner`, which can be applied to your functions to restrict their use to
 * the owner.
 */
abstract contract OwnableUpgradeable is Initializable, ContextUpgradeable {
    address private _owner;

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    /**
     * @dev Initializes the contract setting the deployer as the initial owner.
     */
    function __Ownable_init() internal onlyInitializing {
        __Context_init_unchained();
        __Ownable_init_unchained();
    }

    function __Ownable_init_unchained() internal onlyInitializing {
        _transferOwnership(_msgSender());
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
        _transferOwnership(address(0));
    }

    /**
     * @dev Transfers ownership of the contract to a new account (`newOwner`).
     * Can only be called by the current owner.
     */
    function transferOwnership(address newOwner) public virtual onlyOwner {
        require(newOwner != address(0), "Ownable: new owner is the zero address");
        _transferOwnership(newOwner);
    }

    /**
     * @dev Transfers ownership of the contract to a new account (`newOwner`).
     * Internal function without access restriction.
     */
    function _transferOwnership(address newOwner) internal virtual {
        address oldOwner = _owner;
        _owner = newOwner;
        emit OwnershipTransferred(oldOwner, newOwner);
    }
    uint256[49] private __gap;
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.1 (proxy/utils/Initializable.sol)

pragma solidity ^0.8.0;

import "../../utils/AddressUpgradeable.sol";

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
 *
 * [CAUTION]
 * ====
 * Avoid leaving a contract uninitialized.
 *
 * An uninitialized contract can be taken over by an attacker. This applies to both a proxy and its implementation
 * contract, which may impact the proxy. To initialize the implementation contract, you can either invoke the
 * initializer manually, or you can include a constructor to automatically mark it as initialized when it is deployed:
 *
 * [.hljs-theme-light.nopadding]
 * ```
 * /// @custom:oz-upgrades-unsafe-allow constructor
 * constructor() initializer {}
 * ```
 * ====
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
        // If the contract is initializing we ignore whether _initialized is set in order to support multiple
        // inheritance patterns, but we only do this in the context of a constructor, because in other contexts the
        // contract may have been reentered.
        require(_initializing ? _isConstructor() : !_initialized, "Initializable: contract is already initialized");

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

    /**
     * @dev Modifier to protect an initialization function so that it can only be invoked by functions with the
     * {initializer} modifier, directly or indirectly.
     */
    modifier onlyInitializing() {
        require(_initializing, "Initializable: contract is not initializing");
        _;
    }

    function _isConstructor() private view returns (bool) {
        return !AddressUpgradeable.isContract(address(this));
    }
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.1 (utils/Address.sol)

pragma solidity ^0.8.0;

/**
 * @dev Collection of functions related to the address type
 */
library AddressUpgradeable {
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

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.1 (utils/Context.sol)

pragma solidity ^0.8.0;
import "../proxy/utils/Initializable.sol";

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
abstract contract ContextUpgradeable is Initializable {
    function __Context_init() internal onlyInitializing {
        __Context_init_unchained();
    }

    function __Context_init_unchained() internal onlyInitializing {
    }
    function _msgSender() internal view virtual returns (address) {
        return msg.sender;
    }

    function _msgData() internal view virtual returns (bytes calldata) {
        return msg.data;
    }
    uint256[50] private __gap;
}