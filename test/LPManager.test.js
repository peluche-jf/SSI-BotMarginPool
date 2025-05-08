const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("LPManager", function () {
  let lpManager;
  let owner;
  let addr1;

  beforeEach(async function () {
    [owner, addr1] = await ethers.getSigners();
    const LPManager = await ethers.getContractFactory("LPManager");
    lpManager = await LPManager.deploy();
  });

  describe("Deployment", function () {
    it("Should set the right owner", async function () {
      expect(await lpManager.owner()).to.equal(owner.address);
    });
  });

  describe("POL Deposits", function () {
    it("Should record POL deposit correctly", async function () {
      const polAmount = 100;
      await lpManager.connect(addr1).handlePOLDeposit(polAmount);
      expect(await lpManager.polDeposits(polAmount)).to.equal(addr1.address);
    });
  });
}); 