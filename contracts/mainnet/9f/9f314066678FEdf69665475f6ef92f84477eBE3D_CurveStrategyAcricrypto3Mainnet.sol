//SPDX-License-Identifier: Unlicense
pragma solidity 0.6.12;

import "./CurveStrategy.sol";

contract CurveStrategyAcricrypto3Mainnet is CurveStrategy {

  address public triCrypto_unused; // just a differentiator for the bytecode

  constructor() public {}


  function initializeStrategy(
    address _storage,
    address _vault
  ) public initializer {
    address underlying = address(0xdAD97F7713Ae9437fa9249920eC8507e5FbB23d3);
    address gauge = address(0x3B6B158A76fd8ccc297538F454ce7B4787778c7C);
    address wmatic = address(0x0d500B1d8E8eF31E21C99d1Db9A6444d3ADf1270);
    address crv = address(0x172370d5Cd63279eFa6d502DAB29171933a610AF);
    address usdt = address(0xc2132D05D31c914a87C6611C10748AEb04B58e8F);
    address aTriCrypto3CurveDeposit = address(0x1d8b86e3D88cDb2d34688e87E72F388Cb541B7C8);
    CurveStrategy.initializeBaseStrategy(
      _storage,
      underlying,
      _vault,
      gauge, //rewardPool
      2, //depositArrayPosition
      aTriCrypto3CurveDeposit,
      usdt, //depositToken
      5,
      false
    );
    reward2WETH[wmatic] = [wmatic, weth];
    reward2WETH[crv] = [crv, weth];
    WETH2deposit = [weth, usdt];
    rewardTokens = [crv, wmatic];
    useQuick[crv] = false;
    useQuick[wmatic] = false;
    useQuick[usdt] = false;
  }
}

//SPDX-License-Identifier: Unlicense
pragma solidity 0.6.12;


import "@openzeppelin/contracts/math/Math.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol";
import "@uniswap/v2-core/contracts/interfaces/IUniswapV2Pair.sol";
import "../../base/interface/IVault.sol";
import "../../base/upgradability/BaseUpgradeableStrategy.sol";
import "../../base/interface/curve/Gauge.sol";
import "../../base/interface/curve/ICurveDeposit_2token.sol";
import "../../base/interface/curve/ICurveDeposit_2token_underlying.sol";
import "../../base/interface/curve/ICurveDeposit_3token.sol";
import "../../base/interface/curve/ICurveDeposit_3token_underlying.sol";
import "../../base/interface/curve/ICurveDeposit_4token.sol";
import "../../base/interface/curve/ICurveDeposit_4token_underlying.sol";
import "../../base/interface/curve/ICurveDeposit_5token.sol";
import "../../base/interface/curve/ICurveDeposit_5token_underlying.sol";

