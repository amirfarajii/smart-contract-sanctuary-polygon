/*
https://polygonscan.com/tx/0xa18c711f1f527c12f16e966c3212ca2d7c59d528c5e34759fd8b4cd32e6703da
Deposit Tx

https://polygonscan.com/tx/0x03619d43dc59e8e7be6cbddb2a2a38d37de0b32f6257e8d6e4d9794f1c10361b
Harvest Tx

maybe in sushi farm, if amount to deposit is zero, then it checks if the user is in the farm and if they are then it harvests the farm?
maybe it first checks if harvest should be called(does the silo have a position in the farm), then it checks if deposit should be called

or simply have a deposit sushi farm action, and then a harvest one
*/

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "../BaseSiloAction.sol";
import "../../../interfaces/IMaiVault.sol";
import "../../../interfaces/ISilo.sol";
import "../../../interfaces/IAction.sol";
import "../../../interfaces/IERC20Decimals.sol";
import "../../../interfaces/IPriceFeed.sol";

/*          
                         Mai Vault Front IO
                         ______________
         Collateral In->[              ]->Loan Token Out
        Carrry Through->[              ]->Carrry Through
              RESERVED->[              ]->QI
         Loan to repay->[______________]->Amount of Loan token to repay
Note: RESERVED position is based off the _position uint input

*/
contract MaiVaultFront is BaseSiloAction{

    address constant public QI = 0x580A84C73811E1839F75d86d75d88cCa0c241fF4;//polygon

    /// @dev ratioRange values must have same decimals as miMatic(18)
    constructor(string memory _name, address _siloFactory, address[4] memory _inputs, address[4] memory _outputs, address _qiVault, uint[3] memory _ratioRange, uint _position){
        name = _name;
        metaData = "address[4],address[4],address,uint[3],uint";
        factory = _siloFactory;
        //configurationData = abi.encode(_inputs, _outputs, _qiVault, _ratioRange);
    }

    function enter(address implementation, bytes memory configuration, bytes memory inputData) public override returns(uint[4] memory outputAmounts){
        bytes memory storedConfig = IAction(implementation).getConfig();
        address maiVault;
        address[4] memory input;
        uint[3] memory ratioRange;
        uint[4] memory inputAmounts = abi.decode(inputData, (uint[4]));
        uint vaultId;
        {
            uint position;
            if(storedConfig.length > 0){//if config is set in strategy use it
                (input,,maiVault, ratioRange, position) = abi.decode(storedConfig, (address[4],address[4],address, uint[3],uint));
            }
            else{
               (input,,maiVault, ratioRange, position) = abi.decode(configuration, (address[4],address[4],address, uint[3],uint));
            }
            //carry through 1,2
            if(position == 1){
                outputAmounts[2] = inputAmounts[2];
            }
            else{
                outputAmounts[1] = inputAmounts[1];
            }
            outputAmounts[position] = IERC20Decimals(QI).balanceOf(address(this));
            outputAmounts[position] = _takeFee(implementation, outputAmounts[position], QI);
        }
        outputAmounts[1] = inputAmounts[1];
        outputAmounts[2] = inputAmounts[2];
        IMaiVault vault = IMaiVault(maiVault);
        IERC20Decimals collateral = IERC20Decimals(vault.collateral());
        IERC20Decimals miMatic = IERC20Decimals(vault.mai());
        {
            if(vault.balanceOf(address(this)) == 0){
                //create a vault
                vaultId = vault.createVault();
                //silo.writeStoreUint(0, implementation, vaultId);
            }
            else{
                //vaultId = silo.readStoreUint(implementation, 0);
                vaultId = vault.tokenOfOwnerByIndex(address(this), 0);
            }
        }
        
        //deposit any collateral into the vault
        if(inputAmounts[0] > 0){
            IERC20Decimals(input[0]).approve(maiVault, inputAmounts[0]);
            vault.depositCollateral(vaultId, inputAmounts[0]);
        }

        //repay debt
        if(inputAmounts[3] > 0){
            if(inputAmounts[3] > vault.vaultDebt(vaultId)){//just repay the debt
                miMatic.approve(maiVault, vault.vaultDebt(vaultId));
                vault.payBackToken(vaultId, vault.vaultDebt(vaultId));
            }
            else{
                miMatic.approve(maiVault, inputAmounts[3]);
                vault.payBackToken(vaultId, inputAmounts[3]);
            }
        }
        //check the Collateral to Debt Ratio
        IPriceFeed oracle = IPriceFeed(vault.ethPriceSource());
        uint collateralValue = (vault.vaultCollateral(vaultId) * oracle.latestAnswer()) / (10**oracle.decimals());//in terms of collateral decimals
        collateralValue = ((10**miMatic.decimals()) * collateralValue) / (10**collateral.decimals()); //convert to miMatic decimals
        uint debt = vault.vaultDebt(vaultId); //in terms of miMatic decimals
        if(debt > 0){
            uint CDratio = ((10**miMatic.decimals()) * collateralValue)/debt;//10**18 is to match zeroes in ratioRange
            if(CDratio < ratioRange[0]){
                //need to tell next farm to withdraw tokens to pay back loan
                //calculate amount to repay.
                uint idealDebt = ((10**miMatic.decimals()) * collateralValue) / ratioRange[1];//in miMatic decimals
                outputAmounts[3] = debt - idealDebt;
            }

            else if(CDratio > ratioRange[2]){
                //need to borrow more
                //calculate amount to borrow
                uint idealDebt = ((10**miMatic.decimals()) * collateralValue) / ratioRange[1];
                if((idealDebt - debt) <= vault.getDebtCeiling()){
                    vault.borrowToken(vaultId, (idealDebt - debt));
                    outputAmounts[0] = (idealDebt - debt);
                }
                else if(vault.getDebtCeiling() != 0){
                    vault.borrowToken(vaultId, vault.getDebtCeiling());
                    outputAmounts[0] = vault.getDebtCeiling();
                }
            }
        }
        else {//borrow initial loan
            uint idealDebt = ((10**miMatic.decimals()) * collateralValue) / ratioRange[1];
            if(idealDebt <= vault.getDebtCeiling()){
                vault.borrowToken(vaultId, idealDebt);
                outputAmounts[0] = idealDebt;
            }
            else if(vault.getDebtCeiling() != 0){
                vault.borrowToken(vaultId, vault.getDebtCeiling());
                outputAmounts[0] = vault.getDebtCeiling();
            }
        }
    }

    function exit(address implementation, bytes memory configuration, bytes memory outputData) public override returns(uint[4] memory outputAmounts){
        bytes memory storedConfig = IAction(implementation).getConfig();
        address maiVault;
        address[4] memory input;
        uint[3] memory ratioRange;

        if(storedConfig.length > 0){//if config is set in strategy use it
            (input,,maiVault, ratioRange) = abi.decode(storedConfig, (address[4],address[4],address, uint[3]));
        }
        else{
           (input,,maiVault, ratioRange) = abi.decode(configuration, (address[4],address[4],address, uint[3]));
        }
        uint[4] memory inputAmounts = abi.decode(outputData, (uint[4]));
        uint vaultId;
        IMaiVault vault = IMaiVault(maiVault);
        //IERC20Decimals collateral = IERC20Decimals(vault.collateral());
        IERC20Decimals miMatic = IERC20Decimals(vault.mai());
        {/// @dev might want to change this so that it stores the vault Id it created, and reads from that? Else someone could send a vault token to this silo to try and screw with it
            if(vault.balanceOf(address(this)) == 0){
                //create a vault
                vaultId = vault.createVault();
                //silo.writeStoreUint(0, implementation, vaultId);
            }
            else{
                //vaultId = silo.readStoreUint(implementation, 0);
                vaultId = vault.tokenOfOwnerByIndex(address(this), 0);
            }
        }
        //repay debt
        if(inputAmounts[3] > 0){
            if(inputAmounts[3] > vault.vaultDebt(vaultId)){//just repay the debt
                miMatic.approve(maiVault, vault.vaultDebt(vaultId));
                vault.payBackToken(vaultId, vault.vaultDebt(vaultId));
            }
            else{
                miMatic.approve(maiVault, inputAmounts[3]);
                vault.payBackToken(vaultId, inputAmounts[3]);
            }
        }
        ///@dev maybe add a check to do this if any collateral is in the vault?
        //remove as much collateral possible
        if(vault.checkCollateralPercentage(vaultId) > vault._minimumCollateralPercentage()){
            IERC20Decimals collateral = IERC20Decimals(vault.collateral());
            uint dollarValueToLeave = (vault.vaultDebt(vaultId) * (vault._minimumCollateralPercentage() + 5))/100; //minimum collateral percentage is based off 2 decimals, also add an extra 5 to the min %
            IPriceFeed oracle = IPriceFeed(vault.ethPriceSource());

            uint collateralToLeave = (dollarValueToLeave * (10**oracle.decimals()))/oracle.latestAnswer();//in terms of miMatic decimals
            collateralToLeave = (10**collateral.decimals() * collateralToLeave) / (10**miMatic.decimals());//in terms of collateral
            uint amountToWithdraw = vault.vaultCollateral(vaultId) - collateralToLeave;
            vault.withdrawCollateral(vaultId, amountToWithdraw);
        }
        else if(vault.checkCollateralPercentage(vaultId) == 0){//means the vault has paid off all debt
            vault.withdrawCollateral(vaultId, vault.vaultCollateral(vaultId));
        }
    }

    function createConfig(address[4] memory _inputs, address[4] memory _outputs, address _qiVault, uint[3] memory _ratioRange, uint _position) public pure returns(bytes memory configData){
        configData = abi.encode(_inputs, _outputs, _qiVault, _ratioRange, _position);
    }

    //TODO check if ratio range is in miMatic decimals
    function validateConfig(bytes memory configData) public view override returns(bool){
        address maiVault;
        address[4] memory input;
        uint[3] memory ratioRange;
        uint position;
        (input,,maiVault, ratioRange, position) = abi.decode(configData, (address[4],address[4],address, uint[3],uint));
        if(input[position] != address(0)){//make sure position spot is free
            return false;
        }
        if(position == 0 || position == 3){//needs to be 1 or 2
            return false;
        }
        return true;
    }
    ///@dev added in logic to check debt ceiling when borrowing more
    function checkMaintain(bytes memory configuration) public override view returns(bool){
        bytes memory storedConfig = configurationData;
        address maiVault;
        uint[3] memory ratioRange;
        //uint oracleIndex;

        if(storedConfig.length > 0){//if config is set in strategy use it
            (,,maiVault, ratioRange) = abi.decode(storedConfig, (address[4],address[4],address, uint[3]));
        }
        else{
           (,,maiVault, ratioRange) = abi.decode(configuration, (address[4],address[4],address, uint[3]));
        }
        uint vaultId;
        IMaiVault vault = IMaiVault(maiVault);
        IERC20Decimals collateral = IERC20Decimals(vault.collateral());
        IERC20Decimals miMatic = IERC20Decimals(vault.mai());
        {
            if(vault.balanceOf(msg.sender) == 0){
                return false;
            }
            else{
                //vaultId = silo.readStoreUint(implementation, 0);
                vaultId = vault.tokenOfOwnerByIndex(msg.sender, 0);
            }
        }

        //check the Collateral to Debt Ratio
        IPriceFeed oracle = IPriceFeed(vault.ethPriceSource());
        uint collateralValue = (vault.vaultCollateral(vaultId) * oracle.latestAnswer()) / (10**oracle.decimals());//in terms of collateral decimals
        collateralValue = ((10**miMatic.decimals()) * collateralValue) / (10**collateral.decimals()); //convert to miMatic decimals
        uint debt = vault.vaultDebt(vaultId); //in terms of miMatic decimals
        if(debt > 0){
            uint CDratio = ((10**miMatic.decimals()) * collateralValue)/debt;
            if(CDratio < ratioRange[0]){
                return true;
            }
            else if(CDratio > ratioRange[2]){//minimum debt ceiling value
                //check how much would be borrowed
                uint amountToBorrow = ((10**miMatic.decimals()) * collateralValue)/ratioRange[1] - debt;
                if(amountToBorrow <= vault.getDebtCeiling()){
                    return true;
                }
                else{
                    return false;
                }
            }
            else{
                return false;
            }
        }
        else{
            return false;
        }
    }
}

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "../../interfaces/ISiloFactory.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "../../interfaces/IAction.sol";

