//SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC721/utils/ERC721Holder.sol";
import "./interfaces/DPSStructs.sol";
import "./interfaces/DPSInterfaces.sol";

// import "hardhat/console.sol";

contract DPSDocks is ERC721Holder, ReentrancyGuard, Ownable {
    DPSVoyageI public voyage;
    DPSRandomI public causality;
    IERC721 public dps;
    DPSPirateFeaturesI public dpsFeatures;
    DPSFlagshipI public flagship;
    DPSSupportShipI public supportShip;
    IERC721 public artifact;
    DPSCartographerI public cartographer;
    DPSGameSettingsI public gameSettings;
    DPSChestsI public chest;

    /**
     * @notice list of voyages started by wallet
     */
    mapping(address => mapping(uint256 => LockedVoyage)) private lockedVoyages;

    /**
     * @notice list of voyages finished by wallet
     */
    mapping(address => mapping(uint256 => LockedVoyage)) private finishedVoyages;

    /**
     * @notice list of voyages ids started by wallet
     */
    mapping(address => uint256[]) private lockedVoyagesIds;

    /**
     * @notice list of voyages ids finished by wallet
     */
    mapping(address => uint256[]) private finishedVoyagesIds;

    /**
     * @notice finished voyages results voyageId=>results
     */
    mapping(uint256 => VoyageResult) private voyageResults;

    /**
     * @notice list of locked voyages and their owners id => wallet
     */
    mapping(uint256 => address) private ownerOfLockedVoyages;

    event LockVoyage(
        uint256 indexed _voyageId,
        uint256 indexed _dpsId,
        uint256 indexed _flagshipId,
        uint256[] _supportShipIds,
        uint256 _artifactId
    );

    event ClaimVoyageRewards(
        uint256 indexed _voyageId,
        uint16 _noOfChests,
        uint16 _destroyedSupportships,
        uint16 _healthDamage,
        uint16[] _interactionRNGs,
        uint8[] _interactionResults
    );
    event SetContract(uint256 _target, address _contract);
    event TokenRecovered(address indexed _token, address _destination, uint256 _amount);

    constructor() {}

    /**
     * @notice Locking a voyage
     * @param _causalityParams causality parameters
     * @param _lockedVoyages array of objects that contains:
     * - voyageId
     * - dpsId (Pirate)
     * - flagshipId
     * - supportShipIds - list of support ships ids
     * - artifactId
     * the rest of the params are ignored
     */
    function lockVoyageItems(LockedVoyage[] memory _lockedVoyages, CausalityParams[] memory _causalityParams)
        external
        nonReentrant
    {
        require(gameSettings.isPaused(1) == 0, "Paused");
        require(_lockedVoyages.length == _causalityParams.length, "!Params");
        for (uint256 index; index < _lockedVoyages.length; index++) {
            LockedVoyage memory lockedVoyage = _lockedVoyages[index];
            CausalityParams memory params = _causalityParams[index];
            require(lockedVoyage.voyageId > 0, "!Voyage");
            require(voyage.ownerOf(lockedVoyage.voyageId) == msg.sender, "!vOwner");
            require(dps.ownerOf(lockedVoyage.dpsId) == msg.sender, "!dOwner");

            require(flagship.ownerOf(lockedVoyage.flagshipId) == msg.sender, "fOwner");
            require(flagship.getPartsLevel(lockedVoyage.flagshipId)[uint256(FLAGSHIP_PART.HEALTH)] == 100, "!Health");

            require(lockedVoyages[msg.sender][lockedVoyage.voyageId].voyageId == 0, "Started");
            require(finishedVoyages[msg.sender][lockedVoyage.voyageId].voyageId == 0, "Finished");
            VoyageConfig memory voyageConfig = cartographer.viewVoyageConfiguration(params, lockedVoyage.voyageId);

            if (lockedVoyage.supportShipIds.length > 0) {
                for (uint256 i; i < lockedVoyage.supportShipIds.length; i++) {
                    require(supportShip.ownerOf(lockedVoyage.supportShipIds[i]) == msg.sender, "!spOwner");
                }
            }
            if (lockedVoyage.artifactId > 0) require(artifact.ownerOf(lockedVoyage.artifactId) == msg.sender, "!aOwner");
            require(block.number > voyageConfig.boughtAt + voyageConfig.noOfBlockJumps, "!Generation");

            lockedVoyage.lockedBlock = block.number;
            lockedVoyage.lockedTimestamp = block.timestamp;
            lockedVoyage.claimedTime = 0;
            lockedVoyage.navigation = 0;
            lockedVoyage.luck = 0;
            lockedVoyage.strength = 0;
            lockedVoyage.sequence = voyageConfig.sequence;
            lockedVoyages[msg.sender][lockedVoyage.voyageId] = lockedVoyage;
            lockedVoyagesIds[msg.sender].push(lockedVoyage.voyageId);
            ownerOfLockedVoyages[lockedVoyage.voyageId] = msg.sender;

            dps.safeTransferFrom(msg.sender, address(this), lockedVoyage.dpsId);
            flagship.safeTransferFrom(msg.sender, address(this), lockedVoyage.flagshipId);

            for (uint256 i; i < lockedVoyage.supportShipIds.length; i++) {
                supportShip.safeTransferFrom(msg.sender, address(this), lockedVoyage.supportShipIds[i]);
            }
            if (lockedVoyage.artifactId > 0) artifact.safeTransferFrom(msg.sender, address(this), lockedVoyage.artifactId);

            voyage.safeTransferFrom(msg.sender, address(this), lockedVoyage.voyageId);
            emit LockVoyage(
                lockedVoyage.voyageId,
                lockedVoyage.dpsId,
                lockedVoyage.flagshipId,
                lockedVoyage.supportShipIds,
                lockedVoyage.artifactId
            );
        }
    }

    /**
     * @notice Claiming rewards with params retrieved from the random future blocks
     * @param _voyageIds - ids of the voyages
     * @param _causalityParams - list of parameters used to generated random outcomes
     */
    function claimRewards(uint256[] calldata _voyageIds, CausalityParams[] calldata _causalityParams) external nonReentrant {
        require(_voyageIds.length == _causalityParams.length, "!Params");
        for (uint256 i; i < _voyageIds.length; i++) {
            uint256 voyageId = _voyageIds[i];
            CausalityParams memory params = _causalityParams[i];

            address owner = getLockedVoyageOwner(voyageId);

            LockedVoyage storage lockedVoyage = lockedVoyages[owner][voyageId];
            VoyageConfig memory voyageConfig = voyage.getVoyageConfig(voyageId);
            voyageConfig.sequence = lockedVoyage.sequence;
            require(owner != address(0), "!Owner");

            require(
                lockedVoyage.lockedTimestamp + voyageConfig.noOfInteractions * voyageConfig.gapBetweenInteractions <=
                    block.timestamp,
                "!Finished"
            );

            require(
                block.number > lockedVoyage.lockedBlock + voyageConfig.noOfInteractions * voyageConfig.noOfBlockJumps,
                "!Blocks"
            );

            causality.checkCausalityParams(params, voyageConfig, lockedVoyage);

            VoyageResult memory voyageResult = computeVoyageState(lockedVoyage, voyageConfig, params);
            lockedVoyage.claimedTime = block.timestamp;
            finishedVoyages[owner][lockedVoyage.voyageId] = lockedVoyage;
            finishedVoyagesIds[owner].push(lockedVoyage.voyageId);
            voyageResults[voyageId] = voyageResult;
            awardRewards(voyageResult, voyageConfig.typeOfVoyage, lockedVoyage, owner);
            //we know it does not respect checks-effects-interactions but the contract is too big, maybe next version
            cleanLockedVoyage(lockedVoyage.voyageId, owner);
            emit ClaimVoyageRewards(
                voyageId,
                voyageResult.awardedChests,
                voyageResult.destroyedSupportShips,
                voyageResult.healthDamage,
                voyageResult.interactionRNGs,
                voyageResult.interactionResults
            );
        }
    }

    /**
     * @notice checking voyage state between start start and finish sail, it uses causality parameters to determine the outcome of interactions
     * @param _voyageId - id of the voyage
     * @param _causalityParams - list of parameters used to generated random outcomes, it can be an incomplete list, meaning that you can check mid-sail to determine outcomes
     */
    function checkVoyageState(uint256 _voyageId, CausalityParams memory _causalityParams)
        external
        view
        returns (VoyageResult memory voyageResult)
    {
        LockedVoyage storage lockedVoyage = lockedVoyages[getLockedVoyageOwner(_voyageId)][_voyageId];

        require(voyage.ownerOf(_voyageId) == address(this) && lockedVoyage.voyageId != 0, "!Started");

        VoyageConfig memory voyageConfig = voyage.getVoyageConfig(_voyageId);
        voyageConfig.sequence = lockedVoyage.sequence;
        require((block.timestamp - lockedVoyage.lockedTimestamp) > voyageConfig.gapBetweenInteractions, "!Started");

        uint256 interactions = (block.timestamp - lockedVoyage.lockedTimestamp) / voyageConfig.gapBetweenInteractions;
        if (interactions > voyageConfig.sequence.length) interactions = voyageConfig.sequence.length;
        uint256 length = voyageConfig.sequence.length;
        for (uint256 i; i < length - interactions; i++) {
            voyageConfig.sequence[length - i - 1] = 0;
        }
        return computeVoyageState(lockedVoyage, voyageConfig, _causalityParams);
    }

    /**
     * @notice computing voyage state based on the locked voyage skills and config and causality params
     * @param _lockedVoyage - locked voyage items
     * @param _voyageConfig - voyage config object
     * @param _causalityParams - list of parameters used to generated random outcomes, it can be an incomplete list, meaning that you can check mid-sail to determine outcomes
     * @return VoyageResult - containing the results of a voyage based on interactions
     */
    function computeVoyageState(
        LockedVoyage storage _lockedVoyage,
        VoyageConfig memory _voyageConfig,
        CausalityParams memory _causalityParams
    ) internal view returns (VoyageResult memory) {
        VoyageStatusCache memory claimingRewardsCache;
        (, uint16[3] memory features) = dpsFeatures.getTraitsAndSkills(uint16(_lockedVoyage.dpsId));

        require(features[0] > 0 && features[1] > 0 && features[2] > 0, "!Traits");

        claimingRewardsCache.luck += features[0];
        claimingRewardsCache.navigation += features[1];
        claimingRewardsCache.strength += features[2];
        claimingRewardsCache = gameSettings.computeFlagShipSkills(
            flagship.getPartsLevel(_lockedVoyage.flagshipId),
            claimingRewardsCache
        );
        claimingRewardsCache = gameSettings.computeSupportShipSkills(_lockedVoyage.supportShipIds, claimingRewardsCache);
        VoyageResult memory voyageResult;
        uint256 maxRollCap = gameSettings.getMaxRollCap();
        // console.log(
        //     "[luck, navigation, strength]",
        //     claimingRewardsCache.luck,
        //     claimingRewardsCache.navigation,
        //     claimingRewardsCache.strength
        // );
        voyageResult.interactionResults = new uint8[](_voyageConfig.sequence.length);
        voyageResult.interactionRNGs = new uint16[](_voyageConfig.sequence.length);
        for (uint256 i; i < _voyageConfig.sequence.length; i++) {
            INTERACTION interaction = INTERACTION(_voyageConfig.sequence[i]);
            if (interaction == INTERACTION.NONE || voyageResult.healthDamage == 100) {
                voyageResult.skippedInteractions++;
                continue;
            }

            uint256 result;
            result = causality.getRandom(
                _voyageConfig.buyer,
                _causalityParams.blockNumber[0],
                _causalityParams.hash1[0],
                _causalityParams.hash2[0],
                _causalityParams.timestamp[0],
                _causalityParams.signature[0],
                string(abi.encodePacked("INTERACTION_RESULT", i)),
                0,
                maxRollCap
            );
            (voyageResult, claimingRewardsCache) = interpretResults(
                result,
                voyageResult,
                _lockedVoyage,
                claimingRewardsCache,
                interaction,
                i
            );
            // if (interaction == INTERACTION.CHEST) console.log("CHEST ", result);
            // else if (interaction == INTERACTION.STORM) console.log("STORM ", result);
            // else if (interaction == INTERACTION.ENEMY) console.log("ENEMY ", result);
            voyageResult.interactionRNGs[i] = uint16(result);
        }
        return voyageResult;
    }

    /**
     * @notice interprets a randomness result, meaning that based on the skill points accumulated from base pirate skills,
     *         flagship + support ships, we do a comparition between the result of the randomness and the skill points.
     *         if random > skill points than this interaction fails. Things to notice: if STORM or ENEMY fails then we
     *         destroy a support ship (if exists) or do health damage of 100% which will result in skipping all the upcoming
     *         interactions
     * @param _result - random number generated
     * @param _voyageResult - the result object that is cached and sent along for later on saving into storage
     * @param _lockedVoyage - locked voyage that contains the support ship objects that will get modified (sent as storage) if interaction failed
     * @param _claimingRewardsCache - cache object sent along for points updates
     * @param _interaction - interaction that we compute the outcome for
     * @param _index - current index of interaction, used to update the outcome
     * @return updated voyage results and claimingRewardsCache (this updates in case of a support ship getting destroyed)
     */
    function interpretResults(
        uint256 _result,
        VoyageResult memory _voyageResult,
        LockedVoyage storage _lockedVoyage,
        VoyageStatusCache memory _claimingRewardsCache,
        INTERACTION _interaction,
        uint256 _index
    ) internal view returns (VoyageResult memory, VoyageStatusCache memory) {
        if (_interaction == INTERACTION.CHEST && _result <= _claimingRewardsCache.luck) {
            _voyageResult.awardedChests++;
            _voyageResult.interactionResults[_index] = 1;
        } else if (
            (_interaction == INTERACTION.STORM && _result > _claimingRewardsCache.navigation) ||
            (_interaction == INTERACTION.ENEMY && _result > _claimingRewardsCache.strength)
        ) {
            if (_lockedVoyage.supportShipIds.length - _voyageResult.destroyedSupportShips > 0) {
                _voyageResult.destroyedSupportShips++;
                (uint256 points, SUPPORT_SHIP_TYPE supportShipType) = supportShip.getSkillBoostPerTokenId(
                    _lockedVoyage.supportShipIds[_voyageResult.destroyedSupportShips - 1]
                );
                if (
                    supportShipType == SUPPORT_SHIP_TYPE.SLOOP_STRENGTH ||
                    supportShipType == SUPPORT_SHIP_TYPE.CARAVEL_STRENGTH ||
                    supportShipType == SUPPORT_SHIP_TYPE.GALLEON_STRENGTH
                ) _claimingRewardsCache.strength -= points;
                if (
                    supportShipType == SUPPORT_SHIP_TYPE.SLOOP_LUCK ||
                    supportShipType == SUPPORT_SHIP_TYPE.CARAVEL_LUCK ||
                    supportShipType == SUPPORT_SHIP_TYPE.GALLEON_LUCK
                ) _claimingRewardsCache.luck -= points;
                if (
                    supportShipType == SUPPORT_SHIP_TYPE.SLOOP_NAVIGATION ||
                    supportShipType == SUPPORT_SHIP_TYPE.CARAVEL_NAVIGATION ||
                    supportShipType == SUPPORT_SHIP_TYPE.GALLEON_NAVIGATION
                ) _claimingRewardsCache.navigation -= points;
            } else {
                _voyageResult.healthDamage = 100;
            }
        } else if (_interaction != INTERACTION.CHEST) {
            _voyageResult.interactionResults[_index] = 1;
        }
        return (_voyageResult, _claimingRewardsCache);
    }

    /**
     * @notice awards the voyage (if any) and transfers back the assets that were locked into the voyage
     *         to the owners, also if support ship destroyed, it burns them, if healh damage taken then apply effect on flagship
     * @param _voyageResult - the result of the voyage that is used to award and apply effects
     * @param _typeOfVoyage - used to mint the chests types accordingly with the voyage type
     * @param _lockedVoyage - locked voyage object used to get the locked items that needs to be transferred back
     * @param _owner - the owner of the voyage that will receive rewards + items back
     *
     */
    function awardRewards(
        VoyageResult memory _voyageResult,
        VOYAGE_TYPE _typeOfVoyage,
        LockedVoyage memory _lockedVoyage,
        address _owner
    ) internal {
        chest.mint(_owner, _typeOfVoyage, _voyageResult.awardedChests);
        dps.safeTransferFrom(address(this), _owner, _lockedVoyage.dpsId);

        if (_voyageResult.healthDamage > 0)
            flagship.upgradePart(FLAGSHIP_PART.HEALTH, _lockedVoyage.flagshipId, 100 - _voyageResult.healthDamage);
        flagship.safeTransferFrom(address(this), _owner, _lockedVoyage.flagshipId);

        for (uint256 i; i < _lockedVoyage.supportShipIds.length; i++) {
            if (i < _voyageResult.destroyedSupportShips) supportShip.burn(_lockedVoyage.supportShipIds[i]);
            else supportShip.safeTransferFrom(address(this), _owner, _lockedVoyage.supportShipIds[i]);
        }
        if (_lockedVoyage.artifactId > 0) artifact.safeTransferFrom(address(this), _owner, _lockedVoyage.artifactId);
        voyage.burn(_lockedVoyage.voyageId);
    }

    /**
     * @notice cleans a locked voyage, usually once it's finished
     * @param _voyageId - voyage id
     * @param _owner  - owner of the voyage
     */
    function cleanLockedVoyage(uint256 _voyageId, address _owner) internal {
        uint256[] storage voyagesForOwner = lockedVoyagesIds[_owner];
        for (uint256 i; i < voyagesForOwner.length; i++) {
            if (voyagesForOwner[i] == _voyageId) {
                voyagesForOwner[i] = voyagesForOwner[voyagesForOwner.length - 1];
                voyagesForOwner.pop();
            }
        }
        delete ownerOfLockedVoyages[_voyageId];
        delete lockedVoyages[_owner][_voyageId];
    }

    function onERC721Received(
        address _operator,
        address,
        uint256,
        bytes calldata
    ) public view override returns (bytes4) {
        require(_operator == address(this), "Unauthorized");
        return this.onERC721Received.selector;
    }

    /**
     * @notice Recover NFT sent by mistake to the contract
     * @param _nft the NFT address
     * @param _destination where to send the NFT
     * @param _tokenId the token to want to recover
     */
    function recoverNFT(
        address _nft,
        address _destination,
        uint256 _tokenId
    ) external onlyOwner {
        require(_destination != address(0), "Address(0)");
        IERC721(_nft).safeTransferFrom(address(this), _destination, _tokenId);
        emit TokenRecovered(_nft, _destination, _tokenId);
    }

    /**
     * @notice Recover NFT sent by mistake to the contract
     * @param _nft the 1155 NFT address
     * @param _destination where to send the NFT
     * @param _tokenId the token to want to recover
     * @param _amount amount of this token to want to recover
     */
    function recover1155NFT(
        address _nft,
        address _destination,
        uint256 _tokenId,
        uint256 _amount
    ) external onlyOwner {
        require(_destination != address(0), "Address(0)");
        IERC1155(_nft).safeTransferFrom(address(this), _destination, _tokenId, _amount, "");
        emit TokenRecovered(_nft, _destination, _tokenId);
    }

    /**
     * @notice Recover TOKENS sent by mistake to the contract
     * @param _token the TOKEN address
     * @param _destination where to send the NFT
     */
    function recoverERC20(address _token, address _destination) external onlyOwner {
        require(_destination != address(0), "Address(0)");
        uint256 amount = IERC20(_token).balanceOf(address(this));
        IERC20(_token).transfer(_destination, amount);
        emit TokenRecovered(_token, _destination, amount);
    }

    function cleanVoyageResults(uint256 _voyageId) external onlyOwner {
        delete voyageResults[_voyageId];
    }

    /**
     * SETTERS & GETTERS
     */
    function setContract(address _contract, uint8 _target) external onlyOwner {
        require(_contract != address(0), "Address(0)");
        if (_target == 1) voyage = DPSVoyageI(_contract);
        else if (_target == 2) causality = DPSRandomI(_contract);
        else if (_target == 3) dps = IERC721(_contract);
        else if (_target == 4) flagship = DPSFlagshipI(_contract);
        else if (_target == 5) supportShip = DPSSupportShipI(_contract);
        else if (_target == 6) artifact = IERC721(_contract);
        else if (_target == 7) gameSettings = DPSGameSettingsI(_contract);
        else if (_target == 8) dpsFeatures = DPSPirateFeaturesI(_contract);
        else if (_target == 9) cartographer = DPSCartographerI(_contract);
        else if (_target == 10) chest = DPSChestsI(_contract);
        emit SetContract(_target, _contract);
    }

    function getLockedVoyagesForOwner(address _owner) external view returns (LockedVoyage[] memory locked) {
        locked = new LockedVoyage[](lockedVoyagesIds[_owner].length);
        for (uint256 i; i < lockedVoyagesIds[_owner].length; i++) {
            locked[i] = lockedVoyages[_owner][lockedVoyagesIds[_owner][i]];
        }
    }

    function getLockedVoyageByOwnerAndId(address _owner, uint256 _voyageId)
        external
        view
        returns (LockedVoyage memory locked)
    {
        for (uint256 i; i < lockedVoyagesIds[_owner].length; i++) {
            uint256 tempId = lockedVoyagesIds[_owner][i];
            if (tempId == _voyageId) return lockedVoyages[_owner][tempId];
        }
    }

    function getFinishedVoyagesForOwner(address _owner) external view returns (LockedVoyage[] memory finished) {
        finished = new LockedVoyage[](finishedVoyagesIds[_owner].length);
        for (uint256 i; i < finishedVoyagesIds[_owner].length; i++) {
            finished[i] = finishedVoyages[_owner][finishedVoyagesIds[_owner][i]];
        }
    }

    function getFinishedVoyageByOwnerAndId(address _owner, uint256 _voyageId)
        external
        view
        returns (LockedVoyage memory finished)
    {
        for (uint256 i; i < finishedVoyagesIds[_owner].length; i++) {
            uint256 tempId = finishedVoyagesIds[_owner][i];
            if (tempId == _voyageId) return finishedVoyages[_owner][tempId];
        }
    }

    function getLockedVoyageOwner(uint256 _voyageId) public view returns (address) {
        return ownerOfLockedVoyages[_voyageId];
    }

    function getLastComputedState(uint256 _voyageId) external view returns (VoyageResult memory) {
        return voyageResults[_voyageId];
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

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.0 (token/ERC721/utils/ERC721Holder.sol)

pragma solidity ^0.8.0;

import "../IERC721Receiver.sol";

/**
 * @dev Implementation of the {IERC721Receiver} interface.
 *
 * Accepts all token transfers.
 * Make sure the contract is able to use its token with {IERC721-safeTransferFrom}, {IERC721-approve} or {IERC721-setApprovalForAll}.
 */
contract ERC721Holder is IERC721Receiver {
    /**
     * @dev See {IERC721Receiver-onERC721Received}.
     *
     * Always returns `IERC721Receiver.onERC721Received.selector`.
     */
    function onERC721Received(
        address,
        address,
        uint256,
        bytes memory
    ) public virtual override returns (bytes4) {
        return this.onERC721Received.selector;
    }
}

//SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

enum VOYAGE_TYPE {
    EASY,
    MEDIUM,
    HARD,
    LEGENDARY
}

enum SUPPORT_SHIP_TYPE {
    SLOOP_STRENGTH,
    SLOOP_LUCK,
    SLOOP_NAVIGATION,
    CARAVEL_STRENGTH,
    CARAVEL_LUCK,
    CARAVEL_NAVIGATION,
    GALLEON_STRENGTH,
    GALLEON_LUCK,
    GALLEON_NAVIGATION
}

enum INTERACTION {
    NONE,
    CHEST,
    STORM,
    ENEMY
}

enum FLAGSHIP_PART {
    HEALTH,
    CANNON,
    HULL,
    SAILS,
    HELM,
    FLAG,
    FIGUREHEAD
}

enum SKILL_TYPE {
    LUCK,
    STRENGTH,
    NAVIGATION
}

struct VoyageConfig {
    VOYAGE_TYPE typeOfVoyage;
    uint8 noOfInteractions;
    uint16 noOfBlockJumps;
    // 1 - Chest 2 - Storm 3 - Enemy
    uint8[] sequence;
    uint256 boughtAt;
    uint256 gapBetweenInteractions;
    address buyer;
}

struct CartographerConfig {
    uint8 minNoOfChests;
    uint8 maxNoOfChests;
    uint8 minNoOfStorms;
    uint8 maxNoOfStorms;
    uint8 minNoOfEnemies;
    uint8 maxNoOfEnemies;
    uint8 totalInteractions;
    uint256 gapBetweenInteractions;
}

struct RandomInteractions {
    uint256 randomNoOfChests;
    uint256 randomNoOfStorms;
    uint256 randomNoOfEnemies;
    uint8 generatedChests;
    uint8 generatedStorms;
    uint8 generatedEnemies;
    uint256[] positionsForGeneratingInteractions;
}

struct CausalityParams {
    uint256[] blockNumber;
    bytes32[] hash1;
    bytes32[] hash2;
    uint256[] timestamp;
    bytes[] signature;
}

struct LockedVoyage {
    uint256 voyageId;
    uint256 dpsId;
    uint256 flagshipId;
    uint256[] supportShipIds;
    uint256 artifactId;
    uint256 lockedBlock;
    uint256 lockedTimestamp;
    uint256 claimedTime;
    uint16 navigation;
    uint16 luck;
    uint16 strength;
    uint8[] sequence;
}

struct VoyageResult {
    uint16 awardedChests;
    uint16 destroyedSupportShips;
    uint8 healthDamage;
    uint16 skippedInteractions;
    uint16[] interactionRNGs;
    uint8[] interactionResults;
}

struct VoyageStatusCache {
    uint256 strength;
    uint256 luck;
    uint256 navigation;
    uint256 randomCheckIndex;
}

//SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/token/ERC721/extensions/IERC721Enumerable.sol";
import "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
import "./DPSStructs.sol";

interface DPSVoyageI is IERC721Enumerable {
    function mint(
        address _owner,
        uint256 _tokenId,
        VoyageConfig calldata config
    ) external;

    function burn(uint256 _tokenId) external;

    function getVoyageConfig(uint256 _voyageId) external view returns (VoyageConfig memory config);

    function tokensOfOwner(address _owner) external view returns (uint256[] memory);

    function exists(uint256 _tokenId) external view returns (bool);
}

interface DPSRandomI {
    function getRandomBatch(
        address _address,
        uint256[] memory _blockNumber,
        bytes32[] memory _hash1,
        bytes32[] memory _hash2,
        uint256[] memory _timestamp,
        bytes[] memory _signature,
        string[] memory _entropy,
        uint256 _min,
        uint256 _max
    ) external view returns (uint256[] memory randoms);

    function getRandomUnverifiedBatch(
        address _address,
        uint256[] memory _blockNumber,
        bytes32[] memory _hash1,
        bytes32[] memory _hash2,
        uint256[] memory _timestamp,
        string[] memory _entropy,
        uint256 _min,
        uint256 _max
    ) external pure returns (uint256[] memory randoms);

    function getRandom(
        address _address,
        uint256 _blockNumber,
        bytes32 _hash1,
        bytes32 _hash2,
        uint256 _timestamp,
        bytes memory _signature,
        string memory _entropy,
        uint256 _min,
        uint256 _max
    ) external view returns (uint256 randoms);

    function getRandomUnverified(
        address _address,
        uint256 _blockNumber,
        bytes32 _hash1,
        bytes32 _hash2,
        uint256 _timestamp,
        string memory _entropy,
        uint256 _min,
        uint256 _max
    ) external pure returns (uint256 randoms);

    function checkCausalityParams(
        CausalityParams memory _causalityParams,
        VoyageConfig memory _voyageConfig,
        LockedVoyage memory _lockedVoyage
    ) external pure;
}

interface DPSGameSettingsI {
    function getVoyageConfig(VOYAGE_TYPE _type) external view returns (CartographerConfig memory);

    function getMaxSkillsCap() external view returns (uint16);

    function getMaxRollCap() external view returns (uint16);

    function getFlagshipBaseSkills() external view returns (uint16);

    function getSkillsPerFlagshipParts() external view returns (uint16[7] memory skills);

    function getSkillTypeOfEachFlagshipPart() external view returns (uint8[7] memory skillTypes);

    function getTMAPPerVoyageType(VOYAGE_TYPE _type) external view returns (uint256);

    function getBlockJumps() external view returns (uint16);

    function getGapBetweenVoyagesCreation() external view returns (uint256);

    function getDoubloonsRewardsPerChest(VOYAGE_TYPE _type) external view returns (uint256[] memory);

    function isPaused(uint8 _component) external view returns (uint8);

    function getTmapPerDoubloon() external view returns (uint256);

    function computeFlagShipSkills(
        uint8[7] memory levels,
        VoyageStatusCache memory _claimingRewardsCache
    ) external view returns (VoyageStatusCache memory);

    function computeSupportShipSkills(uint256[] memory _supportShips, VoyageStatusCache memory _claimingRewardsCache)
        external
        view
        returns (VoyageStatusCache memory);
}

interface DPSPirateFeaturesI {
    function getTraitsAndSkills(uint16 _dpsId) external view returns (string[8] memory, uint16[3] memory);
}

interface DPSSupportShipI is IERC721 {
    function getSkillBoostPerTokenId(uint256 _tokenId) external view returns (uint256, SUPPORT_SHIP_TYPE);

    function burn(uint256 _id) external;

    function exists(uint256 _tokenId) external view returns (bool);
}

interface DPSFlagshipI is IERC721 {
    function mint(address _owner, uint256 _id) external;

    function burn(uint256 _id) external;

    function upgradePart(
        FLAGSHIP_PART _trait,
        uint256 _tokenId,
        uint8 _level
    ) external;

    function getPartsLevel(uint256 _flagshipId) external view returns (uint8[7] memory);

    function tokensOfOwner(address _owner) external view returns (uint256[] memory);

    function exists(uint256 _tokenId) external view returns (bool);
}

interface DPSChestsI is IERC1155 {
    function mint(
        address _to,
        VOYAGE_TYPE _voyageType,
        uint256 _amount
    ) external;

    function burn(
        address _from,
        VOYAGE_TYPE _voyageType,
        uint256 _amount
    ) external;
}

interface DPSCartographerI {
    function viewVoyageConfiguration(CausalityParams memory causalityParams, uint256 _voyageId)
        external
        view
        returns (VoyageConfig memory voyageConfig);
}

interface MintableBurnableIERC1155 is IERC1155 {
    function mint(
        address _to,
        VOYAGE_TYPE _voyageType,
        uint256 _amount
    ) external;

    function burn(
        address _from,
        VOYAGE_TYPE _voyageType,
        uint256 _amount
    ) external;
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
// OpenZeppelin Contracts v4.4.0 (token/ERC1155/IERC1155.sol)

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
     * - If the caller is not `from`, it must be have been approved to spend ``from``'s tokens via {setApprovalForAll}.
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