// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.23;

import "./contracts_interfaces_IStoryController.sol";
import "./contracts_interfaces_IOracle.sol";
import "./contracts_interfaces_ITreasury.sol";
import "./contracts_interfaces_IGOC.sol";
import "./contracts_interfaces_IERC20.sol";
import "./contracts_interfaces_IERC721Enumerable.sol";
import "./contracts_interfaces_IAppErrors.sol";
import "./contracts_interfaces_IApplicationEvents.sol";
import "./contracts_lib_CalcLib.sol";
import "./contracts_lib_PackingLib.sol";
import "./contracts_lib_ItemLib.sol";
import "./contracts_lib_StringLib.sol";

library StoryLib {
  using CalcLib for uint;
  using PackingLib for address;
  using PackingLib for uint16;
  using PackingLib for bytes32;
  using PackingLib for bytes32[];

  //region ------------------------ Constants
  /// @notice Max number of items that can be minted per iteration in the stories
  uint internal constant MAX_MINTED_ITEMS_PER_ITERATION = 3;
  //endregion ------------------------ Constants

  //region ------------------------ Story logic

  /// @notice Make action, increment STORY_XXX hero custom data if the dungeon is completed / hero is killed
  function action(IGOC.ActionContext memory ctx, uint16 storyId) internal returns (IGOC.ActionResult memory result) {
    if (storyId == 0) revert IAppErrors.ZeroStoryIdAction();

    result = IStoryController(ctx.controller.storyController()).storyAction(
      ctx.sender,
      ctx.dungeonId,
      ctx.objectId,
      ctx.stageId,
      ctx.heroToken,
      ctx.heroTokenId,
      ctx.biome,
      ctx.iteration,
      ctx.data
    );

    if (result.completed || result.kill) {
      IStatController statController = IStatController(ctx.controller.statController());
      bytes32 index = _getStoryIndex(storyId);
      uint curValue = statController.heroCustomData(ctx.heroToken, ctx.heroTokenId, index);
      statController.setHeroCustomData(ctx.heroToken, ctx.heroTokenId, index, curValue + 1);
    }
  }

  /// @notice Check if the story is available for the hero
  /// The story is available if hero level fits to requirements
  /// and if the hero/global custom data requirements are met (current value is inside of [min, max])
  function isStoryAvailableForHero(
    IStoryController.MainState storage s,
    uint16 storyId,
    address heroToken,
    uint heroTokenId,
    address statController
  ) internal view returns (bool) {
    uint reqLvl = s.storyRequiredLevel[storyId];
    if (reqLvl != 0 && IStatController(statController).heroStats(heroToken, heroTokenId).level < reqLvl) {
      return false;
    }

    IStoryController.CustomDataRequirementRangePacked[] storage allData = s.storyRequiredHeroData[storyId];
    uint len = allData.length;
    for (uint i; i < len; ++i) {
      IStoryController.CustomDataRequirementRangePacked memory data = allData[i];

      if (data.index == bytes32(0)) continue;

      (uint64 min, uint64 max, bool isHeroData) = data.data.unpackCustomDataRequirements();

      uint value = isHeroData
        ? IStatController(statController).heroCustomData(heroToken, heroTokenId, data.index)
        : IStatController(statController).globalCustomData(data.index);

      if (value < uint(min) || value > uint(max)) {
        return false;
      }
    }

    return true;
  }

  /// @notice Update bonus attributes, refresh hero states, initialize and return results
  /// @param mintItemsData Source for _mintRandomItems, random item (max 1, probably 0) is selected and put to results
  /// @param mintItems_ Function _mintRandomItems is passed here. Parameter is required to make unit tests.
  function handleResult(
    IStoryController.StoryActionContext memory context,
    bytes32[] memory attributesChanges,
    bytes32 statsChanges,
    bytes32[] memory mintItemsData,
    function (IStoryController.StoryActionContext memory, bytes32[] memory) internal returns (address[] memory) mintItems_
  ) internal returns (IGOC.ActionResult memory result) {
    result.heroToken = context.heroToken;
    result.heroTokenId = context.heroTokenId;
    result.objectId = context.objectId;

    int32[] memory attributes = _generateAttributes(attributesChanges);

    if (attributes.length != 0) {
      context.statController.changeBonusAttributes(IStatController.ChangeAttributesInfo({
        heroToken: context.heroToken,
        heroTokenId: context.heroTokenId,
        changeAttributes: attributes,
        add: true,
        temporally: true
      }));
      // changeBonusAttributes can change life and mana, so we need to refresh hero stats. It's safer to do it always
      context.heroStats = context.statController.heroStats(context.heroToken, context.heroTokenId);
      emit IApplicationEvents.StoryChangeAttributes(
        context.objectId,
        context.heroToken,
        context.heroTokenId,
        context.dungeonId,
        context.storyId,
        context.stageId,
        context.iteration,
        attributes
      );
    }

    IStoryController.StatsChange memory statsToChange = _generateStats(statsChanges);

    if (statsToChange.heal != 0) {
      int32 max = context.statController.heroAttribute(context.heroToken, context.heroTokenId, uint(IStatController.ATTRIBUTES.LIFE));
      result.heal = max * statsToChange.heal / 100;
    }

    if (statsToChange.manaRegen != 0) {
      int32 max = context.statController.heroAttribute(context.heroToken, context.heroTokenId, uint(IStatController.ATTRIBUTES.MANA));
      result.manaRegen = max * statsToChange.manaRegen / 100;
    }

    if (statsToChange.damage != 0) {
      int32 max = context.statController.heroAttribute(context.heroToken, context.heroTokenId, uint(IStatController.ATTRIBUTES.LIFE));
      result.damage = max * statsToChange.damage / 100;

      if (int32(context.heroStats.life) <= result.damage) {
        result.kill = true;
      }
    }

    if (statsToChange.manaConsumed != 0) {
      int32 max = context.statController.heroAttribute(context.heroToken, context.heroTokenId, uint(IStatController.ATTRIBUTES.MANA));
      result.manaConsumed = CalcLib.minI32(max * statsToChange.manaConsumed / 100, int32(context.heroStats.mana));
    }

    result.experience = statsToChange.experience;
    result.lifeChancesRecovered = statsToChange.lifeChancesRecovered;

    if (mintItemsData.length != 0) {
      result.mintItems = mintItems_(context, mintItemsData);
    }
    return result;
  }

  /// @notice Put data from {heroCustomDatas} and {globalCustomDatas} to {statController}
  function handleCustomDataResult(
    IStoryController.StoryActionContext memory context,
    bytes32[] memory heroCustomDatas,
    bytes32[] memory globalCustomDatas
  ) internal {
    uint len = heroCustomDatas.length;
    for (uint i; i < len; ++i) {

      (bytes32 customDataIndex, int16 value) = heroCustomDatas[i].unpackCustomDataChange();

      if (customDataIndex != 0) {
        uint curValue = context.statController.heroCustomData(context.heroToken, context.heroTokenId, customDataIndex);
        context.statController.setHeroCustomData(
          context.heroToken,
          context.heroTokenId,
          customDataIndex,
          value == 0
            ? 0
            : value > 0
              ? curValue + uint(int(value))
              : curValue.minusWithZeroFloor(uint(int(- value)))
        );
      }
    }

    len = globalCustomDatas.length;
    for (uint i; i < len; ++i) {

      (bytes32 customDataIndex, int16 value) = globalCustomDatas[i].unpackCustomDataChange();

      if (customDataIndex != 0) {
        uint curValue = context.statController.globalCustomData(customDataIndex);
        context.statController.setGlobalCustomData(
          customDataIndex,
          value == 0
            ? 0
            : value > 0
              ? curValue + uint(int(value))
              : curValue.minusWithZeroFloor(uint(int(- value)))
        );
      }
    }
  }

  /// @notice SIP-003: Randomly select one or several items, break them and increase their fragility by 1%.
  function breakItem(IStoryController.StoryActionContext memory context, IStoryController.MainState storage s) internal {
    bytes32[] storage breakInfos = s.burnItem[context.answerIdHash];
    uint length = breakInfos.length;

    for (uint i; i < length; ++i) {
      (uint8 slot, uint64 chance, bool stopIfBroken) = breakInfos[i].unpackBreakInfo();
      uint8[2] memory slots = _adjustSlotToBreak(slot, context.oracle);
      // Normally, {slots} contains two similar items and we need to check only first item.
      // But "hands" is a special case: TWO_HAND and RIGHT_HAND should be checked both independently => + cycle by k
      uint countSlots = slots[0] == slots[1] ? 1 : 2;

      for (uint k = 0; k < countSlots; ++k) {
        if (chance != 0 && context.oracle.getRandomNumberInRange(0, 100, 0) <= uint(chance)) {
          uint8[] memory busySlots = context.statController.heroItemSlots(context.heroToken, context.heroTokenId);

          uint lenBusySlots = busySlots.length;
          if (lenBusySlots != 0) {
            uint busySlotIndex;
            bool itemExist;
            if (slot == 0) {
              busySlotIndex = context.oracle.getRandomNumberInRange(0, lenBusySlots - 1, 0);
              itemExist = true;
            } else {
              for (uint j; j < lenBusySlots; ++j) {
                if (busySlots[j] == slots[k]) {
                  busySlotIndex = j;
                  itemExist = true;
                  break;
                }
              }
            }

            if (itemExist) {
              // SIP-003: don't burn item but break it
              _breakItemInHeroSlot(context, busySlots[busySlotIndex]);
              if (stopIfBroken) {
                return; // go out of two cycles
              }
            }
          }
        }
      }
    }
  }

  /// @notice SCB-1016. There are some slots with equal meaning:
  /// 1) weapon can be RIGHT-HAND, TWO-HAND (LEFT-HAND is not considered here)
  /// 2) ring can be LEFT, RIGHT
  /// 3) skill can be SKILL_1, SKILL_2, SKILL_3
  /// Story-writer is able to specify only one slot to break.
  /// 1) if ONE/TWO-HAND slot is specified then any available weapon (ONE or TWO hands) should be broken
  /// 2) if LEFT right is specified then random(LEFT or RIGHT) slot should be broken
  /// 3) skills - there is same rule as for the rings
  /// @return slots Slots that should be checked. Normally {slots} contains same item twice.
  /// The items are different in one case only: [RIGHT_HAND, TWO_HAND]
  function _adjustSlotToBreak(uint8 slot, IOracle oracle) internal returns (uint8[2] memory slots) {
    if (slot == uint8(IStatController.ItemSlots.RIGHT_HAND) || slot == uint8(IStatController.ItemSlots.TWO_HAND)) {
      return [uint8(IStatController.ItemSlots.RIGHT_HAND), uint8(IStatController.ItemSlots.TWO_HAND)];
    } else if (slot == uint8(IStatController.ItemSlots.RIGHT_RING) || slot == uint8(IStatController.ItemSlots.LEFT_RING)) {
      uint8 selectedSlot = (oracle.getRandomNumber(1, 0) == 0)
        ? uint8(IStatController.ItemSlots.RIGHT_RING)
        : uint8(IStatController.ItemSlots.LEFT_RING);
      return [selectedSlot, selectedSlot];
    } else if (
      slot == uint8(IStatController.ItemSlots.SKILL_1)
      || slot == uint8(IStatController.ItemSlots.SKILL_2)
      || slot == uint8(IStatController.ItemSlots.SKILL_3)
    ) {
      uint rnd = oracle.getRandomNumber(2, 0);
      uint8 selectedSlot = (rnd == 0)
        ? uint8(IStatController.ItemSlots.SKILL_1)
        : ((rnd == 1)
          ? uint8(IStatController.ItemSlots.SKILL_2)
          : uint8(IStatController.ItemSlots.SKILL_3));
      return [selectedSlot, selectedSlot];
    } else {
      return [slot, slot];
    }
  }

  /// @notice Update internal hero state, generate {result}
  /// @param context We update some fields in place, so memory, not calldata here
  function handleAnswer(
    IStoryController.AnswerResultId answerResultId,
    IStoryController.MainState storage s,
    IStoryController.StoryActionContext memory context
  ) external returns (
    IGOC.ActionResult memory result,
    uint16 nextPage,
    uint16[] memory nextPages
  ) {
    return _handleAnswer(answerResultId, s, context, _mintRandomItems);
  }

  /// @notice Update internal hero state, generate {result}
  /// @param context We update some fields in place, so memory, not calldata here
  /// @param mintItems_ Function _mintRandomItems is passed here. Parameter is required to make unit tests.
  function _handleAnswer(
    IStoryController.AnswerResultId answerResultId,
    IStoryController.MainState storage s,
    IStoryController.StoryActionContext memory context,
    function (IStoryController.StoryActionContext memory, bytes32[] memory) internal returns (address[] memory) mintItems_
  ) internal returns (
    IGOC.ActionResult memory result,
    uint16 nextPage,
    uint16[] memory nextPages
  ) {
    result.objectId = context.objectId;
    result.heroTokenId = context.heroTokenId;
    result.heroToken = context.heroToken;

    nextPages = s.nextPageIds[context.storyId.packStoryNextPagesId(
      context.pageId,
      context.heroClassFromAnswerHash,
      context.answerNumber,
      uint8(answerResultId)
    )];
    nextPage = _getNextPage(context.oracle, nextPages);

    // number of items that can be minted inside single iteration in the story is limited
    // if the max is reached the minting is silently skipped
    // we assume here, that mintItems_ mints only 1 item so it's not necessary to limit number of minted items inside mintItems_
    uint mintedInIteration = _getMintedInIteration(s, context);

    if (answerResultId == IStoryController.AnswerResultId.SUCCESS) {
      result = handleResult(
        context,
        s.successInfoAttributes[context.answerIdHash],
        s.successInfoStats[context.answerIdHash],
        mintedInIteration < MAX_MINTED_ITEMS_PER_ITERATION ? s.successInfoMintItems[context.answerIdHash] : new bytes32[](0),
        mintItems_
      );

      handleCustomDataResult(
        context,
        s.customDataResult[context.storyId.packStoryCustomDataResult(
          context.pageId,
          context.heroClassFromAnswerHash,
          context.answerNumber,
          uint8(IStoryController.CustomDataResult.HERO_SUCCESS)
        )],
        s.customDataResult[context.storyId.packStoryCustomDataResult(
          context.pageId,
          context.heroClassFromAnswerHash,
          context.answerNumber,
          uint8(IStoryController.CustomDataResult.GLOBAL_SUCCESS)
        )]
      );
    } else {
      result = handleResult(
        context,
        s.failInfoAttributes[context.answerIdHash],
        s.failInfoStats[context.answerIdHash],
        mintedInIteration < MAX_MINTED_ITEMS_PER_ITERATION ? s.failInfoMintItems[context.answerIdHash] : new bytes32[](0),
        mintItems_
      );

      handleCustomDataResult(
        context,
        s.customDataResult[context.storyId.packStoryCustomDataResult(
          context.pageId,
          context.heroClassFromAnswerHash,
          context.answerNumber,
          uint8(IStoryController.CustomDataResult.HERO_FAIL)
        )],
        s.customDataResult[context.storyId.packStoryCustomDataResult(
          context.pageId,
          context.heroClassFromAnswerHash,
          context.answerNumber,
          uint8(IStoryController.CustomDataResult.GLOBAL_FAIL)
        )]
      );
    }

    if (result.mintItems.length != 0) {
      _setMintedInIteration(s, context, mintedInIteration + result.mintItems.length);
    }
  }

  /// @notice Check if the user has already minted an item within the current iteration of the story.
  /// if the item is already minted any additional minting should be skipped without revert
  function _getMintedInIteration(IStoryController.MainState storage s, IStoryController.StoryActionContext memory context)
  internal view returns (uint countMintedItems) {
    return s.mintedInIteration[context.heroToken.packStoryHeroStateId(context.heroTokenId, context.storyId)][context.iteration];
  }

  /// @notice Mark that the user has already minted an item within the current iteration of the story
  /// Only minting of the single item is allowed per iteration
  function _setMintedInIteration(
    IStoryController.MainState storage s,
    IStoryController.StoryActionContext memory context,
    uint newCountMintedItems
  ) internal {
    s.mintedInIteration[context.heroToken.packStoryHeroStateId(context.heroTokenId, context.storyId)][context.iteration] = newCountMintedItems;
  }

  /// @notice Revert if {heroAnswers} doesn't contain {answerIdHash}
  function checkAnswerIndexValid(bytes32[] memory heroAnswers, bytes32 answerIdHash) internal pure {
    uint len = heroAnswers.length;
    for (uint i; i < len; ++i) {
      if (heroAnswers[i] == answerIdHash) return;
    }
    revert IAppErrors.NotAnswer();
  }

  /// @notice Clear heroState for the current story
  /// @return nextObjs Default nextObjectsRewrite for the current page (values for 0 hero class)
  function finishStory(IStoryController.StoryActionContext memory ctx, IStoryController.MainState storage s) internal returns (
    uint32[] memory nextObjs
  ) {
    delete s.heroState[ctx.heroToken.packStoryHeroStateId(ctx.heroTokenId, ctx.storyId)];
    // It's not necessary to clear mintedInIteration because for each hero each object has a sequence of iterations
    // that is not reset on changing dungeons

    return s.nextObjectsRewrite[ctx.storyId.packStoryPageId(ctx.pageId, 0)];
  }

  //endregion ------------------------ Story logic

  //region ------------------------ Internal utils for story logic

  /// @dev This function is made separate to simplify unit testing
  function _mintRandomItems(IStoryController.StoryActionContext memory context, bytes32[] memory mintItemsData) internal returns (
    address[] memory
  ) {
    uint len = mintItemsData.length;
    address[] memory mintItems = new address[](len);
    uint32[] memory mintItemsChances = new uint32[](len);
    for (uint i; i < len; ++i) {
      (mintItems[i], mintItemsChances[i]) = mintItemsData[i].unpackItemMintInfo();
    }

    return ItemLib.mintRandomItems(ItemLib.MintItemInfo({
      mintItems: mintItems,
      mintItemsChances: mintItemsChances,
      amplifier: 0,
      seed: 0,
      oracle: context.oracle,
      magicFind: 0,
      destroyItems: 0,
      maxItems: 1, // MINT ONLY 1 ITEM!
      mintDropChanceDelta: StatLib.mintDropChanceDelta(context.heroStats.experience, uint8(context.heroStats.level), context.biome),
      mintDropChanceNgLevelMultiplier: 1e18
    }));
  }

  /// @param attributesChanges Values+ids packed using toBytes32ArrayWithIds
  function _generateAttributes(bytes32[] memory attributesChanges) internal pure returns (int32[] memory attributes) {
    if (attributesChanges.length != 0) {
      (int32[] memory values, uint8[] memory ids) = attributesChanges.toInt32ArrayWithIds();
      uint len = ids.length;
      if (len != 0) {
        attributes = new int32[](uint(IStatController.ATTRIBUTES.END_SLOT));
        for (uint i; i < len; ++i) {
          int32 value = values[i];
          attributes[ids[i]] = value;
        }
      }
    }

    return attributes;
  }

  function _generateStats(bytes32 statsChanges) internal pure returns (IStoryController.StatsChange memory change) {
    (
      change.experience,
      change.heal,
      change.manaRegen,
      change.lifeChancesRecovered,
      change.damage,
      change.manaConsumed
    ) = statsChanges.unpackStatsChange();

    return change;
  }

  /// @notice Break the item from the given {slot} (i.e. reduce item's durability to 0) and take it off
  /// Broken item is taken off also.
  function _breakItemInHeroSlot(IStoryController.StoryActionContext memory ctx, uint8 slot) internal {
    (address itemAdr, uint itemId) = ctx.statController.heroItemSlot(ctx.heroToken, uint64(ctx.heroTokenId), slot).unpackNftId();

    // take off the broken item and mark it as broken
    ctx.itemController.takeOffDirectly(itemAdr, itemId, ctx.heroToken, ctx.heroTokenId, slot, ctx.sender, true);

    // add 1% of fragility, deprecated
    // ctx.itemController.incBrokenItemFragility(itemAdr, itemId);

    emit IApplicationEvents.ItemBroken(
      ctx.heroToken,
      ctx.heroTokenId,
      ctx.dungeonId,
      ctx.objectId,
      itemAdr,
      itemId,
      ctx.stageId,
      ctx.iteration
    );
  }

  function _getNextPage(IOracle oracle, uint16[] memory pages) internal returns (uint16) {
    if (pages.length == 0) {
      return 0;
    }
    if (pages.length == 1) {
      return pages[0];
    }
    return pages[oracle.getRandomNumberInRange(0, pages.length - 1, 0)];
  }

  function _getStoryIndex(uint16 storyId) internal pure returns (bytes32) {
    return bytes32(abi.encodePacked("STORY_", StringLib._toString(storyId)));
  }
  //endregion ------------------------ Internal utils for story logic

  //region ------------------------ Check answers

  function checkAnswer(
    IStoryController.StoryActionContext memory context,
    IStoryController.MainState storage s
  ) external returns (IStoryController.AnswerResultId result) {
    result = checkAnswerAttributes(context, context.answerIdHash, s);
    if (result == IStoryController.AnswerResultId.SUCCESS) {
      result = checkAnswerItems(context, context.answerIdHash, s);
    }
    if (result == IStoryController.AnswerResultId.SUCCESS) {
      result = checkAnswerTokens(context, context.answerIdHash, s);
    }
    if (result == IStoryController.AnswerResultId.SUCCESS) {
      result = checkAnswerDelay(context);
    }
    if (result == IStoryController.AnswerResultId.SUCCESS) {
      result = checkAnswerHeroCustomData(context, context.answerIdHash, s);
    }
    if (result == IStoryController.AnswerResultId.SUCCESS) {
      result = checkAnswerGlobalCustomData(context, context.answerIdHash, s);
    }
    if (result == IStoryController.AnswerResultId.SUCCESS) {
      result = checkAnswerRandom(context);
    }
  }

  /// @notice Check if hero attribute values meet attribute requirements for the given answer
  function checkAnswerAttributes(
    IStoryController.StoryActionContext memory context,
    bytes32 answerIndex,
    IStoryController.MainState storage s
  ) internal view returns (IStoryController.AnswerResultId) {
    bytes32[] storage reqs = s.attributeRequirements[answerIndex];
    uint length = reqs.length;

    for (uint i; i < length; ++i) {
      (uint8 attributeIndex, int32 value, bool isCore) = reqs[i].unpackStoryAttributeRequirement();
      if (isCore) {
        IStatController.CoreAttributes memory base = context.statController.heroBaseAttributes(context.heroToken, context.heroTokenId);
        if (attributeIndex == uint8(IStatController.ATTRIBUTES.STRENGTH) && base.strength < value) {
          return IStoryController.AnswerResultId.ATTRIBUTE_FAIL;
        }
        if (attributeIndex == uint8(IStatController.ATTRIBUTES.DEXTERITY) && base.dexterity < value) {
          return IStoryController.AnswerResultId.ATTRIBUTE_FAIL;
        }
        if (attributeIndex == uint8(IStatController.ATTRIBUTES.VITALITY) && base.vitality < value) {
          return IStoryController.AnswerResultId.ATTRIBUTE_FAIL;
        }
        if (attributeIndex == uint8(IStatController.ATTRIBUTES.ENERGY) && base.energy < value) {
          return IStoryController.AnswerResultId.ATTRIBUTE_FAIL;
        }
      } else {
        int32 attr = context.statController.heroAttribute(context.heroToken, context.heroTokenId, attributeIndex);
        if (attr < value) {
          return IStoryController.AnswerResultId.ATTRIBUTE_FAIL;
        }
      }
    }

    return IStoryController.AnswerResultId.SUCCESS;
  }

  /// @notice Check item requirements for the given answer, check following issues:
  /// 1) For equipped item: check if it is on balance
  /// 2) For not equipped item: burn first owned item if requireItemBurn OR check that not equipped item is on balance
  function checkAnswerItems(
    IStoryController.StoryActionContext memory context,
    bytes32 answerIndex,
    IStoryController.MainState storage s
  ) internal returns (IStoryController.AnswerResultId) {

    bytes32[] storage reqs = s.itemRequirements[answerIndex];
    uint length = reqs.length;

    for (uint i; i < length; ++i) {
      (address item, bool requireItemBurn, bool requireItemEquipped) = reqs[i].unpackStoryItemRequirement();

      // equipped item is on balance of the heroToken, not on balance of the sender
      if (requireItemEquipped && IERC721Enumerable(item).balanceOf(context.heroToken) == 0) {
        revert IAppErrors.NotItem1();
      }

      if (requireItemBurn) {
        _burnFirstOwnedItem(context, item);
      }

      if (!requireItemEquipped && !requireItemBurn) {
        if (IERC721Enumerable(item).balanceOf(context.sender) == 0) revert IAppErrors.NotItem2();
      }

    }
    return IStoryController.AnswerResultId.SUCCESS;
  }

  /// @notice burn first owned item and generate event
  /// @dev Use separate function to workaround stack too deep
  function _burnFirstOwnedItem(IStoryController.StoryActionContext memory context, address item) internal {
    uint itemId = IERC721Enumerable(item).tokenOfOwnerByIndex(context.sender, 0);
    context.itemController.destroy(item, itemId); // destroy reverts if the item is equipped

    emit IApplicationEvents.NotEquippedItemBurned(
      context.heroToken,
      context.heroTokenId,
      context.dungeonId,
      context.storyId,
      item,
      itemId,
      context.stageId,
      context.iteration
    );
  }

  /// @notice Ensure that the sender has enough amounts of the required tokens, send fees to the treasury
  function checkAnswerTokens(
    IStoryController.StoryActionContext memory context,
    bytes32 answerIndex,
    IStoryController.MainState storage s
  ) internal returns (IStoryController.AnswerResultId) {
    bytes32[] memory reqs = s.tokenRequirements[answerIndex];
    uint length = reqs.length;
    for (uint i; i < length; ++i) {
      (address token, uint88 amount, bool requireTransfer) = reqs[i].unpackStoryTokenRequirement();
      amount = uint88(adjustTokenAmountToGameToken(uint(amount), context.controller));

      if (amount != 0) {
        uint balance = IERC20(token).balanceOf(context.sender);
        if (balance < uint(amount)) revert IAppErrors.NotEnoughAmount(balance, uint(amount));

        if (requireTransfer) {
          context.controller.process(token, amount, context.sender);
        }
      }
    }
    return IStoryController.AnswerResultId.SUCCESS;
  }

  function adjustTokenAmountToGameToken(uint amount, IController controller) internal view returns(uint) {
    return amount * controller.gameTokenPrice() / 1e18;
  }

  /// @notice Generate error randomly
  function checkAnswerRandom(IStoryController.StoryActionContext memory context) internal returns (IStoryController.AnswerResultId) {
    (uint32 random,,) = context.answerAttributes.unpackStorySimpleRequirement();

    if (random != 0 && random < 100) {
      if (context.oracle.getRandomNumber(100, 0) > uint(random)) {
        return IStoryController.AnswerResultId.RANDOM_FAIL;
      }
    } else if (random > 100) {
      revert IAppErrors.NotRandom(random);
    }

    return IStoryController.AnswerResultId.SUCCESS;
  }

  /// @notice Ensure that the answer was given fast enough
  function checkAnswerDelay(IStoryController.StoryActionContext memory context) internal view returns (IStoryController.AnswerResultId) {

    (,uint32 delay,) = context.answerAttributes.unpackStorySimpleRequirement();

    if (delay != 0) {
      uint lastCall = uint(context.heroLastActionTS);
      if (lastCall != 0 && lastCall < block.timestamp && block.timestamp - lastCall > uint(delay)) {
        return IStoryController.AnswerResultId.DELAY_FAIL;
      }
    }

    return IStoryController.AnswerResultId.SUCCESS;
  }

  function checkAnswerHeroCustomData(
    IStoryController.StoryActionContext memory context,
    bytes32 answerIndex,
    IStoryController.MainState storage s
  ) internal view returns (IStoryController.AnswerResultId) {
    return _checkAnswerCustomData(context, s.heroCustomDataRequirement[answerIndex], true);
  }

  function checkAnswerGlobalCustomData(
    IStoryController.StoryActionContext memory context,
    bytes32 answerIndex,
    IStoryController.MainState storage s
  ) internal view returns (IStoryController.AnswerResultId) {
    return _checkAnswerCustomData(context, s.globalCustomDataRequirement[answerIndex], false);
  }

  function _checkAnswerCustomData(
    IStoryController.StoryActionContext memory context,
    IStoryController.CustomDataRequirementPacked[] memory datas,
    bool heroCustomData
  ) internal view returns (IStoryController.AnswerResultId) {
    uint len = datas.length;
    for (uint i; i < len; ++i) {
      IStoryController.CustomDataRequirementPacked memory data = datas[i];

      if (data.index != 0) {
        (uint valueMin, uint valueMax, bool mandatory) = data.data.unpackCustomDataRequirements();
        uint heroValue = heroCustomData
          ? context.statController.heroCustomData(context.heroToken, context.heroTokenId, data.index)
          : context.statController.globalCustomData(data.index);

        if (heroValue < valueMin || heroValue > valueMax) {
          if (mandatory) {
            if (heroCustomData) {
              revert IAppErrors.NotHeroData();
            } else {
              revert IAppErrors.NotGlobalData();
            }
          } else {
            return heroCustomData
              ? IStoryController.AnswerResultId.HERO_CUSTOM_DATA_FAIL
              : IStoryController.AnswerResultId.GLOBAL_CUSTOM_DATA_FAIL;
          }
        }
      }
    }

    return IStoryController.AnswerResultId.SUCCESS;
  }

  //endregion ------------------------ Check answers
}