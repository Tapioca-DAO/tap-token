// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.18;

import {BaseBoringBatchable} from "@boringcrypto/boring-solidity/contracts/BoringBatchable.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "tapioca-sdk/dist/contracts/util/ERC4494.sol";

// ********************************************************************************
// *******************************,                 ,******************************
// *************************                               ************************
// *********************                                       ********************
// *****************,                     @@@                     ,****************
// ***************                        @@@                        **************
// *************                    (@@@@@@@@@@@@@(                    ************
// ***********                   @@@@@@@@#@@@#@@@@@@@@                   **********
// **********                 .@@@@@      @@@      @@@@@.                 *********
// *********                 @@@@@        @@@        @@@@@                 ********
// ********                 @@@@@&        @@@         /@@@@                 *******
// *******                 &@@@@@@        @@@          #@@@&                 ******
// ******,                 @@@@@@@@,      @@@           @@@@                 ,*****
// ******                 #@@@&@@@@@@@@#  @@@           &@@@(                 *****
// ******                 %@@@%   @@@@@@@@@@@@@@@(      (@@@%                 *****
// ******                 %@@@%          %@@@@@@@@@@@@. %@@@#                 *****
// ******.                /@@@@           @@@    *@@@@@@@@@@*                .*****
// *******                 @@@@           @@@       &@@@@@@@                 ******
// *******                 /@@@@          @@@        @@@@@@/                .******
// ********                 %&&&&         @@@        &&&&&#                 *******
// *********                 *&&&&#       @@@       &&&&&,                 ********
// **********.                 %&&&&&,    &&&    ,&&&&&%                 .*********
// ************                   &&&&&&&&&&&&&&&&&&&                   ***********
// **************                     .#&&&&&&&%.                     *************
// ****************                       %%%                       ***************
// *******************                    %%%                    ******************
// **********************                                    .*********************
// ***************************                           **************************
// ************************************..     ..***********************************

// TODO: Data sizes; fits in one slot
struct TapEntry {
    uint256 expiry; // expiry timestamp
    uint256 tapAmount; // amount of TAP to be released
    uint256 multiplier; // voting power
    uint256 lastInactive; // One week BEFORE the staker gets a share of rewards
    uint256 lastActive; // Last week that the staker shares in rewards
}

struct WeekTotals {
    // For [0..currentWeek] this is a cumulative total: it consists of the
    // active votes in the previous week, minus the votes known to expire this
    // week. For future weeks, it is a negative number corresponding to the
    // expiring votes.
    // TODO: Will fit in an int128
    int256 netActiveVotes;
    // rewardTokens index -> amount
    mapping(uint256 => uint256) totalDistPerVote;
}

