//SPDX-License-Identifier: GPL-3.0

// ╔══╗────────────╔══╗
// ║  ║ 9Tales.io  ║  ║
// ║ ╔╬═╦╗╔═╦═╦╦═╦╗║╔╗║ 
// ║ ╚╣╬║╚╣╬║║║║╩╣╚╣╔╗║
// ╚══╩═╩═╩═╩╩═╩═╩═╩══╝

pragma solidity ^0.8.9;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "./interfaces/IGSstorage.sol";

contract GSkeeper is Ownable {

    // STATE

    bool public paused;
    IGSstorage public gsStorage;
    uint256 public lastSync;

    // ERRORS

    error Paused();
    error OnlyOwner();
    error GSNotSet();
    error KeeperSyncingDisabled();
    error TooSoon();
    error OutOfRange();

    // EVENTS

    event ActiveItemsSynced(address keeper, uint256 removedCount, uint256 newCount, uint256 totalSupply);

    // MODIFIERS

    function _isOwner() internal view returns (bool) {
        return (owner() == _msgSender() || _msgSender() == gsStorage.owner());
    }

    function _checkOwner() internal view override {
        if(!_isOwner()) revert OnlyOwner();
    }

    // CONSTRUCTOR

    constructor(address _gsStorage) {
        setGSStorageAddress(_gsStorage);
    }

    // OWNER FUNCTIONS

    function setGSStorageAddress(address _newMBStorageAddress)
        public
        onlyOwner
    {
        IGSstorage(_newMBStorageAddress).owner();
        gsStorage = IGSstorage(_newMBStorageAddress);
    }

    function setPaused(bool _newState)
        public
        onlyOwner
    {
        paused = _newState;
    }

    // KEEPER FUNCTIONS

    function checkUpkeep(bytes calldata checkData)
        public
        view
        returns (bool upkeepNeeded, bytes memory performData)
    {
        if (address(gsStorage) == address(0) || !gsStorage.authorizedOp(address(this))) return (false,"");
        if (paused || gsStorage.gsPaused()) return (false,"");
        if (!gsStorage.keeperAutoSync() || block.timestamp - lastSync < gsStorage.syncInterval()) return (false,"");
        uint256 _activeCount = gsStorage.getActiveItemsCount();
        for(uint256 j=0; j < _activeCount; j++) {
            uint _itemRef = gsStorage.activeItems(j);
            if(!_isItemValid(_itemRef)) return (true,"");
        }
    }

    function performUpkeep(bytes calldata performData) external {
        if (address(gsStorage) == address(0)) revert GSNotSet();
        if (!_isOwner() && !gsStorage.authorizedOp(address(this))) revert GSNotSet();
        if (paused || gsStorage.gsPaused()) revert Paused();
        if (!gsStorage.keeperAutoSync()) revert KeeperSyncingDisabled();
        if (block.timestamp - lastSync < gsStorage.syncInterval()) revert TooSoon();
        syncActiveItems();
        lastSync = block.timestamp;
    }

    function syncActiveItems() internal returns(uint256 removedCount, uint256 newCount, uint256 totalSupply) {
        IGSstorage.Item memory _item;
        uint256 _activeCount = gsStorage.getActiveItemsCount();
        for(uint256 j=0; j < _activeCount; j++) {
            uint _itemRef = gsStorage.activeItems(_activeCount - 1 - j);
            if(!_isItemValid(_itemRef)) {
                _item = gsStorage.itemsRegistry(_itemRef);
                _item.active = false;
                gsStorage._updateItem(_item);
                gsStorage._forceUpdateList(0,2,_activeCount - j - 1, gsStorage.activeItems(_activeCount - removedCount - 1));
                gsStorage._forceUpdateList(0,0,0,0);
                gsStorage._forceUpdateList(1,1,0,_itemRef);
                removedCount++;
            } else {
                newCount++;
                totalSupply += _item.supply;
            }
        }
        emit ActiveItemsSynced(msg.sender, removedCount, newCount, totalSupply);
    }

    function _isItemValid(uint256 _itemRef) public view returns(bool) {
        IGSstorage.Item memory _item = gsStorage.itemsRegistry(_itemRef);
        if (!_item.active) return false;
        if (!(_item.endTime > block.timestamp)) return false;
        if (_item.supply == 0) return false;
        if (_item.onChainType == IGSstorage.chType.ERC1155) {
            if (IERC1155(_item.itemContract).balanceOf(gsStorage.itemsVault(), _item.itemTokenId) == 0) 
                return false;
            if (!IERC1155(_item.itemContract).isApprovedForAll(gsStorage.itemsVault(), address(gsStorage))) 
                return false;
        } else if (_item.onChainType == IGSstorage.chType.ERC721) {
            if (_item.maxAmount != 1 || _item.supply != 1) 
                return false;
            if (IERC721(_item.itemContract).ownerOf(_item.itemTokenId) != gsStorage.itemsVault())
                return false;
            if (!IERC721(_item.itemContract).isApprovedForAll(gsStorage.itemsVault(), address(gsStorage)))
                return false;
        }
        return true;
    }

}