contract CurveStrategy is BaseUpgradeableStrategy {

  using SafeMath for uint256;
  using SafeERC20 for IERC20;

  address public constant quickswapRouterV2 = address(0xa5E0829CaCEd8fFDD4De3c43696c57F7D7A678ff);
  address public constant sushiswapRouterV2 = address(0x1b02dA8Cb0d097eB8D57A175b88c7D8b47997506);
  address public constant weth = address(0x7ceB23fD6bC0adD59E62ac25578270cFf1b9f619);

  // additional storage slots (on top of BaseUpgradeableStrategy ones) are defined here
  bytes32 internal constant _DEPOSIT_ARRAY_POSITION_SLOT = 0xb7c50ef998211fff3420379d0bf5b8dfb0cee909d1b7d9e517f311c104675b09;
  bytes32 internal constant _CURVE_DEPOSIT_SLOT = 0xb306bb7adebd5a22f5e4cdf1efa00bc5f62d4f5554ef9d62c1b16327cd3ab5f9;
  bytes32 internal constant _DEPOSIT_TOKEN_SLOT = 0x219270253dbc530471c88a9e7c321b36afda219583431e7b6c386d2d46e70c86;
  bytes32 internal constant _NTOKENS_SLOT = 0xbb60b35bae256d3c1378ff05e8d7bee588cd800739c720a107471dfa218f74c1;
  bytes32 internal constant _DEPOSIT_UNDERLYING_SLOT = 0x7e1abf1e7032ca991b157f8f3d98f150896400297dd9e71e770edb7ac08d6216;

  address[] public WETH2deposit;
  mapping (address => address[]) public reward2WETH;
  mapping (address => bool) public useQuick;
  address[] public rewardTokens;

  constructor() public BaseUpgradeableStrategy() {
    assert(_DEPOSIT_ARRAY_POSITION_SLOT == bytes32(uint256(keccak256("eip1967.strategyStorage.depositArrayPosition")) - 1));
    assert(_CURVE_DEPOSIT_SLOT == bytes32(uint256(keccak256("eip1967.strategyStorage.curveDeposit")) - 1));
    assert(_DEPOSIT_TOKEN_SLOT == bytes32(uint256(keccak256("eip1967.strategyStorage.depositToken")) - 1));
    assert(_NTOKENS_SLOT == bytes32(uint256(keccak256("eip1967.strategyStorage.nTokens")) - 1));
    assert(_DEPOSIT_UNDERLYING_SLOT == bytes32(uint256(keccak256("eip1967.strategyStorage.depositUnderlying")) - 1));
  }

  function initializeBaseStrategy(
    address _storage,
    address _underlying,
    address _vault,
    address _rewardPool,
    uint256 _depositArrayPosition,
    address _curveDeposit,
    address _depositToken,
    uint256 _nTokens,
    bool _depositUnderlying
  ) public initializer {

    BaseUpgradeableStrategy.initialize(
      _storage,
      _underlying,
      _vault,
      _rewardPool,
      weth,
      80, // profit sharing numerator
      1000, // profit sharing denominator
      true, // sell
      0, // sell floor
      12 hours // implementation change delay
    );
    _setNTokens(_nTokens);
    _setDepositArrayPosition(_depositArrayPosition);
    _setCurveDeposit(_curveDeposit);
    _setDepositToken(_depositToken);
    _setDepositUnderlying(_depositUnderlying);
    WETH2deposit = new address[](0);
    rewardTokens = new address[](0);
  }

  /*///////////////////////////////////////////////////////////////
                  STORAGE SETTER AND GETTER
  //////////////////////////////////////////////////////////////*/

  /**
  * Can completely disable claiming UNI rewards and selling. Good for emergency withdraw in the
  * simplest possible way.
  */
  function setSell(bool s) public onlyGovernance {
    _setSell(s);
  }

  function setSellFloor(uint256 floor) public onlyGovernance {
    _setSellFloor(floor);
  }

  function _setDepositArrayPosition(uint256 _value) internal {
    require(_value < nTokens(), "Deposit array position out of bounds");
    setUint256(_DEPOSIT_ARRAY_POSITION_SLOT, _value);
  }

  function depositArrayPosition() public view returns (uint256) {
    return getUint256(_DEPOSIT_ARRAY_POSITION_SLOT);
  }

  function _setCurveDeposit(address _address) internal {
    setAddress(_CURVE_DEPOSIT_SLOT, _address);
  }

  function curveDeposit() public view returns (address) {
    return getAddress(_CURVE_DEPOSIT_SLOT);
  }

  function _setDepositToken(address _address) internal {
    setAddress(_DEPOSIT_TOKEN_SLOT, _address);
  }

  function depositToken() public view returns (address) {
    return getAddress(_DEPOSIT_TOKEN_SLOT);
  }

  function _setNTokens(uint256 _value) internal {
    setUint256(_NTOKENS_SLOT, _value);
  }

  function nTokens() public view returns (uint256) {
    return getUint256(_NTOKENS_SLOT);
  }

  function _setDepositUnderlying(bool _value) internal {
    setBoolean(_DEPOSIT_UNDERLYING_SLOT, _value);
  }

  function depositUnderlying() public view returns (bool) {
    return getBoolean(_DEPOSIT_UNDERLYING_SLOT);
  }

 /*///////////////////////////////////////////////////////////////
              REWARD & DEPOSIT TOKEN SETTINGS
  //////////////////////////////////////////////////////////////*/

  function setDepositLiquidationPath(address [] memory _route, bool _useQuick) public onlyGovernance {
    require(_route[0] == weth, "Path should start with WETH");
    require(_route[_route.length-1] == depositToken(), "Path should end with depositToken");
    WETH2deposit = _route;
    useQuick[_route[_route.length-1]] = _useQuick;
  }

  function setRewardLiquidationPath(address [] memory _route, bool _useQuick) public onlyGovernance {
    require(_route[_route.length-1] == weth, "Path should end with WETH");
    bool isReward = false;
    for(uint256 i = 0; i < rewardTokens.length; i++){
      if (_route[0] == rewardTokens[i]) {
        isReward = true;
      }
    }
    require(isReward, "Path should start with a rewardToken");
    reward2WETH[_route[0]] = _route;
    useQuick[_route[0]] = _useQuick;
  }

  function addRewardToken(address _token, address[] memory _path2WETH, bool _useQuick) public onlyGovernance {
    require(_path2WETH[_path2WETH.length-1] == weth, "Path should end with WETH");
    require(_path2WETH[0] == _token, "Path should start with rewardToken");
    rewardTokens.push(_token);
    reward2WETH[_token] = _path2WETH;
    useQuick[_token] = _useQuick;
  }

  function changeDepositToken(address _depositToken, address[] memory _WETH2token, bool _useQuick, uint256 _depositArrayPosition) public onlyGovernance {
    _setDepositArrayPosition(_depositArrayPosition);
    _setDepositToken(_depositToken);
    setDepositLiquidationPath(_WETH2token, _useQuick);
  }

  /*///////////////////////////////////////////////////////////////
                  PROXY - FINALIZE UPGRADE
  //////////////////////////////////////////////////////////////*/

  function finalizeUpgrade() external onlyGovernance {
    _finalizeUpgrade();
  }

  /*///////////////////////////////////////////////////////////////
                  INTERNAL HELPER FUNCTIONS
  //////////////////////////////////////////////////////////////*/

  function _rewardPoolBalance() internal view returns (uint256 bal) {
      bal = Gauge(rewardPool()).balanceOf(address(this));
  }

  function _emergencyExitRewardPool() internal {
    uint256 stakedBalance = _rewardPoolBalance();
    if (stakedBalance != 0) {
        _withdrawUnderlyingFromPool(stakedBalance);
    }
  }

  function _withdrawUnderlyingFromPool(uint256 amount) internal {
    address rewardPool_ = rewardPool();
    Gauge(rewardPool_).withdraw(
      Math.min(Gauge(rewardPool_).balanceOf(address(this)), amount)
    );
  }
  function _enterRewardPool() internal {
    address underlying_ = underlying(); 
    address rewardPool_ = rewardPool();
    uint256 entireBalance = IERC20(underlying_).balanceOf(address(this));
    IERC20(underlying_).safeApprove(rewardPool_, 0);
    IERC20(underlying_).safeApprove(rewardPool_, entireBalance);
    Gauge(rewardPool_).deposit(entireBalance);
  }

  function _liquidateReward() internal {
    if (!sell()) {
      // Profits can be disabled for possible simplified and rapoolId exit
      emit ProfitsNotCollected(sell(), false);
      return;
    }

    for(uint256 i = 0; i < rewardTokens.length; i++){
      address token = rewardTokens[i];
      uint256 rewardBalance = IERC20(token).balanceOf(address(this));
      if (rewardBalance == 0 || reward2WETH[token].length < 2) {
        continue;
      }

      address routerV2;
      if(useQuick[token]) {
        routerV2 = quickswapRouterV2;
      } else {
        routerV2 = sushiswapRouterV2;
      }
      IERC20(token).safeApprove(routerV2, 0);
      IERC20(token).safeApprove(routerV2, rewardBalance);
      // we can accept 1 as the minimum because this will be called only by a trusted worker
      IUniswapV2Router02(routerV2).swapExactTokensForTokens(
        rewardBalance, 1, reward2WETH[token], address(this), block.timestamp
      );
    }
  
    address rewardToken_ = rewardToken();
    uint256 rewardBalance = IERC20(rewardToken_).balanceOf(address(this));

    notifyProfitInRewardToken(rewardBalance);
    uint256 remainingRewardBalance = IERC20(rewardToken_).balanceOf(address(this));

    if (remainingRewardBalance == 0) {
      return;
    }

    address routerV2;
    if(useQuick[depositToken()]) {
      routerV2 = quickswapRouterV2;
    } else {
      routerV2 = sushiswapRouterV2;
    }
    // allow Uniswap to sell our reward
    IERC20(rewardToken_).safeApprove(routerV2, 0);
    IERC20(rewardToken_).safeApprove(routerV2, remainingRewardBalance);

    // we can accept 1 as minimum because this is called only by a trusted role
    uint256 amountOutMin = 1;

    IUniswapV2Router02(routerV2).swapExactTokensForTokens(
      remainingRewardBalance,
      amountOutMin,
      WETH2deposit,
      address(this),
      block.timestamp
    );

    uint256 tokenBalance = IERC20(depositToken()).balanceOf(address(this));
    if (tokenBalance > 0) {
      _depositCurve();
    }
  }

  /*
  *   Stakes everything the strategy holds into the reward pool
  */
  function _investAllUnderlying() internal onlyNotPausedInvesting {
    // this check is needed, because most of the SNX reward pools will revert if
    // you try to stake(0).
    if(IERC20(underlying()).balanceOf(address(this)) > 0) {
      _enterRewardPool();
    }
  }
  
  function _depositCurve() internal {
    uint256 tokenBalance = IERC20(depositToken()).balanceOf(address(this));
    address curveDeposit_ = curveDeposit();
    uint256 nTokens_ = nTokens();

    IERC20(depositToken()).safeApprove(curveDeposit_, 0);
    IERC20(depositToken()).safeApprove(curveDeposit_, tokenBalance);

    // we can accept 0 as minimum, this will be called only by trusted roles
    uint256 minimum = 0;
    if (depositUnderlying()) {
      if (nTokens_ == 2) {
        uint256[2] memory depositArray;
        depositArray[depositArrayPosition()] = tokenBalance;
        ICurveDeposit_2token_underlying(curveDeposit_).add_liquidity(depositArray, minimum, true);
      } else if (nTokens_ == 3) {
        uint256[3] memory depositArray;
        depositArray[depositArrayPosition()] = tokenBalance;
        ICurveDeposit_3token_underlying(curveDeposit_).add_liquidity(depositArray, minimum, true);
      } else if (nTokens_ == 4) {
        uint256[4] memory depositArray;
        depositArray[depositArrayPosition()] = tokenBalance;
        ICurveDeposit_4token_underlying(curveDeposit_).add_liquidity(depositArray, minimum, true);
      } else {
        uint256[5] memory depositArray;
        depositArray[depositArrayPosition()] = tokenBalance;
        ICurveDeposit_5token_underlying(curveDeposit_).add_liquidity(depositArray, minimum, true);
      } 
    } else {
      if (nTokens_ == 2) {
        uint256[2] memory depositArray;
        depositArray[depositArrayPosition()] = tokenBalance;
        ICurveDeposit_2token(curveDeposit_).add_liquidity(depositArray, minimum);
      } else if (nTokens_ == 3) {
        uint256[3] memory depositArray;
        depositArray[depositArrayPosition()] = tokenBalance;
        ICurveDeposit_3token(curveDeposit_).add_liquidity(depositArray, minimum);
      } else if (nTokens_ == 4) {
        uint256[4] memory depositArray;
        depositArray[depositArrayPosition()] = tokenBalance;
        ICurveDeposit_4token(curveDeposit_).add_liquidity(depositArray, minimum);
      } else {
        uint256[5] memory depositArray;
        depositArray[depositArrayPosition()] = tokenBalance;
        ICurveDeposit_5token(curveDeposit_).add_liquidity(depositArray, minimum);
      } 
    }
  }

  /*///////////////////////////////////////////////////////////////
                  PUBLIC EMERGENCY FUNCTIONS
  //////////////////////////////////////////////////////////////*/

  /*
  *   In case there are some issues discovered about the pool or underlying asset
  *   Governance can exit the pool properly
  *   The function is only used for emergency to exit the pool
  */
  function emergencyExit() public onlyGovernance {
    _emergencyExitRewardPool();
    _setPausedInvesting(true);
  }

  /*
  *   Resumes the ability to invest into the underlying reward pools
  */
  function continueInvesting() public onlyGovernance {
    _setPausedInvesting(false);
  }

  /*///////////////////////////////////////////////////////////////
                  ISTRATEGY FUNCTION IMPLEMENTATIONS
  //////////////////////////////////////////////////////////////*/

  /*
  *   Withdraws all the asset to the vault
  */
  function withdrawAllToVault() public restricted {
    _withdrawUnderlyingFromPool(_rewardPoolBalance());
    _liquidateReward();
    address underlying_ = underlying();
    IERC20(underlying_).safeTransfer(vault(), IERC20(underlying_).balanceOf(address(this)));
  }

  /*
  *   Withdraws all the asset to the vault
  */
  function withdrawToVault(uint256 _amount) public restricted {
    // Typically there wouldn't be any amount here
    // however, it is possible because of the emergencyExit
    address underlying_ = underlying();
    uint256 entireBalance = IERC20(underlying_).balanceOf(address(this));

    if(_amount > entireBalance){
      // While we have the check above, we still using SafeMath below
      // for the peace of mind (in case something gets changed in between)
      uint256 needToWithdraw = _amount.sub(entireBalance);
      uint256 toWithdraw = Math.min(_rewardPoolBalance(), needToWithdraw);
      _withdrawUnderlyingFromPool(toWithdraw);
    }
    IERC20(underlying_).safeTransfer(vault(), _amount);
  }

  /*
  *   Note that we currently do not have a mechanism here to include the
  *   amount of reward that is accrued.
  */
  function investedUnderlyingBalance() external view returns (uint256) {
    if (rewardPool() == address(0)) {
      return IERC20(underlying()).balanceOf(address(this));
    }
    // Adding the amount locked in the reward pool and the amount that is somehow in this contract
    // both are in the units of "underlying"
    // The second part is needed because there is the emergency exit mechanism
    // which would break the assumption that all the funds are always inside of the reward pool
    return _rewardPoolBalance().add(IERC20(underlying()).balanceOf(address(this)));
  }

  /*
  *   Governance or Controller can claim coins that are somehow transferred into the contract
  *   Note that they cannot come in take away coins that are used and defined in the strategy itself
  */
  function salvage(address _recipient, address _token, uint256 _amount) external onlyControllerOrGovernance {
     // To make sure that governance cannot come in and take away the coins
    require(!unsalvagableTokens(_token), "token is defined as not salvagable");
    IERC20(_token).safeTransfer(_recipient, _amount);
  }

    function unsalvagableTokens(address _token) public view returns (bool) {
    return (_token == rewardToken() || _token == underlying());
  }

  /*
  *   Get the reward, sell it in exchange for underlying, invest what you got.
  *   It's not much, but it's honest work.
  *
  *   Note that although `onlyNotPausedInvesting` is not added here,
  *   calling `_investAllUnderlying()` affectively blocks the usage of `doHardWork`
  *   when the investing is being paused by governance.
  */
  function doHardWork() external onlyNotPausedInvesting restricted {
    Gauge(rewardPool()).claim_rewards();
    _liquidateReward();
    _investAllUnderlying();
  }

  function depositArbCheck() public pure returns(bool) {
    return true;
  }
}

