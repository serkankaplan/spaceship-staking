const {expect} = require("chai");
const {BN, expectEvent, expectRevert, time} = require('@openzeppelin/test-helpers');
const DummyERC20 = artifacts.require("DummyERC20");
const DummyERC721 = artifacts.require("DummyERC721");
const SpaceshipStacking = artifacts.require("SpaceshipStacking");


describe("ERC721", function () {
    var dummyERC20;
    var dummyERC721;

    before(async function () {
        dummyERC20 = await DummyERC20.new("dummy", "dy", 100000000);
        dummyERC721 = await DummyERC721.new();
    });

    it("Should be able to deploy Staking contract", async function () {
        const spaceshipStacking = await SpaceshipStacking.new(dummyERC20.address);
        expect(await spaceshipStacking.tlm()).to.equal(dummyERC20.address);
    });

    it("Should be able to add a mission to the Staking contract", async function () {
        const spaceshipStacking = await SpaceshipStacking.new(dummyERC20.address);

        const receipt = await spaceshipStacking.addMission(Math.floor(Date.now() / 1000),
            Math.floor(Date.now() / 1000) + 60 * 60 * 24,
            100, 1000, 10 * 60,
            [5, 10, 50, 250], "an awesome mission with big profit", "First Mission");
        expectEvent(receipt, 'MissionAdded');
    });

    it("Should not be able to add a mission as a non admin to the Staking contract", async function () {
        const spaceshipStacking = await SpaceshipStacking.new(dummyERC20.address);
        const [owner, addr1] = await web3.eth.getAccounts();

        await expectRevert(spaceshipStacking.addMission(Math.floor(Date.now() / 1000),
            Math.floor(Date.now() / 1000) + 60 * 60 * 24,
            100, 1000, 10 * 60,
            [5, 10, 50, 250], "an awesome mission with big profit", "First Mission"
            , {from: addr1}),
            "SpaceshipStacking: must have admin role to add mission.");
    });

    it("Should not be able to add a mission with boost array less than 4 to the Staking contract", async function () {
        const spaceshipStacking = await SpaceshipStacking.new(dummyERC20.address);

        await expectRevert(spaceshipStacking.addMission(Math.floor(Date.now() / 1000),
            Math.floor(Date.now() / 1000) + 60 * 60 * 24,
            100, 1000, 10 * 60,
            [5, 10, 50], "an awesome mission with big profit", "First Mission"),
            "BNB supercharge config array must be 4 elements.");
    });

    it("Should not be able to add a mission with boost array more than 4 to the Staking contract", async function () {
        const spaceshipStacking = await SpaceshipStacking.new(dummyERC20.address);

        await expectRevert(spaceshipStacking.addMission(Math.floor(Date.now() / 1000),
            Math.floor(Date.now() / 1000) + 60 * 60 * 24,
            100, 1000, 10 * 60,
            [5, 10, 50, 250, 500], "an awesome mission with big profit", "First Mission"),
            "BNB supercharge config array must be 4 elements.");
    });

    it("Should be able to get mission count of Staking contract", async function () {
        const spaceshipStacking = await SpaceshipStacking.new(dummyERC20.address);

        await spaceshipStacking.addMission(Math.floor(Date.now() / 1000),
            Math.floor(Date.now() / 1000) + 60 * 60 * 24,
            100, 1000, 10 * 60,
            [5, 10, 50, 250], "an awesome mission with big profit", "First Mission");
        const missionCount = await spaceshipStacking.getMissionCount()

        expect(missionCount.toNumber()).to.equal(1);
    });

    it("Should be able to start a mission from the Staking contract", async function () {
        const spaceshipStacking = await SpaceshipStacking.new(dummyERC20.address);

        const [owner, addr1] = await web3.eth.getAccounts();

        const missionCost = 1000;
        const shipCount = 3;
        await dummyERC20.transfer(addr1, missionCost * shipCount);

        await dummyERC20.approve(spaceshipStacking.address, missionCost * shipCount, {from: addr1});

        await spaceshipStacking.addMission(Math.floor(Date.now() / 1000),
            Math.floor(Date.now() / 1000) + 60 * 60 * 24,
            100, missionCost, 10 * 60,
            [5, 10, 50, 250], "an awesome mission with big profit", "First Mission");

        time.increase(60 * 60);

        const receipt = await spaceshipStacking.startMission(0, shipCount, {from: addr1})
        expectEvent(receipt, 'MissionStarted', {missionId: "0", user: addr1});

    });

    it("Should not be able to start a mission before start date from the Staking contract", async function () {
        const spaceshipStacking = await SpaceshipStacking.new(dummyERC20.address);

        const [owner, addr1] = await web3.eth.getAccounts();

        const missionCost = 1000;
        const shipCount = 3;
        await dummyERC20.transfer(addr1, missionCost * shipCount);

        await dummyERC20.approve(spaceshipStacking.address, missionCost * shipCount, {from: addr1});

        await spaceshipStacking.addMission(Math.floor(Date.now() / 1000) + 60 * 60 * 12,
            Math.floor(Date.now() / 1000) + 60 * 60 * 24,
            100, missionCost, 10 * 60,
            [5, 10, 50, 250], "an awesome mission with big profit", "First Mission");

        await expectRevert(spaceshipStacking.startMission(0, shipCount, {from: addr1}),
            "Mission has not started yet.")
    });

    it("Should not be able to start a mission after launch date from the Staking contract", async function () {
        const spaceshipStacking = await SpaceshipStacking.new(dummyERC20.address);

        const [owner, addr1] = await web3.eth.getAccounts();

        const missionCost = 1000;
        const shipCount = 3;
        await dummyERC20.transfer(addr1, missionCost * shipCount);

        await dummyERC20.approve(spaceshipStacking.address, missionCost * shipCount, {from: addr1});

        await spaceshipStacking.addMission(Math.floor(Date.now() / 1000) + 60 * 60 * 12,
            Math.floor(Date.now() / 1000) + 60 * 60 * 24,
            100, missionCost, 10 * 60,
            [5, 10, 50, 250], "an awesome mission with big profit", "First Mission");

        time.increase(25 * 60 * 60);

        await expectRevert(spaceshipStacking.startMission(0, shipCount, {from: addr1}),
            "Mission has been already launched.")
    });

    it("Should not be able to start a disabled mission from the Staking contract", async function () {
        const spaceshipStacking = await SpaceshipStacking.new(dummyERC20.address);

        const [owner, addr1] = await web3.eth.getAccounts();

        const missionCost = 1000;
        const shipCount = 3;
        await dummyERC20.transfer(addr1, missionCost * shipCount);

        await dummyERC20.approve(spaceshipStacking.address, missionCost * shipCount, {from: addr1});

        await spaceshipStacking.addMission(Math.floor(Date.now() / 1000),
            Math.floor(Date.now() / 1000) + 60 * 60 * 24,
            100, missionCost, 10 * 60,
            [5, 10, 50, 250], "an awesome mission with big profit", "First Mission");

        await spaceshipStacking.disableMission(0)
        time.increase(60 * 60);

        await expectRevert(spaceshipStacking.startMission(0, shipCount, {from: addr1}),
            " Mission must be active.")
    });

    it("Should be able to start same mission from the Staking contract more than once", async function () {
        const spaceshipStacking = await SpaceshipStacking.new(dummyERC20.address);

        const [owner, addr1] = await web3.eth.getAccounts();

        const missionCost = 1000;
        const shipCount = 3;

        const receipt = await spaceshipStacking.addMission(Math.floor(Date.now() / 1000),
            Math.floor(Date.now() / 1000) + 60 * 60 * 48,
            100, missionCost, 10 * 60,
            [5, 10, 50, 250], "an awesome mission with big profit", "First Mission");

        const missionId = receipt.logs[0].args.missionId.toNumber();
        time.increase(60 * 60);

        await startMission(dummyERC20, addr1, missionId,  missionCost, shipCount, spaceshipStacking);

        await startMission(dummyERC20, addr1, missionId, missionCost, shipCount, spaceshipStacking);

    });

    it("Should be able to start mission from the Staking contract with BNB transfer", async function () {
        const spaceshipStacking = await SpaceshipStacking.new(dummyERC20.address);

        const [owner, addr1] = await web3.eth.getAccounts();

        const missionCost = 1000;
        const shipCount = 3;

        const receipt = await spaceshipStacking.addMission(Math.floor(Date.now() / 1000),
            Math.floor(Date.now() / 1000) + 60 * 60 * 48,
            100, missionCost, 10 * 60,
            [5, 10, 50, 250], "an awesome mission with big profit", "First Mission");

        const missionId = receipt.logs[0].args.missionId.toNumber();

        time.increase(60 * 60);
        await startMission(dummyERC20, addr1, missionId, missionCost, shipCount, spaceshipStacking, 5 * 10 ** 18);

        const contractBalance = await web3.eth.getBalance(spaceshipStacking.address)
        expect(parseInt(contractBalance)).to.equal(5*10**18);

    });

    it("Should be able to read started mission of a user from the Staking contract", async function () {
        const spaceshipStacking = await SpaceshipStacking.new(dummyERC20.address);

        const [owner, addr1] = await web3.eth.getAccounts();

        const missionCost = 1000;
        const shipCount = 3;

        const receipt1 = await spaceshipStacking.addMission(Math.floor(Date.now() / 1000),
            Math.floor(Date.now() / 1000) + 60 * 60 * 48,
            100, missionCost, 10 * 60,
            [5, 10, 50, 250], "an awesome mission with big profit", "First Mission");
        const missionId1 = receipt1.logs[0].args.missionId.toNumber();

        const receipt2 = await spaceshipStacking.addMission(Math.floor(Date.now() / 1000),
            Math.floor(Date.now() / 1000) + 60 * 60 * 48,
            100, missionCost, 10 * 60,
            [5, 10, 50, 250], "an awesome mission with big profit", "First Mission");
        const missionId2 = receipt2.logs[0].args.missionId.toNumber();

        time.increase(60 * 60);
        const shipCountSecondMission = 6
        await startMission(dummyERC20, addr1, missionId1,  missionCost, shipCount, spaceshipStacking, 1 * 10 ** 18);
        await startMission(dummyERC20, addr1, missionId1,  missionCost, shipCount, spaceshipStacking, 2 * 10 ** 18);
        await startMission(dummyERC20, addr1, missionId2,  missionCost, shipCountSecondMission, spaceshipStacking, 3 * 10 ** 18);

        const missionCount = await spaceshipStacking.getMissionCount()
        expect(parseInt(missionCount)).to.equal(2);
        const usersLaunchedMission = await spaceshipStacking.getUsersLaunchedMission()
        expect(parseInt(usersLaunchedMission)).to.equal(1);

        const startedInFirstMission = await spaceshipStacking.getLaunchedMissionPerMissionIdsCountForUser(addr1, missionId1)
        expect(parseInt(startedInFirstMission)).to.equal(2);

        const startedInSecondMission = await spaceshipStacking.getLaunchedMissionPerMissionIdsCountForUser(addr1, missionId2)
        expect(parseInt(startedInSecondMission)).to.equal(1);

        const launchedMissionOfUser = await spaceshipStacking.getLaunchedMissionOfUser(addr1, missionId2, 0)
        expect(launchedMissionOfUser[1].toString()).to.equal((3 * 10 ** 18).toString());
        expect(launchedMissionOfUser[2].toNumber()).to.equal(shipCountSecondMission);
        expect(launchedMissionOfUser[3]).to.equal(false);
        expect(launchedMissionOfUser[4]).to.equal(false);

    });

});

async function startMission(dummyERC20, addr1, missionId,  missionCost, shipCount, spaceshipStacking, bnb) {
    await dummyERC20.transfer(addr1, missionCost * shipCount);
    await dummyERC20.approve(spaceshipStacking.address, missionCost * shipCount * 2, {from: addr1});
    const receipt = await spaceshipStacking.startMission(missionId, shipCount, {from: addr1, value: bnb})
    expectEvent(receipt, 'MissionStarted', {missionId: missionId.toString(), user: addr1});
}

