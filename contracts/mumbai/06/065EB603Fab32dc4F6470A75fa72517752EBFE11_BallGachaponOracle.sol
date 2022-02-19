// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Context.sol";

import "../interfaces/IBallGachaponOracleCaller.sol";
import "../interfaces/IZomonStruct.sol";
import "../interfaces/IRuneStruct.sol";

contract BallGachaponOracle is Context, Ownable {
    uint256 private _randomNonce = 0;
    uint256 private _modulus = 1000;

    mapping(uint256 => bool) private _pendingRequests;

    event RequestedBallGachapon(
        uint256 requestId,
        address indexed callerAddress,
        uint16 serverId
    );
    event ReportedBallGachapon(
        address indexed callerAddress,
        Zomon[] zomonsData,
        RunesMint runesData
    );

    // Simplified EIP-165 for wrapper contracts to detect if they are targeting the right contract
    function isBallGachaponOracle() external pure returns (bool) {
        return true;
    }

    // Emits the event to trigger the oracle
    function getBallGachapon(uint16 _serverId) external returns (uint256) {
        _randomNonce++;

        uint256 requestId = _getRequestRandomId();

        _pendingRequests[requestId] = true;

        emit RequestedBallGachapon(requestId, _msgSender(), _serverId);

        return requestId;
    }

    // Calls the oracle caller back with the random zomon generated by the oracle
    function reportBallGachapon(
        uint256 _requestId,
        address _callerAddress,
        string calldata _tokenURIPrefix,
        Zomon[] calldata _zomonsData,
        RunesMint calldata _runesData
    ) external onlyOwner {
        require(_pendingRequests[_requestId], "REQUEST_ID_IS_NOT_PENDING");

        delete _pendingRequests[_requestId];

        IBallGachaponOracleCaller callerContractInstance;
        callerContractInstance = IBallGachaponOracleCaller(_callerAddress);

        // Verify the contract is the one we expect
        require(
            callerContractInstance.isBallGachaponOracleCaller(),
            "CALLER_ADDRESS_IS_NOT_AN_ORACLE_CALLER_CONTRACT_INSTANCE"
        );

        callerContractInstance.callback(
            _requestId,
            _tokenURIPrefix,
            _zomonsData,
            _runesData
        );

        emit ReportedBallGachapon(_callerAddress, _zomonsData, _runesData);
    }

    /* Utils */
    function _getRequestRandomId() private view returns (uint256) {
        return
            uint256(
                keccak256(
                    abi.encodePacked(
                        block.timestamp,
                        _msgSender(),
                        _randomNonce
                    )
                )
            ) % _modulus;
    }
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.1 (access/Ownable.sol)

pragma solidity ^0.8.0;

import "../utils/Context.sol";

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
    constructor() {
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

// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "./IZomonStruct.sol";
import "./IRuneStruct.sol";

interface IBallGachaponOracleCaller {
    function isBallGachaponOracleCaller() external pure returns (bool);

    function callback(
        uint256 _requestId,
        string calldata _tokenURIPrefix,
        Zomon[] calldata _zomonsData,
        RunesMint calldata _runesData
    ) external;
}

// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

struct Zomon {
    /* 32 bytes pack */
    uint16 serverId;
    uint16 set;
    uint8 edition;
    uint8 rarity;
    uint8 gender;
    uint8 zodiacSign;
    uint16 skill;
    uint16 leaderSkill;
    bool canLevelUp;
    bool hasEvolution;
    uint16 level;
    uint8 evolution;
    uint24 hp;
    uint24 attack;
    uint24 defense;
    uint24 critical;
    uint24 evasion;
    /*****************/
    uint8 maxRunesCount;
    uint16 generation;
    uint8[] types;
    uint16[] dice;
    uint16[] runes;
    string name;
}

// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

struct Rune {
    uint16 serverId;
    uint16 set;
    uint8 zomonType;
    bool canBeCharmed;
    uint256 disenchantAmount;
    string name;
}

struct RunesMint {
    uint256[] ids;
    uint256[] amounts;
}