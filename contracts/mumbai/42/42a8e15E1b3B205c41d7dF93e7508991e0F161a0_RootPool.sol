pragma solidity ^0.7.6;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface IFxStateRootTunnel {
 function receiveMessage(bytes memory message) external;   
}

interface IRootChainManagerProxy {
    function exit(bytes calldata data) external;
}

interface IWithdrawManagerProxy {
    function processExits(address token) external;
}

interface IERC20PredicateBurnOnly {
    function startExitWithBurntTokens(bytes calldata data) external;
}

contract RootPool {
IFxStateRootTunnel public rootTunnel;
IERC20 public  token;
IRootChainManagerProxy public rootChainManagerProxy;
IWithdrawManagerProxy withdrawManagerProxy;
IERC20PredicateBurnOnly erc20PredicateBurnOnly;

// _rootTunnel 0xE88B1933504CD8BB58f99437bbb93809D76aFeBF
// token maticToken 0x499d11e0b6eac7c0593d8fb292dcbbf815fb29ae
// Rootchain manager proxy 0xbbd7cbfa79faee899eaf900f13c9065bf03b1a74
// withdraw manager proxy 0x2923C8dD6Cdf6b2507ef91de74F1d5E0F11Eac53
// erc20PredicateBurnOnly 0xf213e8fF5d797ed2B052D3b96C11ac71dB358027
constructor(address _rootTunnel, address _token, address _rootChainManagerProxy, address  _withdrawManagerProxy, address _erc20PredicateBurnOnly) {
    rootTunnel = IFxStateRootTunnel(_rootTunnel);
    token = IERC20(_token);
    rootChainManagerProxy = IRootChainManagerProxy(_rootChainManagerProxy);
    withdrawManagerProxy = IWithdrawManagerProxy(_withdrawManagerProxy);
    erc20PredicateBurnOnly = IERC20PredicateBurnOnly(_erc20PredicateBurnOnly);
}


function startExitWithBurntTokens(bytes memory data) public {
    erc20PredicateBurnOnly.startExitWithBurntTokens(data);
}


function receiveMessageAndClaimTokenPlasma(bytes memory messageReceiveData) public {
    rootTunnel.receiveMessage(messageReceiveData);
    withdrawManagerProxy.processExits(address(token));
}

function receiveMessageAndClaimToken(bytes memory messageReceiveData, uint256 amount, bytes memory tokenClaimData) public {
    rootTunnel.receiveMessage(messageReceiveData);
    rootChainManagerProxy.exit(tokenClaimData);

    //poLido stake
    //bridge
    //message batch, stMaticAmount
}

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