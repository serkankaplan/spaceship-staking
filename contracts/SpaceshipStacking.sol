pragma solidity ^0.7.0;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./DummyERC721.sol";

contract SpaceshipStacking is AccessControl {
    using SafeMath for uint256;

    constructor(address _tlmAddress, address _erc721) {
        _setupRole(DEFAULT_ADMIN_ROLE, _msgSender());
        tlm = IERC20(_tlmAddress);
        erc721 = DummyERC721(_erc721);
    }

    struct Mission {
        uint256 startDate;
        uint256 launchDate;
        uint256 rewardTLM;
        string tokenURI;
        uint256 missionCost;
        uint256 missionLength;
        uint256[] bnbSuperCharge;
        string description;
        string name;
        bool isActive;
    }

    struct LaunchedMission {
        uint256 bnbStake;
        uint256 spaceShipCount;
        bool rewardClaimed;
        uint8 tokenMinted;
    }

    event MissionAdded(
        uint256 indexed missionId
    );

    event MissionStarted(
        uint256 indexed missionId,
        address indexed user
    );

    event RewardClaimed(
        uint256 indexed missionId,
        address indexed user
    );


    event MissionDisabled(
        uint256 indexed missionId
    );

    IERC20 public tlm;
    DummyERC721 public erc721;

    mapping(address => mapping(uint256 => LaunchedMission[])) public launchedMissions;
    mapping(address => uint256[]) public userLaunchedMissionIds;
    address[] public usersLaunchedMission;
    mapping(address => bool) public usersLaunchedMissionControl;

    Mission[] public missions;


    /** @dev add mission with configurations
     *
     * Emits a {MissionAdded} event
     *
     *
     * Requirements:
     *
     * Admin only access
     * bnbSuperCharge array must be 4 elements
     *
     */
    function addMission(uint256 start, uint256 launchDate, uint256 rewardTLM, string memory tokenURI, uint256 missionCost, uint256 missionLength, uint256[] memory bnbSuperCharge, string memory description, string memory name) external {
        require(hasRole(DEFAULT_ADMIN_ROLE, _msgSender()), "SpaceshipStacking: must have admin role to add mission.");
        require(bnbSuperCharge.length == 4, "BNB supercharge config array must be 4 elements.");

        uint256 missionId = missions.length;

        missions.push(Mission({
        startDate : start,
        launchDate : launchDate,
        rewardTLM : rewardTLM,
        tokenURI: tokenURI,
        missionCost : missionCost,
        missionLength : missionLength,
        bnbSuperCharge : bnbSuperCharge,
        description : description,
        name : name,
        isActive : true
        }));

        emit MissionAdded(missionId);
    }

    /** @dev Disables a mission which will close it to start mission
     *
     * Emits a {MissionDisabled} event
     *
     *
     * Requirements:
     *
     * Admin only access
     *
     */
    function disableMission(uint256 missionId) external {
        require(hasRole(DEFAULT_ADMIN_ROLE, _msgSender()), "SpaceshipStacking: must have admin role to disable mission");

        Mission storage mission = missions[missionId];
        require(mission.isActive, "Mission must be active");
        mission.isActive = false;
        emit MissionDisabled(missionId);
    }

    /** @dev Starts a mission between start and launch time
     *
     * Emits a {MissionStarted} event
     *
     * User can send BNB to boost TLM rewards.
     +
     * Requirements:
     *
     * If not before launch date time then error
     * If Spaceships and TLM amount do not match then error
     * If Mission Ref/Number not valid then error
     *
     */
    function startMission(uint256 missionId, uint256 spaceShipCount) external payable {
        require(spaceShipCount > 0, "You must send at least one ship.");
        Mission storage mission = missions[missionId];
        require(mission.isActive, "Mission must be active.");
        require(mission.startDate < block.timestamp, "Mission has not started yet.");
        require(mission.launchDate > block.timestamp, "Mission has been already launched.");
        tlm.transferFrom(msg.sender, address(this), mission.missionCost.mul(spaceShipCount));
        if (launchedMissions[msg.sender][missionId].length == 0) {
            userLaunchedMissionIds[msg.sender].push(missionId);
        }

        if (usersLaunchedMissionControl[msg.sender] == false) {
            usersLaunchedMissionControl[msg.sender] = true;
            usersLaunchedMission.push(msg.sender);
        }
        LaunchedMission memory launchedMission;
        launchedMission.bnbStake = msg.value;
        launchedMission.spaceShipCount = spaceShipCount;

        launchedMissions[msg.sender][missionId].push(launchedMission);
        emit  MissionStarted(
            missionId,
            msg.sender
        );
    }

    /** @dev claims mission reward after mission ends
     *  user gets staked TLM tokens and reward plus staked BNB coins
     * Emits a {RewardClaimed} event
     *
     * Requirements:
     *
     * User can not claim reward twice
     * Blocktime must be mission launchDate plus missionLength
     *
     */
    function claimReward(uint256 missionId, uint256 missionIndex) external {
        Mission storage mission = missions[missionId];
        require(block.timestamp > mission.launchDate.add(mission.missionLength), "Mission has not finished yet.");
        LaunchedMission storage launchedMission = launchedMissions[msg.sender][missionId][missionIndex];
        require(launchedMission.spaceShipCount > 0, "You did not joined the mission.");
        require(launchedMission.rewardClaimed == false, "Mission reward has already been claimed.");

        launchedMission.rewardClaimed = true;
        uint256 reward = launchedMission.spaceShipCount.mul(mission.rewardTLM).mul(calculateBoostMultiplier(mission.bnbSuperCharge, launchedMission.bnbStake));
        uint256 totalTlmToTransferBack = mission.missionCost.mul(launchedMission.spaceShipCount).add(reward);

        tlm.transfer(msg.sender, totalTlmToTransferBack);
        msg.sender.transfer(launchedMission.bnbStake);

        emit  RewardClaimed(
            missionId,
            msg.sender
        );
    }

    /** @dev claims mission reward token after mission ends
     *  contracts mints token from set ERC721 contract
     * ERC721 Emits a {Transfer} event
     *
     * Requirements:
     *
     * User can not claim token twice.
     * User has to claim reward first.
     * User can claim max 5 token from one mission.
     *
     */
    function claimToken(uint256 missionId, uint256 missionIndex) external {
        LaunchedMission storage launchedMission = launchedMissions[msg.sender][missionId][missionIndex];
        require(launchedMission.rewardClaimed == true, "Mission reward needs to be claimed first.");
        require(launchedMission.tokenMinted == 0, "Tokens already minted for this launch.");
        Mission storage mission = missions[missionId];

        uint8 totalMintedTokens = 0;
        for (uint i = 0; i < launchedMissions[msg.sender][missionId].length; i++) {
            totalMintedTokens += launchedMissions[msg.sender][missionId][i].tokenMinted;
        }
        require(totalMintedTokens < 5, "You can not get more than 5 tokens for a mission.");
        uint8 tokenCanBeMint = 5 - totalMintedTokens;

        if (launchedMission.spaceShipCount < tokenCanBeMint) {
            tokenCanBeMint = uint8(launchedMission.spaceShipCount);
        }
        launchedMission.tokenMinted = tokenCanBeMint;
        for (uint i = 0; i < tokenCanBeMint; i++) {
            uint256 tokenId = erc721.mint(msg.sender);
            erc721.setTokenURI(tokenId, mission.tokenURI);
        }
    }

    function calculateBoostMultiplier(uint256[] memory bnbSuperCharge, uint256 bnbValue) public pure returns (uint256){
        for (uint i = bnbSuperCharge.length; i > 0; i--) {
            if (bnbValue >= bnbSuperCharge[i - 1]) {
                return i + 1;
            }
        }
        return 1;
    }

    function getMissionCount() public view returns (uint256) {
        return missions.length;
    }

    function getLaunchedMissionIdsCountForUser(address user) public view returns (uint256) {
        return userLaunchedMissionIds[user].length;
    }

    function getLaunchedMissionPerMissionIdsCountForUser(address user, uint256 missionId) public view returns (uint256) {
        return launchedMissions[user][missionId].length;
    }

    function getUsersLaunchedMission() public view returns (uint256) {
        return usersLaunchedMission.length;
    }

    function getLaunchedMissionOfUser(address user, uint256 missionId, uint256 index) public view returns (uint256, uint256, bool, uint8) {
        return (launchedMissions[user][missionId][index].bnbStake,
        launchedMissions[user][missionId][index].spaceShipCount,
        launchedMissions[user][missionId][index].rewardClaimed,
        launchedMissions[user][missionId][index].tokenMinted);
    }
}