//SPDX-License-Identifier: GPL-3.0

// ╔══╗────────────╔══╗
// ║  ║ 9Tales.io  ║  ║
// ║ ╔╬═╦╗╔═╦═╦╦═╦╗║╔╗║ 
// ║ ╚╣╬║╚╣╬║║║║╩╣╚╣╔╗║
// ╚══╩═╩═╩═╩╩═╩═╩═╩══╝

pragma solidity ^0.8.9;

interface IGSstorage {
    enum chType {
        ERC1155,
        ERC721,
        offChain
    }

    // [ref, startTime, endTime, supply, maxAmount, priceYdf, interval, totalPurchases, itemTokenId, itemContract, onChainType, active]

    struct Item {
        uint256 ref;
        uint256 startTime;
        uint256 endTime;
        uint256 supply;
        uint256 maxAmount;
        uint256 priceYdf;
        uint256 interval;
        uint256 totalPurchases;
        uint256 itemTokenId;
        address itemContract;
        chType onChainType;
        bool active;
    }

    function owner() external view returns(address);
    function admins(address) external view returns(bool);
    function authorizedOp(address) external view returns(bool);
    
    function gsPaused() external view returns(bool);
    function nitConditActivated() external view returns(bool);
    function sigRequired() external view returns(bool);
    function keeperAutoSync() external view returns(bool);
    function syncInterval() external view returns(uint256);
    function globalMaxAmount() external view returns(uint256);
    
    function ydfContract() external view returns(address);
    function nitConditionsContract() external view returns(address);
    function defaultItemsContract() external view returns(address);
    function itemsVault() external view returns(address);
    function cbSigner() external view returns(address);

    function itemsRegistry(uint256) external view returns(Item memory);
    function itemsTitles(uint256) external view returns(string memory);
    function itemsURIs(uint256) external view returns(string memory);
    function itemsConditions(uint256, uint256) external view returns(uint32);
    function getItemSupply(uint256) external view returns(uint256);
    function getItemTotalPurchases(uint256) external view returns(uint256);

    function allItems(uint256) external view returns(uint256);
    function activeItems(uint256) external view returns(uint256);
    function oldItems(uint256) external view returns(uint256);

    function itemBuyers(uint256,uint256) external view returns(address);
    function userBoughtItems(address,uint256) external view returns(uint256);
    function itemPurchasesOfUser(uint256,address) external view returns(uint256);
    
    function getAllItemsCount() external view returns(uint256);
    function getActiveItemsCount() external view returns(uint256);
    function getOldItemsCount() external view returns(uint256);
    function lastBoughtItem(uint256, address) external view returns(uint256);
    
    function getItemConditionsCount(uint256) external view returns(uint256);
    function getItemBuyersCount(uint256) external view returns(uint256);
    function getUserBoughtItemsCount(address) external view returns(uint256);
    
    function _distributeItem(address, uint256, uint256) external;

    function _updateItem(Item calldata) external;
    function _setItemTitle(uint256, string calldata) external;
    function _setItemURI(uint256, string calldata) external;
    function _forceUpdateList(uint256,uint256,uint256,uint256) external;
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.7.0) (token/ERC1155/IERC1155.sol)

pragma solidity ^0.8.0;

import "../../utils/introspection/IERC165.sol";

/**
 * @dev Required interface of an ERC1155 compliant contract, as defined in the
 * https://eips.ethereum.org/EIPS/eip-1155[EIP].
 *
 * _Available since v3.1._
 */
interface IERC1155 is IERC165 {
    /**
     * @dev Emitted when `value` tokens of token type `id` are transferred from `from` to `to` by `operator`.
     */
    event TransferSingle(address indexed operator, address indexed from, address indexed to, uint256 id, uint256 value);

    /**
     * @dev Equivalent to multiple {TransferSingle} events, where `operator`, `from` and `to` are the same for all
     * transfers.
     */
    event TransferBatch(
        address indexed operator,
        address indexed from,
        address indexed to,
        uint256[] ids,
        uint256[] values
    );

