/**
 *Submitted for verification at polygonscan.com on 2022-03-10
*/

pragma solidity ^0.8.2;

interface IUniswap {
    function swapExactETHForTokens(uint amountOutMin, address[] calldata path, address to, uint deadline)
        external
        payable
        returns (uint[] memory amounts);
    function WETH() external pure returns (address);
    function swapExactTokensForTokens(uint amountIn,uint amountOutMin,address[] calldata path,address to,uint deadline) external returns (uint[] memory amounts);
    function swapExactTokensForETH(uint amountIn, uint amountOutMin, address[] calldata path, address to, uint deadline)
        external
        returns (uint[] memory amounts);

    function getAmountsOut(uint amountIn, address[] calldata path) external view returns (uint[] memory amounts);
}

interface IWormhole{
    function transferTokens(address token, uint256 amount, uint16 recipientChain, bytes32 recipient, uint256 arbiterFee, uint32 nonce) external payable returns (uint64 sequence);
    function wrapAndTransferETH(uint16 recipientChain, bytes32 recipient, uint256 arbiterFee, uint32 nonce) external payable returns (uint64 sequence);
    function completeTransfer(bytes memory encodedVm) external;

}

interface IWormholeCore{
    function publishMessage(uint32 nonce, bytes memory payload, uint8 consistencyLevel) external payable returns (uint64 sequence);
    function parseAndVerifyVM(bytes calldata encodedVM) external view returns (IWormholeCore.VM memory vm, bool valid, string memory reason);
    struct Signature {
		bytes32 r;
		bytes32 s;
		uint8 v;
		uint8 guardianIndex;
	}
    struct VM {
		uint8 version;
		uint32 timestamp;
		uint32 nonce;
		uint16 emitterChainId;
		bytes32 emitterAddress;
		uint64 sequence;
		uint8 consistencyLevel;
		bytes payload;

		uint32 guardianSetIndex;
		Signature[] signatures;

		bytes32 hash;
	}
    
}

interface IERC20{
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function transfer(address to, uint256 amount) external returns (bool);
    function allowance(address owner, address spender) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
}

library Address{
    function isContract(address account) internal view returns (bool) {
        return account.code.length > 0;
    }

    function sendValue(address payable recipient, uint256 amount) internal {
        require(address(this).balance >= amount, "Address: insufficient balance");
        (bool success, ) = recipient.call{value: amount}("");
        require(success, "Address: unable to send value, recipient may have reverted");
    }

    function functionCall(address target, bytes memory data) internal returns (bytes memory) {
        return functionCall(target, data, "Address: low-level call failed");
    }

    function functionCall(address target, bytes memory data, string memory errorMessage) internal returns (bytes memory) {
        return functionCallWithValue(target, data, 0, errorMessage);
    }

    function functionCallWithValue(address target, bytes memory data, uint256 value, string memory errorMessage) internal returns (bytes memory) {
        require(address(this).balance >= value, "Address: insufficient balance for call");
        require(isContract(target), "Address: call to non-contract");
        (bool success, bytes memory returndata) = target.call{value: value}(data);
        return verifyCallResult(success, returndata, errorMessage);
    }

    function functionStaticCall(address target, bytes memory data, string memory errorMessage) internal view returns (bytes memory) {
        require(isContract(target), "Address: static call to non-contract");
        (bool success, bytes memory returndata) = target.staticcall(data);
        return verifyCallResult(success, returndata, errorMessage);
    }

    function functionDelegateCall(address target, bytes memory data, string memory errorMessage) internal returns (bytes memory) {
        require(isContract(target), "Address: delegate call to non-contract");
        (bool success, bytes memory returndata) = target.delegatecall(data);
        return verifyCallResult(success, returndata, errorMessage);
    }

    function verifyCallResult(bool success, bytes memory returndata, string memory errorMessage) internal pure returns (bytes memory) {
        if (success) { return returndata;} 
        else { if (returndata.length > 0) { assembly {
                                                        let returndata_size := mload(returndata)
                                                        revert(add(32, returndata), returndata_size)
                                                     }
                                          } 
               else { revert(errorMessage); }
            }
    }
}

