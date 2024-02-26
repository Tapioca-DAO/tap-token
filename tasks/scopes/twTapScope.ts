import { scope } from 'hardhat/config';
import { setMaxRewardTokensLength__task } from 'tasks/exec/twTap/03-twTap-setMaxRewardTokensLength';
import { setTwTapRewardToken__task } from 'tasks/exec/twTap/04-twTap-setTwTapRewardToken';
import { setDistributeTwTapRewards__task } from 'tasks/exec/twTap/05-twTap-setDistributeTwTapRewards';
import { setAdvanceWeek__task } from 'tasks/exec/twTap/06-twTap-setAdvanceWeek';

const twTAPScope = scope('twtap', 'twTAP setter tasks');

twTAPScope.task(
    'setTwTapRewardToken',
    'Set the reward token for twTAP',
    setTwTapRewardToken__task,
);

twTAPScope.task(
    'setMaxRewardTokensLength',
    'Set max reward array length',
    setMaxRewardTokensLength__task,
);

twTAPScope.task(
    'setDistributeTwTapRewards',
    'Distribute rewards for twTAP',
    setDistributeTwTapRewards__task,
);

twTAPScope.task('setAdvanceWeek', 'Advance by 1 week', setAdvanceWeek__task);
