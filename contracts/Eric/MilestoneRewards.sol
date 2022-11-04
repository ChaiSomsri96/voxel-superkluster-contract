//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

contract VoxelX {

    // event to track progress updates
    event LeaderboardUpdate(address user, uint256 rank, uint256 points);
    // event to track referral bonus payments
    event ReferralBonusPaid(address referrer, address referredAddress, uint256 bonusAmount);
    // event to track quest completion and rewards
    event QuestCompleted(address user, uint256 questId, uint256 rewardAmount);

    // mapping to store user progress
    mapping (address => uint256) public progress;
    // mapping to store referral bonus balance for each user
    mapping (address => uint256)

    Quest storage struct:

    struct Quest {
        QuestType questType;
        QuestDifficulty questDifficulty;
        uint256 rewardAmount;
        RewardMethod rewardMethod;
        uint256 totalTasks;
        uint256[] milestoneAmounts;
        uint256[] milestoneRewards;
        uint256 activityLevel;
    }

    Mapping to store quests:

    mapping (uint256 => Quest) public quests;

    Function to add a new quest:

    function addQuest(QuestType questType, QuestDifficulty questDifficulty, uint256 rewardAmount, RewardMethod rewardMethod, uint256 totalTasks, uint256[] milestoneAmounts, uint256[] milestoneRewards, uint256 activityLevel) public {
        require(isAdmin(), "Only admins can add new quests.");
        uint256 questId = quests.length;
        quests[questId] = Quest({
            questType: questType,
            questDifficulty: questDifficulty,
            rewardAmount: rewardAmount,
            rewardMethod: rewardMethod,
            totalTasks: totalTasks,
            milestoneAmounts: milestoneAmounts,
            milestoneRewards: milestoneRewards,
            activityLevel: activityLevel
        });
        // trigger QuestAdded event
        emit QuestAdded(questId, questType, questDifficulty, rewardAmount, rewardMethod, totalTasks, milestoneAmounts, milestoneRewards, activityLevel);
    }

    // define a struct to store quest information
    struct Quest {
        QuestType questType;
        QuestDifficulty questDifficulty;
        uint256 rewardAmount;
        RewardMethod rewardMethod;
        uint256 totalTasks;
        uint256[] milestoneAmounts;
        uint256[] milestoneRewards;
        uint256 activityLevel;
    }

    // mapping to store quest information
    mapping (uint256 => Quest) public quests;

    // function to get quest information
    function getQuestInformation(uint256 questId) public view returns (QuestType, QuestDifficulty, uint256, RewardMethod, uint256, uint256[], uint256[]) {
        Quest memory quest = quests[questId];
        return (quest.questType, quest.questDifficulty, quest.rewardAmount, quest.rewardMethod, quest.totalTasks, quest.milestoneAmounts, quest.milestoneRewards);
    }

    // function to calculate referral bonus
    function calculateReferralBonus(uint256 questId) internal view returns (uint256) {
        return quests[questId].rewardAmount.mul(quests[questId].activityLevel).div(100);
    }

    // function to pay referral bonus
    function payReferralBonus(address referredAddress, uint256 questId) public {
        require(referralBonuses[msg.sender] > 0, "You have not earned any referral bonuses.");
        uint256 bonusAmount = referralBonuses[msg.sender];
        // check if the referred address is eligible for referral bonus
        if (isEligibleForReferralBonus(referredAddress, questId)) {
            // transfer the referral bonus to the referred address
            require(voxelXToken.transfer(referredAddress, bonusAmount), "Transfer failed.");
            // update referral bonus balance of the referred address
            referralBonuses[referredAddress] = referralBonuses[referredAddress].add(bonusAmount);
            // trigger ReferralBonusPaid event
            emit ReferralBonusPaid(msg.sender, referredAddress, bonusAmount);
        } else {
            // transfer the referral bonus back to the sender
            require(voxelXToken.transfer(msg.sender, bonusAmount), "Transfer failed.");
        }
    }

    // function to check if a user is eligible for referral bonus
    function isEligibleForReferralBonus(address referredAddress, uint256 questId) internal view returns (bool) {
        return referredAddress != address(0) &&
        quests[questId].rewardMethod == RewardMethod.ReferralBasedDistribution &&
        progress[referredAddress] >= quests[questId].activityLevel;
    }

    // function to calculate user progress
    function updateUserProgress(uint256 points) public {
        progress[msg.sender] = progress[msg.sender].add(points);
        // trigger LeaderboardUpdate

        // create a new quest object and add it to the quests mapping
        uint256 questId = quests.length;
        quests.push(Quest({
            questType: questType,
            questDifficulty: questDifficulty,
            rewardAmount: rewardAmount,
            rewardMethod: rewardMethod,
            totalTasks: totalTasks,
            milestoneAmounts: milestoneAmounts,
            milestoneRewards: milestoneRewards,
            activityLevel: activityLevel
        }));

        // trigger QuestAdded event
        emit QuestAdded(questId);
    }

    // function to remove a quest
    function removeQuest(uint256 questId) public {
        require(isAdmin(), "Only admins can remove quests.");
        require(questId < quests.length, "Quest not found.");

        // remove the quest from the quests mapping
        delete quests[questId];

        // trigger QuestRemoved event
        emit QuestRemoved(questId);
    }

    // function to update a quest
    function updateQuest(uint256 questId, QuestType questType, QuestDifficulty questDifficulty, uint256 rewardAmount, RewardMethod rewardMethod, uint256 totalTasks, uint256[] milestoneAmounts, uint256[] milestoneRewards, uint256 activityLevel) public {
        require(isAdmin(), "Only admins can update quests.");
        require(questId < quests.length, "Quest not found.");

        // update the quest in the quests mapping
        quests[questId] = Quest({
            questType: questType,
            questDifficulty: questDifficulty,
            rewardAmount: rewardAmount,
            rewardMethod: rewardMethod,
            totalTasks: totalTasks,
            milestoneAmounts: milestoneAmounts,
            milestoneRewards: milestoneRewards,
            activityLevel: activityLevel
        });

        // trigger QuestUpdated event
        emit QuestUpdated(questId);
    }

    // function to get quest details
    function getQuestDetails(uint256 questId) public view returns (QuestType, QuestDifficulty, uint256, RewardMethod, uint256, uint256[], uint256[], uint256) {
        require(questId < quests.length, "Quest not found.");

        // return the quest details
        return (
        quests[questId].questType,
        quests[questId].questDifficulty,
        quests[questId].rewardAmount,
        quests[questId].rewardMethod,
        quests[questId].totalTasks,
        quests[questId].milestoneAmounts,
        quests[questId].milestoneRewards,
        quests[questId].activityLevel
        );
    }

    // function to get all quests
    function getAllQuests() public view returns (Quest[] memory) {
        return quests;
    }

    // function to get progress of a user
    function getUserProgress(address user) public view returns (uint256) {
        return progress[user];
    }

    // function to get reward balance of a user
    function getRewardBalance(address user) public view returns (uint256) {
        return rewards[user];
    }

    // function to get referral bonus balance of a user
    function getReferralBonusBalance(address user) public view returns (uint256) {
        return referralBonuses[user];
    }

    // function to check if a user is admin or not
    function isAdmin() internal view returns (bool) {
        return admins[msg.sender];
    }
}