// SPDX-License-Identifier: MIT

pragma solidity >=0.6.0 <0.8.0;

/**
 * @dev Standard math utilities missing in the Solidity language.
 */
library Math {
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
        // (a + b) / 2 can overflow, so we distribute
        return (a / 2) + (b / 2) + ((a % 2 + b % 2) / 2);
    }
}

// SPDX-License-Identifier: MIT

pragma solidity >=0.6.0 <0.8.0;

/**
 * @dev Wrappers over Solidity's arithmetic operations with added overflow
 * checks.
 *
 * Arithmetic operations in Solidity wrap on overflow. This can easily result
 * in bugs, because programmers usually assume that an overflow raises an
 * error, which is the standard behavior in high level programming languages.
 * `SafeMath` restores this intuition by reverting the transaction when an
 * operation overflows.
 *
 * Using this library instead of the unchecked operations eliminates an entire
 * class of bugs, so it's recommended to use it always.
 */
library SafeMath {
    /**
     * @dev Returns the addition of two unsigned integers, with an overflow flag.
     *
     * _Available since v3.4._
     */
    function tryAdd(uint256 a, uint256 b) internal pure returns (bool, uint256) {
        uint256 c = a + b;
        if (c < a) return (false, 0);
        return (true, c);
    }

    /**
     * @dev Returns the substraction of two unsigned integers, with an overflow flag.
     *
     * _Available since v3.4._
     */
    function trySub(uint256 a, uint256 b) internal pure returns (bool, uint256) {
        if (b > a) return (false, 0);
        return (true, a - b);
    }

    /**
     * @dev Returns the multiplication of two unsigned integers, with an overflow flag.
     *
     * _Available since v3.4._
     */
    function tryMul(uint256 a, uint256 b) internal pure returns (bool, uint256) {
        // Gas optimization: this is cheaper than requiring 'a' not being zero, but the
        // benefit is lost if 'b' is also tested.
        // See: https://github.com/OpenZeppelin/openzeppelin-contracts/pull/522
        if (a == 0) return (true, 0);
        uint256 c = a * b;
        if (c / a != b) return (false, 0);
        return (true, c);
    }

    /**
     * @dev Returns the division of two unsigned integers, with a division by zero flag.
     *
     * _Available since v3.4._
     */
    function tryDiv(uint256 a, uint256 b) internal pure returns (bool, uint256) {
        if (b == 0) return (false, 0);
        return (true, a / b);
    }

    /**
     * @dev Returns the remainder of dividing two unsigned integers, with a division by zero flag.
     *
     * _Available since v3.4._
     */
    function tryMod(uint256 a, uint256 b) internal pure returns (bool, uint256) {
        if (b == 0) return (false, 0);
        return (true, a % b);
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
        uint256 c = a + b;
        require(c >= a, "SafeMath: addition overflow");
        return c;
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
        require(b <= a, "SafeMath: subtraction overflow");
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
        if (a == 0) return 0;
        uint256 c = a * b;
        require(c / a == b, "SafeMath: multiplication overflow");
        return c;
    }

    /**
     * @dev Returns the integer division of two unsigned integers, reverting on
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
    function div(uint256 a, uint256 b) internal pure returns (uint256) {
        require(b > 0, "SafeMath: division by zero");
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
        require(b > 0, "SafeMath: modulo by zero");
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
    function sub(uint256 a, uint256 b, string memory errorMessage) internal pure returns (uint256) {
        require(b <= a, errorMessage);
        return a - b;
    }

    /**
     * @dev Returns the integer division of two unsigned integers, reverting with custom message on
     * division by zero. The result is rounded towards zero.
     *
     * CAUTION: This function is deprecated because it requires allocating memory for the error
     * message unnecessarily. For custom revert reasons use {tryDiv}.
     *
     * Counterpart to Solidity's `/` operator. Note: this function uses a
     * `revert` opcode (which leaves remaining gas untouched) while Solidity
     * uses an invalid opcode to revert (consuming all remaining gas).
     *
     * Requirements:
     *
     * - The divisor cannot be zero.
     */
    function div(uint256 a, uint256 b, string memory errorMessage) internal pure returns (uint256) {
        require(b > 0, errorMessage);
        return a / b;
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
    function mod(uint256 a, uint256 b, string memory errorMessage) internal pure returns (uint256) {
        require(b > 0, errorMessage);
        return a % b;
    }
}

// SPDX-License-Identifier: MIT

pragma solidity >=0.6.0 <0.8.0;

import "./IERC20.sol";
import "../../math/SafeMath.sol";
import "../../utils/Address.sol";

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
    using SafeMath for uint256;
    using Address for address;

    function safeTransfer(IERC20 token, address to, uint256 value) internal {
        _callOptionalReturn(token, abi.encodeWithSelector(token.transfer.selector, to, value));
    }

    function safeTransferFrom(IERC20 token, address from, address to, uint256 value) internal {
        _callOptionalReturn(token, abi.encodeWithSelector(token.transferFrom.selector, from, to, value));
    }

    /**
     * @dev Deprecated. This function has issues similar to the ones found in
     * {IERC20-approve}, and its usage is discouraged.
     *
     * Whenever possible, use {safeIncreaseAllowance} and
     * {safeDecreaseAllowance} instead.
     */
    function safeApprove(IERC20 token, address spender, uint256 value) internal {
        // safeApprove should only be called when setting an initial allowance,
        // or when resetting it to zero. To increase and decrease it, use
        // 'safeIncreaseAllowance' and 'safeDecreaseAllowance'
        // solhint-disable-next-line max-line-length
        require((value == 0) || (token.allowance(address(this), spender) == 0),
            "SafeERC20: approve from non-zero to non-zero allowance"
        );
        _callOptionalReturn(token, abi.encodeWithSelector(token.approve.selector, spender, value));
    }

    function safeIncreaseAllowance(IERC20 token, address spender, uint256 value) internal {
        uint256 newAllowance = token.allowance(address(this), spender).add(value);
        _callOptionalReturn(token, abi.encodeWithSelector(token.approve.selector, spender, newAllowance));
    }

    function safeDecreaseAllowance(IERC20 token, address spender, uint256 value) internal {
        uint256 newAllowance = token.allowance(address(this), spender).sub(value, "SafeERC20: decreased allowance below zero");
        _callOptionalReturn(token, abi.encodeWithSelector(token.approve.selector, spender, newAllowance));
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
        if (returndata.length > 0) { // Return data is optional
            // solhint-disable-next-line max-line-length
            require(abi.decode(returndata, (bool)), "SafeERC20: ERC20 operation did not succeed");
        }
    }
}

