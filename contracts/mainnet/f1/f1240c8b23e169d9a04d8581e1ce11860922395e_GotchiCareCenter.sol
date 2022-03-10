/**
 *Submitted for verification at polygonscan.com on 2022-03-10
*/

// File: @openzeppelin/contracts/token/ERC20/IERC20.sol

// SPDX-License-Identifier: MIT

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
abstract contract Context {
    function _msgSender() internal view virtual returns (address) {
        return msg.sender;
    }

    function _msgData() internal view virtual returns (bytes calldata) {
        this; // silence state mutability warning without generating bytecode - see https://github.com/ethereum/solidity/issues/2691
        return msg.data;
    }
}




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
abstract contract Ownable is Context {
    address private _owner;

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    /**
     * @dev Initializes the contract setting the deployer as the initial owner.
     */
    constructor () {
        address msgSender = _msgSender();
        _owner = msgSender;
        emit OwnershipTransferred(address(0), msgSender);
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
        emit OwnershipTransferred(_owner, address(0));
        _owner = address(0);
    }

    /**
     * @dev Transfers ownership of the contract to a new account (`newOwner`).
     * Can only be called by the current owner.
     */
    function transferOwnership(address newOwner) public virtual onlyOwner {
        require(newOwner != address(0), "Ownable: new owner is the zero address");
        emit OwnershipTransferred(_owner, newOwner);
        _owner = newOwner;
    }
}






/**
 * @title TokenRecover
 * @author Vittorio Minacori (https://github.com/vittominacori)
 * @dev Allows owner to recover any ERC20 sent into the contract
 */
contract TokenRecover is Ownable {
    /**
     * @dev Remember that only owner can call so be careful when use on contracts generated from other contracts.
     * @param tokenAddress The token contract address
     * @param tokenAmount Number of tokens to be sent
     */
    function recoverERC20(address tokenAddress, uint256 tokenAmount) public virtual onlyOwner {
        IERC20(tokenAddress).transfer(owner(), tokenAmount);
    }
}




interface IGotchiContract {
    function ownerOf(uint256 _id) external view returns (address);

    function isPetOperatorForAll(address _owner, address _operator) external view returns (bool);
}

contract GotchiCareCenter is TokenRecover {
    uint256 public pricePerPet = 0.02 ether;
    address public gotchiContract = 0x86935F11C86623deC8a25696E1C19a8659CbF95d;
    address public gelatoContract = 0x527a819db1eb0e34426297b03bae11F2f8B3A19E;

    mapping(uint256 => address) public pets; // Gotchi => owner
    mapping(address => uint256) public balances; // Owner => balance
    mapping(uint256 => uint256) public indexes; // Gotchi => array index;
    uint256[] public petIds;
    uint256 public feeEarned;
    uint256 public lastFeeChargedAt;

    function interactWith() public view returns (uint256[] memory) {
        uint256[] memory ids = new uint256[](petIds.length);
        uint256 counter = 0;
        for (uint256 i = 0; i < petIds.length; i++) {
            if (
                petIds[i] > 0 &&
                balances[pets[petIds[i]]] >= pricePerPet &&
                IGotchiContract(gotchiContract).isPetOperatorForAll(
                    IGotchiContract(gotchiContract).ownerOf(petIds[i]),
                    gelatoContract
                )
            ) {
                ids[i] = petIds[i];
                counter++;
            }
        }

        if (ids.length == 0) {
            revert("Nothing to pet");
        }

        return ids;
    }

    function setGotchiContractAddress(address _gotchiContract) public onlyOwner {
        gotchiContract = _gotchiContract;
    }

    function setGelatoContractAddress(address _gelatoContract) public onlyOwner {
        gelatoContract = _gelatoContract;
    }

    function addPetCare(uint256 id) external payable {
        require(pets[id] == address(0), "Pet is already added");
        require(IGotchiContract(gotchiContract).ownerOf(id) == msg.sender, "You are not the owner of this Pet");
        require(balances[msg.sender] >= pricePerPet || msg.value >= pricePerPet);
        pets[id] = msg.sender;
        indexes[id] = petIds.length;
        petIds.push(id);

        balances[msg.sender] += msg.value;
        balances[msg.sender] -= pricePerPet;

        feeEarned += pricePerPet;
    }

    function stopPetCare(uint256 id) external {
        require(pets[id] != address(0), "Pet is not added");
        require(IGotchiContract(gotchiContract).ownerOf(id) == msg.sender, "You are not the owner of this Pet");
        delete petIds[indexes[id]];
        delete pets[id];
    }

    function getPrice() external view returns (uint256) {
        return pricePerPet;
    }

    function setPrice(uint256 amount) external onlyOwner returns (uint256) {
        pricePerPet = amount;
        return pricePerPet;
    }

    function withdraw(uint256 _amount) external {
        uint256 amount = balances[msg.sender];

        if (amount >= _amount) {
            balances[msg.sender] -= _amount;
            payable(msg.sender).transfer(amount);
        } else {
            revert("Invalid");
        }
    }

    function withdrawEarnings() external onlyOwner {
        uint256 amount = feeEarned;
        feeEarned = 0;
        payable(msg.sender).transfer(amount);
    }

    function withdrawAll() external {
        uint256 amount = balances[msg.sender];

        require(amount > 0, "nothing to withdraw");

        balances[msg.sender] = 0;
        payable(msg.sender).transfer(amount);
    }

    function refund(address _address, uint256 _amount) external onlyOwner {
        require(balances[_address] >= _amount, "Insufficient balance");

        balances[_address] -= _amount;
        payable(_address).transfer(_amount);
    }

    function chargeDailyFees() public {
        require(lastFeeChargedAt == 0 || block.timestamp >= lastFeeChargedAt + 1 days);
        lastFeeChargedAt = block.timestamp;

        uint256[] memory ids = interactWith();

        for (uint256 i = 0; i < ids.length; i++) {
            if (balances[pets[ids[i]]] >= pricePerPet) {
                balances[pets[ids[i]]] -= pricePerPet;
                feeEarned += pricePerPet;
            }
        }
    }

    function getBalance() public view returns (uint256) {
        return balances[msg.sender];
    }

    function getBalanceOf(address _address) public view returns (uint256) {
        return balances[_address];
    }

    receive() external payable {
        balances[msg.sender] += msg.value;
    }

    fallback() external payable {
        balances[msg.sender] += msg.value;
    }
}