uint256 newQuestId = quests.length;

quests.push(Quest({
    questType: questType,
    questDifficulty: questDifficulty,
    rewardAmount: rewardAmount,
    rewardMethod: rewardMethod,
    totalTasks: totalTasks,
    milestoneAmounts: milestoneAmounts,
    milestoneRewards: milestoneRewards,
    activityLevel: activityLevel
}));
// trigger QuestAdded event
emit QuestAdded(newQuestId);
}

// function to remove an existing quest
function removeQuest(uint256 questId) public {
    require(isAdmin(), "Only admins can remove existing quests.");
    require(questId < quests.length, "Quest with specified id does not exist.");
    // delete the quest from the array
    delete quests[questId];
    // trigger QuestRemoved event
    emit QuestRemoved(questId);
}

// function to update an existing quest
function updateQuest(uint256 questId, QuestType questType, QuestDifficulty questDifficulty, uint256 rewardAmount, RewardMethod rewardMethod, uint256 totalTasks, uint256[] milestoneAmounts, uint256[] milestoneRewards, uint256 activityLevel) public {
    require(isAdmin(), "Only admins can update existing quests.");
    require(questId < quests.length, "Quest with specified id does not exist.");
    quests[questId].questType = questType;
    quests[questId].questDifficulty = questDifficulty;
    quests[questId].rewardAmount = rewardAmount;
    quests[questId].rewardMethod = rewardMethod;
    quests[questId].totalTasks = totalTasks;
    quests[questId].milestoneAmounts = milestoneAmounts;
    quests[questId].milestoneRewards = milestoneRewards;
    quests[questId].activityLevel = activityLevel;
    // trigger QuestUpdated event
    emit QuestUpdated(questId);
}