library SafeERC20{
    using Address for address;

    function safeTransfer(IERC20 token, address to, uint256 value) internal {
        _callOptionalReturn(token, abi.encodeWithSelector(token.transfer.selector, to, value));
    }

    function safeTransferFrom(IERC20 token, address from, address to, uint256 value) internal {
        _callOptionalReturn(token, abi.encodeWithSelector(token.transferFrom.selector, from, to, value));
    }

    function safeApprove(IERC20 token, address spender, uint256 value) internal {
        // safeApprove should only be called when setting an initial allowance,
        // or when resetting it to zero. To increase and decrease it, use
        // 'safeIncreaseAllowance' and 'safeDecreaseAllowance'
        require((value == 0) || (token.allowance(address(this), spender) == 0),
                "SafeERC20: approve from non-zero to non-zero allowance");
        _callOptionalReturn(token, abi.encodeWithSelector(token.approve.selector, spender, value));
    }

    function safeIncreaseAllowance(IERC20 token, address spender, uint256 value) internal {
        uint256 newAllowance = token.allowance(address(this), spender) + value;
        _callOptionalReturn(token, abi.encodeWithSelector(token.approve.selector, spender, newAllowance));
    }

    function safeDecreaseAllowance(IERC20 token, address spender, uint256 value) internal {
        unchecked {
            uint256 oldAllowance = token.allowance(address(this), spender);
            require(oldAllowance >= value, "SafeERC20: decreased allowance below zero");
            uint256 newAllowance = oldAllowance - value;
            _callOptionalReturn(token, abi.encodeWithSelector(token.approve.selector, spender, newAllowance));
        }
    }

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

library BytesLib{

        function toAddress(bytes memory _bytes, uint256 _start)  internal pure returns (address) {
        require(_bytes.length >= _start + 20, "toAddress_outOfBounds");
        address tempAddress;

        assembly {
            tempAddress := div(mload(add(add(_bytes, 0x20), _start)), 0x1000000000000000000000000)
        }

        return tempAddress;
    }

    function toUint256(bytes memory _bytes, uint256 _start)  internal pure returns (uint256) {
        require(_bytes.length >= _start + 32, "toUint256_outOfBounds");
        uint256 tempUint;

        assembly {
            tempUint := mload(add(add(_bytes, 0x20), _start))
        }

        return tempUint;
    }
}


contract MagpieCore{
    using BytesLib for bytes;
    IUniswap uniswap;
    IWormhole bridge;
    address bridgeAddress;
    address uniswapAddress;
    // uint deadline = block.timestamp + 1500;
    uint256 arbiterFeeValue =0;
    IWormholeCore coreBridge;
    address[] PathTarget;

    constructor(address _uniswap, address _bridgeAddress, address _coreBridge) public {
        uniswap = IUniswap(_uniswap);
        uniswapAddress = _uniswap;
        bridge = IWormhole(_bridgeAddress);
        bridgeAddress = _bridgeAddress;
        coreBridge = IWormholeCore(_coreBridge);


    }

    struct userInput{
        address[]  path;
        address[] targetPath;
        uint256 amountIn;
        uint16 recipientChainId;
        bytes32 recipient;
    }
    struct Payload{
        address[] targetPath;
        uint256 targetAmountIn;
        uint256 targetAmountOutMin;
        address targetToAddress;

    }


    function swapInToken(userInput memory ui) external payable returns(uint64 tokenSequence, uint64 coreSequence){
        uint[] memory amounts;
        uint[] memory amountsOut;
        uint32 nonceValue = uint32(block.timestamp % 2**32);
        address _origToken = ui.path[0];
        IERC20 originalToken = IERC20(_origToken);



        {
        require(originalToken.transferFrom(msg.sender, address(this), ui.amountIn), 'transferFrom failed.');
        require(originalToken.approve(address(uniswap), ui.amountIn), 'approve failed.');
        amountsOut = uniswap.getAmountsOut(ui.amountIn, ui.path);
        amounts = uniswap.swapExactTokensForTokens(ui.amountIn,amountsOut[amountsOut.length-1],ui.path,address(this),nonceValue+50000);
        }
        
        {
        address swapTokenAddress = ui.path[ui.path.length-1];
        IERC20 token = IERC20(swapTokenAddress);
        SafeERC20.safeIncreaseAllowance(token, bridgeAddress, amounts[amounts.length-1]);
        tokenSequence = bridge.transferTokens{value: msg.value}(swapTokenAddress, amounts[amounts.length-1], ui.recipientChainId, ui.recipient, arbiterFeeValue,nonceValue);
        }
        
        uint[] memory targetAmountsOut;
        targetAmountsOut = uniswap.getAmountsOut(amounts[amounts.length-1], ui.targetPath);
        
        {Payload memory payload = Payload({targetPath: ui.targetPath, 
                                          targetAmountIn: amounts[amounts.length-1],
                                          targetAmountOutMin: targetAmountsOut[targetAmountsOut.length-1],
                                          targetToAddress: msg.sender});
        bytes memory encoded = abi.encodePacked(payload.targetPath, payload.targetAmountIn, payload.targetAmountOutMin, payload.targetToAddress);
        uint8 consistencyLevel = 5;
        coreSequence = coreBridge.publishMessage{value: msg.value}(nonceValue, encoded, consistencyLevel);}
    }

    function swapOutToken(bytes memory encodedVmBridge, bytes memory encodedVmCore, uint deadline) external {
        bridge.completeTransfer(encodedVmBridge);
        (IWormholeCore.VM memory vm, bool valid, string memory reason) = coreBridge.parseAndVerifyVM(encodedVmCore);
        if (valid == true){
            Payload memory payload = parsePayload(vm.payload);
            address swapToken = payload.targetPath[0];
            IERC20 token = IERC20(swapToken);
            require(token.approve(address(uniswap), payload.targetAmountIn), 'approve failed.');
            uniswap.swapExactTokensForTokens(payload.targetAmountIn, payload.targetAmountOutMin, payload.targetPath, payload.targetToAddress, deadline);            
        }
    }


    function parsePayload(bytes memory encoded) public pure returns(Payload memory payload){
        uint index = 0;
        uint i;
        for(i=0; i<payload.targetPath.length; i++){
            payload.targetPath[i] = encoded.toAddress(index);
            index += 20;
        }        
        payload.targetAmountIn = encoded.toUint256(index);
        index +=32;
        payload.targetAmountOutMin = encoded.toUint256(index);
        index += 32;
        payload.targetToAddress = encoded.toAddress(index);
        index += 20;
        require(encoded.length == index, "invalid Transfer");
    }


}
        

/*
Uniswap: 0xa5e0829caced8ffdd4de3c43696c57f7d7a678ff
TokenBridge: 0x5a58505a96d1dbf8df91cb21b54419fc36e93fde
CoreBridge: 0x7A4B5a56256163F07b2C80A7cA55aBE66c4ec4d7 */