//swap actions should check and make sure the amount is enough to even make a swap
//if an action charges a fee, then it should take it in here
//TODO each action needs to have some fee thing worked out
//TODO each action should have a view function that allows the front end to enter the required config data(EX: input tokens, outputs tokens, farm address), then returns the abi encoded config data
abstract contract BaseSiloAction {

    bytes public configurationData;//if not set on deployment, then they use the value in the Silo
    string public name;
    uint constant public MAX_TRANSIENT_VARIABLES = 4;
    address public factory;
    uint constant public FEE_DECIMALS = 10000;
    string public metaData;

    function enter(address implementation, bytes memory configuration, bytes memory inputData) public virtual returns(uint[4] memory);

    function exit(address implementation, bytes memory configuration, bytes memory outputData) public virtual returns(uint[4] memory);

    function getConfig() public view returns(bytes memory){
        return configurationData;
    }

    function getFactory() public view returns(address){
        return factory;
    }

    function getDecimals() public view returns(uint){
        return FEE_DECIMALS;
    }

    function getMetaData() public view returns(string memory){
        return metaData;
    }

    function checkMaintain(bytes memory configuration) public view virtual returns(bool);

    function _takeFee(address _action, uint _gains, address _token) internal virtual returns(uint remaining){
        (uint fee, address recipient) = ISiloFactory(IAction(_action).getFactory()).getFeeInfo( _action);
        uint feeToTake = _gains * fee / IAction(_action).getDecimals();
        if(feeToTake > 0){
            SafeERC20.safeTransfer(IERC20(_token), recipient, feeToTake);
            remaining = _gains - feeToTake;    
        }
        else{
            remaining = _gains;
        }
    }

    //TODO add functions so that APR is automatically updated as people use the action, or even just stats? Like how much GFI has been swapped for with this action?
    function validateConfig(bytes memory configData) public view virtual returns(bool); 
}

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