// function to get the number of quests
function getNumberOfQuests() public view returns (uint256) {
    return quests.length;
}

// function to get details of a quest
function getQuestDetails(uint256 questId) public view returns (QuestType, QuestDifficulty, uint256, RewardMethod, uint256, uint256[], uint256[], uint256) {
    require(questId < quests.length, "Quest with specified id does not exist.");
    return (quests[questId].questType, quests[questId].questDifficulty, quests[questId].rewardAmount, quests[questId].rewardMethod, quests[questId].totalTasks, quests[questId].milestoneAmounts, quests[questId].milestoneRewards, quests[questId].activityLevel);
}

// function to get a user's progress
function getUserProgress(address user) public view returns (uint256) {
    return progress[user];
}

// function to get a user's rewards balance
function getUserRewards(address user) public view returns (uint256) {
    return rewards[user];
}

// function to get a user's referral bonus balance
function getReferralBonus(address user) public view returns (uint256) {
    return referralBonuses[user];
}
}

// function to check if a user has completed a task
function isTaskCompleted(uint256 questId, uint256 taskId) public view returns (bool) {
    return tasks[msg.sender][questId][taskId];
}

// function to complete a task
function completeTask(uint256 questId, uint256 taskId) public {
    require(!isTaskCompleted(questId, taskId), "Task is already completed.");
    tasks[msg.sender][questId][taskId] = true;

    // calculate reward points for the task
    uint256 rewardPoints = calculateTaskReward(questId, taskId);
    // update user progress
    updateUserProgress(rewardPoints);

    // check if the user has completed all tasks of the quest
    if (isQuestCompleted(questId)) {
        // calculate rewards for the quest
        uint256 questReward = calculateQuestReward(questId);
        // update rewards balance of the user
        rewards[msg.sender] = rewards[msg.sender].add(questReward);
        // trigger QuestCompleted event
        emit QuestCompleted(msg.sender, questId, questReward);
    }
}

// function to check if a user has completed a quest
function isQuestCompleted(uint256 questId) internal view returns (bool) {
    uint256 totalTasks = quests[questId].totalTasks;
    for (uint256 i = 0; i < totalTasks; i++) {
        if (!tasks[msg.sender][questId][i]) {
            return false;
        }
    }
    return true;
}

// function to calculate reward points for a task
function calculateTaskReward(uint256 questId, uint256 taskId) internal view returns (uint256) {
    return quests[questId].milestoneAmounts[taskId].mul(quests[questId].activityLevel).div(100);
}

// function to calculate rewards for a quest
function calculateQuestReward(uint256 questId) internal view returns (uint256) {
    uint256 questReward = 0;
    uint256 totalTasks = quests[questId].totalTasks;
    for (uint256 i = 0; i < totalTasks; i++) {
        questReward = questReward.add(quests[questId].milestoneRewards[i]);
    }
    return questReward;
}