pragma solidity >=0.6.2;

import './IUniswapV2Router01.sol';

interface IUniswapV2Router02 is IUniswapV2Router01 {
    function removeLiquidityETHSupportingFeeOnTransferTokens(
        address token,
        uint liquidity,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline
    ) external returns (uint amountETH);
    function removeLiquidityETHWithPermitSupportingFeeOnTransferTokens(
        address token,
        uint liquidity,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline,
        bool approveMax, uint8 v, bytes32 r, bytes32 s
    ) external returns (uint amountETH);

    function swapExactTokensForTokensSupportingFeeOnTransferTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external;
    function swapExactETHForTokensSupportingFeeOnTransferTokens(
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external payable;
    function swapExactTokensForETHSupportingFeeOnTransferTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external;
}

pragma solidity >=0.5.0;

interface IUniswapV2Pair {
    event Approval(address indexed owner, address indexed spender, uint value);
    event Transfer(address indexed from, address indexed to, uint value);

    function name() external pure returns (string memory);
    function symbol() external pure returns (string memory);
    function decimals() external pure returns (uint8);
    function totalSupply() external view returns (uint);
    function balanceOf(address owner) external view returns (uint);
    function allowance(address owner, address spender) external view returns (uint);

    function approve(address spender, uint value) external returns (bool);
    function transfer(address to, uint value) external returns (bool);
    function transferFrom(address from, address to, uint value) external returns (bool);

    function DOMAIN_SEPARATOR() external view returns (bytes32);
    function PERMIT_TYPEHASH() external pure returns (bytes32);
    function nonces(address owner) external view returns (uint);

    function permit(address owner, address spender, uint value, uint deadline, uint8 v, bytes32 r, bytes32 s) external;

    event Mint(address indexed sender, uint amount0, uint amount1);
    event Burn(address indexed sender, uint amount0, uint amount1, address indexed to);
    event Swap(
        address indexed sender,
        uint amount0In,
        uint amount1In,
        uint amount0Out,
        uint amount1Out,
        address indexed to
    );
    event Sync(uint112 reserve0, uint112 reserve1);

    function MINIMUM_LIQUIDITY() external pure returns (uint);
    function factory() external view returns (address);
    function token0() external view returns (address);
    function token1() external view returns (address);
    function getReserves() external view returns (uint112 reserve0, uint112 reserve1, uint32 blockTimestampLast);
    function price0CumulativeLast() external view returns (uint);
    function price1CumulativeLast() external view returns (uint);
    function kLast() external view returns (uint);

    function mint(address to) external returns (uint liquidity);
    function burn(address to) external returns (uint amount0, uint amount1);
    function swap(uint amount0Out, uint amount1Out, address to, bytes calldata data) external;
    function skim(address to) external;
    function sync() external;

    function initialize(address, address) external;
}

//SPDX-License-Identifier: Unlicense

pragma solidity 0.6.12;

interface IVault {

    function initializeVault(
      address _storage,
      address _underlying,
      uint256 _toInvestNumerator,
      uint256 _toInvestDenominator
    ) external ;

    function underlyingBalanceInVault() external view returns (uint256);
    function underlyingBalanceWithInvestment() external view returns (uint256);

    function underlying() external view returns (address);
    function strategy() external view returns (address);

    function setStrategy(address _strategy) external;
    function announceStrategyUpdate(address _strategy) external;
    function setVaultFractionToInvest(uint256 numerator, uint256 denominator) external;

    function deposit(uint256 amountWei) external;
    function depositFor(uint256 amountWei, address holder) external;

    function withdrawAll() external;
    function withdraw(uint256 numberOfShares) external;
    function getPricePerFullShare() external view returns (uint256);

    function underlyingBalanceWithInvestmentForHolder(address holder) view external returns (uint256);