interface IMaiVault {
    function balanceOf(address _address) external view returns(uint);
    function createVault() external returns(uint); //returns the vault id
    function getDebtCeiling() external view returns(uint); //how much more Mai can be minted from the vault
    function checkCollateralPercentage(uint vaultId) external view returns(uint); //Collateral / Debt per with 2 decimals ie 199 is 199%
    function depositCollateral(uint256 vaultID, uint256 amount) external;
    function borrowToken(uint256 vaultID, uint256 amount) external;
    function payBackToken(uint256 vaultID, uint256 amount) external;
    function getEthPriceSource() external view returns(uint);
    function getTokenPriceSource() external view returns(uint);
    function vaultDebt(uint id) external view returns(uint);
    function vaultCollateral(uint id) external view returns(uint);
    function ethPriceSource() external view returns(address);
    function mai() external view returns(address);
    function collateral() external view returns(address);
    function tokenOfOwnerByIndex(address _owner, uint _index) external view returns(uint);
    function _minimumCollateralPercentage() external view returns(uint);
    function withdrawCollateral(uint vaultId, uint amount) external;
}

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

struct PriceOracle{
        address oracle;
        uint actionPrice;
    }

interface ISilo{
    function initialize(uint siloID) external;
    function Deposit() external;
    function Withdraw() external;
    function Maintain() external;
    function ExitSilo(address caller) external;
    function adminCall(address target, bytes memory data) external;
    function setStrategy(address[4] memory input, bytes[] memory _configurationData, address[] memory _implementations) external;
    function getConfig() external view returns(bytes memory config);
    function withdrawToken(address token, address recipient) external;
    function adjustSiloDelay(uint _newDelay) external;
    function checkUpkeep(bytes calldata checkData) external view returns (bool upkeepNeeded, bytes memory performData);
    function performUpkeep(bytes calldata performData) external;
    function siloDelay() external view returns(uint);
    function lastTimeMaintained() external view returns(uint);
    function setName(string memory name) external;
    function inStrategy() external view returns(bool);
}

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