// function to get quest information
function getQuestInfo(uint256 questId) public view returns (QuestType, QuestDifficulty, uint256, RewardMethod, uint256, uint256[], uint256[], uint256) {
    return (
        quests[questId].questType,
        quests[questId].questDifficulty,
        quests[questId].rewardAmount,
        quests[questId].rewardMethod,
        quests[questId].totalTasks,
        quests[questId].milestoneAmounts,
        quests[questId].milestoneRewards,
        quests[questId].activityLevel
    );
}

// function to get user quest progress
function getUserQuestProgress(address user, uint256 questId) public view returns (uint256) {
    uint256 completedTasks = 0;
    uint256 totalTasks = quests[questId].totalTasks;
    for (uint256 i = 0; i < totalTasks; i++) {
        if (tasks[user][questId][i]) {
            completedTasks++;
        }
    }

// function to update quest information
function updateQuest(uint256 questId, QuestType questType, QuestDifficulty questDifficulty, uint256 rewardAmount, RewardMethod rewardMethod, uint256 totalTasks, uint256[] milestoneAmounts, uint256[] milestoneRewards, uint256 activityLevel) public {
    require(isAdmin(), "Only admins can update quests.");
    require(questId < quests.length, "Quest not found.");

    quests[questId].questType = questType;
    quests[questId].questDifficulty = questDifficulty;
    quests[questId].rewardAmount = rewardAmount;
    quests[questId].rewardMethod = rewardMethod;
    quests[questId].totalTasks = totalTasks;
    quests[questId].milestoneAmounts = milestoneAmounts;
    quests[questId].milestoneRewards = milestoneRewards;
    quests[questId].activityLevel = activityLevel;

    // trigger QuestUpdated event
    emit QuestUpdated(questId, questType, questDifficulty, rewardAmount, rewardMethod, totalTasks, milestoneAmounts, milestoneRewards, activityLevel);
}

// function to delete quest
function deleteQuest(uint256 questId) public {
    require(isAdmin(), "Only admins can delete quests.");
    require(questId < quests.length, "Quest not found.");

    delete quests[questId];

    // trigger QuestDeleted event
    emit QuestDeleted(questId);
}

// function to get quest information
function getQuestInfo(uint256 questId) public view returns (QuestType, QuestDifficulty, uint256, RewardMethod, uint256, uint256[], uint256[], uint256) {
    require(questId < quests.length, "Quest not found.");

    return (
        quests[questId].questType,
        quests[questId].questDifficulty,
        quests[questId].rewardAmount,
        quests[questId].rewardMethod,
        quests[questId].totalTasks,
        quests[questId].milestoneAmounts,
        quests[questId].milestoneRewards,
        quests[questId].activityLevel
    );
}

// function to get all quests information
function getAllQuests() public view returns (Quest[]) {
    return quests;
}

// function to get user progress
function getUserProgress(address user) public view returns (uint256) {
    return progress[user];
}

// function to get user rewards balance
function getUserRewards(address user) public view returns (uint256) {
    return rewards[user];
}

// function to get user referral bonus balance
function getReferralBonus(address user) public view returns (uint256) {
    return referralBonuses[user];
}
}

    uint256 newQuestId = quests.push(Quest(questType, questDifficulty, rewardAmount, rewardMethod, totalTasks, milestoneAmounts, milestoneRewards, activityLevel)) - 1;
    // trigger QuestAdded event
    emit QuestAdded(newQuestId, questType, questDifficulty, rewardAmount, rewardMethod, totalTasks, milestoneAmounts, milestoneRewards, activityLevel);
}

// function to update quest status
function updateQuestStatus(uint256 questId, QuestStatus questStatus) public {
    require(isAdmin(), "Only admins can update quest status.");
    quests[questId].status = questStatus;
    // trigger QuestUpdated event
    emit QuestUpdated(questId, questStatus);
}

