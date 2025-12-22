import { expect, assert } from "chai";
// import { parseUnits } from "ethers";
import { ethers, network } from "hardhat";

    const DAI = "0x6B175474E89094C44Da98b954EedeAC495271d0F";
    const USDT = "0xdAC17F958D2ee523a2206206994597C13D831ec7"
    const DAI_WHALE = "0x9759A6Ac90977b93B58547b4A71c78317f391A28";


describe("Curve Swap Test", function () {
    let signers;
    let daiWhale;

    let dai;
    let usdt;

    // main contract
    let swapContract;
    let swapAddress;
    let whaleAddress;
    before(async function () {
        await network.provider.request({
            method: "hardhat_impersonateAccount",
            // method: "hardhat_impersonification",
            params: [DAI_WHALE],
        })

        await network.provider.send("hardhat_setBalance", [
            DAI_WHALE,
            "0x3635C9ADC5DEA00000" // 1000 ETH
        ]);

        daiWhale = await ethers.getSigner(DAI_WHALE);
        dai = await ethers.getContractAt("IERC20", DAI);
        usdt = await ethers.getContractAt("IERC20", USDT);
    })

    it("Should deploy contract", async function() {
        signers = await ethers.getSigners();
        const Swap = await ethers.getContractFactory("Swap");
        swapContract = await Swap.deploy();

        swapAddress = await swapContract.getAddress();
        whaleAddress = await daiWhale.getAddress();

        let owner = await swapContract.owner();
        console.log("Owner: ", owner);
    })

    // it("Should get DAI and USDT contracts", async function() {
    //     signers = await ethers.getSigners();
    //     const Swap = await ethers.getContractFactory("Swap");
    //     swapContract = await Swap.deploy();

    //     let owner = await swapContract.owner();
    //     console.log("Owner: ", owner);
    // })

    it("Should Deposit DAI", async function () {
        let balance = await dai.balanceOf(whaleAddress);
        expect(balance).to.be.gt(0n);

        await dai.connect(daiWhale).approve(swapAddress, balance);

        await swapContract.connect(daiWhale).deposit(DAI, balance);
        let daiBalance = await dai.balanceOf(swapAddress);
        expect(daiBalance == dai)
        expect(daiBalance).to.be.gt(0n);

        console.log("DAI balance: ", daiBalance)
    })

    it("Should Swap DAI for USDT", async function() {
        let daiBalance = await dai.balanceOf(swapAddress);

        console.log("DAI in contract:", daiBalance);


        await swapContract.connect(daiWhale).swap(DAI, USDT, daiBalance);

        let usdtBalance = await usdt.balanceOf(swapAddress);
        console.log("USDT Balance: ", usdtBalance);

        let usdtBalance1 = await swapContract.getBalance(whaleAddress, USDT);
        let daiBalanceAfter = await dai.balanceOf(swapAddress);
        let usdtBalanceAfter = await usdt.balanceOf(swapAddress);


        console.log("dai balance: ", daiBalanceAfter);
        console.log("usdt balance: ", usdtBalance);
        console.log("usdt balance after: ", usdtBalanceAfter);
        console.log("usdt balance in contract:", usdtBalance1);
    })

    it("Should Withdraw USDT", async function() {
        let usdtBalance = await usdt.balanceOf(swapAddress);
        let usdtBalance0 = await usdt.balanceOf(whaleAddress);

        console.log("USDT balance: ", usdtBalance);
        console.log("Swap contract address: ", swapAddress);

        await swapContract.connect(daiWhale).withdraw(USDT, usdtBalance);
        let userBalance1 = await usdt.balanceOf(whaleAddress);

        console.log("dai balance of contract: ",usdtBalance);
        console.log("added usdt balance of user: ", userBalance1 - usdtBalance0);

    })
})