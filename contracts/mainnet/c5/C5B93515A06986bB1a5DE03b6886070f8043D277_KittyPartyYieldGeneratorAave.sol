// SPDX-License-Identifier: BSL
pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";

import '../interfaces/IKittyPartyInit.sol';
import "../interfaces/IKittyPartyYieldGenerator.sol";

contract KittyPartyYieldGeneratorAave is Initializable, IKittyPartyYieldGenerator, OwnableUpgradeable {
    address _treasuryContract;
    address payable public AaveContract;
    address payable public AaveRewardContract;
    address public rewardTokenAddress;

    uint256 public constant MAX = type(uint256).max;
    uint256 public totalLocked;

    mapping(address => IKittyPartyYieldGenerator.KittyPartyYieldInfo) public kittyPartyYieldInfo;

    event YieldCreated(uint256 lpTokens, uint256 sellTokens);
    event RewardsClaimed(bool rewardsClaimed,uint256 rewardTokenBalance);
    event YieldClaimed(uint256 lpTokens);

    function __KittyPartyYieldGeneratorAave_init(address treasuryContractParam) public initializer {
        _treasuryContract = treasuryContractParam;
        __Ownable_init();
    }

    function setAllowanceDeposit(address _kittyParty) public {
        address sellToken = kittyPartyYieldInfo[_kittyParty].sellTokenAddress;
        require(IERC20Upgradeable(sellToken).approve(AaveContract, MAX), "Not able to set allowance");
    }

    function setAllowanceWithdraw(address _kittyParty) public {
        address lpTokenAddress = kittyPartyYieldInfo[_kittyParty].lpTokenAddress;               
        require(IERC20Upgradeable(lpTokenAddress).approve(AaveContract, MAX), "Not able to set allowance");
        IERC20Upgradeable(rewardTokenAddress).approve(AaveRewardContract, MAX);
    }

    /**
     * @dev This function deposits DAI and receives equivalent amount of atokens
     */    
    function createLockedValue(bytes calldata) 
        external 
        payable
        override
        returns (uint256 vaultTokensRec)
    {
        address sellToken = kittyPartyYieldInfo[msg.sender].sellTokenAddress;
        address lpToken = kittyPartyYieldInfo[msg.sender].lpTokenAddress;

        require(IERC20Upgradeable(sellToken).approve(AaveContract, MAX), "Not enough allowance");
        uint256 daiBalance = IERC20Upgradeable(sellToken).balanceOf(address(this));
        uint256 initialBalance = IERC20Upgradeable(lpToken).balanceOf(address(this));

        bytes memory payload = abi.encodeWithSignature("deposit(address,uint256,address,uint16)",
                                                       sellToken,
                                                       daiBalance,
                                                       address(this),
                                                       0);
        (bool success,) = address(AaveContract).call(payload);
        require(success, 'Deposit Failed');
        
        vaultTokensRec = IERC20Upgradeable(lpToken).balanceOf(address(this)) - initialBalance;
        kittyPartyYieldInfo[msg.sender].lockedAmount += vaultTokensRec;
        totalLocked += vaultTokensRec;
        emit YieldCreated(vaultTokensRec, daiBalance);
    }

    /**
     * @dev This function claims accrued rewards and withdraws the deposited tokens and sends them to the treasury contract
     */
    function unwindLockedValue(bytes calldata) 
        external 
        override 
        returns (uint256 tokensRec)
    {
        IKittyPartyYieldGenerator.KittyPartyYieldInfo storage kpInfo = kittyPartyYieldInfo[msg.sender];
        
        bytes memory payload = abi.encodeWithSignature("kittyInitiator()");
        (bool success, bytes memory returnData) = address(msg.sender).staticcall(payload);
        
        IKittenPartyInit.KittyInitiator memory kittyInitiator = abi.decode(returnData, (IKittenPartyInit.KittyInitiator));
        // Get funds back in the same token that we sold in  DAI, since for now the treasury only releases DAI
        require(IERC20Upgradeable(kpInfo.sellTokenAddress).approve(AaveContract, MAX), "Not enough allowance");
        uint256 rewardTokenBalance = 0;
        uint256 lpTokenBalance = IERC20Upgradeable(kpInfo.lpTokenAddress).balanceOf(address(this));

        //set party yield as a portion of claimable pool
        kpInfo.yieldGeneratedInLastRound = (lpTokenBalance * kpInfo.lockedAmount / totalLocked) - (kittyInitiator.amountInDAIPerRound / 10);
        totalLocked -= kpInfo.lockedAmount;

        // Create an array with lp token address for checking rewards
        address[] memory lpTokens = new address[](1);
        lpTokens[0] = kpInfo.lpTokenAddress; 
        // Check the balance of accrued rewards
        payload = abi.encodeWithSignature("getRewardsBalance(address[],address)",
                                                        lpTokens,
                                                        address(this));
        (bool rewardsExists, bytes memory return_Data) = address(AaveRewardContract).staticcall(payload);

        if(rewardsExists == true) {
            (rewardTokenBalance) = abi.decode(return_Data, (uint256));
            // Claim balance rewards and sent to treasury
            payload = abi.encodeWithSignature("claimRewards(address[],uint256,address)",
                                              lpTokens,
                                              rewardTokenBalance,
                                              _treasuryContract);
            (bool rewardsClaimed,) = address(AaveRewardContract).call(payload);
            emit RewardsClaimed(rewardsClaimed, rewardTokenBalance);
        }

        // Withdraws deposited DAI and burns atokens
        payload = abi.encodeWithSignature("withdraw(address,uint256,address)",
                                          kpInfo.sellTokenAddress,
                                          kpInfo.yieldGeneratedInLastRound + (kittyInitiator.amountInDAIPerRound / 10),
                                          _treasuryContract);
        (success,) = address(AaveContract).call(payload);
        require(success, 'Withdraw failed');

        emit YieldClaimed(kpInfo.yieldGeneratedInLastRound);

        return  kpInfo.yieldGeneratedInLastRound;
    }

    function treasuryAddress() external view override returns (address treasuryContractAddress) {
        return _treasuryContract;
    }

    function lockedAmount(address kittyParty) external view override returns (uint256 totalLockedValue) {
        return kittyPartyYieldInfo[kittyParty].lockedAmount;
    }

    function yieldCurrent(address kittyParty) external view returns (uint256 yieldToBeGeneratedInCurrentRound) {
        uint256 lpTokenBalance = IERC20Upgradeable(kittyPartyYieldInfo[kittyParty].lpTokenAddress).balanceOf(address(this));
        return lpTokenBalance * kittyPartyYieldInfo[kittyParty].lockedAmount / totalLocked;
    }

    function yieldGenerated(address kittyParty) external view override returns (uint256) {
        return kittyPartyYieldInfo[kittyParty].yieldGeneratedInLastRound;
    }

    function lockedPool(address kittyParty) external view override returns (address) {
        return kittyPartyYieldInfo[kittyParty].poolAddress;
    }

    function setPlatformDepositContractAddress(address payable _AaveContract) external override onlyOwner {
        AaveContract = _AaveContract;
    }

    function setPlatformRewardContractAddress(address payable _AaveRewardContract, address _rewardTokenAddress) external override onlyOwner {
        AaveRewardContract = _AaveRewardContract;
        rewardTokenAddress = _rewardTokenAddress;
    }

    //@dev allow party to set their own pair of addresses for yield
    function setPartyInfo(address _sellTokenAddress, address _lpTokenAddress) external override {
        kittyPartyYieldInfo[msg.sender].sellTokenAddress = _sellTokenAddress;
        kittyPartyYieldInfo[msg.sender].lpTokenAddress = _lpTokenAddress;
    }

    function setPlatformWithdrawContractAddress(address payable) external override onlyOwner {
    }

    /**@dev emergency drain to be activated by DAO
     */
    function withdraw(
        IERC20Upgradeable token, 
        address recipient, 
        uint256 amount
    ) 
        public 
        onlyOwner 
    {
        token.transfer(recipient, amount);
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
pragma solidity ^0.8.2;

interface IKittenPartyInit {
    struct KittyInitiator { 
        uint8 kreatorFeesInBasisPoints;
        uint8 daoFeesInBasisPoints;
        uint8 winningStrategy;
        uint8 timeToCollection; 
        uint16 maxKittens;
        uint16 durationInDays;
        uint256 amountInDAIPerRound;
        bytes32 partyName;
        address daiAddress;
        address yieldContract; 
        address winnerStrategy; 
    }

    struct KittyYieldArgs {
        address sellTokenAddress;
        address lpTokenAddress;
    }
    
    struct KittyPartyFactoryArgs {
        address tomCatContract;
        address accountantContract;
        address litterAddress;
        address daoTreasuryContract;
        address keeperContractAddress;
    }

    struct KittyPartyControllerVars {
        address kreator;
        uint256 kreatorStake;
        uint profit;
        uint profitToSplit;
        uint yieldWithPrincipal;
        // The number of kittens inside that party
        uint8 localKittens;
        // A state representing whether the party has started and completed
        uint8 internalState;
    }
}

// SPDX-License-Identifier: BSL
pragma solidity ^0.8.0;

/**
 * @dev Interface of the Kitty Party Yield Generator
 */
interface IKittyPartyYieldGenerator {
    struct KittyPartyYieldInfo { 
      uint256 lockedAmount;
      uint256 yieldGeneratedInLastRound;
      address sellTokenAddress;
      address poolAddress;
      address lpTokenAddress;
    }
    
    /**
     * @dev Create a new LockedValue in the pool
     */
    function createLockedValue(bytes calldata) external payable returns (uint256);
 
    /**
     * @dev Unwind a LockedValue in the pool
     */
    function unwindLockedValue(bytes calldata) external returns (uint256);

    /**
     * @dev Returns the address of the treasury contract
     */
    function treasuryAddress() external view returns (address);

    /**
     * @dev Returns the amount of tokens staked for a specific kitty party.
     */
    function lockedAmount(address) external view returns (uint256);

    /**
     * @dev Returns the amount of tokens staked for a specific kitty party.
     */
    function yieldGenerated(address) external view returns (uint256);

    /**
     * @dev Returns the pool in which the kitty party tokens were staked
     */
    function lockedPool(address) external view returns (address);

    /**
     * @dev Returns the pool in which the kitty party tokens were staked
     */
    function setPlatformRewardContractAddress(address payable,address) external;
    function setPlatformDepositContractAddress(address payable) external;
    function setPlatformWithdrawContractAddress(address payable) external;
    function setPartyInfo(address, address) external;
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