// function to update quest rewards
function updateQuestRewards(uint256 questId, uint256 rewardAmount, uint256[] milestoneAmounts, uint256[] milestoneRewards) public {
    require(isAdmin(), "Only admins can update quest rewards.");
    quests[questId].rewardAmount = rewardAmount;
    quests[questId].milestoneAmounts = milestoneAmounts;
    quests[questId].milestoneRewards = milestoneRewards;
    // trigger QuestRewardsUpdated event
    emit QuestRewardsUpdated(questId, rewardAmount, milestoneAmounts, milestoneRewards);
}

// function to get quest details
function getQuestDetails(uint256 questId) public view returns (QuestType questType, QuestDifficulty questDifficulty, uint256 rewardAmount, RewardMethod rewardMethod, uint256 totalTasks, uint256[] milestoneAmounts, uint256[] milestoneRewards, uint256 activityLevel, QuestStatus questStatus) {
    Quest memory quest = quests[questId];
    return (quest.type, quest.difficulty, quest.rewardAmount, quest.rewardMethod, quest.totalTasks, quest.milestoneAmounts, quest.milestoneRewards, quest.activityLevel, quest.status);
}

// function to get all quests
function getAllQuests() public view returns (Quest[] memory) {
    return quests;
}

// function to get user rewards
function getUserRewards(address user) public view returns (uint256) {
    return rewards[user];

}

// function to get user referral bonus balance
function getUserReferralBonus(address user) public view returns (uint256) {
    return referralBonuses[user];
}

// function to get user progress
function getUserProgress(address user) public view returns (uint256) {
    return progress[user];
}

// function to check if an address is admin
function isAdmin() internal view returns (bool) {
    return msg.sender == admin;
}
}

    questId = quests.push(Quest({
        questType: questType,
        questDifficulty: questDifficulty,
        rewardAmount: rewardAmount,
        rewardMethod: rewardMethod,
        totalTasks: totalTasks,
        completedTasks: 0,
        milestoneAmounts: milestoneAmounts,
        milestoneRewards: milestoneRewards,
        activityLevel: activityLevel
    })) - 1;

    // trigger NewQuest event
    emit NewQuest(questId, questType, questDifficulty, rewardAmount, rewardMethod, totalTasks);
}

// function to complete a task
function completeTask(uint256 questId) public {
    require(quests[questId].completedTasks < quests[questId].totalTasks, "Quest already completed.");
    quests[questId].completedTasks++;

    // check if the quest is completed
    if (quests[questId].completedTasks == quests[questId].totalTasks) {

        uint256 reward = quests[questId].rewardAmount;

        // check if the quest has milestones
        if (quests[questId].milestoneAmounts.length > 0) {

            for (uint256 i = 0; i < quests[questId].milestoneAmounts.length; i++) {
                if (quests[questId].completedTasks == quests[questId].milestoneAmounts[i]) {
                    reward += quests[questId].milestoneRewards[i];
                    break;
                }
            }
        }

        // check the reward method for the quest
        switch (quests[questId].rewardMethod) {
            case RewardMethod.InstantPayout:
                // transfer the rewards to the user
                require(voxelXToken.transfer(msg.sender, reward), "Transfer failed.");
                break;
            case RewardMethod.LevelBasedDistribution:
                if (progress[msg.sender] >= quests[questId].activityLevel) {
                    require(voxelXToken.transfer(msg.sender, reward), "Transfer failed.");
                }
                break;
            case RewardMethod.ReferralBasedDistribution:
                referralBonuses[msg.sender] = referralBonuses[msg.sender].add(calculateReferralBonus(questId));
                break;
            default:
                // add the rewards to the balance of the user
                rewards[msg.sender] = rewards[msg.sender].add(reward);
                break;
        }

        // trigger QuestCompleted event
        emit QuestCompleted(msg.sender, questId, reward);
    }
}

}

}
