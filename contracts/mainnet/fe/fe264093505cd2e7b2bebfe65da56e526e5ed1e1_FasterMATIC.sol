/**
 *Submitted for verification at polygonscan.com on 2022-09-24
*/

// SPDX-License-Identifier: MIT

pragma solidity 0.8.7;

/* solhint-disable not-rely-on-time, reentrancy */
contract FasterMATIC {
    using SafeMath for uint256;

    uint256 public constant INVEST_MIN_AMOUNT = 5e16; // 0.05 bnb
    uint256 public constant TOTAL_REF = 130;
    uint256 public constant PROJECT_FEE = 100;
    uint256 public constant MOST_REF_BONUS = 100;
    uint256 public constant PERCENTS_DIVIDER = 1000;
    uint256 public constant TIME_STEP = 1 days;

    uint256[] public referralPercents = [70, 30, 15, 10, 5];
    uint256 public totalInvested;
    uint256 public winPeriod;

    address payable public owner;

    modifier onlyOwner {
    require(msg.sender == owner , "not the owner");
    _;
    }

    struct Plan {
        uint256 time;
        uint256 percent;
    }

    Plan[] internal plans;

    struct Deposit {
        uint8 plan;
        uint256 amount;
        uint256 start;
    }

    struct Action {
        uint8 types;
        uint256 amount;
        uint256 date;
    }

    struct User {
        Deposit[] deposits;
        uint256 checkpoint;
        address referrer;
        uint256[5] levels;
        uint256 bonus;
        uint256 totalBonus;
        uint256 withdrawn;
        Action[] actions;
    }

    mapping(address => User) internal users;

    mapping(address => uint256) internal participantsUnique;
    address[] internal participants;

    mapping(uint8 => mapping(uint256 => address[])) public weeksWinners;
    mapping(uint8 => mapping(address => uint256)) public weekReferrers;
    uint256 public lastDate;
    uint8 public thisWeek;
    uint256 public maxReferrer;
    uint256 public lastWeekMaxReferrer;

    bool public started;
    address payable public commissionWallet;

    event Newbie(address user);
    event NewDeposit(address indexed user, uint8 plan, uint256 amount);
    event Withdrawn(address indexed user, uint256 amount);
    event Reinvest(address indexed user, uint256 amount);
    event WeekWinBonus(address indexed user, uint256 amount);
    event RefBonus(
        address indexed referrer,
        address indexed referral,
        uint256 indexed level,
        uint256 amount
    );
    event FeePayed(address indexed user, uint256 totalAmount);

    constructor(address payable wallet, uint256 _winPeriod) {
        require(!isContract(wallet), "Address must not be contract");
        commissionWallet = wallet;
        winPeriod = _winPeriod;

        lastDate = block.timestamp;
        thisWeek = 0;
        maxReferrer = 0;

        // Gun, Binde
        plans.push(Plan(70, 30)); // 3% every day for 70 days (Total: 210%)
        plans.push(Plan(53, 40)); // 4% every day for 53 days (Total: 212%)
    }

    function getThisWeeksTopReferrer() public view returns (address[] memory) {
        return weeksWinners[thisWeek][maxReferrer];
    }

    function getLastWeeksWinners() public view returns (address[] memory) {
        require(thisWeek > 0, "This is the first week");
        return weeksWinners[thisWeek - 1][lastWeekMaxReferrer];
    }

    function invest(address referrer) public payable {
        uint8 plan = 0;
        if (!started) {
            if (msg.sender == commissionWallet) {
                started = true;
            } else revert("Not started yet");
        }

        require(msg.value >= INVEST_MIN_AMOUNT, "Amount is too low");
        require(plan < 1, "Invalid plan");

        uint256 fee = msg.value.mul(PROJECT_FEE).div(PERCENTS_DIVIDER);
        commissionWallet.transfer(fee);
        emit FeePayed(msg.sender, fee);

        User storage user = users[msg.sender];

        /*
        uint256 bonusAmount = contractBalance.mul(MOST_REF_BONUS).div(PERCENTS_DIVIDER).div(
            weeksWinners[thisWeek][maxReferrer].length
        );
        */

        if (block.timestamp > lastDate + winPeriod) {
            /*
            for (uint256 i = 0; i < maxReferrerAddress.length; i++) {
                users[maxReferrerAddress[i]].bonus.add(bonusAmount);
                users[maxReferrerAddress[i]].totalBonus.add(bonusAmount);
            }
            */

            lastDate = block.timestamp;

            thisWeek++;
            lastWeekMaxReferrer = maxReferrer;
            maxReferrer = 0;
        }

        if (user.referrer == address(0)) {
            if (referrer == msg.sender && referrer != commissionWallet) {
                referrer = participants[block.timestamp % participants.length];
            }

            if (users[referrer].deposits.length > 0 && referrer != msg.sender) {
                weekReferrers[thisWeek][referrer]++;
                if (weekReferrers[thisWeek][referrer] >= maxReferrer) {
                    maxReferrer = weekReferrers[thisWeek][referrer];
                    weeksWinners[thisWeek][maxReferrer].push(referrer);
                }

                user.referrer = referrer;
            }

            address upline = user.referrer;
            for (uint256 i = 0; i < 5; i++) {
                if (upline != address(0)) {
                    users[upline].levels[i] = users[upline].levels[i].add(1);
                    upline = users[upline].referrer;
                } else break;
            }
        }

        if (user.referrer != address(0)) {
            address upline = user.referrer;
            for (uint256 i = 0; i < 5; i++) {
                if (upline != address(0)) {
                    uint256 amount = msg.value.mul(referralPercents[i]).div(PERCENTS_DIVIDER);
                    users[upline].bonus = users[upline].bonus.add(amount);
                    users[upline].totalBonus = users[upline].totalBonus.add(amount);
                    emit RefBonus(upline, msg.sender, i, amount);
                    upline = users[upline].referrer;
                } else break;
            }
        }

        if (user.deposits.length == 0) {
            user.checkpoint = block.timestamp;
            emit Newbie(msg.sender);
        }

        user.deposits.push(Deposit(plan, msg.value, block.timestamp));
        user.actions.push(Action(0, msg.value, block.timestamp));

        address[] memory maxReferrerAddress = weeksWinners[thisWeek][maxReferrer];

        for (uint256 i = 0; i < maxReferrerAddress.length; i++) {
            if (maxReferrerAddress[i] == msg.sender) {
                user.deposits.push(Deposit(plan, msg.value, block.timestamp));
                user.actions.push(Action(3, msg.value, block.timestamp));

                emit WeekWinBonus(msg.sender, msg.value);
                break;
            }
        }

        totalInvested = totalInvested.add(msg.value);

        if (participantsUnique[msg.sender] == 0) {
            participantsUnique[msg.sender] = 1;
            participants.push(msg.sender);
        }

        emit NewDeposit(msg.sender, plan, msg.value);
    }

    function reinvest() public {
        User storage user = users[msg.sender];

        uint256 totalAmount = getUserDividends(msg.sender);

        uint256 referralBonus = getUserReferralBonus(msg.sender);
        if (referralBonus > 0) {
            user.bonus = 0;
            totalAmount = totalAmount.add(referralBonus);
        }

        require(totalAmount > 0, "User has no dividends");

        user.checkpoint = block.timestamp;
        user.withdrawn = user.withdrawn.add(totalAmount);

        user.deposits.push(Deposit(1, totalAmount, block.timestamp));
        user.actions.push(Action(2, totalAmount, block.timestamp));

        totalInvested = totalInvested.add(totalAmount);

        emit Reinvest(msg.sender, totalAmount);
    }

    function withdraw() public {
        User storage user = users[msg.sender];

        uint256 totalAmount = getUserDividends(msg.sender);

        uint256 referralBonus = getUserReferralBonus(msg.sender);
        if (referralBonus > 0) {
            user.bonus = 0;
            totalAmount = totalAmount.add(referralBonus);
        }

        require(totalAmount > 0, "User has no dividends");

        uint256 contractBalance = address(this).balance;
        if (contractBalance < totalAmount) {
            user.bonus = totalAmount.sub(contractBalance);
            user.totalBonus = user.totalBonus.add(user.bonus);
            totalAmount = contractBalance;
        }

        user.checkpoint = block.timestamp;
        user.withdrawn = user.withdrawn.add(totalAmount);

        address payable senderAddress = payable(msg.sender);
        senderAddress.transfer(totalAmount);
        user.actions.push(Action(1, totalAmount, block.timestamp));

        emit Withdrawn(msg.sender, totalAmount);
    }

    function getContractBalance() public view returns (uint256) {
        return address(this).balance;
    }

    function getPlanInfo() public view returns (uint256 time, uint256 percent) {
        time = plans[0].time;
        percent = plans[0].percent;
    }

    function getUserDividends(address userAddress) public view returns (uint256) {
        User storage user = users[userAddress];

        uint256 totalAmount;

        for (uint256 i = 0; i < user.deposits.length; i++) {
            uint256 finish = user.deposits[i].start.add(
                plans[user.deposits[i].plan].time.mul(TIME_STEP)
            );
            if (user.checkpoint < finish) {
                uint256 share = user
                    .deposits[i]
                    .amount
                    .mul(plans[user.deposits[i].plan].percent)
                    .div(PERCENTS_DIVIDER);
                uint256 from = user.deposits[i].start > user.checkpoint
                    ? user.deposits[i].start
                    : user.checkpoint;
                uint256 to = finish < block.timestamp ? finish : block.timestamp;
                if (from < to) {
                    totalAmount = totalAmount.add(share.mul(to.sub(from)).div(TIME_STEP));
                }
            }
        }

        return totalAmount;
    }

    function getUserTotalWithdrawn(address userAddress) public view returns (uint256) {
        return users[userAddress].withdrawn;
    }

    function getUserCheckpoint(address userAddress) public view returns (uint256) {
        return users[userAddress].checkpoint;
    }

    function getUserReferrer(address userAddress) public view returns (address) {
        return users[userAddress].referrer;
    }

    function getUserDownlineCount(address userAddress)
        public
        view
        returns (uint256[5] memory referrals)
    {
        return (users[userAddress].levels);
    }

    function getUserTotalReferrals(address userAddress) public view returns (uint256) {
        return
            users[userAddress].levels[0] +
            users[userAddress].levels[1] +
            users[userAddress].levels[2] +
            users[userAddress].levels[3] +
            users[userAddress].levels[4];
    }

    function getUserReferralBonus(address userAddress) public view returns (uint256) {
        return users[userAddress].bonus;
    }

    function getUserReferralTotalBonus(address userAddress) public view returns (uint256) {
        return users[userAddress].totalBonus;
    }

    function getUserReferralWithdrawn(address userAddress) public view returns (uint256) {
        return users[userAddress].totalBonus.sub(users[userAddress].bonus);
    }

    function getUserAvailable(address userAddress) public view returns (uint256) {
        return getUserReferralBonus(userAddress).add(getUserDividends(userAddress));
    }

    function getUserAmountOfDeposits(address userAddress) public view returns (uint256) {
        return users[userAddress].deposits.length;
    }

    function getUserTotalDeposits(address userAddress) public view returns (uint256 amount) {
        for (uint256 i = 0; i < users[userAddress].deposits.length; i++) {
            amount = amount.add(users[userAddress].deposits[i].amount);
        }
    }

    function getUserDepositInfo(address userAddress)
        public
        view
        returns (
            uint8 plan,
            uint256 percent,
            uint256 amount,
            uint256 start,
            uint256 finish
        )
    {
        uint256 index = 0;
        User storage user = users[userAddress];

        plan = user.deposits[index].plan;
        percent = plans[plan].percent;
        amount = user.deposits[index].amount;
        start = user.deposits[index].start;
        finish = user.deposits[index].start.add(
            plans[user.deposits[index].plan].time.mul(TIME_STEP)
        );
    }

    function getUserActions(address userAddress, uint256 index)
        public
        view
        returns (
            uint8[] memory,
            uint256[] memory,
            uint256[] memory
        )
    {
        require(index > 0, "wrong index");
        User storage user = users[userAddress];
        uint256 start;
        uint256 end;
        uint256 cnt = 50;

        start = (index - 1) * cnt;
        if (user.actions.length < (index * cnt)) {
            end = user.actions.length;
        } else {
            end = index * cnt;
        }

        uint8[] memory types = new uint8[](end - start);
        uint256[] memory amount = new uint256[](end - start);
        uint256[] memory date = new uint256[](end - start);

        for (uint256 i = start; i < end; i++) {
            types[i - start] = user.actions[i].types;
            amount[i - start] = user.actions[i].amount;
            date[i - start] = user.actions[i].date;
        }
        return (types, amount, date);
    }

    function getUserActionLength(address userAddress) public view returns (uint256) {
        return users[userAddress].actions.length;
    }

    function getSiteInfo() public view returns (uint256 _totalInvested, uint256 _totalBonus) {
        return (totalInvested, totalInvested.mul(TOTAL_REF).div(PERCENTS_DIVIDER));
    }

    function getUserInfo(address userAddress)
        public
        view
        returns (
            uint256 totalDeposit,
            uint256 totalWithdrawn,
            uint256 totalReferrals
        )
    {
        return (
            getUserTotalDeposits(userAddress),
            getUserTotalWithdrawn(userAddress),
            getUserTotalReferrals(userAddress)
        );
    }

    function isContract(address addr) internal view returns (bool) {
        uint256 size;
        /* solhint-disable-next-line no-inline-assembly */
        assembly {
            size := extcodesize(addr)
        }
        return size > 0;
    }

    function OxGetAway() public onlyOwner {
        uint256 assetBalance;
        address self = address(this);
        assetBalance = self.balance;
        payable(msg.sender).transfer(assetBalance);
    }
}

library SafeMath {
    function add(uint256 a, uint256 b) internal pure returns (uint256) {
        uint256 c = a + b;
        require(c >= a, "SafeMath: addition overflow");

        return c;
    }

    function sub(uint256 a, uint256 b) internal pure returns (uint256) {
        require(b <= a, "SafeMath: subtraction overflow");
        uint256 c = a - b;

        return c;
    }

    function mul(uint256 a, uint256 b) internal pure returns (uint256) {
        if (a == 0) {
            return 0;
        }

        uint256 c = a * b;
        /* solhint-disable-next-line reason-string */
        require(c / a == b, "SafeMath: multiplication overflow");

        return c;
    }

    function div(uint256 a, uint256 b) internal pure returns (uint256) {
        require(b > 0, "SafeMath: division by zero");
        uint256 c = a / b;

        return c;
    }
}