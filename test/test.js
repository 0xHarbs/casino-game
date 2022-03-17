const { expect } = require("chai");

const vrfCoordinator = "0xb3dCcb4Cf7a26f6cf6B120Cf5A73875B7BBc655B";
const linkToken = "0x01BE23585060835E02B77ef475b0Cc51aA1e0709";
const vrfKeyHash = "0x2ed0feb3e7fd2022120aa84fab1945545a9f2ffc9076fd6156fa96eaff4c1311";

describe('NFTDAO', function () {
    let Contract, contract, owner, addr1, addr2;

    beforeEach(async () => {
        Contract = await ethers.getContractFactory('Roulette');
        contract = await Contract.deploy(vrfCoordinator, linkToken, vrfKeyHash);
        await contract.deployed();
        [owner, addr1, addr2, _] = await ethers.getSigners();
    });

    describe('Deployment', () => {
        it('should set the correct owner', async () => {
            expect(await contract.owner()).to.equal(owner.address);
        })
    })
    describe('Betting', () => {
        it("should top up balance", async () => {
            await contract.addBalance({ value: ethers.utils.parseEther("0.1") }) // msg.value is 0.1 ether
            const balance0 = await contract.balance(owner.address);
            expect(balance0.toString()).to.equal("100000000000000000")
        })
        it("should bet on game", async () => {
            await contract.addBalance({ value: ethers.utils.parseEther("0.2") }) // msg.value is 0.1 ether
            await contract.betOnSpin(1, 0);
            const bet0 = await contract.bets(0);
        })
        it("should withdraw funds", async () => {
            await contract.addBalance({ value: ethers.utils.parseEther("0.2") }) // msg.value is 0.1 ether
            await contract.withdraw(ethers.utils.parseEther("0.1"))
            const balance0 = await contract.balance(owner.address);
            expect(balance0.toString()).to.equal("100000000000000000");
        })
    })
    describe("Randomness", () => {
        it("should generate winner", async () => {
            await contract.addBalance({ value: ethers.utils.parseEther("0.2") }) // msg.value is 0.1 ether
            await contract.betOnSpin(1, 0);
            await contract.spinWheel()
            expect(contract.balanceRequired()).to.equal(0);
        })
    })
});