    /**
     * @dev Emitted when `account` grants or revokes permission to `operator` to transfer their tokens, according to
     * `approved`.
     */
    event ApprovalForAll(address indexed account, address indexed operator, bool approved);

    /**
     * @dev Emitted when the URI for token type `id` changes to `value`, if it is a non-programmatic URI.
     *
     * If an {URI} event was emitted for `id`, the standard
     * https://eips.ethereum.org/EIPS/eip-1155#metadata-extensions[guarantees] that `value` will equal the value
     * returned by {IERC1155MetadataURI-uri}.
     */
    event URI(string value, uint256 indexed id);

    /**
     * @dev Returns the amount of tokens of token type `id` owned by `account`.
     *
     * Requirements:
     *
     * - `account` cannot be the zero address.
     */
    function balanceOf(address account, uint256 id) external view returns (uint256);

    /**
     * @dev xref:ROOT:erc1155.adoc#batch-operations[Batched] version of {balanceOf}.
     *
     * Requirements:
     *
     * - `accounts` and `ids` must have the same length.
     */
    function balanceOfBatch(address[] calldata accounts, uint256[] calldata ids)
        external
        view
        returns (uint256[] memory);

    /**
     * @dev Grants or revokes permission to `operator` to transfer the caller's tokens, according to `approved`,
     *
     * Emits an {ApprovalForAll} event.
     *
     * Requirements:
     *
     * - `operator` cannot be the caller.
     */
    function setApprovalForAll(address operator, bool approved) external;

    /**
     * @dev Returns true if `operator` is approved to transfer ``account``'s tokens.
     *
     * See {setApprovalForAll}.
     */
    function isApprovedForAll(address account, address operator) external view returns (bool);

    /**
     * @dev Transfers `amount` tokens of token type `id` from `from` to `to`.
     *
     * Emits a {TransferSingle} event.
     *
     * Requirements:
     *
     * - `to` cannot be the zero address.
     * - If the caller is not `from`, it must have been approved to spend ``from``'s tokens via {setApprovalForAll}.
     * - `from` must have a balance of tokens of type `id` of at least `amount`.
     * - If `to` refers to a smart contract, it must implement {IERC1155Receiver-onERC1155Received} and return the
     * acceptance magic value.
     */
    function safeTransferFrom(
        address from,
        address to,
        uint256 id,
        uint256 amount,
        bytes calldata data
    ) external;

    /**
     * @dev xref:ROOT:erc1155.adoc#batch-operations[Batched] version of {safeTransferFrom}.
     *
     * Emits a {TransferBatch} event.
     *
     * Requirements:
     *
     * - `ids` and `amounts` must have the same length.
     * - If `to` refers to a smart contract, it must implement {IERC1155Receiver-onERC1155BatchReceived} and return the
     * acceptance magic value.
     */
    function safeBatchTransferFrom(
        address from,
        address to,
        uint256[] calldata ids,
        uint256[] calldata amounts,
        bytes calldata data
    ) external;
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.7.0) (access/Ownable.sol)

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
     * @dev Throws if called by any account other than the owner.
     */
    modifier onlyOwner() {
        _checkOwner();
        _;
    }

    /**
     * @dev Returns the address of the current owner.
     */
    function owner() public view virtual returns (address) {
        return _owner;
    }

    /**
     * @dev Throws if the sender is not the owner.
     */
    function _checkOwner() internal view virtual {
        require(owner() == _msgSender(), "Ownable: caller is not the owner");
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
// OpenZeppelin Contracts (last updated v4.7.0) (token/ERC721/IERC721.sol)

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

    /**
     * @dev Safely transfers `tokenId` token from `from` to `to`, checking first that contract recipients
     * are aware of the ERC721 protocol to prevent tokens from being forever locked.
     *
     * Requirements:
     *
     * - `from` cannot be the zero address.
     * - `to` cannot be the zero address.
     * - `tokenId` token must exist and be owned by `from`.
     * - If the caller is not `from`, it must have been allowed to move this token by either {approve} or {setApprovalForAll}.
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
     * @dev Returns the account approved for `tokenId` token.
     *
     * Requirements:
     *
     * - `tokenId` must exist.
     */
    function getApproved(uint256 tokenId) external view returns (address operator);

    /**
     * @dev Returns if the `operator` is allowed to manage all of the assets of `owner`.
     *
     * See {setApprovalForAll}
     */
    function isApprovedForAll(address owner, address operator) external view returns (bool);
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