contract TWTap is ERC721, ERC721Permit, BaseBoringBatchable {
    using SafeERC20 for IERC20;

    address public portal; // address of the portal
    uint256 public mintedTWTap;

    // The current week is determined by creation, but there are values that
    // need to be updated weekly. If, for any reason whatsoever, this cannot
    // be done in time, the `lastProcessedWeek` will be behind until this is
    // done.
    uint256 public constant WEEK = 7 days;
    uint256 public creation; // Week 0 starts here
    uint256 public lastProcessedWeek;
    mapping(uint256 => WeekTotals) public weekTotals;

    mapping(uint256 => TapEntry) public entry; // tokenId => entry

    // If we assume 128 bit balances for the reward token -- which fit 1e40
    // "tokens" at the most comonly used 1e18 precision -- then we can use
    // the other 128 bits to store the tokens allotted to a single vote more
    // accurately. Votes are proportional to the amount of TAP locked, weighted
    // by a multiplier. TAP has a supply of 100M * 1e18 (87 bits), and the
    // weight ranges from 10-100% in basis points, so 10k (14 bits).
    // the multiplier is at most 100% = 10k (14 bits), so we are safe.
    uint256 public constant DIST_PRECISION = 2 ** 128;

    IERC20[] public rewardTokens;

    // tokenId -> rewardTokens index -> amount
    mapping(uint256 => mapping(uint256 => uint256)) public claimed;

    constructor()
        ERC721("Time Weighted TAP", "twTAP")
        ERC721Permit("Time Weighted TAP")
    {
        creation = block.timestamp;
    }

    modifier onlyPortal() {
        require(msg.sender == portal, "twTAP: only portal");
        _;
    }

    modifier inCurrentWeek() {
        require(lastProcessedWeek == currentWeek(), "Week not updated");
        _;
    }

    // ==========
    //   EVENTS
    // ==========
    event Mint(address indexed to, uint256 indexed tokenId, TapEntry position);
    event Burn(
        address indexed from,
        uint256 indexed tokenId,
        TapEntry position
    );

    // =========
    //    READ
    // =========

    // TODO implement tokenURI
    // function tokenURI(
    //     uint256 _tokenId
    // ) public view override returns (string memory) {
    //     return tokenURIs[_tokenId];
    // }

    function currentWeek() public view returns (uint256) {
        return (block.timestamp - creation) / WEEK;
    }

    function isApprovedOrOwner(
        address _spender,
        uint256 _tokenId
    ) external view returns (bool) {
        return _isApprovedOrOwner(_spender, _tokenId);
    }

    /// @notice Return the owner of the tokenId and the attributes of the position.
    function attributes(
        uint256 _tokenId
    ) external view returns (address, TapEntry memory) {
        return (ownerOf(_tokenId), entry[_tokenId]);
    }

    /// @notice Check if a token exists
    function exists(uint256 _tokenId) external view returns (bool) {
        return _exists(_tokenId);
    }

    /// @notice Amount currently claimable for each reward token
    function claimable(
        uint256 _tokenId
    ) public view returns (uint256[] memory) {
        uint256 len = rewardTokens.length;
        uint256[] memory result = new uint256[](len);

        // Why not storage? Because we are going to fit it all into one slot
        TapEntry memory position = entry[_tokenId];
        // Math is safe: (TODO: update types)
        uint256 votes = position.tapAmount * position.multiplier;
        if (votes == 0) {
            return result;
        }

        // If the "last processed week" is behind the actual week, rewards
        // get processed as if it were earlier.
        uint256 week = lastProcessedWeek;
        if (week <= position.lastInactive) {
            return result;
        }
        if (position.lastActive < week) {
            week = position.lastActive;
        }

        WeekTotals storage cur = weekTotals[week];
        WeekTotals storage prev = weekTotals[position.lastInactive];

        for (uint256 i = 0; i < len; ) {
            // Math is safe: (TODO: proof, make entire loop unchecked)
            uint256 net = cur.totalDistPerVote[i] - prev.totalDistPerVote[i];
            result[i] = ((votes * net) / DIST_PRECISION) - claimed[_tokenId][i];
            unchecked {
                ++i;
            }
        }
        return result;
    }

    // ==========
    //    WRITE
    // ==========

    // function setTokenURI(uint256 _tokenId, string calldata _tokenURI) external {
    //     require(
    //         _isApprovedOrOwner(msg.sender, _tokenId),
    //         "twTap: only approved or owner"
    //     );
    //     tokenURIs[_tokenId] = _tokenURI;
    // }

    /// @notice Indicate that (a) week(s) have passed and update running totals
    /// @notice Reverts if called in week 0. Let it.
    /// @param _limit Maximum number of weeks to process in one call
    function advanceWeek(uint256 _limit) public {
        // TODO: Make whole function unchecked
        uint256 cur = currentWeek();
        uint256 week = lastProcessedWeek;
        uint256 goal = cur;
        unchecked {
            if (goal - week > _limit) {
                goal = week + _limit;
            }
        }
        uint256 len = rewardTokens.length;
        while (week < goal) {
            WeekTotals storage prev = weekTotals[week];
            WeekTotals storage next = weekTotals[++week];
            // TODO: Math is safe
            next.netActiveVotes += prev.netActiveVotes;
            for (uint256 i = 0; i < len; ) {
                next.totalDistPerVote[i] += prev.totalDistPerVote[i];
                unchecked {
                    ++i;
                }
            }
        }
        lastProcessedWeek = goal;
    }

    /// @notice mint twTAP
    /// @param _to address to mint to
    /// @param _expiry timestamp
    /// @param _tapAmount amount of TAP to be released
    /// @param _multiplier voting power (in basis points)
    function mint(
        address _to,
        uint256 _expiry,
        uint256 _tapAmount,
        uint256 _multiplier
    ) external onlyPortal inCurrentWeek returns (uint256 tokenId) {
        require(_expiry > block.timestamp, "Expired");
        tokenId = ++mintedTWTap;
        _safeMint(_to, tokenId);

        // Cast is safe:
        //   `_multiplier` fits in 14 bits (TODO: Enforce -- merge)
        //   `_tapAmount` fits in 87 bits (see TAP contract)
        int256 votes = int256(_tapAmount * _multiplier);
        // Eligibility starts NEXT week (for the locker; not globally)
        uint256 w0 = currentWeek();
        uint256 w1 = w0 + (_expiry - creation) / WEEK;

        // TODO: More gas efficient to populate in memory?
        TapEntry storage position = entry[tokenId];
        position.expiry = _expiry;
        position.tapAmount = _tapAmount;
        position.multiplier = _multiplier;

        position.lastInactive = w0;
        position.lastActive = w1;
        weekTotals[w0].netActiveVotes += votes;
        weekTotals[w1].netActiveVotes -= votes;

        emit Mint(_to, tokenId, position);
    }

    /// @notice burns twTAP. Caller should claim outstanding rewards first.
    /// @param _tokenId tokenId to burn
    function burn(uint256 _tokenId) external {
        // TODO: Enforce that token is expired. (Merge with portal)
        //       Since the token can only be burnt after expiry, totals do not
        //       need to be updated.
        require(
            _isApprovedOrOwner(msg.sender, _tokenId),
            "twTap: only approved or owner"
        );

        _burn(_tokenId);
        // TODO: Recover some gas by emptying out `claimed`?

        TapEntry memory position = entry[_tokenId];
        emit Burn(msg.sender, _tokenId, position);
    }

    /// @notice claims all rewards distributed since token mint or last claim.
    /// @param _tokenId tokenId whose rewards to claim
    /// @param _to address to receive the rewards
    function claim(uint256 _tokenId, address _to) external {
        // Implementation of _isApprovedOrOwner, with additional _to == owner
        // check:
        address owner = ownerOf(_tokenId);
        require(
            msg.sender == owner ||
                _to == owner ||
                isApprovedForAll(owner, msg.sender) ||
                getApproved(_tokenId) == msg.sender,
            "twTap: only approved or owner"
        );

        uint256[] memory amounts = claimable(_tokenId);
        uint256 len = amounts.length;
        unchecked {
            for (uint256 i = 0; i < len; ++i) {
                uint256 amount = amounts[i];
                if (amount > 0) {
                    // Math is safe: `amount` calculated safely in `claimable()`
                    claimed[_tokenId][i] += amount;
                    rewardTokens[i].safeTransfer(_to, amount);
                }
            }
        }
    }

    /// @notice distributes a reward among all tokens, weighted by voting power
    /// @notice The reward gets allocated to all positions that have locked in
    /// @notice the current week. Fails, intentionally, if this number is zero.
    /// @param _rewardTokenId index of the reward in `rewardTokens`
    /// @param _amount amount of reward token to distribute
    function distribute(
        uint256 _rewardTokenId,
        uint256 _amount
    ) external inCurrentWeek {
        WeekTotals storage totals = weekTotals[lastProcessedWeek];
        IERC20 rewardToken = rewardTokens[_rewardTokenId];
        // If this is a DBZ then there are no positions to give the reward to.
        // Since reward eligibility starts in the week after locking, there is
        // no way to give out rewards THIS week:
        // Cast is safe: `netActiveVotes` is at most zero by construction of
        // weekly totals and the requirement that they are up to date.
        // TODO: Word this better
        totals.totalDistPerVote[_rewardTokenId] +=
            (_amount * DIST_PRECISION) /
            uint256(totals.netActiveVotes);
        rewardToken.safeTransferFrom(msg.sender, address(this), _amount);
    }

    function addRewardToken(
        IERC20 token
    ) external onlyPortal returns (uint256) {
        uint256 i = rewardTokens.length;
        rewardTokens.push(token);
        return i;
    }

    /// @notice tDP claim
    function portalClaim() external {
        require(portal == address(0), "twTap: only once");
        portal = msg.sender;
    }
}