interface IAction{
    function getConfig() external view returns(bytes memory config);
    function checkMaintain(bytes memory configuration) external view returns(bool);
    function validateConfig(bytes memory configData) external view returns(bool); 
    function getMetaData() external view returns(string memory);
    function getFactory() external view returns(address);
    function getDecimals() external view returns(uint);
}

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

/**
 * @dev Interface of the ERC20 standard as defined in the EIP.
 */
interface IERC20Decimals {
    /**
     * @dev Returns the amount of tokens in existence.
     */
    function totalSupply() external view returns (uint256);


    function decimals() external view returns(uint256);

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

pragma solidity ^0.8.0;

interface IPriceFeed {
    function latestAnswer() external view returns(uint);
    function decimals() external view returns(uint); //
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/extensions/IERC721Enumerable.sol";

interface ISiloFactory is IERC721Enumerable{
    function tokenMinimum(address _token) external view returns(uint _minimum);
    function balanceOf(address _owner) external view returns(uint);
    function tokenOfOwnerByIndex(address owner, uint256 index) external view returns (uint256);
    function managerFactory() external view returns(address);
    function siloMap(uint _id) external view returns(address);
    function tierManager() external view returns(address);
    function ownerOf(uint _id) external view returns(address);
    function siloToId(address silo) external view returns(uint);
    function CreateSilo(address recipient) external returns(uint);
    function setActionStack(uint siloID, address[4] memory input, address[] memory _implementations, bytes[] memory _configurationData) external;
    function Withdraw(uint siloID) external;
    function getFeeInfo(address _action) external view returns(uint fee, address recipient);
    function strategyMaxGas() external view returns(uint);
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.5.0) (token/ERC20/IERC20.sol)

pragma solidity ^0.8.0;

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
// OpenZeppelin Contracts v4.4.1 (token/ERC20/utils/SafeERC20.sol)

pragma solidity ^0.8.0;

import "../IERC20.sol";
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
// OpenZeppelin Contracts (last updated v4.5.0) (token/ERC721/extensions/IERC721Enumerable.sol)

pragma solidity ^0.8.0;

import "../IERC721.sol";

/**
 * @title ERC-721 Non-Fungible Token Standard, optional enumeration extension
 * @dev See https://eips.ethereum.org/EIPS/eip-721
 */
interface IERC721Enumerable is IERC721 {
    /**
     * @dev Returns the total amount of tokens stored by the contract.
     */
    function totalSupply() external view returns (uint256);