    // hard work should be callable only by the controller (by the hard worker) or by governance
    function doHardWork() external;
}

//SPDX-License-Identifier: Unlicense

pragma solidity 0.6.12;

import "@openzeppelin/contracts-upgradeable/proxy/Initializable.sol";
import "./BaseUpgradeableStrategyStorage.sol";
import "../inheritance/ControllableInit.sol";
import "../interface/IController.sol";
import "../interface/IFeeRewardForwarder.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";

contract BaseUpgradeableStrategy is Initializable, ControllableInit, BaseUpgradeableStrategyStorage {
  using SafeMath for uint256;
  using SafeERC20 for IERC20;

  event ProfitsNotCollected(bool sell, bool floor);
  event ProfitLogInReward(uint256 profitAmount, uint256 feeAmount, uint256 timestamp);
  event ProfitAndBuybackLog(uint256 profitAmount, uint256 feeAmount, uint256 timestamp);

  modifier restricted() {
    require(msg.sender == vault() || msg.sender == controller()
      || msg.sender == governance(),
      "The sender has to be the controller, governance, or vault");
    _;
  }

  // This is only used in `investAllUnderlying()`
  // The user can still freely withdraw from the strategy
  modifier onlyNotPausedInvesting() {
    require(!pausedInvesting(), "Action blocked as the strategy is in emergency state");
    _;
  }

  constructor() public BaseUpgradeableStrategyStorage() {
  }

  function initialize(
    address _storage,
    address _underlying,
    address _vault,
    address _rewardPool,
    address _rewardToken,
    uint256 _profitSharingNumerator,
    uint256 _profitSharingDenominator,
    bool _sell,
    uint256 _sellFloor,
    uint256 _implementationChangeDelay
  ) public initializer {
    ControllableInit.initialize(
      _storage
    );
    _setUnderlying(_underlying);
    _setVault(_vault);
    _setRewardPool(_rewardPool);
    _setRewardToken(_rewardToken);
    _setProfitSharingNumerator(_profitSharingNumerator);
    _setProfitSharingDenominator(_profitSharingDenominator);

    _setSell(_sell);
    _setSellFloor(_sellFloor);
    _setNextImplementationDelay(_implementationChangeDelay);
    _setPausedInvesting(false);
  }

  /**
  * Schedules an upgrade for this vault's proxy.
  */
  function scheduleUpgrade(address impl) public onlyGovernance {
    _setNextImplementation(impl);
    _setNextImplementationTimestamp(block.timestamp.add(nextImplementationDelay()));
  }

  function _finalizeUpgrade() internal {
    _setNextImplementation(address(0));
    _setNextImplementationTimestamp(0);
  }

  function shouldUpgrade() external view returns (bool, address) {
    return (
      nextImplementationTimestamp() != 0
        && block.timestamp > nextImplementationTimestamp()
        && nextImplementation() != address(0),
      nextImplementation()
    );
  }

  // reward notification

  function notifyProfitInRewardToken(uint256 _rewardBalance) internal {
    if( _rewardBalance > 0 ){
      uint256 feeAmount = _rewardBalance.mul(profitSharingNumerator()).div(profitSharingDenominator());
      emit ProfitLogInReward(_rewardBalance, feeAmount, block.timestamp);
      IERC20(rewardToken()).safeApprove(controller(), 0);
      IERC20(rewardToken()).safeApprove(controller(), feeAmount);

      IController(controller()).notifyFee(
        rewardToken(),
        feeAmount
      );
    } else {
      emit ProfitLogInReward(0, 0, block.timestamp);
    }
  }
}

//SPDX-License-Identifier: Unlicense
pragma solidity 0.6.12;

interface Gauge {
    function deposit(uint) external;
    function balanceOf(address) external view returns (uint);
    function withdraw(uint) external;
    function user_checkpoint(address) external;
    function claim_rewards() external;
}

interface VotingEscrow {
    function create_lock(uint256 v, uint256 time) external;
    function increase_amount(uint256 _value) external;
    function increase_unlock_time(uint256 _unlock_time) external;
    function withdraw() external;
}

interface Mintr {
    function mint(address) external;
}

//SPDX-License-Identifier: Unlicense
pragma solidity 0.6.12;

interface ICurveDeposit_2token {
  function get_virtual_price() external view returns (uint);
  function add_liquidity(
    uint256[2] calldata amounts,
    uint256 min_mint_amount
  ) external payable;
  function remove_liquidity_imbalance(
    uint256[2] calldata amounts,
    uint256 max_burn_amount
  ) external;
  function remove_liquidity(
    uint256 _amount,
    uint256[2] calldata amounts
  ) external;
  function exchange(
    int128 from, int128 to, uint256 _from_amount, uint256 _min_to_amount
  ) external payable;
  function calc_token_amount(
    uint256[2] calldata amounts,
    bool deposit
  ) external view returns(uint);
}

//SPDX-License-Identifier: Unlicense
pragma solidity 0.6.12;

interface ICurveDeposit_2token_underlying {
  function get_virtual_price() external view returns (uint);
  function add_liquidity(
    uint256[2] calldata amounts,
    uint256 min_mint_amount,
    bool use_underlying
  ) external;
  function remove_liquidity_imbalance(
    uint256[2] calldata amounts,
    uint256 max_burn_amount,
    bool use_underlying
  ) external;
  function remove_liquidity(
    uint256 _amount,
    uint256[2] calldata amounts,
    bool use_underlying
  ) external;
  function exchange(
    int128 from, int128 to, uint256 _from_amount, uint256 _min_to_amount
  ) external;
  function exchange_underlying(
    int128 from, int128 to, uint256 _from_amount, uint256 _min_to_amount
  ) external;
  function calc_token_amount(
    uint256[2] calldata amounts,
    bool deposit
  ) external view returns(uint);
}

//SPDX-License-Identifier: Unlicense
pragma solidity 0.6.12;

interface ICurveDeposit_3token {
  function get_virtual_price() external view returns (uint);
  function add_liquidity(
    uint256[3] calldata amounts,
    uint256 min_mint_amount
  ) external;
  function remove_liquidity_imbalance(
    uint256[3] calldata amounts,
    uint256 max_burn_amount
  ) external;
  function remove_liquidity(
    uint256 _amount,
    uint256[3] calldata amounts
  ) external;
  function exchange(
    int128 from, int128 to, uint256 _from_amount, uint256 _min_to_amount
  ) external;
  function calc_token_amount(
    uint256[3] calldata amounts,
    bool deposit
  ) external view returns(uint);
}

//SPDX-License-Identifier: Unlicense
pragma solidity 0.6.12;

interface ICurveDeposit_3token_underlying {
  function get_virtual_price() external view returns (uint);
  function add_liquidity(
    uint256[3] calldata amounts,
    uint256 min_mint_amount,
    bool use_underlying
  ) external;
  function remove_liquidity_imbalance(
    uint256[3] calldata amounts,
    uint256 max_burn_amount,
    bool use_underlying
  ) external;
  function remove_liquidity(
    uint256 _amount,
    uint256[3] calldata amounts,
    bool use_underlying
  ) external;
  function exchange(
    int128 from, int128 to, uint256 _from_amount, uint256 _min_to_amount
  ) external;
  function exchange_underlying(
    int128 from, int128 to, uint256 _from_amount, uint256 _min_to_amount
  ) external;
  function calc_token_amount(
    uint256[3] calldata amounts,
    bool deposit
  ) external view returns(uint);
}

//SPDX-License-Identifier: Unlicense
pragma solidity 0.6.12;

interface ICurveDeposit_4token {
  function get_virtual_price() external view returns (uint);
  function add_liquidity(
    uint256[4] calldata amounts,
    uint256 min_mint_amount
  ) external;
  function remove_liquidity_imbalance(
    uint256[4] calldata amounts,
    uint256 max_burn_amount
  ) external;
  function remove_liquidity(
    uint256 _amount,
    uint256[4] calldata amounts
  ) external;
  function exchange(
    int128 from, int128 to, uint256 _from_amount, uint256 _min_to_amount
  ) external;
  function calc_token_amount(
    uint256[4] calldata amounts,
    bool deposit
  ) external view returns(uint);
}

//SPDX-License-Identifier: Unlicense
pragma solidity 0.6.12;

interface ICurveDeposit_4token_underlying {
  function get_virtual_price() external view returns (uint);
  function add_liquidity(
    uint256[4] calldata amounts,
    uint256 min_mint_amount,
    bool use_underlying
  ) external;
  function remove_liquidity_imbalance(
    uint256[4] calldata amounts,
    uint256 max_burn_amount,
    bool use_underlying
  ) external;
  function remove_liquidity(
    uint256 _amount,
    uint256[4] calldata amounts,
    bool use_underlying
  ) external;
  function exchange(
    int128 from, int128 to, uint256 _from_amount, uint256 _min_to_amount
  ) external;
  function exchange_underlying(
    int128 from, int128 to, uint256 _from_amount, uint256 _min_to_amount
  ) external;
  function calc_token_amount(
    uint256[4] calldata amounts,
    bool deposit
  ) external view returns(uint);
}

//SPDX-License-Identifier: Unlicense
pragma solidity 0.6.12;

interface ICurveDeposit_5token {
  function get_virtual_price() external view returns (uint);
  function add_liquidity(
    uint256[5] calldata amounts,
    uint256 min_mint_amount
  ) external;
  function remove_liquidity_imbalance(
    uint256[5] calldata amounts,
    uint256 max_burn_amount
  ) external;
  function remove_liquidity(
    uint256 _amount,
    uint256[5] calldata amounts
  ) external;
  function exchange(
    int128 from, int128 to, uint256 _from_amount, uint256 _min_to_amount
  ) external;
  function calc_token_amount(
    uint256[5] calldata amounts,
    bool deposit
  ) external view returns(uint);
}

//SPDX-License-Identifier: Unlicense
pragma solidity 0.6.12;

interface ICurveDeposit_5token_underlying {
  function get_virtual_price() external view returns (uint);
  function add_liquidity(
    uint256[5] calldata amounts,
    uint256 min_mint_amount,
    bool use_underlying
  ) external;
  function remove_liquidity_imbalance(
    uint256[5] calldata amounts,
    uint256 max_burn_amount,
    bool use_underlying
  ) external;
  function remove_liquidity(
    uint256 _amount,
    uint256[5] calldata amounts,
    bool use_underlying
  ) external;
  function exchange(
    int128 from, int128 to, uint256 _from_amount, uint256 _min_to_amount
  ) external;
  function exchange_underlying(
    int128 from, int128 to, uint256 _from_amount, uint256 _min_to_amount
  ) external;
  function calc_token_amount(
    uint256[5] calldata amounts,
    bool deposit
  ) external view returns(uint);
}

// SPDX-License-Identifier: MIT

pragma solidity >=0.6.0 <0.8.0;

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
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);

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

