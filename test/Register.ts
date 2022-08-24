import { time } from "@nomicfoundation/hardhat-network-helpers";
import { expect } from "chai";
import { ethers, upgrades } from "hardhat";
import { Register } from "../typechain-types";
import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";

describe("Register", function () {
  const ADMIN_ROLE = ethers.utils.keccak256(
    ethers.utils.toUtf8Bytes("ADMIN_ROLE")
  );
  const AUTHOR_ROLE = ethers.utils.keccak256(
    ethers.utils.toUtf8Bytes("AUTHOR_ROLE")
  );
  const EXPIRATION_TIME = 2592000;
  let admin: SignerWithAddress;
  let alice: SignerWithAddress;
  let bob: SignerWithAddress;
  let eve: SignerWithAddress;
  let tom: SignerWithAddress;

  let register: Register;

  before(async () => {
    [admin, alice, bob, eve, tom] = await ethers.getSigners();

    const Register = await ethers.getContractFactory("Register");
    register = <Register>await upgrades.deployProxy(Register);
    await register.deployed();
  });

  describe("Deployment", function () {
    it("Should set the right admin_role", async function () {
      const result = await register.hasRole(ADMIN_ROLE, admin.address);
      expect(result).to.be.equal(true);
    });
  });

  describe("C.R.U.D Test By Author", function () {
    it("Should create a list of membership", async function () {
      await register.grantRole(AUTHOR_ROLE, alice.address);
      await register
        .connect(alice)
        .create([bob.address, eve.address], ["Bob", "Eve"]);
      const now = await time.latest();
      const bobMembership = await register.get(1);
      const eveMembership = await register.get(2);
      expect(bobMembership.creationTimestamp).to.be.equal(now);
      expect(bobMembership.expirationTimestamp).to.be.equal(
        now + EXPIRATION_TIME
      );
      expect(bobMembership.user).to.be.equal(bob.address);
      expect(bobMembership.username).to.be.equal("Bob");

      expect(eveMembership.creationTimestamp).to.be.equal(now);
      expect(eveMembership.expirationTimestamp).to.be.equal(
        now + EXPIRATION_TIME
      );
      expect(eveMembership.user).to.be.equal(eve.address);
      expect(eveMembership.username).to.be.equal("Eve");
    });

    it("Should revert when a non-author creates a list of membership", async function () {
      await expect(
        register.connect(bob).create([bob.address, eve.address], ["Bob", "Eve"])
      ).to.be.revertedWith("Reg: NoAuthor");
    });

    it("Should revert when more than 2 memberships created for one user", async function () {
      await expect(
        register.connect(alice).create([bob.address], ["Bob"])
      ).to.be.revertedWith("Reg: DuplicatedMember");
    });

    it("Should update a list of membership", async function () {
      const now = await time.latest();
      await register
        .connect(alice)
        .update([1], [bob.address], ["Bob_Updated"], [now]);
      const bobMembership = await register.get(1);
      expect(bobMembership.creationTimestamp).to.be.equal(now);
      expect(bobMembership.expirationTimestamp).to.be.equal(
        now + EXPIRATION_TIME
      );
      expect(bobMembership.user).to.be.equal(bob.address);
      expect(bobMembership.username).to.be.equal("Bob_Updated");
    });

    it("Should revert when a non-author updates a list of membership", async function () {
      const now = await time.latest();
      await expect(
        register.update([1], [bob.address], ["Bob_Updated"], [now])
      ).to.be.revertedWith("Reg: NoAuthor");
    });

    it("Should revert when new membership created through update", async function () {
      const now = await time.latest();
      await expect(
        register.connect(alice).update([3], [tom.address], ["Tom"], [now])
      ).to.be.revertedWith("Reg: Unavailable");
    });

    it("Should remove a list of membership", async function () {
      await register.connect(alice).remove([1]);
      const deletedMembership = await register.get(0);
      expect(deletedMembership.user).to.be.equal(
        "0x0000000000000000000000000000000000000000"
      );
      expect(deletedMembership.username).to.be.equal("");
      expect(deletedMembership.creationTimestamp).to.be.equal(0);
      expect(deletedMembership.expirationTimestamp).to.be.equal(0);
    });

    it("Should revert when a non-author removes a list of membership", async function () {
      await expect(register.remove([2])).to.be.revertedWith("Reg: NoAuthor");
    });

    it("Should revert when non-existing membership is removed", async function () {
      await expect(register.connect(alice).remove([1])).to.be.revertedWith(
        "Reg: NoMembership"
      );
    });
  });

  describe("Update Test By User", function () {
    it("Should update username of his own membership", async function () {
      await register.connect(eve).change(2, "Eve_Updated");
    });

    it("Should revert updating username of his own membership when membership expired", async function () {
      await time.increase(2592000);
      await expect(register.connect(eve).change(2, "Eve")).to.be.revertedWith(
        "Reg: MembershipExpired"
      );
    });
  });
});