    /**
     * @dev Returns a token ID owned by `owner` at a given `index` of its token list.
     * Use along with {balanceOf} to enumerate all of ``owner``'s tokens.
     */
    function tokenOfOwnerByIndex(address owner, uint256 index) external view returns (uint256);

    /**
     * @dev Returns a token ID at a given `index` of all the tokens stored by the contract.
     * Use along with {totalSupply} to enumerate all tokens.
     */
    function tokenByIndex(uint256 index) external view returns (uint256);
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.1 (token/ERC721/IERC721.sol)

pragma solidity ^0.8.0;

import "../../utils/introspection/IERC165.sol";

/**
 * @dev Required interface of an ERC721 compliant contract.
 */
interface IERC721 is IERC165 {
    /**
     * @dev Emitted when `tokenId` token is transferred from `from` to `to`.
     */
    event Transfer(address indexed from, address indexed to, uint256 indexed tokenId);

    /**
     * @dev Emitted when `owner` enables `approved` to manage the `tokenId` token.
     */
    event Approval(address indexed owner, address indexed approved, uint256 indexed tokenId);

    /**
     * @dev Emitted when `owner` enables or disables (`approved`) `operator` to manage all of its assets.
     */
    event ApprovalForAll(address indexed owner, address indexed operator, bool approved);