pragma solidity >=0.6.2 <0.8.0;

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
        // solhint-disable-next-line no-inline-assembly
        assembly { size := extcodesize(account) }
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

        // solhint-disable-next-line avoid-low-level-calls, avoid-call-value
        (bool success, ) = recipient.call{ value: amount }("");
        require(success, "Address: unable to send value, recipient may have reverted");
    }

    /**
     * @dev Performs a Solidity function call using a low level `call`. A
     * plain`call` is an unsafe replacement for a function call: use this
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
    function functionCall(address target, bytes memory data, string memory errorMessage) internal returns (bytes memory) {
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
    function functionCallWithValue(address target, bytes memory data, uint256 value) internal returns (bytes memory) {
        return functionCallWithValue(target, data, value, "Address: low-level call with value failed");
    }

    /**
     * @dev Same as {xref-Address-functionCallWithValue-address-bytes-uint256-}[`functionCallWithValue`], but
     * with `errorMessage` as a fallback revert reason when `target` reverts.
     *
     * _Available since v3.1._
     */
    function functionCallWithValue(address target, bytes memory data, uint256 value, string memory errorMessage) internal returns (bytes memory) {
        require(address(this).balance >= value, "Address: insufficient balance for call");
        require(isContract(target), "Address: call to non-contract");

        // solhint-disable-next-line avoid-low-level-calls
        (bool success, bytes memory returndata) = target.call{ value: value }(data);
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
    function functionStaticCall(address target, bytes memory data, string memory errorMessage) internal view returns (bytes memory) {
        require(isContract(target), "Address: static call to non-contract");

        // solhint-disable-next-line avoid-low-level-calls
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
    function functionDelegateCall(address target, bytes memory data, string memory errorMessage) internal returns (bytes memory) {
        require(isContract(target), "Address: delegate call to non-contract");

        // solhint-disable-next-line avoid-low-level-calls
        (bool success, bytes memory returndata) = target.delegatecall(data);
        return _verifyCallResult(success, returndata, errorMessage);
    }

    function _verifyCallResult(bool success, bytes memory returndata, string memory errorMessage) private pure returns(bytes memory) {
        if (success) {
            return returndata;
        } else {
            // Look for revert reason and bubble it up if present
            if (returndata.length > 0) {
                // The easiest way to bubble the revert reason is using memory via assembly

                // solhint-disable-next-line no-inline-assembly
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

pragma solidity >=0.6.2;

interface IUniswapV2Router01 {
    function factory() external pure returns (address);
    function WETH() external pure returns (address);

    function addLiquidity(
        address tokenA,
        address tokenB,
        uint amountADesired,
        uint amountBDesired,
        uint amountAMin,
        uint amountBMin,
        address to,
        uint deadline
    ) external returns (uint amountA, uint amountB, uint liquidity);
    function addLiquidityETH(
        address token,
        uint amountTokenDesired,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline
    ) external payable returns (uint amountToken, uint amountETH, uint liquidity);
    function removeLiquidity(
        address tokenA,
        address tokenB,
        uint liquidity,
        uint amountAMin,
        uint amountBMin,
        address to,
        uint deadline
    ) external returns (uint amountA, uint amountB);
    function removeLiquidityETH(
        address token,
        uint liquidity,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline
    ) external returns (uint amountToken, uint amountETH);
    function removeLiquidityWithPermit(
        address tokenA,
        address tokenB,
        uint liquidity,
        uint amountAMin,
        uint amountBMin,
        address to,
        uint deadline,
        bool approveMax, uint8 v, bytes32 r, bytes32 s
    ) external returns (uint amountA, uint amountB);
    function removeLiquidityETHWithPermit(
        address token,
        uint liquidity,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline,
        bool approveMax, uint8 v, bytes32 r, bytes32 s
    ) external returns (uint amountToken, uint amountETH);
    function swapExactTokensForTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external returns (uint[] memory amounts);
    function swapTokensForExactTokens(
        uint amountOut,
        uint amountInMax,
        address[] calldata path,
        address to,
        uint deadline
    ) external returns (uint[] memory amounts);
    function swapExactETHForTokens(uint amountOutMin, address[] calldata path, address to, uint deadline)
        external
        payable
        returns (uint[] memory amounts);
    function swapTokensForExactETH(uint amountOut, uint amountInMax, address[] calldata path, address to, uint deadline)
        external
        returns (uint[] memory amounts);
    function swapExactTokensForETH(uint amountIn, uint amountOutMin, address[] calldata path, address to, uint deadline)
        external
        returns (uint[] memory amounts);
    function swapETHForExactTokens(uint amountOut, address[] calldata path, address to, uint deadline)
        external
        payable
        returns (uint[] memory amounts);

    function quote(uint amountA, uint reserveA, uint reserveB) external pure returns (uint amountB);
    function getAmountOut(uint amountIn, uint reserveIn, uint reserveOut) external pure returns (uint amountOut);
    function getAmountIn(uint amountOut, uint reserveIn, uint reserveOut) external pure returns (uint amountIn);
    function getAmountsOut(uint amountIn, address[] calldata path) external view returns (uint[] memory amounts);
    function getAmountsIn(uint amountOut, address[] calldata path) external view returns (uint[] memory amounts);
}

// SPDX-License-Identifier: MIT

// solhint-disable-next-line compiler-version
pragma solidity >=0.4.24 <0.8.0;

import "../utils/AddressUpgradeable.sol";

/**
 * @dev This is a base contract to aid in writing upgradeable contracts, or any kind of contract that will be deployed
 * behind a proxy. Since a proxied contract can't have a constructor, it's common to move constructor logic to an
 * external initializer function, usually called `initialize`. It then becomes necessary to protect this initializer
 * function so it can only be called once. The {initializer} modifier provided by this contract will have this effect.
 *
 * TIP: To avoid leaving the proxy in an uninitialized state, the initializer function should be called as early as
 * possible by providing the encoded function call as the `_data` argument to {UpgradeableProxy-constructor}.
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
        require(_initializing || _isConstructor() || !_initialized, "Initializable: contract is already initialized");

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

    /// @dev Returns true if and only if the function is running in the constructor
    function _isConstructor() private view returns (bool) {
        return !AddressUpgradeable.isContract(address(this));
    }
}

//SPDX-License-Identifier: Unlicense

pragma solidity 0.6.12;

import "@openzeppelin/contracts-upgradeable/proxy/Initializable.sol";

contract BaseUpgradeableStrategyStorage {

  bytes32 internal constant _UNDERLYING_SLOT = 0xa1709211eeccf8f4ad5b6700d52a1a9525b5f5ae1e9e5f9e5a0c2fc23c86e530;
  bytes32 internal constant _VAULT_SLOT = 0xefd7c7d9ef1040fc87e7ad11fe15f86e1d11e1df03c6d7c87f7e1f4041f08d41;

  bytes32 internal constant _REWARD_TOKEN_SLOT = 0xdae0aafd977983cb1e78d8f638900ff361dc3c48c43118ca1dd77d1af3f47bbf;
  bytes32 internal constant _REWARD_POOL_SLOT = 0x3d9bb16e77837e25cada0cf894835418b38e8e18fbec6cfd192eb344bebfa6b8;
  bytes32 internal constant _SELL_FLOOR_SLOT = 0xc403216a7704d160f6a3b5c3b149a1226a6080f0a5dd27b27d9ba9c022fa0afc;
  bytes32 internal constant _SELL_SLOT = 0x656de32df98753b07482576beb0d00a6b949ebf84c066c765f54f26725221bb6;
  bytes32 internal constant _PAUSED_INVESTING_SLOT = 0xa07a20a2d463a602c2b891eb35f244624d9068572811f63d0e094072fb54591a;

  bytes32 internal constant _PROFIT_SHARING_NUMERATOR_SLOT = 0xe3ee74fb7893020b457d8071ed1ef76ace2bf4903abd7b24d3ce312e9c72c029;
  bytes32 internal constant _PROFIT_SHARING_DENOMINATOR_SLOT = 0x0286fd414602b432a8c80a0125e9a25de9bba96da9d5068c832ff73f09208a3b;

  bytes32 internal constant _NEXT_IMPLEMENTATION_SLOT = 0x29f7fcd4fe2517c1963807a1ec27b0e45e67c60a874d5eeac7a0b1ab1bb84447;
  bytes32 internal constant _NEXT_IMPLEMENTATION_TIMESTAMP_SLOT = 0x414c5263b05428f1be1bfa98e25407cc78dd031d0d3cd2a2e3d63b488804f22e;
  bytes32 internal constant _NEXT_IMPLEMENTATION_DELAY_SLOT = 0x82b330ca72bcd6db11a26f10ce47ebcfe574a9c646bccbc6f1cd4478eae16b31;

  constructor() public {
    assert(_UNDERLYING_SLOT == bytes32(uint256(keccak256("eip1967.strategyStorage.underlying")) - 1));
    assert(_VAULT_SLOT == bytes32(uint256(keccak256("eip1967.strategyStorage.vault")) - 1));
    assert(_REWARD_TOKEN_SLOT == bytes32(uint256(keccak256("eip1967.strategyStorage.rewardToken")) - 1));
    assert(_REWARD_POOL_SLOT == bytes32(uint256(keccak256("eip1967.strategyStorage.rewardPool")) - 1));
    assert(_SELL_FLOOR_SLOT == bytes32(uint256(keccak256("eip1967.strategyStorage.sellFloor")) - 1));
    assert(_SELL_SLOT == bytes32(uint256(keccak256("eip1967.strategyStorage.sell")) - 1));
    assert(_PAUSED_INVESTING_SLOT == bytes32(uint256(keccak256("eip1967.strategyStorage.pausedInvesting")) - 1));

    assert(_PROFIT_SHARING_NUMERATOR_SLOT == bytes32(uint256(keccak256("eip1967.strategyStorage.profitSharingNumerator")) - 1));
    assert(_PROFIT_SHARING_DENOMINATOR_SLOT == bytes32(uint256(keccak256("eip1967.strategyStorage.profitSharingDenominator")) - 1));

    assert(_NEXT_IMPLEMENTATION_SLOT == bytes32(uint256(keccak256("eip1967.strategyStorage.nextImplementation")) - 1));
    assert(_NEXT_IMPLEMENTATION_TIMESTAMP_SLOT == bytes32(uint256(keccak256("eip1967.strategyStorage.nextImplementationTimestamp")) - 1));
    assert(_NEXT_IMPLEMENTATION_DELAY_SLOT == bytes32(uint256(keccak256("eip1967.strategyStorage.nextImplementationDelay")) - 1));
  }

  function _setUnderlying(address _address) internal {
    setAddress(_UNDERLYING_SLOT, _address);
  }

  function underlying() public virtual view returns (address) {
    return getAddress(_UNDERLYING_SLOT);
  }

  function _setRewardPool(address _address) internal {
    setAddress(_REWARD_POOL_SLOT, _address);
  }

  function rewardPool() public view returns (address) {
    return getAddress(_REWARD_POOL_SLOT);
  }

  function _setRewardToken(address _address) internal {
    setAddress(_REWARD_TOKEN_SLOT, _address);
  }

  function rewardToken() public view returns (address) {
    return getAddress(_REWARD_TOKEN_SLOT);
  }

  function _setVault(address _address) internal {
    setAddress(_VAULT_SLOT, _address);
  }

  function vault() public virtual view returns (address) {
    return getAddress(_VAULT_SLOT);
  }

  // a flag for disabling selling for simplified emergency exit
  function _setSell(bool _value) internal {
    setBoolean(_SELL_SLOT, _value);
  }

  function sell() public view returns (bool) {
    return getBoolean(_SELL_SLOT);
  }

  function _setPausedInvesting(bool _value) internal {
    setBoolean(_PAUSED_INVESTING_SLOT, _value);
  }

  function pausedInvesting() public view returns (bool) {
    return getBoolean(_PAUSED_INVESTING_SLOT);
  }

  function _setSellFloor(uint256 _value) internal {
    setUint256(_SELL_FLOOR_SLOT, _value);
  }

  function sellFloor() public view returns (uint256) {
    return getUint256(_SELL_FLOOR_SLOT);
  }

  function _setProfitSharingNumerator(uint256 _value) internal {
    setUint256(_PROFIT_SHARING_NUMERATOR_SLOT, _value);
  }

  function profitSharingNumerator() public view returns (uint256) {
    return getUint256(_PROFIT_SHARING_NUMERATOR_SLOT);
  }

  function _setProfitSharingDenominator(uint256 _value) internal {
    setUint256(_PROFIT_SHARING_DENOMINATOR_SLOT, _value);
  }

  function profitSharingDenominator() public view returns (uint256) {
    return getUint256(_PROFIT_SHARING_DENOMINATOR_SLOT);
  }

  // upgradeability

  function _setNextImplementation(address _address) internal {
    setAddress(_NEXT_IMPLEMENTATION_SLOT, _address);
  }

  function nextImplementation() public view returns (address) {
    return getAddress(_NEXT_IMPLEMENTATION_SLOT);
  }

  function _setNextImplementationTimestamp(uint256 _value) internal {
    setUint256(_NEXT_IMPLEMENTATION_TIMESTAMP_SLOT, _value);
  }

  function nextImplementationTimestamp() public view returns (uint256) {
    return getUint256(_NEXT_IMPLEMENTATION_TIMESTAMP_SLOT);
  }

  function _setNextImplementationDelay(uint256 _value) internal {
    setUint256(_NEXT_IMPLEMENTATION_DELAY_SLOT, _value);
  }

  function nextImplementationDelay() public view returns (uint256) {
    return getUint256(_NEXT_IMPLEMENTATION_DELAY_SLOT);
  }

  function setBoolean(bytes32 slot, bool _value) internal {
    setUint256(slot, _value ? 1 : 0);
  }

  function getBoolean(bytes32 slot) internal view returns (bool) {
    return (getUint256(slot) == 1);
  }

  function setAddress(bytes32 slot, address _address) internal {
    // solhint-disable-next-line no-inline-assembly
    assembly {
      sstore(slot, _address)
    }
  }

  function setUint256(bytes32 slot, uint256 _value) internal {
    // solhint-disable-next-line no-inline-assembly
    assembly {
      sstore(slot, _value)
    }
  }

  function getAddress(bytes32 slot) internal view returns (address str) {
    // solhint-disable-next-line no-inline-assembly
    assembly {
      str := sload(slot)
    }
  }

  function getUint256(bytes32 slot) internal view returns (uint256 str) {
    // solhint-disable-next-line no-inline-assembly
    assembly {
      str := sload(slot)
    }
  }
}

//SPDX-License-Identifier: Unlicense

pragma solidity 0.6.12;

import "./GovernableInit.sol";

// A clone of Governable supporting the Initializable interface and pattern
contract ControllableInit is GovernableInit {

  constructor() public {
  }

  function initialize(address _storage) public override initializer {
    GovernableInit.initialize(_storage);
  }

  modifier onlyController() {
    require(Storage(_storage()).isController(msg.sender), "Not a controller");
    _;
  }

  modifier onlyControllerOrGovernance(){
    require((Storage(_storage()).isController(msg.sender) || Storage(_storage()).isGovernance(msg.sender)),
      "The caller must be controller or governance");
    _;
  }

  function controller() public view returns (address) {
    return Storage(_storage()).controller();
  }
}

//SPDX-License-Identifier: Unlicense

pragma solidity 0.6.12;

interface IController {
    // [Grey list]
    // An EOA can safely interact with the system no matter what.
    // If you're using Metamask, you're using an EOA.
    // Only smart contracts may be affected by this grey list.
    //
    // This contract will not be able to ban any EOA from the system
    // even if an EOA is being added to the greyList, he/she will still be able
    // to interact with the whole system as if nothing happened.
    // Only smart contracts will be affected by being added to the greyList.
    // This grey list is only used in Vault.sol, see the code there for reference
    function greyList(address _target) external view returns(bool);

    function addVaultAndStrategy(address _vault, address _strategy) external;
    function doHardWork(address _vault) external;

    function salvage(address _token, uint256 amount) external;
    function salvageStrategy(address _strategy, address _token, uint256 amount) external;

    function notifyFee(address _underlying, uint256 fee) external;
    function profitSharingNumerator() external view returns (uint256);
    function profitSharingDenominator() external view returns (uint256);

    function feeRewardForwarder() external view returns(address);
    function setFeeRewardForwarder(address _value) external;
}

//SPDX-License-Identifier: Unlicense

pragma solidity 0.6.12;

interface IFeeRewardForwarder {
    function poolNotifyFixedTarget(address _token, uint256 _amount) external;
    function profitSharingPool() external view returns (address);
    function setConversionPath(address[] calldata _route, address[] calldata _routers) external;
}

// SPDX-License-Identifier: MIT

pragma solidity >=0.6.2 <0.8.0;

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
        // solhint-disable-next-line no-inline-assembly
        assembly { size := extcodesize(account) }
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

        // solhint-disable-next-line avoid-low-level-calls, avoid-call-value
        (bool success, ) = recipient.call{ value: amount }("");
        require(success, "Address: unable to send value, recipient may have reverted");
    }

    /**
     * @dev Performs a Solidity function call using a low level `call`. A
     * plain`call` is an unsafe replacement for a function call: use this
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
    function functionCall(address target, bytes memory data, string memory errorMessage) internal returns (bytes memory) {
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
    function functionCallWithValue(address target, bytes memory data, uint256 value) internal returns (bytes memory) {
        return functionCallWithValue(target, data, value, "Address: low-level call with value failed");
    }

    /**
     * @dev Same as {xref-Address-functionCallWithValue-address-bytes-uint256-}[`functionCallWithValue`], but
     * with `errorMessage` as a fallback revert reason when `target` reverts.
     *
     * _Available since v3.1._
     */
    function functionCallWithValue(address target, bytes memory data, uint256 value, string memory errorMessage) internal returns (bytes memory) {
        require(address(this).balance >= value, "Address: insufficient balance for call");
        require(isContract(target), "Address: call to non-contract");

        // solhint-disable-next-line avoid-low-level-calls
        (bool success, bytes memory returndata) = target.call{ value: value }(data);
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
    function functionStaticCall(address target, bytes memory data, string memory errorMessage) internal view returns (bytes memory) {
        require(isContract(target), "Address: static call to non-contract");

        // solhint-disable-next-line avoid-low-level-calls
        (bool success, bytes memory returndata) = target.staticcall(data);
        return _verifyCallResult(success, returndata, errorMessage);
    }

    function _verifyCallResult(bool success, bytes memory returndata, string memory errorMessage) private pure returns(bytes memory) {
        if (success) {
            return returndata;
        } else {
            // Look for revert reason and bubble it up if present
            if (returndata.length > 0) {
                // The easiest way to bubble the revert reason is using memory via assembly

                // solhint-disable-next-line no-inline-assembly
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

//SPDX-License-Identifier: Unlicense

pragma solidity 0.6.12;

import "@openzeppelin/contracts-upgradeable/proxy/Initializable.sol";
import "./Storage.sol";

// A clone of Governable supporting the Initializable interface and pattern
contract GovernableInit is Initializable {

  bytes32 internal constant _STORAGE_SLOT = 0xa7ec62784904ff31cbcc32d09932a58e7f1e4476e1d041995b37c917990b16dc;

  modifier onlyGovernance() {
    require(Storage(_storage()).isGovernance(msg.sender), "Not governance");
    _;
  }

  constructor() public {
    assert(_STORAGE_SLOT == bytes32(uint256(keccak256("eip1967.governableInit.storage")) - 1));
  }

  function initialize(address _store) public virtual initializer {
    _setStorage(_store);
  }

  function _setStorage(address newStorage) private {
    bytes32 slot = _STORAGE_SLOT;
    // solhint-disable-next-line no-inline-assembly
    assembly {
      sstore(slot, newStorage)
    }
  }

  function setStorage(address _store) public onlyGovernance {
    require(_store != address(0), "new storage shouldn't be empty");
    _setStorage(_store);
  }

  function _storage() internal view returns (address str) {
    bytes32 slot = _STORAGE_SLOT;
    // solhint-disable-next-line no-inline-assembly
    assembly {
      str := sload(slot)
    }
  }

  function governance() public view returns (address) {
    return Storage(_storage()).governance();
  }
}

//SPDX-License-Identifier: Unlicense

pragma solidity 0.6.12;

contract Storage {

  address public governance;
  address public controller;

  constructor() public {
    governance = msg.sender;
  }

  modifier onlyGovernance() {
    require(isGovernance(msg.sender), "Not governance");
    _;
  }

  function setGovernance(address _governance) public onlyGovernance {
    require(_governance != address(0), "new governance shouldn't be empty");
    governance = _governance;
  }

  function setController(address _controller) public onlyGovernance {
    require(_controller != address(0), "new controller shouldn't be empty");
    controller = _controller;
  }

  function isGovernance(address account) public view returns (bool) {
    return account == governance;
  }

  function isController(address account) public view returns (bool) {
    return account == controller;
  }
}