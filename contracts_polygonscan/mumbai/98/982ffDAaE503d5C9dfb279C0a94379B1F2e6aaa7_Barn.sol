// SPDX-License-Identifier: MIT LICENSE

pragma solidity 0.8.7;

import "@openzeppelin/contracts/interfaces/IERC721Receiver.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@chainlink/contracts/src/v0.8/VRFConsumerBase.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./Woolf.sol";
import "./WOOL.sol";

contract Barn is
    Ownable,
    IERC721Receiver,
    Pausable,
    VRFConsumerBase,
    ReentrancyGuard
{
    /**
     * VRF randomness variables
     * ROLL_IN_PROGRESS the value used to show random calling is not finished yet
     *
     */
    struct RollerData {
        uint16[] tokenIds;
        bool unstake;
        uint256[] owed;
        address sender;
    }

    uint256 private constant ROLL_IN_PROGRESS = 42;

    bytes32 private s_keyHash;
    uint256 private s_fee;
    mapping(bytes32 => RollerData) private s_rollers;
    // mapping(address => uint256) private s_results;
    mapping(address => mapping(uint16 => uint16)) private _stakedTokensOfOwner;
    mapping(address => uint16) private _nrOfStakedTokensOfOwner;

    // maximum alpha score for a Wolf
    uint8 public constant MAX_ALPHA = 8;

    // struct to store a stake's token, owner, and earning values
    struct Stake {
        uint16 tokenId;
        uint80 value;
        address owner;
    }

    event TokenStaked(address owner, uint16 tokenId, uint256 value);
    event SheepClaimed(uint16 tokenId, uint256 earned, bool unstaked);
    event SheepArrayClaimed(uint16[] tokenIds, uint256[] earned, bool unstaked);
    event WolfClaimed(uint256 tokenId, uint256 earned, bool unstaked);

    // Events
    // DiceRolled event
    event DiceRolled(bytes32 indexed requestId, RollerData indexed roller);
    event DiceLanded(bytes32 indexed requestId, uint256 indexed result);

    // reference to the Woolf NFT contract
    Woolf woolf;
    // reference to the $WOOL contract for minting $WOOL earnings
    WOOL wool;

    // maps tokenId to stake
    mapping(uint256 => Stake) public barn;
    // maps alpha to all Wolf stakes with that alpha
    mapping(uint256 => Stake[]) public pack;
    // tracks location of each Wolf in Pack
    mapping(uint256 => uint256) public packIndices;
    // total alpha scores staked
    uint256 public totalAlphaStaked = 0;
    // any rewards distributed when no wolves are staked
    uint256 public unaccountedRewards = 0;
    // amount of $WOOL due for each alpha point staked
    uint256 public woolPerAlpha = 0;

    // sheep earn 10000 $WOOL per day
    uint256 public constant DAILY_WOOL_RATE = 10000 ether;
    // sheep must have 2 days worth of $WOOL to unstake or else it's too cold
    uint256 public constant MINIMUM_TO_EXIT = 2 days;
    // wolves take a 20% tax on all $WOOL claimed
    uint256 public constant WOOL_CLAIM_TAX_PERCENTAGE = 20;
    // there will only ever be (roughly) 2.4 billion $WOOL earned through staking
    uint256 public constant MAXIMUM_GLOBAL_WOOL = 2400000000 ether;

    // amount of $WOOL earned so far
    uint256 public totalWoolEarned;
    // number of Sheep staked in the Barn
    uint256 public totalSheepStaked;

    // number of Woolf staked in the Barn
    uint256 public totalWoolfStaked;

    // the last time $WOOL was claimed
    uint256 public lastClaimTimestamp;

    // emergency rescue to allow unstaking without any checks but without $WOOL
    bool public rescueEnabled = false;

    /**
     * @param _woolf reference to the Woolf NFT contract
     * @param _wool reference to the $WOOL token
     */
    constructor(
        address _woolf,
        address _wool,
        address vrfCoordinator,
        address link,
        bytes32 keyHash,
        uint256 fee
    ) VRFConsumerBase(vrfCoordinator, link) {
        woolf = Woolf(_woolf);
        wool = WOOL(_wool);

        s_keyHash = keyHash;
        s_fee = fee;
    }

    /** Randomness */

    // rollDice function
    function rollDice(RollerData memory roller)
        internal
        onlyOwner
        returns (bytes32 requestId)
    {
        // checking LINK balance
        require(
            LINK.balanceOf(address(this)) >= s_fee,
            "Not enough LINK to pay fee"
        );

        // checking if roller has already rolled die
        // require(s_results[roller] == 0, "Already rolled");

        // requesting randomness
        requestId = requestRandomness(s_keyHash, s_fee);

        // storing requestId and roller address
        s_rollers[requestId] = roller;

        // emitting event to signal rolling of die
        // s_results[roller.address] = ROLL_IN_PROGRESS;
        emit DiceRolled(requestId, roller);
    }

    // fulfillRandomness function : override of VRFConsumerBase
    function fulfillRandomness(bytes32 requestId, uint256 randomness)
        internal
        override
    {
        // s_results[s_rollers[requestId].sender] = randomness;
        uint256 _sumOfOwed = 0;

        uint256[] storage owed = s_rollers[requestId].owed;

        uint256[] memory randomArray = expand(randomness, owed.length);

        for (uint256 i = 0; i < owed.length; i++ ) {
          if (randomArray[i] & 1 == 1) {
              
            // 50% chance of all $WOOL stolen
            _payWolfTax(owed[i]);
            owed[i] = 0;
          }

          _sumOfOwed += owed[i];

          uint16 tokenId = s_rollers[requestId].tokenIds[i];

          woolf.safeTransferFrom(
              address(this),
              s_rollers[requestId].sender,
              tokenId,
              ""
          ); // send back Sheep
          delete barn[tokenId];
          totalSheepStaked -= 1;

          removeFromStakedTokenOfOwner(s_rollers[requestId].sender, tokenId);  

        }

        if (_sumOfOwed > 0){
            wool.mint(_msgSender(), _sumOfOwed);
        } 
        
        emit SheepArrayClaimed(s_rollers[requestId].tokenIds, owed, s_rollers[requestId].unstake);
        
        // emit SheepClaimed(tokenId, owed, s_rollers[requestId].unstake);
        
    }

    function expand(uint256 randomValue, uint256 n)
        internal
        pure
        returns (uint256[] memory expandedValues)
    {
        expandedValues = new uint256[](n);
        for (uint256 i = 0; i < n; i++) {
            expandedValues[i] = uint256(keccak256(abi.encode(randomValue, i)));
        }
        return expandedValues;
    }

    function getNrOfStakedTokenIds(address account)external view returns(uint16){
        return _nrOfStakedTokensOfOwner[account];
    }

    function getStakedTokenIdOfOwner(address account,uint16 index)external view returns (uint16) {
        return _stakedTokensOfOwner[account][index];
    }

    /** STAKING */

    /**
     * adds Sheep and Wolves to the Barn and Pack
     * @param account the address of the staker
     * @param tokenIds the IDs of the Sheep and Wolves to stake
     */
    function addManyToBarnAndPack(address account, uint16[] calldata tokenIds)
        external
    {
        require(
            account == _msgSender() || _msgSender() == address(woolf),
            "DONT GIVE YOUR TOKENS AWAY"
        );
        for (uint256 i = 0; i < tokenIds.length; i++) {
            if (_msgSender() != address(woolf)) {
                // dont do this step if its a mint + stake
                require(
                    woolf.ownerOf(tokenIds[i]) == _msgSender(),
                    "AINT YO TOKEN"
                );
                woolf.transferFrom(_msgSender(), address(this), tokenIds[i]);
            } else if (tokenIds[i] == 0) {
                continue; // there may be gaps in the array for stolen tokens
            }

            if (isSheep(tokenIds[i])) _addSheepToBarn(account, tokenIds[i]);
            else _addWolfToPack(account, tokenIds[i]);
        }
    }

    /**
     * adds a single Sheep to the Barn
     * @param account the address of the staker
     * @param tokenId the ID of the Sheep to add to the Barn
     */
    function _addSheepToBarn(address account, uint16 tokenId)
        internal
        whenNotPaused
        _updateEarnings
        nonReentrant
    {
        barn[tokenId] = Stake({
            owner: account,
            tokenId: uint16(tokenId),
            value: uint80(block.timestamp)
        });
        
        _stakedTokensOfOwner[account][_nrOfStakedTokensOfOwner[account]] = tokenId;
        _nrOfStakedTokensOfOwner[account] += 1;
        totalSheepStaked += 1;
        emit TokenStaked(account, tokenId, block.timestamp);
    }

    /**
     * adds a single Wolf to the Pack
     * @param account the address of the staker
     * @param tokenId the ID of the Wolf to add to the Pack
     */
    function _addWolfToPack(address account, uint16 tokenId)
        internal
        nonReentrant
    {
        uint256 alpha = _alphaForWolf(tokenId);
        totalAlphaStaked += alpha; // Portion of earnings ranges from 8 to 5
        packIndices[tokenId] = pack[alpha].length; // Store the location of the wolf in the Pack
        pack[alpha].push(
            Stake({
                owner: account,
                tokenId: tokenId,
                value: uint80(woolPerAlpha)
            })
        ); // Add the wolf to the Pack
        totalWoolfStaked += 1;

        _stakedTokensOfOwner[account][_nrOfStakedTokensOfOwner[account]] = tokenId;
        _nrOfStakedTokensOfOwner[account] += 1;

        emit TokenStaked(account, tokenId, woolPerAlpha);
    }

    /** CLAIMING / UNSTAKING */

    /**
     * realize $WOOL earnings and optionally unstake tokens from the Barn / Pack
     * to unstake a Sheep it will require it has 2 days worth of $WOOL unclaimed
     * @param tokenIds the IDs of the tokens to claim earnings from
     * @param unstake whether or not to unstake ALL of the tokens listed in tokenIds
     */
    function claimManyFromBarnAndPack(uint16[] calldata tokenIds, bool unstake)
        external
        whenNotPaused
        _updateEarnings
        nonReentrant
    {
        uint256 owed = 0;
        uint256 sheepCount = getSheepCount(tokenIds);
        uint256 _i = 0;
        uint16[] memory _tokenIdsForSheep = new uint16[](sheepCount);

        for (uint256 i = 0; i < tokenIds.length; i++) {
            if (isSheep(tokenIds[i])) {
                _tokenIdsForSheep[_i] = tokenIds[i];
                _i += 1;
            }
                // owed += _claimSheepFromBarn(tokenIds[i], unstake);
            else owed += _claimWolfFromPack(tokenIds[i], unstake);
        }
        if (_tokenIdsForSheep.length > 0) {
            _claimSheepArrayFromBarn(_tokenIdsForSheep, unstake);
            
        } else {
            if (owed != 0){
                wool.mint(_msgSender(), owed);
            }            
        }
        
    }

    function getSheepCount(uint16[] memory tokenIds)internal view returns (uint256 count){
        count = 0;
        for (uint256 i = 0; i < tokenIds.length; i++) {
            if (isSheep(tokenIds[i])){
                count += 1;
            } 
        }        
    }

    /**
     * realize $WOOL earnings for a single Sheep and optionally unstake it
     * if not unstaking, pay a 20% tax to the staked Wolves
     * if unstaking, there is a 50% chance all $WOOL is stolen
     * @param tokenIds the ID array of the Sheep to claim earnings from
     * @param unstake whether or not to unstake the Sheep
     * 
     */
   
    function _claimSheepArrayFromBarn(uint16[] memory tokenIds, bool unstake)
        internal
    {
        uint256[] memory owed = new uint256[](tokenIds.length);

        for (uint256 i = 0; i < tokenIds.length; i++) {
            uint256 tokenId = tokenIds[i];
            Stake memory stake = barn[tokenId];
            require(stake.owner == _msgSender(), "SWIPER, NO SWIPING");
            require(
                !(unstake && block.timestamp - stake.value < MINIMUM_TO_EXIT),
                "GONNA BE COLD WITHOUT TWO DAY'S WOOL"
            );

            if (totalWoolEarned < MAXIMUM_GLOBAL_WOOL) {
                owed[i] =  ((block.timestamp - stake.value) * DAILY_WOOL_RATE) / 1 days;
                
            } else if (stake.value > lastClaimTimestamp) {
                owed[i] = 0; // $WOOL production stopped already                 
            } else {

                owed[i] = ((lastClaimTimestamp - stake.value) * DAILY_WOOL_RATE) / 1 days; // stop earning additional $WOOL if it's all been earned
            }
        }

        if (unstake) {

            RollerData memory rollerData = RollerData({
                tokenIds: tokenIds,
                unstake: unstake,
                owed: owed,
                sender: _msgSender()
            });
            rollDice(rollerData);

        } else {

          for(uint256 i = 0; i < owed.length; i++) {
            
            _payWolfTax((owed[i] * WOOL_CLAIM_TAX_PERCENTAGE) / 100); // percentage tax to staked wolves
            owed[i] = (owed[i] * (100 - WOOL_CLAIM_TAX_PERCENTAGE)) / 100; // remainder goes to Sheep owner

            barn[tokenIds[i]] = Stake({
                owner: _msgSender(),
                tokenId: tokenIds[i],
                value: uint80(block.timestamp)
            }); // reset stake

            emit SheepArrayClaimed(tokenIds, owed, unstake);

          }

        }
    }

    function removeFromStakedTokenOfOwner(address account,uint16 tokenId)internal nonReentrant{
        
        uint16 _count = 0;
        for(uint16 i = 0; i < _nrOfStakedTokensOfOwner[account]; i++) {
            if(tokenId == _stakedTokensOfOwner[account][i]){
                delete _stakedTokensOfOwner[account][i];
                _count += 1;
                break;
            }
        }

        _nrOfStakedTokensOfOwner[account] -= _count;
    }

    /**
     * realize $WOOL earnings for a single Wolf and optionally unstake it
     * Wolves earn $WOOL proportional to their Alpha rank
     * @param tokenId the ID of the Wolf to claim earnings from
     * @param unstake whether or not to unstake the Wolf
     * @return owed - the amount of $WOOL earned
     */
    function _claimWolfFromPack(uint16 tokenId, bool unstake)
        internal
        returns (uint256 owed)
    {
        require(
            woolf.ownerOf(tokenId) == address(this),
            "AINT A PART OF THE PACK"
        );
        uint256 alpha = _alphaForWolf(tokenId);
        Stake memory stake = pack[alpha][packIndices[tokenId]];
        require(stake.owner == _msgSender(), "SWIPER, NO SWIPING");
        owed = (alpha) * (woolPerAlpha - stake.value); // Calculate portion of tokens based on Alpha
        if (unstake) {
            totalAlphaStaked -= alpha; // Remove Alpha from total staked
            totalWoolfStaked -= 1;
            woolf.safeTransferFrom(address(this), _msgSender(), tokenId, ""); // Send back Wolf
            Stake memory lastStake = pack[alpha][pack[alpha].length - 1];
            pack[alpha][packIndices[tokenId]] = lastStake; // Shuffle last Wolf to current position
            packIndices[lastStake.tokenId] = packIndices[tokenId];
            pack[alpha].pop(); // Remove duplicate
            delete packIndices[tokenId]; // Delete old mapping

            removeFromStakedTokenOfOwner(_msgSender(), tokenId);

        } else {
            pack[alpha][packIndices[tokenId]] = Stake({
                owner: _msgSender(),
                tokenId: uint16(tokenId),
                value: uint80(woolPerAlpha)
            }); // reset stake
        }
        emit WolfClaimed(tokenId, owed, unstake);
    }

    /**
     * emergency unstake tokens
     * @param tokenIds the IDs of the tokens to claim earnings from
     */
    function rescue(uint16[] calldata tokenIds) external {
        require(rescueEnabled, "RESCUE DISABLED");
        uint16 tokenId;
        Stake memory stake;
        Stake memory lastStake;
        uint256 alpha;
        for (uint256 i = 0; i < tokenIds.length; i++) {
            tokenId = tokenIds[i];
            if (isSheep(tokenId)) {
                stake = barn[tokenId];
                require(stake.owner == _msgSender(), "SWIPER, NO SWIPING");
                woolf.safeTransferFrom(
                    address(this),
                    _msgSender(),
                    uint256(tokenId),
                    ""
                ); // send back Sheep
                delete barn[tokenId];
                totalSheepStaked -= 1;
                emit SheepClaimed(tokenId, 0, true);
            } else {
                alpha = _alphaForWolf(tokenId);
                stake = pack[alpha][packIndices[tokenId]];
                require(stake.owner == _msgSender(), "SWIPER, NO SWIPING");
                totalAlphaStaked -= alpha; // Remove Alpha from total staked
                woolf.safeTransferFrom(
                    address(this),
                    _msgSender(),
                    tokenId,
                    ""
                ); // Send back Wolf
                totalWoolfStaked -= 1;
                lastStake = pack[alpha][pack[alpha].length - 1];
                pack[alpha][packIndices[tokenId]] = lastStake; // Shuffle last Wolf to current position
                packIndices[lastStake.tokenId] = packIndices[tokenId];
                pack[alpha].pop(); // Remove duplicate
                delete packIndices[tokenId]; // Delete old mapping
                emit WolfClaimed(tokenId, 0, true);
            }
        }
    }

    /** ACCOUNTING */

    /**
     * add $WOOL to claimable pot for the Pack
     * @param amount $WOOL to add to the pot
     */
    function _payWolfTax(uint256 amount) internal {
        if (totalAlphaStaked == 0) {
            // if there's no staked wolves
            unaccountedRewards += amount; // keep track of $WOOL due to wolves
            return;
        }
        // makes sure to include any unaccounted $WOOL
        woolPerAlpha += (amount + unaccountedRewards) / totalAlphaStaked;
        unaccountedRewards = 0;
    }

    /**
     * tracks $WOOL earnings to ensure it stops once 2.4 billion is eclipsed
     */
    modifier _updateEarnings() {
        if (totalWoolEarned < MAXIMUM_GLOBAL_WOOL) {
            totalWoolEarned +=
                ((block.timestamp - lastClaimTimestamp) *
                    totalSheepStaked *
                    DAILY_WOOL_RATE) /
                1 days;
            lastClaimTimestamp = block.timestamp;
        }
        _;
    }

    /** ADMIN */

    /**
     * allows owner to enable "rescue mode"
     * simplifies accounting, prioritizes tokens out in emergency
     */
    function setRescueEnabled(bool _enabled) external onlyOwner {
        rescueEnabled = _enabled;
    }

    /**
     * enables owner to pause / unpause minting
     */
    function setPaused(bool _paused) external onlyOwner {
        if (_paused) _pause();
        else _unpause();
    }

    /** READ ONLY */

    /**
     * checks if a token is a Sheep
     * @param tokenId the ID of the token to check
     * @return sheep - whether or not a token is a Sheep
     */
    function isSheep(uint256 tokenId) public view returns (bool sheep) {
        (sheep, , , , , , , , , ) = woolf.tokenTraits(tokenId);
    }

    /**
     * gets the alpha score for a Wolf
     * @param tokenId the ID of the Wolf to get the alpha score for
     * @return the alpha score of the Wolf (5-8)
     */
    function _alphaForWolf(uint256 tokenId) internal view returns (uint8) {
        (, , , , , , , , , uint8 alphaIndex) = woolf.tokenTraits(tokenId);
        return MAX_ALPHA - alphaIndex; // alpha index is 0-3
    }

    /**
     * chooses a random Wolf thief when a newly minted token is stolen
     * @param seed a random value to choose a Wolf from
     * @return the owner of the randomly selected Wolf thief
     */
    function randomWolfOwner(uint256 seed) external view returns (address) {
        if (totalAlphaStaked == 0) return address(0x0);
        uint256 bucket = (seed & 0xFFFFFFFF) % totalAlphaStaked; // choose a value from 0 to total alpha staked
        uint256 cumulative;
        seed >>= 32;
        // loop through each bucket of Wolves with the same alpha score
        for (uint256 i = MAX_ALPHA - 3; i <= MAX_ALPHA; i++) {
            cumulative += pack[i].length * i;
            // if the value is not inside of that bucket, keep going
            if (bucket >= cumulative) continue;
            // get the address of a random Wolf with that alpha score
            return pack[i][seed % pack[i].length].owner;
        }
        return address(0x0);
    }

    
    function onERC721Received(
        address,
        address from,
        uint256,
        bytes calldata
    ) external pure override returns (bytes4) {
        require(from == address(0x0), "Cannot send tokens to Barn directly");
        return IERC721Receiver.onERC721Received.selector;
    }
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.0 (interfaces/IERC721Receiver.sol)

pragma solidity ^0.8.0;

import "../token/ERC721/IERC721Receiver.sol";

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.0 (security/Pausable.sol)

pragma solidity ^0.8.0;

import "../utils/Context.sol";

/**
 * @dev Contract module which allows children to implement an emergency stop
 * mechanism that can be triggered by an authorized account.
 *
 * This module is used through inheritance. It will make available the
 * modifiers `whenNotPaused` and `whenPaused`, which can be applied to
 * the functions of your contract. Note that they will not be pausable by
 * simply including this module, only once the modifiers are put in place.
 */
abstract contract Pausable is Context {
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
    constructor() {
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
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.0 (security/ReentrancyGuard.sol)

pragma solidity ^0.8.0;

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
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./interfaces/LinkTokenInterface.sol";

import "./VRFRequestIDBase.sol";

/** ****************************************************************************
 * @notice Interface for contracts using VRF randomness
 * *****************************************************************************
 * @dev PURPOSE
 *
 * @dev Reggie the Random Oracle (not his real job) wants to provide randomness
 * @dev to Vera the verifier in such a way that Vera can be sure he's not
 * @dev making his output up to suit himself. Reggie provides Vera a public key
 * @dev to which he knows the secret key. Each time Vera provides a seed to
 * @dev Reggie, he gives back a value which is computed completely
 * @dev deterministically from the seed and the secret key.
 *
 * @dev Reggie provides a proof by which Vera can verify that the output was
 * @dev correctly computed once Reggie tells it to her, but without that proof,
 * @dev the output is indistinguishable to her from a uniform random sample
 * @dev from the output space.
 *
 * @dev The purpose of this contract is to make it easy for unrelated contracts
 * @dev to talk to Vera the verifier about the work Reggie is doing, to provide
 * @dev simple access to a verifiable source of randomness.
 * *****************************************************************************
 * @dev USAGE
 *
 * @dev Calling contracts must inherit from VRFConsumerBase, and can
 * @dev initialize VRFConsumerBase's attributes in their constructor as
 * @dev shown:
 *
 * @dev   contract VRFConsumer {
 * @dev     constuctor(<other arguments>, address _vrfCoordinator, address _link)
 * @dev       VRFConsumerBase(_vrfCoordinator, _link) public {
 * @dev         <initialization with other arguments goes here>
 * @dev       }
 * @dev   }
 *
 * @dev The oracle will have given you an ID for the VRF keypair they have
 * @dev committed to (let's call it keyHash), and have told you the minimum LINK
 * @dev price for VRF service. Make sure your contract has sufficient LINK, and
 * @dev call requestRandomness(keyHash, fee, seed), where seed is the input you
 * @dev want to generate randomness from.
 *
 * @dev Once the VRFCoordinator has received and validated the oracle's response
 * @dev to your request, it will call your contract's fulfillRandomness method.
 *
 * @dev The randomness argument to fulfillRandomness is the actual random value
 * @dev generated from your seed.
 *
 * @dev The requestId argument is generated from the keyHash and the seed by
 * @dev makeRequestId(keyHash, seed). If your contract could have concurrent
 * @dev requests open, you can use the requestId to track which seed is
 * @dev associated with which randomness. See VRFRequestIDBase.sol for more
 * @dev details. (See "SECURITY CONSIDERATIONS" for principles to keep in mind,
 * @dev if your contract could have multiple requests in flight simultaneously.)
 *
 * @dev Colliding `requestId`s are cryptographically impossible as long as seeds
 * @dev differ. (Which is critical to making unpredictable randomness! See the
 * @dev next section.)
 *
 * *****************************************************************************
 * @dev SECURITY CONSIDERATIONS
 *
 * @dev A method with the ability to call your fulfillRandomness method directly
 * @dev could spoof a VRF response with any random value, so it's critical that
 * @dev it cannot be directly called by anything other than this base contract
 * @dev (specifically, by the VRFConsumerBase.rawFulfillRandomness method).
 *
 * @dev For your users to trust that your contract's random behavior is free
 * @dev from malicious interference, it's best if you can write it so that all
 * @dev behaviors implied by a VRF response are executed *during* your
 * @dev fulfillRandomness method. If your contract must store the response (or
 * @dev anything derived from it) and use it later, you must ensure that any
 * @dev user-significant behavior which depends on that stored value cannot be
 * @dev manipulated by a subsequent VRF request.
 *
 * @dev Similarly, both miners and the VRF oracle itself have some influence
 * @dev over the order in which VRF responses appear on the blockchain, so if
 * @dev your contract could have multiple VRF requests in flight simultaneously,
 * @dev you must ensure that the order in which the VRF responses arrive cannot
 * @dev be used to manipulate your contract's user-significant behavior.
 *
 * @dev Since the ultimate input to the VRF is mixed with the block hash of the
 * @dev block in which the request is made, user-provided seeds have no impact
 * @dev on its economic security properties. They are only included for API
 * @dev compatability with previous versions of this contract.
 *
 * @dev Since the block hash of the block which contains the requestRandomness
 * @dev call is mixed into the input to the VRF *last*, a sufficiently powerful
 * @dev miner could, in principle, fork the blockchain to evict the block
 * @dev containing the request, forcing the request to be included in a
 * @dev different block with a different hash, and therefore a different input
 * @dev to the VRF. However, such an attack would incur a substantial economic
 * @dev cost. This cost scales with the number of blocks the VRF oracle waits
 * @dev until it calls responds to a request.
 */
abstract contract VRFConsumerBase is VRFRequestIDBase {
  /**
   * @notice fulfillRandomness handles the VRF response. Your contract must
   * @notice implement it. See "SECURITY CONSIDERATIONS" above for important
   * @notice principles to keep in mind when implementing your fulfillRandomness
   * @notice method.
   *
   * @dev VRFConsumerBase expects its subcontracts to have a method with this
   * @dev signature, and will call it once it has verified the proof
   * @dev associated with the randomness. (It is triggered via a call to
   * @dev rawFulfillRandomness, below.)
   *
   * @param requestId The Id initially returned by requestRandomness
   * @param randomness the VRF output
   */
  function fulfillRandomness(bytes32 requestId, uint256 randomness) internal virtual;

  /**
   * @dev In order to keep backwards compatibility we have kept the user
   * seed field around. We remove the use of it because given that the blockhash
   * enters later, it overrides whatever randomness the used seed provides.
   * Given that it adds no security, and can easily lead to misunderstandings,
   * we have removed it from usage and can now provide a simpler API.
   */
  uint256 private constant USER_SEED_PLACEHOLDER = 0;

  /**
   * @notice requestRandomness initiates a request for VRF output given _seed
   *
   * @dev The fulfillRandomness method receives the output, once it's provided
   * @dev by the Oracle, and verified by the vrfCoordinator.
   *
   * @dev The _keyHash must already be registered with the VRFCoordinator, and
   * @dev the _fee must exceed the fee specified during registration of the
   * @dev _keyHash.
   *
   * @dev The _seed parameter is vestigial, and is kept only for API
   * @dev compatibility with older versions. It can't *hurt* to mix in some of
   * @dev your own randomness, here, but it's not necessary because the VRF
   * @dev oracle will mix the hash of the block containing your request into the
   * @dev VRF seed it ultimately uses.
   *
   * @param _keyHash ID of public key against which randomness is generated
   * @param _fee The amount of LINK to send with the request
   *
   * @return requestId unique ID for this request
   *
   * @dev The returned requestId can be used to distinguish responses to
   * @dev concurrent requests. It is passed as the first argument to
   * @dev fulfillRandomness.
   */
  function requestRandomness(bytes32 _keyHash, uint256 _fee) internal returns (bytes32 requestId) {
    LINK.transferAndCall(vrfCoordinator, _fee, abi.encode(_keyHash, USER_SEED_PLACEHOLDER));
    // This is the seed passed to VRFCoordinator. The oracle will mix this with
    // the hash of the block containing this request to obtain the seed/input
    // which is finally passed to the VRF cryptographic machinery.
    uint256 vRFSeed = makeVRFInputSeed(_keyHash, USER_SEED_PLACEHOLDER, address(this), nonces[_keyHash]);
    // nonces[_keyHash] must stay in sync with
    // VRFCoordinator.nonces[_keyHash][this], which was incremented by the above
    // successful LINK.transferAndCall (in VRFCoordinator.randomnessRequest).
    // This provides protection against the user repeating their input seed,
    // which would result in a predictable/duplicate output, if multiple such
    // requests appeared in the same block.
    nonces[_keyHash] = nonces[_keyHash] + 1;
    return makeRequestId(_keyHash, vRFSeed);
  }

  LinkTokenInterface internal immutable LINK;
  address private immutable vrfCoordinator;

  // Nonces for each VRF key from which randomness has been requested.
  //
  // Must stay in sync with VRFCoordinator[_keyHash][this]
  mapping(bytes32 => uint256) /* keyHash */ /* nonce */
    private nonces;

  /**
   * @param _vrfCoordinator address of VRFCoordinator contract
   * @param _link address of LINK token contract
   *
   * @dev https://docs.chain.link/docs/link-token-contracts
   */
  constructor(address _vrfCoordinator, address _link) {
    vrfCoordinator = _vrfCoordinator;
    LINK = LinkTokenInterface(_link);
  }

  // rawFulfillRandomness is called by VRFCoordinator when it receives a valid VRF
  // proof. rawFulfillRandomness then calls fulfillRandomness, after validating
  // the origin of the call
  function rawFulfillRandomness(bytes32 requestId, uint256 randomness) external {
    require(msg.sender == vrfCoordinator, "Only VRFCoordinator can fulfill");
    fulfillRandomness(requestId, randomness);
  }
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.0 (access/Ownable.sol)

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

// SPDX-License-Identifier: MIT LICENSE

pragma solidity 0.8.7;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "./interfaces/IWoolf.sol";
import "./interfaces/IBarn.sol";
import "./interfaces/ITraits.sol";
import "./WOOL.sol";

contract Woolf is IWoolf, ERC721Enumerable, Ownable, Pausable {
    // mint price
    uint256 public constant MINT_PRICE = .069420 ether;
    // max number of tokens that can be minted - 50000 in production
    uint256 public immutable MAX_TOKENS;
    // number of tokens that can be claimed for free - 20% of MAX_TOKENS
    uint256 public PAID_TOKENS;
    // number of tokens have been minted so far
    uint16 public minted;

    // number of sheeps in total minted
    uint16 public mintedSheeps;

    // number of stolean sheeps in total minted
    uint16 public stolenSheeps;

    // number of stolean woolves in total minted
    uint16 public stolenWoolfs;

    // mapping from tokenId to a struct containing the token's traits
    mapping(uint256 => SheepWolf) public tokenTraits;
    // mapping from hashed(tokenTrait) to the tokenId it's associated with
    // used to ensure there are no duplicates
    mapping(uint256 => uint256) public existingCombinations;

    // list of probabilities for each trait type
    // 0 - 9 are associated with Sheep, 10 - 18 are associated with Wolves
    uint8[][18] public rarities;
    // list of aliases for Walker's Alias algorithm
    // 0 - 9 are associated with Sheep, 10 - 18 are associated with Wolves
    uint8[][18] public aliases;

    // reference to the Barn for choosing random Wolf thieves
    IBarn public barn;
    // reference to $WOOL for burning on mint
    WOOL public wool;
    // reference to Traits
    ITraits public traits;

    /**
     * instantiates contract and rarity tables
     */
    constructor(
        address _wool,
        address _traits,
        uint256 _maxTokens
    ) ERC721("Wolf Game", "WGAME") {
        wool = WOOL(_wool);
        traits = ITraits(_traits);
        MAX_TOKENS = _maxTokens;
        PAID_TOKENS = _maxTokens / 5;

        // I know this looks weird but it saves users gas by making lookup O(1)
        // A.J. Walker's Alias Algorithm
        // sheep
        // fur
        rarities[0] = [15, 50, 200, 250, 255];
        aliases[0] = [4, 4, 4, 4, 4];
        // head
        rarities[1] = [
            190,
            215,
            240,
            100,
            110,
            135,
            160,
            185,
            80,
            210,
            235,
            240,
            80,
            80,
            100,
            100,
            100,
            245,
            250,
            255
        ];
        aliases[1] = [
            1,
            2,
            4,
            0,
            5,
            6,
            7,
            9,
            0,
            10,
            11,
            17,
            0,
            0,
            0,
            0,
            4,
            18,
            19,
            19
        ];
        // ears
        rarities[2] = [255, 30, 60, 60, 150, 156];
        aliases[2] = [0, 0, 0, 0, 0, 0];
        // eyes
        rarities[3] = [
            221,
            100,
            181,
            140,
            224,
            147,
            84,
            228,
            140,
            224,
            250,
            160,
            241,
            207,
            173,
            84,
            254,
            220,
            196,
            140,
            168,
            252,
            140,
            183,
            236,
            252,
            224,
            255
        ];
        aliases[3] = [
            1,
            2,
            5,
            0,
            1,
            7,
            1,
            10,
            5,
            10,
            11,
            12,
            13,
            14,
            16,
            11,
            17,
            23,
            13,
            14,
            17,
            23,
            23,
            24,
            27,
            27,
            27,
            27
        ];
        // nose
        rarities[4] = [175, 100, 40, 250, 115, 100, 185, 175, 180, 255];
        aliases[4] = [3, 0, 4, 6, 6, 7, 8, 8, 9, 9];
        // mouth
        rarities[5] = [
            80,
            225,
            227,
            228,
            112,
            240,
            64,
            160,
            167,
            217,
            171,
            64,
            240,
            126,
            80,
            255
        ];
        aliases[5] = [1, 2, 3, 8, 2, 8, 8, 9, 9, 10, 13, 10, 13, 15, 13, 15];
        // neck
        rarities[6] = [255];
        aliases[6] = [0];
        // feet
        rarities[7] = [
            243,
            189,
            133,
            133,
            57,
            95,
            152,
            135,
            133,
            57,
            222,
            168,
            57,
            57,
            38,
            114,
            114,
            114,
            255
        ];
        aliases[7] = [
            1,
            7,
            0,
            0,
            0,
            0,
            0,
            10,
            0,
            0,
            11,
            18,
            0,
            0,
            0,
            1,
            7,
            11,
            18
        ];
        // alphaIndex
        rarities[8] = [255];
        aliases[8] = [0];

        // wolves
        // fur
        rarities[9] = [210, 90, 9, 9, 9, 150, 9, 255, 9];
        aliases[9] = [5, 0, 0, 5, 5, 7, 5, 7, 5];
        // head
        rarities[10] = [255];
        aliases[10] = [0];
        // ears
        rarities[11] = [255];
        aliases[11] = [0];
        // eyes
        rarities[12] = [
            135,
            177,
            219,
            141,
            183,
            225,
            147,
            189,
            231,
            135,
            135,
            135,
            135,
            246,
            150,
            150,
            156,
            165,
            171,
            180,
            186,
            195,
            201,
            210,
            243,
            252,
            255
        ];
        aliases[12] = [
            1,
            2,
            3,
            4,
            5,
            6,
            7,
            8,
            13,
            3,
            6,
            14,
            15,
            16,
            16,
            17,
            18,
            19,
            20,
            21,
            22,
            23,
            24,
            25,
            26,
            26,
            26
        ];
        // nose
        rarities[13] = [255];
        aliases[13] = [0];
        // mouth
        rarities[14] = [
            239,
            244,
            249,
            234,
            234,
            234,
            234,
            234,
            234,
            234,
            130,
            255,
            247
        ];
        aliases[14] = [1, 2, 11, 0, 11, 11, 11, 11, 11, 11, 11, 11, 11];
        // neck
        rarities[15] = [
            75,
            180,
            165,
            120,
            60,
            150,
            105,
            195,
            45,
            225,
            75,
            45,
            195,
            120,
            255
        ];
        aliases[15] = [1, 9, 0, 0, 0, 0, 0, 0, 0, 12, 0, 0, 14, 12, 14];
        // feet
        rarities[16] = [255];
        aliases[16] = [0];
        // alphaIndex
        rarities[17] = [8, 160, 73, 255];
        aliases[17] = [2, 3, 3, 3];
    }

    /** EXTERNAL */

    /**
     * mint a token - 90% Sheep, 10% Wolves
     * The first 20% are free to claim, the remaining cost $WOOL
     */
    function mint(uint256 amount, bool stake) external payable whenNotPaused {
        require(tx.origin == _msgSender(), "Only EOA");
        require(minted + amount <= MAX_TOKENS, "All tokens minted");
        require(amount > 0 && amount <= 10, "Invalid mint amount");
        if (minted < PAID_TOKENS) {
            require(
                minted + amount <= PAID_TOKENS,
                "All tokens on-sale already sold"
            );
            require(amount * MINT_PRICE == msg.value, "Invalid payment amount");
        } else {
            require(msg.value == 0);
        }

        uint256 totalWoolCost = 0;
        uint16[] memory tokenIds = stake
            ? new uint16[](amount)
            : new uint16[](0);
        uint256 seed;
        for (uint256 i = 0; i < amount; i++) {
            minted++;
            seed = random(minted);
            SheepWolf memory mintedNow = generate(minted, seed);
            if (mintedNow.isSheep) {
                mintedSheeps += 1;
            }
            address recipient = selectRecipient(seed);

            if (recipient != _msgSender()) {
                if (mintedNow.isSheep) {
                    stolenSheeps += 1;
                } else {
                    stolenWoolfs += 1;
                }
            }

            if (!stake || recipient != _msgSender()) {
                _safeMint(recipient, minted);
            } else {
                _safeMint(address(barn), minted);
                tokenIds[i] = minted;
            }
            totalWoolCost += mintCost(minted);
        }

        if (totalWoolCost > 0) wool.burn(_msgSender(), totalWoolCost);
        if (stake) barn.addManyToBarnAndPack(_msgSender(), tokenIds);
    }

    /**
     * the first 20% are paid in ETH
     * the next 20% are 20000 $WOOL
     * the next 40% are 40000 $WOOL
     * the final 20% are 80000 $WOOL
     * @param tokenId the ID to check the cost of to mint
     * @return the cost of the given token ID
     */
    function mintCost(uint256 tokenId) public view returns (uint256) {
        if (tokenId <= PAID_TOKENS) return 0;
        if (tokenId <= (MAX_TOKENS * 2) / 5) return 20000 ether;
        if (tokenId <= (MAX_TOKENS * 4) / 5) return 40000 ether;
        return 80000 ether;
    }

    function transferFrom(
        address from,
        address to,
        uint256 tokenId
    ) public virtual override {
        // Hardcode the Barn's approval so that users don't have to waste gas approving
        if (_msgSender() != address(barn))
            require(
                _isApprovedOrOwner(_msgSender(), tokenId),
                "ERC721: transfer caller is not owner nor approved"
            );
        _transfer(from, to, tokenId);
    }

    /** INTERNAL */

    /**
     * generates traits for a specific token, checking to make sure it's unique
     * @param tokenId the id of the token to generate traits for
     * @param seed a pseudorandom 256 bit number to derive traits from
     * @return t - a struct of traits for the given token ID
     */
    function generate(uint256 tokenId, uint256 seed)
        internal
        returns (SheepWolf memory t)
    {
        t = selectTraits(seed);
        if (existingCombinations[structToHash(t)] == 0) {
            tokenTraits[tokenId] = t;
            existingCombinations[structToHash(t)] = tokenId;
            return t;
        }
        return generate(tokenId, random(seed));
    }

    /**
     * uses A.J. Walker's Alias algorithm for O(1) rarity table lookup
     * ensuring O(1) instead of O(n) reduces mint cost by more than 50%
     * probability & alias tables are generated off-chain beforehand
     * @param seed portion of the 256 bit seed to remove trait correlation
     * @param traitType the trait type to select a trait for
     * @return the ID of the randomly selected trait
     */
    function selectTrait(uint16 seed, uint8 traitType)
        internal
        view
        returns (uint8)
    {
        uint8 trait = uint8(seed) % uint8(rarities[traitType].length);
        if (seed >> 8 < rarities[traitType][trait]) return trait;
        return aliases[traitType][trait];
    }

    /**
     * the first 20% (ETH purchases) go to the minter
     * the remaining 80% have a 10% chance to be given to a random staked wolf
     * @param seed a random value to select a recipient from
     * @return the address of the recipient (either the minter or the Wolf thief's owner)
     */
    function selectRecipient(uint256 seed) internal view returns (address) {
        if (minted <= PAID_TOKENS || ((seed >> 245) % 10) != 0)
            return _msgSender(); // top 10 bits haven't been used
        address thief = barn.randomWolfOwner(seed >> 144); // 144 bits reserved for trait selection
        if (thief == address(0x0)) return _msgSender();
        return thief;
    }

    /**
     * selects the species and all of its traits based on the seed value
     * @param seed a pseudorandom 256 bit number to derive traits from
     * @return t -  a struct of randomly selected traits
     */
    function selectTraits(uint256 seed)
        internal
        view
        returns (SheepWolf memory t)
    {
        t.isSheep = (seed & 0xFFFF) % 10 != 0;
        uint8 shift = t.isSheep ? 0 : 9;
        seed >>= 16;
        t.fur = selectTrait(uint16(seed & 0xFFFF), 0 + shift);
        seed >>= 16;
        t.head = selectTrait(uint16(seed & 0xFFFF), 1 + shift);
        seed >>= 16;
        t.ears = selectTrait(uint16(seed & 0xFFFF), 2 + shift);
        seed >>= 16;
        t.eyes = selectTrait(uint16(seed & 0xFFFF), 3 + shift);
        seed >>= 16;
        t.nose = selectTrait(uint16(seed & 0xFFFF), 4 + shift);
        seed >>= 16;
        t.mouth = selectTrait(uint16(seed & 0xFFFF), 5 + shift);
        seed >>= 16;
        t.neck = selectTrait(uint16(seed & 0xFFFF), 6 + shift);
        seed >>= 16;
        t.feet = selectTrait(uint16(seed & 0xFFFF), 7 + shift);
        seed >>= 16;
        t.alphaIndex = selectTrait(uint16(seed & 0xFFFF), 8 + shift);
    }

    /**
     * converts a struct to a 256 bit hash to check for uniqueness
     * @param s the struct to pack into a hash
     * @return the 256 bit hash of the struct
     */
    function structToHash(SheepWolf memory s) internal pure returns (uint256) {
        return
            uint256(
                bytes32(
                    abi.encodePacked(
                        s.isSheep,
                        s.fur,
                        s.head,
                        s.eyes,
                        s.mouth,
                        s.neck,
                        s.ears,
                        s.feet,
                        s.alphaIndex
                    )
                )
            );
    }

    /**
     * generates a pseudorandom number
     * @param seed a value ensure different outcomes for different sources in the same block
     * @return a pseudorandom value
     */
    function random(uint256 seed) internal view returns (uint256) {
        return
            uint256(
                keccak256(
                    abi.encodePacked(
                        tx.origin,
                        blockhash(block.number - 1),
                        block.timestamp,
                        seed
                    )
                )
            );
    }

    /** READ */

    function getTokenTraits(uint256 tokenId)
        external
        view
        override
        returns (SheepWolf memory)
    {
        return tokenTraits[tokenId];
    }

    function getPaidTokens() external view override returns (uint256) {
        return PAID_TOKENS;
    }

    /** ADMIN */

    /**
     * called after deployment so that the contract can get random wolf thieves
     * @param _barn the address of the Barn
     */
    function setBarn(address _barn) external onlyOwner {
        barn = IBarn(_barn);
    }

    /**
     * allows owner to withdraw funds from minting
     */
    function withdraw() external onlyOwner {
        payable(owner()).transfer(address(this).balance);
    }

    /**
     * updates the number of tokens for sale
     */
    function setPaidTokens(uint256 _paidTokens) external onlyOwner {
        PAID_TOKENS = _paidTokens;
    }

    /**
     * enables owner to pause / unpause minting
     */
    function setPaused(bool _paused) external onlyOwner {
        if (_paused) _pause();
        else _unpause();
    }

    /** RENDER */

    function tokenURI(uint256 tokenId)
        public
        view
        override
        returns (string memory)
    {
        require(
            _exists(tokenId),
            "ERC721Metadata: URI query for nonexistent token"
        );
        return traits.tokenURI(tokenId);
    }
}

// SPDX-License-Identifier: MIT LICENSE

pragma solidity 0.8.7;
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";


contract WOOL is ERC20, Ownable {

  // a mapping from an address to whether or not it can mint / burn
  mapping(address => bool) controllers;
  
  constructor() ERC20("WOOL", "WOOL") { }

  /**
   * mints $WOOL to a recipient
   * @param to the recipient of the $WOOL
   * @param amount the amount of $WOOL to mint
   */
  function mint(address to, uint256 amount) external {
    require(controllers[msg.sender], "Only controllers can mint");
    _mint(to, amount);
  }

  /**
   * burns $WOOL from a holder
   * @param from the holder of the $WOOL
   * @param amount the amount of $WOOL to burn
   */
  function burn(address from, uint256 amount) external {
    require(controllers[msg.sender], "Only controllers can burn");
    _burn(from, amount);
  }

  /**
   * enables an address to mint / burn
   * @param controller the address to enable
   */
  function addController(address controller) external onlyOwner {
    controllers[controller] = true;
  }

  /**
   * disables an address from minting / burning
   * @param controller the address to disbale
   */
  function removeController(address controller) external onlyOwner {
    controllers[controller] = false;
  }
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.0 (token/ERC721/IERC721Receiver.sol)

pragma solidity ^0.8.0;

/**
 * @title ERC721 token receiver interface
 * @dev Interface for any contract that wants to support safeTransfers
 * from ERC721 asset contracts.
 */
interface IERC721Receiver {
    /**
     * @dev Whenever an {IERC721} `tokenId` token is transferred to this contract via {IERC721-safeTransferFrom}
     * by `operator` from `from`, this function is called.
     *
     * It must return its Solidity selector to confirm the token transfer.
     * If any other value is returned or the interface is not implemented by the recipient, the transfer will be reverted.
     *
     * The selector can be obtained in Solidity with `IERC721.onERC721Received.selector`.
     */
    function onERC721Received(
        address operator,
        address from,
        uint256 tokenId,
        bytes calldata data
    ) external returns (bytes4);
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.0 (utils/Context.sol)

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

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface LinkTokenInterface {
  function allowance(address owner, address spender) external view returns (uint256 remaining);

  function approve(address spender, uint256 value) external returns (bool success);

  function balanceOf(address owner) external view returns (uint256 balance);

  function decimals() external view returns (uint8 decimalPlaces);

  function decreaseApproval(address spender, uint256 addedValue) external returns (bool success);

  function increaseApproval(address spender, uint256 subtractedValue) external;

  function name() external view returns (string memory tokenName);

  function symbol() external view returns (string memory tokenSymbol);

  function totalSupply() external view returns (uint256 totalTokensIssued);

  function transfer(address to, uint256 value) external returns (bool success);

  function transferAndCall(
    address to,
    uint256 value,
    bytes calldata data
  ) external returns (bool success);

  function transferFrom(
    address from,
    address to,
    uint256 value
  ) external returns (bool success);
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract VRFRequestIDBase {
  /**
   * @notice returns the seed which is actually input to the VRF coordinator
   *
   * @dev To prevent repetition of VRF output due to repetition of the
   * @dev user-supplied seed, that seed is combined in a hash with the
   * @dev user-specific nonce, and the address of the consuming contract. The
   * @dev risk of repetition is mostly mitigated by inclusion of a blockhash in
   * @dev the final seed, but the nonce does protect against repetition in
   * @dev requests which are included in a single block.
   *
   * @param _userSeed VRF seed input provided by user
   * @param _requester Address of the requesting contract
   * @param _nonce User-specific nonce at the time of the request
   */
  function makeVRFInputSeed(
    bytes32 _keyHash,
    uint256 _userSeed,
    address _requester,
    uint256 _nonce
  ) internal pure returns (uint256) {
    return uint256(keccak256(abi.encode(_keyHash, _userSeed, _requester, _nonce)));
  }

  /**
   * @notice Returns the id for this request
   * @param _keyHash The serviceAgreement ID to be used for this request
   * @param _vRFInputSeed The seed to be passed directly to the VRF
   * @return The id for this request
   *
   * @dev Note that _vRFInputSeed is not the seed passed by the consuming
   * @dev contract, but the one generated by makeVRFInputSeed
   */
  function makeRequestId(bytes32 _keyHash, uint256 _vRFInputSeed) internal pure returns (bytes32) {
    return keccak256(abi.encodePacked(_keyHash, _vRFInputSeed));
  }
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.0 (token/ERC721/extensions/ERC721Enumerable.sol)

pragma solidity ^0.8.0;

import "../ERC721.sol";
import "./IERC721Enumerable.sol";

/**
 * @dev This implements an optional extension of {ERC721} defined in the EIP that adds
 * enumerability of all the token ids in the contract as well as all token ids owned by each
 * account.
 */
abstract contract ERC721Enumerable is ERC721, IERC721Enumerable {
    // Mapping from owner to list of owned token IDs
    mapping(address => mapping(uint256 => uint256)) private _ownedTokens;

    // Mapping from token ID to index of the owner tokens list
    mapping(uint256 => uint256) private _ownedTokensIndex;

    // Array with all token ids, used for enumeration
    uint256[] private _allTokens;

    // Mapping from token id to position in the allTokens array
    mapping(uint256 => uint256) private _allTokensIndex;

    /**
     * @dev See {IERC165-supportsInterface}.
     */
    function supportsInterface(bytes4 interfaceId) public view virtual override(IERC165, ERC721) returns (bool) {
        return interfaceId == type(IERC721Enumerable).interfaceId || super.supportsInterface(interfaceId);
    }

    /**
     * @dev See {IERC721Enumerable-tokenOfOwnerByIndex}.
     */
    function tokenOfOwnerByIndex(address owner, uint256 index) public view virtual override returns (uint256) {
        require(index < ERC721.balanceOf(owner), "ERC721Enumerable: owner index out of bounds");
        return _ownedTokens[owner][index];
    }

    /**
     * @dev See {IERC721Enumerable-totalSupply}.
     */
    function totalSupply() public view virtual override returns (uint256) {
        return _allTokens.length;
    }

    /**
     * @dev See {IERC721Enumerable-tokenByIndex}.
     */
    function tokenByIndex(uint256 index) public view virtual override returns (uint256) {
        require(index < ERC721Enumerable.totalSupply(), "ERC721Enumerable: global index out of bounds");
        return _allTokens[index];
    }

    /**
     * @dev Hook that is called before any token transfer. This includes minting
     * and burning.
     *
     * Calling conditions:
     *
     * - When `from` and `to` are both non-zero, ``from``'s `tokenId` will be
     * transferred to `to`.
     * - When `from` is zero, `tokenId` will be minted for `to`.
     * - When `to` is zero, ``from``'s `tokenId` will be burned.
     * - `from` cannot be the zero address.
     * - `to` cannot be the zero address.
     *
     * To learn more about hooks, head to xref:ROOT:extending-contracts.adoc#using-hooks[Using Hooks].
     */
    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 tokenId
    ) internal virtual override {
        super._beforeTokenTransfer(from, to, tokenId);

        if (from == address(0)) {
            _addTokenToAllTokensEnumeration(tokenId);
        } else if (from != to) {
            _removeTokenFromOwnerEnumeration(from, tokenId);
        }
        if (to == address(0)) {
            _removeTokenFromAllTokensEnumeration(tokenId);
        } else if (to != from) {
            _addTokenToOwnerEnumeration(to, tokenId);
        }
    }

    /**
     * @dev Private function to add a token to this extension's ownership-tracking data structures.
     * @param to address representing the new owner of the given token ID
     * @param tokenId uint256 ID of the token to be added to the tokens list of the given address
     */
    function _addTokenToOwnerEnumeration(address to, uint256 tokenId) private {
        uint256 length = ERC721.balanceOf(to);
        _ownedTokens[to][length] = tokenId;
        _ownedTokensIndex[tokenId] = length;
    }

    /**
     * @dev Private function to add a token to this extension's token tracking data structures.
     * @param tokenId uint256 ID of the token to be added to the tokens list
     */
    function _addTokenToAllTokensEnumeration(uint256 tokenId) private {
        _allTokensIndex[tokenId] = _allTokens.length;
        _allTokens.push(tokenId);
    }

    /**
     * @dev Private function to remove a token from this extension's ownership-tracking data structures. Note that
     * while the token is not assigned a new owner, the `_ownedTokensIndex` mapping is _not_ updated: this allows for
     * gas optimizations e.g. when performing a transfer operation (avoiding double writes).
     * This has O(1) time complexity, but alters the order of the _ownedTokens array.
     * @param from address representing the previous owner of the given token ID
     * @param tokenId uint256 ID of the token to be removed from the tokens list of the given address
     */
    function _removeTokenFromOwnerEnumeration(address from, uint256 tokenId) private {
        // To prevent a gap in from's tokens array, we store the last token in the index of the token to delete, and
        // then delete the last slot (swap and pop).

        uint256 lastTokenIndex = ERC721.balanceOf(from) - 1;
        uint256 tokenIndex = _ownedTokensIndex[tokenId];

        // When the token to delete is the last token, the swap operation is unnecessary
        if (tokenIndex != lastTokenIndex) {
            uint256 lastTokenId = _ownedTokens[from][lastTokenIndex];

            _ownedTokens[from][tokenIndex] = lastTokenId; // Move the last token to the slot of the to-delete token
            _ownedTokensIndex[lastTokenId] = tokenIndex; // Update the moved token's index
        }

        // This also deletes the contents at the last position of the array
        delete _ownedTokensIndex[tokenId];
        delete _ownedTokens[from][lastTokenIndex];
    }

    /**
     * @dev Private function to remove a token from this extension's token tracking data structures.
     * This has O(1) time complexity, but alters the order of the _allTokens array.
     * @param tokenId uint256 ID of the token to be removed from the tokens list
     */
    function _removeTokenFromAllTokensEnumeration(uint256 tokenId) private {
        // To prevent a gap in the tokens array, we store the last token in the index of the token to delete, and
        // then delete the last slot (swap and pop).

        uint256 lastTokenIndex = _allTokens.length - 1;
        uint256 tokenIndex = _allTokensIndex[tokenId];

        // When the token to delete is the last token, the swap operation is unnecessary. However, since this occurs so
        // rarely (when the last minted token is burnt) that we still do the swap here to avoid the gas cost of adding
        // an 'if' statement (like in _removeTokenFromOwnerEnumeration)
        uint256 lastTokenId = _allTokens[lastTokenIndex];

        _allTokens[tokenIndex] = lastTokenId; // Move the last token to the slot of the to-delete token
        _allTokensIndex[lastTokenId] = tokenIndex; // Update the moved token's index

        // This also deletes the contents at the last position of the array
        delete _allTokensIndex[tokenId];
        _allTokens.pop();
    }
}

// SPDX-License-Identifier: MIT LICENSE

pragma solidity 0.8.7;

interface IWoolf {

  // struct to store each token's traits
  struct SheepWolf {
    bool isSheep;
    uint8 fur;
    uint8 head;
    uint8 ears;
    uint8 eyes;
    uint8 nose;
    uint8 mouth;
    uint8 neck;
    uint8 feet;
    uint8 alphaIndex;
  }


  function getPaidTokens() external view returns (uint256);
  function getTokenTraits(uint256 tokenId) external view returns (SheepWolf memory);
}

// SPDX-License-Identifier: MIT LICENSE 

pragma solidity 0.8.7;

interface IBarn {
  function addManyToBarnAndPack(address account, uint16[] calldata tokenIds) external;
  function randomWolfOwner(uint256 seed) external view returns (address);
}

// SPDX-License-Identifier: MIT LICENSE 

pragma solidity 0.8.7;

interface ITraits {
  function tokenURI(uint256 tokenId) external view returns (string memory);
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.0 (token/ERC721/ERC721.sol)

pragma solidity ^0.8.0;

import "./IERC721.sol";
import "./IERC721Receiver.sol";
import "./extensions/IERC721Metadata.sol";
import "../../utils/Address.sol";
import "../../utils/Context.sol";
import "../../utils/Strings.sol";
import "../../utils/introspection/ERC165.sol";

/**
 * @dev Implementation of https://eips.ethereum.org/EIPS/eip-721[ERC721] Non-Fungible Token Standard, including
 * the Metadata extension, but not including the Enumerable extension, which is available separately as
 * {ERC721Enumerable}.
 */
contract ERC721 is Context, ERC165, IERC721, IERC721Metadata {
    using Address for address;
    using Strings for uint256;

    // Token name
    string private _name;

    // Token symbol
    string private _symbol;

    // Mapping from token ID to owner address
    mapping(uint256 => address) private _owners;

    // Mapping owner address to token count
    mapping(address => uint256) private _balances;

    // Mapping from token ID to approved address
    mapping(uint256 => address) private _tokenApprovals;

    // Mapping from owner to operator approvals
    mapping(address => mapping(address => bool)) private _operatorApprovals;

    /**
     * @dev Initializes the contract by setting a `name` and a `symbol` to the token collection.
     */
    constructor(string memory name_, string memory symbol_) {
        _name = name_;
        _symbol = symbol_;
    }

    /**
     * @dev See {IERC165-supportsInterface}.
     */
    function supportsInterface(bytes4 interfaceId) public view virtual override(ERC165, IERC165) returns (bool) {
        return
            interfaceId == type(IERC721).interfaceId ||
            interfaceId == type(IERC721Metadata).interfaceId ||
            super.supportsInterface(interfaceId);
    }

    /**
     * @dev See {IERC721-balanceOf}.
     */
    function balanceOf(address owner) public view virtual override returns (uint256) {
        require(owner != address(0), "ERC721: balance query for the zero address");
        return _balances[owner];
    }

    /**
     * @dev See {IERC721-ownerOf}.
     */
    function ownerOf(uint256 tokenId) public view virtual override returns (address) {
        address owner = _owners[tokenId];
        require(owner != address(0), "ERC721: owner query for nonexistent token");
        return owner;
    }

    /**
     * @dev See {IERC721Metadata-name}.
     */
    function name() public view virtual override returns (string memory) {
        return _name;
    }

    /**
     * @dev See {IERC721Metadata-symbol}.
     */
    function symbol() public view virtual override returns (string memory) {
        return _symbol;
    }

    /**
     * @dev See {IERC721Metadata-tokenURI}.
     */
    function tokenURI(uint256 tokenId) public view virtual override returns (string memory) {
        require(_exists(tokenId), "ERC721Metadata: URI query for nonexistent token");

        string memory baseURI = _baseURI();
        return bytes(baseURI).length > 0 ? string(abi.encodePacked(baseURI, tokenId.toString())) : "";
    }

    /**
     * @dev Base URI for computing {tokenURI}. If set, the resulting URI for each
     * token will be the concatenation of the `baseURI` and the `tokenId`. Empty
     * by default, can be overriden in child contracts.
     */
    function _baseURI() internal view virtual returns (string memory) {
        return "";
    }

    /**
     * @dev See {IERC721-approve}.
     */
    function approve(address to, uint256 tokenId) public virtual override {
        address owner = ERC721.ownerOf(tokenId);
        require(to != owner, "ERC721: approval to current owner");

        require(
            _msgSender() == owner || isApprovedForAll(owner, _msgSender()),
            "ERC721: approve caller is not owner nor approved for all"
        );

        _approve(to, tokenId);
    }

    /**
     * @dev See {IERC721-getApproved}.
     */
    function getApproved(uint256 tokenId) public view virtual override returns (address) {
        require(_exists(tokenId), "ERC721: approved query for nonexistent token");

        return _tokenApprovals[tokenId];
    }

    /**
     * @dev See {IERC721-setApprovalForAll}.
     */
    function setApprovalForAll(address operator, bool approved) public virtual override {
        _setApprovalForAll(_msgSender(), operator, approved);
    }

    /**
     * @dev See {IERC721-isApprovedForAll}.
     */
    function isApprovedForAll(address owner, address operator) public view virtual override returns (bool) {
        return _operatorApprovals[owner][operator];
    }

    /**
     * @dev See {IERC721-transferFrom}.
     */
    function transferFrom(
        address from,
        address to,
        uint256 tokenId
    ) public virtual override {
        //solhint-disable-next-line max-line-length
        require(_isApprovedOrOwner(_msgSender(), tokenId), "ERC721: transfer caller is not owner nor approved");

        _transfer(from, to, tokenId);
    }

    /**
     * @dev See {IERC721-safeTransferFrom}.
     */
    function safeTransferFrom(
        address from,
        address to,
        uint256 tokenId
    ) public virtual override {
        safeTransferFrom(from, to, tokenId, "");
    }

    /**
     * @dev See {IERC721-safeTransferFrom}.
     */
    function safeTransferFrom(
        address from,
        address to,
        uint256 tokenId,
        bytes memory _data
    ) public virtual override {
        require(_isApprovedOrOwner(_msgSender(), tokenId), "ERC721: transfer caller is not owner nor approved");
        _safeTransfer(from, to, tokenId, _data);
    }

    /**
     * @dev Safely transfers `tokenId` token from `from` to `to`, checking first that contract recipients
     * are aware of the ERC721 protocol to prevent tokens from being forever locked.
     *
     * `_data` is additional data, it has no specified format and it is sent in call to `to`.
     *
     * This internal function is equivalent to {safeTransferFrom}, and can be used to e.g.
     * implement alternative mechanisms to perform token transfer, such as signature-based.
     *
     * Requirements:
     *
     * - `from` cannot be the zero address.
     * - `to` cannot be the zero address.
     * - `tokenId` token must exist and be owned by `from`.
     * - If `to` refers to a smart contract, it must implement {IERC721Receiver-onERC721Received}, which is called upon a safe transfer.
     *
     * Emits a {Transfer} event.
     */
    function _safeTransfer(
        address from,
        address to,
        uint256 tokenId,
        bytes memory _data
    ) internal virtual {
        _transfer(from, to, tokenId);
        require(_checkOnERC721Received(from, to, tokenId, _data), "ERC721: transfer to non ERC721Receiver implementer");
    }

    /**
     * @dev Returns whether `tokenId` exists.
     *
     * Tokens can be managed by their owner or approved accounts via {approve} or {setApprovalForAll}.
     *
     * Tokens start existing when they are minted (`_mint`),
     * and stop existing when they are burned (`_burn`).
     */
    function _exists(uint256 tokenId) internal view virtual returns (bool) {
        return _owners[tokenId] != address(0);
    }

    /**
     * @dev Returns whether `spender` is allowed to manage `tokenId`.
     *
     * Requirements:
     *
     * - `tokenId` must exist.
     */
    function _isApprovedOrOwner(address spender, uint256 tokenId) internal view virtual returns (bool) {
        require(_exists(tokenId), "ERC721: operator query for nonexistent token");
        address owner = ERC721.ownerOf(tokenId);
        return (spender == owner || getApproved(tokenId) == spender || isApprovedForAll(owner, spender));
    }

    /**
     * @dev Safely mints `tokenId` and transfers it to `to`.
     *
     * Requirements:
     *
     * - `tokenId` must not exist.
     * - If `to` refers to a smart contract, it must implement {IERC721Receiver-onERC721Received}, which is called upon a safe transfer.
     *
     * Emits a {Transfer} event.
     */
    function _safeMint(address to, uint256 tokenId) internal virtual {
        _safeMint(to, tokenId, "");
    }

    /**
     * @dev Same as {xref-ERC721-_safeMint-address-uint256-}[`_safeMint`], with an additional `data` parameter which is
     * forwarded in {IERC721Receiver-onERC721Received} to contract recipients.
     */
    function _safeMint(
        address to,
        uint256 tokenId,
        bytes memory _data
    ) internal virtual {
        _mint(to, tokenId);
        require(
            _checkOnERC721Received(address(0), to, tokenId, _data),
            "ERC721: transfer to non ERC721Receiver implementer"
        );
    }

    /**
     * @dev Mints `tokenId` and transfers it to `to`.
     *
     * WARNING: Usage of this method is discouraged, use {_safeMint} whenever possible
     *
     * Requirements:
     *
     * - `tokenId` must not exist.
     * - `to` cannot be the zero address.
     *
     * Emits a {Transfer} event.
     */
    function _mint(address to, uint256 tokenId) internal virtual {
        require(to != address(0), "ERC721: mint to the zero address");
        require(!_exists(tokenId), "ERC721: token already minted");

        _beforeTokenTransfer(address(0), to, tokenId);

        _balances[to] += 1;
        _owners[tokenId] = to;

        emit Transfer(address(0), to, tokenId);
    }

    /**
     * @dev Destroys `tokenId`.
     * The approval is cleared when the token is burned.
     *
     * Requirements:
     *
     * - `tokenId` must exist.
     *
     * Emits a {Transfer} event.
     */
    function _burn(uint256 tokenId) internal virtual {
        address owner = ERC721.ownerOf(tokenId);

        _beforeTokenTransfer(owner, address(0), tokenId);

        // Clear approvals
        _approve(address(0), tokenId);

        _balances[owner] -= 1;
        delete _owners[tokenId];

        emit Transfer(owner, address(0), tokenId);
    }

    /**
     * @dev Transfers `tokenId` from `from` to `to`.
     *  As opposed to {transferFrom}, this imposes no restrictions on msg.sender.
     *
     * Requirements:
     *
     * - `to` cannot be the zero address.
     * - `tokenId` token must be owned by `from`.
     *
     * Emits a {Transfer} event.
     */
    function _transfer(
        address from,
        address to,
        uint256 tokenId
    ) internal virtual {
        require(ERC721.ownerOf(tokenId) == from, "ERC721: transfer of token that is not own");
        require(to != address(0), "ERC721: transfer to the zero address");

        _beforeTokenTransfer(from, to, tokenId);

        // Clear approvals from the previous owner
        _approve(address(0), tokenId);

        _balances[from] -= 1;
        _balances[to] += 1;
        _owners[tokenId] = to;

        emit Transfer(from, to, tokenId);
    }

    /**
     * @dev Approve `to` to operate on `tokenId`
     *
     * Emits a {Approval} event.
     */
    function _approve(address to, uint256 tokenId) internal virtual {
        _tokenApprovals[tokenId] = to;
        emit Approval(ERC721.ownerOf(tokenId), to, tokenId);
    }

    /**
     * @dev Approve `operator` to operate on all of `owner` tokens
     *
     * Emits a {ApprovalForAll} event.
     */
    function _setApprovalForAll(
        address owner,
        address operator,
        bool approved
    ) internal virtual {
        require(owner != operator, "ERC721: approve to caller");
        _operatorApprovals[owner][operator] = approved;
        emit ApprovalForAll(owner, operator, approved);
    }

    /**
     * @dev Internal function to invoke {IERC721Receiver-onERC721Received} on a target address.
     * The call is not executed if the target address is not a contract.
     *
     * @param from address representing the previous owner of the given token ID
     * @param to target address that will receive the tokens
     * @param tokenId uint256 ID of the token to be transferred
     * @param _data bytes optional data to send along with the call
     * @return bool whether the call correctly returned the expected magic value
     */
    function _checkOnERC721Received(
        address from,
        address to,
        uint256 tokenId,
        bytes memory _data
    ) private returns (bool) {
        if (to.isContract()) {
            try IERC721Receiver(to).onERC721Received(_msgSender(), from, tokenId, _data) returns (bytes4 retval) {
                return retval == IERC721Receiver.onERC721Received.selector;
            } catch (bytes memory reason) {
                if (reason.length == 0) {
                    revert("ERC721: transfer to non ERC721Receiver implementer");
                } else {
                    assembly {
                        revert(add(32, reason), mload(reason))
                    }
                }
            }
        } else {
            return true;
        }
    }

    /**
     * @dev Hook that is called before any token transfer. This includes minting
     * and burning.
     *
     * Calling conditions:
     *
     * - When `from` and `to` are both non-zero, ``from``'s `tokenId` will be
     * transferred to `to`.
     * - When `from` is zero, `tokenId` will be minted for `to`.
     * - When `to` is zero, ``from``'s `tokenId` will be burned.
     * - `from` and `to` are never both zero.
     *
     * To learn more about hooks, head to xref:ROOT:extending-contracts.adoc#using-hooks[Using Hooks].
     */
    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 tokenId
    ) internal virtual {}
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.0 (token/ERC721/extensions/IERC721Enumerable.sol)

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
    function tokenOfOwnerByIndex(address owner, uint256 index) external view returns (uint256 tokenId);

    /**
     * @dev Returns a token ID at a given `index` of all the tokens stored by the contract.
     * Use along with {totalSupply} to enumerate all tokens.
     */
    function tokenByIndex(uint256 index) external view returns (uint256);
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.0 (token/ERC721/IERC721.sol)

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
// OpenZeppelin Contracts v4.4.0 (token/ERC721/extensions/IERC721Metadata.sol)

pragma solidity ^0.8.0;

import "../IERC721.sol";

/**
 * @title ERC-721 Non-Fungible Token Standard, optional metadata extension
 * @dev See https://eips.ethereum.org/EIPS/eip-721
 */
interface IERC721Metadata is IERC721 {
    /**
     * @dev Returns the token collection name.
     */
    function name() external view returns (string memory);

    /**
     * @dev Returns the token collection symbol.
     */
    function symbol() external view returns (string memory);

    /**
     * @dev Returns the Uniform Resource Identifier (URI) for `tokenId` token.
     */
    function tokenURI(uint256 tokenId) external view returns (string memory);
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.0 (utils/Address.sol)

pragma solidity ^0.8.0;

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

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.0 (utils/Strings.sol)

pragma solidity ^0.8.0;

/**
 * @dev String operations.
 */
library Strings {
    bytes16 private constant _HEX_SYMBOLS = "0123456789abcdef";

    /**
     * @dev Converts a `uint256` to its ASCII `string` decimal representation.
     */
    function toString(uint256 value) internal pure returns (string memory) {
        // Inspired by OraclizeAPI's implementation - MIT licence
        // https://github.com/oraclize/ethereum-api/blob/b42146b063c7d6ee1358846c198246239e9360e8/oraclizeAPI_0.4.25.sol

        if (value == 0) {
            return "0";
        }
        uint256 temp = value;
        uint256 digits;
        while (temp != 0) {
            digits++;
            temp /= 10;
        }
        bytes memory buffer = new bytes(digits);
        while (value != 0) {
            digits -= 1;
            buffer[digits] = bytes1(uint8(48 + uint256(value % 10)));
            value /= 10;
        }
        return string(buffer);
    }

    /**
     * @dev Converts a `uint256` to its ASCII `string` hexadecimal representation.
     */
    function toHexString(uint256 value) internal pure returns (string memory) {
        if (value == 0) {
            return "0x00";
        }
        uint256 temp = value;
        uint256 length = 0;
        while (temp != 0) {
            length++;
            temp >>= 8;
        }
        return toHexString(value, length);
    }

    /**
     * @dev Converts a `uint256` to its ASCII `string` hexadecimal representation with fixed length.
     */
    function toHexString(uint256 value, uint256 length) internal pure returns (string memory) {
        bytes memory buffer = new bytes(2 * length + 2);
        buffer[0] = "0";
        buffer[1] = "x";
        for (uint256 i = 2 * length + 1; i > 1; --i) {
            buffer[i] = _HEX_SYMBOLS[value & 0xf];
            value >>= 4;
        }
        require(value == 0, "Strings: hex length insufficient");
        return string(buffer);
    }
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.0 (utils/introspection/ERC165.sol)

pragma solidity ^0.8.0;

import "./IERC165.sol";

/**
 * @dev Implementation of the {IERC165} interface.
 *
 * Contracts that want to implement ERC165 should inherit from this contract and override {supportsInterface} to check
 * for the additional interface id that will be supported. For example:
 *
 * ```solidity
 * function supportsInterface(bytes4 interfaceId) public view virtual override returns (bool) {
 *     return interfaceId == type(MyInterface).interfaceId || super.supportsInterface(interfaceId);
 * }
 * ```
 *
 * Alternatively, {ERC165Storage} provides an easier to use but more expensive implementation.
 */
abstract contract ERC165 is IERC165 {
    /**
     * @dev See {IERC165-supportsInterface}.
     */
    function supportsInterface(bytes4 interfaceId) public view virtual override returns (bool) {
        return interfaceId == type(IERC165).interfaceId;
    }
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.0 (utils/introspection/IERC165.sol)

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
// OpenZeppelin Contracts v4.4.0 (token/ERC20/ERC20.sol)

pragma solidity ^0.8.0;

import "./IERC20.sol";
import "./extensions/IERC20Metadata.sol";
import "../../utils/Context.sol";

/**
 * @dev Implementation of the {IERC20} interface.
 *
 * This implementation is agnostic to the way tokens are created. This means
 * that a supply mechanism has to be added in a derived contract using {_mint}.
 * For a generic mechanism see {ERC20PresetMinterPauser}.
 *
 * TIP: For a detailed writeup see our guide
 * https://forum.zeppelin.solutions/t/how-to-implement-erc20-supply-mechanisms/226[How
 * to implement supply mechanisms].
 *
 * We have followed general OpenZeppelin Contracts guidelines: functions revert
 * instead returning `false` on failure. This behavior is nonetheless
 * conventional and does not conflict with the expectations of ERC20
 * applications.
 *
 * Additionally, an {Approval} event is emitted on calls to {transferFrom}.
 * This allows applications to reconstruct the allowance for all accounts just
 * by listening to said events. Other implementations of the EIP may not emit
 * these events, as it isn't required by the specification.
 *
 * Finally, the non-standard {decreaseAllowance} and {increaseAllowance}
 * functions have been added to mitigate the well-known issues around setting
 * allowances. See {IERC20-approve}.
 */
contract ERC20 is Context, IERC20, IERC20Metadata {
    mapping(address => uint256) private _balances;

    mapping(address => mapping(address => uint256)) private _allowances;

    uint256 private _totalSupply;

    string private _name;
    string private _symbol;

    /**
     * @dev Sets the values for {name} and {symbol}.
     *
     * The default value of {decimals} is 18. To select a different value for
     * {decimals} you should overload it.
     *
     * All two of these values are immutable: they can only be set once during
     * construction.
     */
    constructor(string memory name_, string memory symbol_) {
        _name = name_;
        _symbol = symbol_;
    }

    /**
     * @dev Returns the name of the token.
     */
    function name() public view virtual override returns (string memory) {
        return _name;
    }

    /**
     * @dev Returns the symbol of the token, usually a shorter version of the
     * name.
     */
    function symbol() public view virtual override returns (string memory) {
        return _symbol;
    }

    /**
     * @dev Returns the number of decimals used to get its user representation.
     * For example, if `decimals` equals `2`, a balance of `505` tokens should
     * be displayed to a user as `5.05` (`505 / 10 ** 2`).
     *
     * Tokens usually opt for a value of 18, imitating the relationship between
     * Ether and Wei. This is the value {ERC20} uses, unless this function is
     * overridden;
     *
     * NOTE: This information is only used for _display_ purposes: it in
     * no way affects any of the arithmetic of the contract, including
     * {IERC20-balanceOf} and {IERC20-transfer}.
     */
    function decimals() public view virtual override returns (uint8) {
        return 18;
    }

    /**
     * @dev See {IERC20-totalSupply}.
     */
    function totalSupply() public view virtual override returns (uint256) {
        return _totalSupply;
    }

    /**
     * @dev See {IERC20-balanceOf}.
     */
    function balanceOf(address account) public view virtual override returns (uint256) {
        return _balances[account];
    }

    /**
     * @dev See {IERC20-transfer}.
     *
     * Requirements:
     *
     * - `recipient` cannot be the zero address.
     * - the caller must have a balance of at least `amount`.
     */
    function transfer(address recipient, uint256 amount) public virtual override returns (bool) {
        _transfer(_msgSender(), recipient, amount);
        return true;
    }

    /**
     * @dev See {IERC20-allowance}.
     */
    function allowance(address owner, address spender) public view virtual override returns (uint256) {
        return _allowances[owner][spender];
    }

    /**
     * @dev See {IERC20-approve}.
     *
     * Requirements:
     *
     * - `spender` cannot be the zero address.
     */
    function approve(address spender, uint256 amount) public virtual override returns (bool) {
        _approve(_msgSender(), spender, amount);
        return true;
    }

    /**
     * @dev See {IERC20-transferFrom}.
     *
     * Emits an {Approval} event indicating the updated allowance. This is not
     * required by the EIP. See the note at the beginning of {ERC20}.
     *
     * Requirements:
     *
     * - `sender` and `recipient` cannot be the zero address.
     * - `sender` must have a balance of at least `amount`.
     * - the caller must have allowance for ``sender``'s tokens of at least
     * `amount`.
     */
    function transferFrom(
        address sender,
        address recipient,
        uint256 amount
    ) public virtual override returns (bool) {
        _transfer(sender, recipient, amount);

        uint256 currentAllowance = _allowances[sender][_msgSender()];
        require(currentAllowance >= amount, "ERC20: transfer amount exceeds allowance");
        unchecked {
            _approve(sender, _msgSender(), currentAllowance - amount);
        }

        return true;
    }

    /**
     * @dev Atomically increases the allowance granted to `spender` by the caller.
     *
     * This is an alternative to {approve} that can be used as a mitigation for
     * problems described in {IERC20-approve}.
     *
     * Emits an {Approval} event indicating the updated allowance.
     *
     * Requirements:
     *
     * - `spender` cannot be the zero address.
     */
    function increaseAllowance(address spender, uint256 addedValue) public virtual returns (bool) {
        _approve(_msgSender(), spender, _allowances[_msgSender()][spender] + addedValue);
        return true;
    }

    /**
     * @dev Atomically decreases the allowance granted to `spender` by the caller.
     *
     * This is an alternative to {approve} that can be used as a mitigation for
     * problems described in {IERC20-approve}.
     *
     * Emits an {Approval} event indicating the updated allowance.
     *
     * Requirements:
     *
     * - `spender` cannot be the zero address.
     * - `spender` must have allowance for the caller of at least
     * `subtractedValue`.
     */
    function decreaseAllowance(address spender, uint256 subtractedValue) public virtual returns (bool) {
        uint256 currentAllowance = _allowances[_msgSender()][spender];
        require(currentAllowance >= subtractedValue, "ERC20: decreased allowance below zero");
        unchecked {
            _approve(_msgSender(), spender, currentAllowance - subtractedValue);
        }

        return true;
    }

    /**
     * @dev Moves `amount` of tokens from `sender` to `recipient`.
     *
     * This internal function is equivalent to {transfer}, and can be used to
     * e.g. implement automatic token fees, slashing mechanisms, etc.
     *
     * Emits a {Transfer} event.
     *
     * Requirements:
     *
     * - `sender` cannot be the zero address.
     * - `recipient` cannot be the zero address.
     * - `sender` must have a balance of at least `amount`.
     */
    function _transfer(
        address sender,
        address recipient,
        uint256 amount
    ) internal virtual {
        require(sender != address(0), "ERC20: transfer from the zero address");
        require(recipient != address(0), "ERC20: transfer to the zero address");

        _beforeTokenTransfer(sender, recipient, amount);

        uint256 senderBalance = _balances[sender];
        require(senderBalance >= amount, "ERC20: transfer amount exceeds balance");
        unchecked {
            _balances[sender] = senderBalance - amount;
        }
        _balances[recipient] += amount;

        emit Transfer(sender, recipient, amount);

        _afterTokenTransfer(sender, recipient, amount);
    }

    /** @dev Creates `amount` tokens and assigns them to `account`, increasing
     * the total supply.
     *
     * Emits a {Transfer} event with `from` set to the zero address.
     *
     * Requirements:
     *
     * - `account` cannot be the zero address.
     */
    function _mint(address account, uint256 amount) internal virtual {
        require(account != address(0), "ERC20: mint to the zero address");

        _beforeTokenTransfer(address(0), account, amount);

        _totalSupply += amount;
        _balances[account] += amount;
        emit Transfer(address(0), account, amount);

        _afterTokenTransfer(address(0), account, amount);
    }

    /**
     * @dev Destroys `amount` tokens from `account`, reducing the
     * total supply.
     *
     * Emits a {Transfer} event with `to` set to the zero address.
     *
     * Requirements:
     *
     * - `account` cannot be the zero address.
     * - `account` must have at least `amount` tokens.
     */
    function _burn(address account, uint256 amount) internal virtual {
        require(account != address(0), "ERC20: burn from the zero address");

        _beforeTokenTransfer(account, address(0), amount);

        uint256 accountBalance = _balances[account];
        require(accountBalance >= amount, "ERC20: burn amount exceeds balance");
        unchecked {
            _balances[account] = accountBalance - amount;
        }
        _totalSupply -= amount;

        emit Transfer(account, address(0), amount);

        _afterTokenTransfer(account, address(0), amount);
    }

    /**
     * @dev Sets `amount` as the allowance of `spender` over the `owner` s tokens.
     *
     * This internal function is equivalent to `approve`, and can be used to
     * e.g. set automatic allowances for certain subsystems, etc.
     *
     * Emits an {Approval} event.
     *
     * Requirements:
     *
     * - `owner` cannot be the zero address.
     * - `spender` cannot be the zero address.
     */
    function _approve(
        address owner,
        address spender,
        uint256 amount
    ) internal virtual {
        require(owner != address(0), "ERC20: approve from the zero address");
        require(spender != address(0), "ERC20: approve to the zero address");

        _allowances[owner][spender] = amount;
        emit Approval(owner, spender, amount);
    }

    /**
     * @dev Hook that is called before any transfer of tokens. This includes
     * minting and burning.
     *
     * Calling conditions:
     *
     * - when `from` and `to` are both non-zero, `amount` of ``from``'s tokens
     * will be transferred to `to`.
     * - when `from` is zero, `amount` tokens will be minted for `to`.
     * - when `to` is zero, `amount` of ``from``'s tokens will be burned.
     * - `from` and `to` are never both zero.
     *
     * To learn more about hooks, head to xref:ROOT:extending-contracts.adoc#using-hooks[Using Hooks].
     */
    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 amount
    ) internal virtual {}

    /**
     * @dev Hook that is called after any transfer of tokens. This includes
     * minting and burning.
     *
     * Calling conditions:
     *
     * - when `from` and `to` are both non-zero, `amount` of ``from``'s tokens
     * has been transferred to `to`.
     * - when `from` is zero, `amount` tokens have been minted for `to`.
     * - when `to` is zero, `amount` of ``from``'s tokens have been burned.
     * - `from` and `to` are never both zero.
     *
     * To learn more about hooks, head to xref:ROOT:extending-contracts.adoc#using-hooks[Using Hooks].
     */
    function _afterTokenTransfer(
        address from,
        address to,
        uint256 amount
    ) internal virtual {}
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.0 (token/ERC20/IERC20.sol)

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
// OpenZeppelin Contracts v4.4.0 (token/ERC20/extensions/IERC20Metadata.sol)

pragma solidity ^0.8.0;

import "../IERC20.sol";

/**
 * @dev Interface for the optional metadata functions from the ERC20 standard.
 *
 * _Available since v4.1._
 */
interface IERC20Metadata is IERC20 {
    /**
     * @dev Returns the name of the token.
     */
    function name() external view returns (string memory);

    /**
     * @dev Returns the symbol of the token.
     */
    function symbol() external view returns (string memory);

    /**
     * @dev Returns the decimals places of the token.
     */
    function decimals() external view returns (uint8);
}