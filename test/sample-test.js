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

        await expectRevert( spaceshipStacking.addMission(Math.floor(Date.now() / 1000),
            Math.floor(Date.now() / 1000) + 60 * 60 * 24,
            100, 1000, 10 * 60,
            [5, 10, 50, 250], "an awesome mission with big profit", "First Mission"
            , {from: addr1}),
            "SpaceshipStacking: must have admin role to add mission.");
    });

    it("Should not be able to add a mission with boost array less than 4 to the Staking contract", async function () {
        const spaceshipStacking = await SpaceshipStacking.new(dummyERC20.address);

        await expectRevert( spaceshipStacking.addMission(Math.floor(Date.now() / 1000),
            Math.floor(Date.now() / 1000) + 60 * 60 * 24,
            100, 1000, 10 * 60,
            [5, 10, 50], "an awesome mission with big profit", "First Mission"),
            "BNB supercharge config array must be 4 elements.");
    });

    it("Should not be able to add a mission with boost array more than 4 to the Staking contract", async function () {
        const spaceshipStacking = await SpaceshipStacking.new(dummyERC20.address);

        await expectRevert( spaceshipStacking.addMission(Math.floor(Date.now() / 1000),
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


});