    /**
     * @dev Returns the number of tokens in ``owner``'s account.
     */
    function balanceOf(address owner) external view returns (uint256 balance);

    /**
     * @dev Returns the owner of the `tokenId` token.
     *
     * Requirements:
     *
     * - `tokenId` must exist.
     */
    function ownerOf(uint256 tokenId) external view returns (address owner);

    /**
     * @dev Safely transfers `tokenId` token from `from` to `to`, checking first that contract recipients
     * are aware of the ERC721 protocol to prevent tokens from being forever locked.
     *
     * Requirements:
     *
     * - `from` cannot be the zero address.
     * - `to` cannot be the zero address.
     * - `tokenId` token must exist and be owned by `from`.
     * - If the caller is not `from`, it must be have been allowed to move this token by either {approve} or {setApprovalForAll}.
     * - If `to` refers to a smart contract, it must implement {IERC721Receiver-onERC721Received}, which is called upon a safe transfer.
     *
     * Emits a {Transfer} event.
     */
    function safeTransferFrom(
        address from,
        address to,
        uint256 tokenId
    ) external;

    /**
     * @dev Transfers `tokenId` token from `from` to `to`.
     *
     * WARNING: Usage of this method is discouraged, use {safeTransferFrom} whenever possible.
     *
     * Requirements:
     *
     * - `from` cannot be the zero address.
     * - `to` cannot be the zero address.
     * - `tokenId` token must be owned by `from`.
     * - If the caller is not `from`, it must be approved to move this token by either {approve} or {setApprovalForAll}.
     *
     * Emits a {Transfer} event.
     */
    function transferFrom(
        address from,
        address to,
        uint256 tokenId
    ) external;

    /**
     * @dev Gives permission to `to` to transfer `tokenId` token to another account.
     * The approval is cleared when the token is transferred.
     *
     * Only a single account can be approved at a time, so approving the zero address clears previous approvals.
     *
     * Requirements:
     *
     * - The caller must own the token or be an approved operator.
     * - `tokenId` must exist.
     *
     * Emits an {Approval} event.
     */
    function approve(address to, uint256 tokenId) external;

    /**
     * @dev Returns the account approved for `tokenId` token.
     *
     * Requirements:
     *
     * - `tokenId` must exist.
     */
    function getApproved(uint256 tokenId) external view returns (address operator);

    /**
     * @dev Approve or remove `operator` as an operator for the caller.
     * Operators can call {transferFrom} or {safeTransferFrom} for any token owned by the caller.
     *
     * Requirements:
     *
     * - The `operator` cannot be the caller.
     *
     * Emits an {ApprovalForAll} event.
     */
    function setApprovalForAll(address operator, bool _approved) external;

    /**
     * @dev Returns if the `operator` is allowed to manage all of the assets of `owner`.
     *
     * See {setApprovalForAll}
     */
    function isApprovedForAll(address owner, address operator) external view returns (bool);

    /**
     * @dev Safely transfers `tokenId` token from `from` to `to`.
     *
     * Requirements:
     *
     * - `from` cannot be the zero address.
     * - `to` cannot be the zero address.
     * - `tokenId` token must exist and be owned by `from`.
     * - If the caller is not `from`, it must be approved to move this token by either {approve} or {setApprovalForAll}.
     * - If `to` refers to a smart contract, it must implement {IERC721Receiver-onERC721Received}, which is called upon a safe transfer.
     *
     * Emits a {Transfer} event.
     */
    function safeTransferFrom(
        address from,
        address to,
        uint256 tokenId,
        bytes calldata data
    ) external;
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
// OpenZeppelin Contracts (last updated v4.5.0) (utils/Address.sol)

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