pragma solidity ^0.7.0;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "hardhat/console.sol";

contract SpaceshipStacking is AccessControl {
    using SafeMath for uint256;

    constructor(address _tlmAddress) public {
        _setupRole(DEFAULT_ADMIN_ROLE, _msgSender());
        tlm = IERC20(_tlmAddress);
    }

    struct Mission {
        uint256 startDate;
        uint256 launchDate;
        uint256 rewardTLM;
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
        bool tokenMinted;
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

    mapping(address => mapping(uint256 => LaunchedMission[])) public launchedMissions;
    mapping(address => uint256[]) public userLaunchedMissionIds;
    address[] public usersLaunchedMission;
    mapping(address => bool) public usersLaunchedMissionControl;

    Mission[] public missions;


    /*
    *
    *
    *
    *
    */
    function addMission(uint256 start, uint256 launchDate, uint256 rewardTLM, uint256 missionCost, uint256 missionLength, uint256[] memory bnbSuperCharge, string memory description, string memory name) external {
        require(hasRole(DEFAULT_ADMIN_ROLE, _msgSender()), "SpaceshipStacking: must have admin role to add mission.");
        require(bnbSuperCharge.length == 4, "BNB supercharge config array must be 4 elements.");

        uint256 missionId = missions.length;

        missions.push(Mission({
        startDate : start,
        launchDate : launchDate,
        rewardTLM : rewardTLM,
        missionCost : missionCost,
        missionLength : missionLength,
        bnbSuperCharge : bnbSuperCharge,
        description : description,
        name : name,
        isActive : true
        }));

        emit MissionAdded(missionId);
    }

    function disableMission(uint256 missionId) external {
        require(hasRole(DEFAULT_ADMIN_ROLE, _msgSender()), "SpaceshipStacking: must have admin role to disable mission");

        Mission storage mission = missions[missionId];
        require(mission.isActive, "Mission must be active");
        mission.isActive = false;
        emit MissionDisabled(missionId);
    }

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

    function claimReward(uint256 missionId, uint256 missionIndex) external {
        Mission storage mission = missions[missionId];
        require(block.timestamp > mission.launchDate.add(mission.missionLength), "Mission has not finished yet.");
        LaunchedMission storage launchedMission = launchedMissions[msg.sender][missionId][missionIndex];
        require(launchedMission.rewardClaimed == false, "Mission reward has already been claimed.");

        launchedMission.rewardClaimed = true;
        uint256 reward = launchedMission.spaceShipCount.mul(mission.rewardTLM).mul(calculateBoostMultiplier(mission.bnbSuperCharge, launchedMission.bnbStake));
        uint256 totalTlmToTransferBack = mission.missionCost.mul(launchedMission.spaceShipCount).add(reward);
        tlm.transfer(msg.sender, totalTlmToTransferBack);
        msg.sender.send(launchedMission.bnbStake);

        emit  RewardClaimed(
            missionId,
            msg.sender
        );
    }

    function calculateBoostMultiplier(uint256[] memory bnbSuperCharge, uint256 bnbValue) public pure returns (uint256){
        for (uint i = bnbSuperCharge.length; i > 0; i--) {
            if (bnbValue > bnbSuperCharge[i - 1]) {
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

    function getLaunchedMissionOfUser(address user, uint256 missionId, uint256 index) public view returns (uint256, uint256, bool, bool) {
        return (launchedMissions[user][missionId][index].bnbStake,
        launchedMissions[user][missionId][index].spaceShipCount,
        launchedMissions[user][missionId][index].rewardClaimed,
        launchedMissions[user][missionId][index].tokenMinted);
    }
}
