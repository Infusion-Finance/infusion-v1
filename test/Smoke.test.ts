import 'hardhat'
import '@nomicfoundation/hardhat-ethers'
import { ethers } from "hardhat";
import { time, mine } from "@nomicfoundation/hardhat-network-helpers";
import { expect } from "chai";
import { SignerWithAddress } from "@nomicfoundation/hardhat-ethers/signers";
import { FeeDistributor, Pair, PairFactory, Router, TERC20, TokenLocker, WETH9 } from '../typechain-types';

describe("Smoke tests", () => {
  describe("Testing Infusion contracts", () => {
    const MAX_LOCK_DAYS = 30;
    let deployer: SignerWithAddress;
    let router: Router;
    let factory: PairFactory;
    let lockFactory: LockFactory;
    let weth: WETH9;
    let usdToken: TERC20;
    let usdBToken: TERC20;
    let tokenLocker: TokenLocker;
    let feeDistributor: FeeDistributor;
    let pair: TERC20;

    before(async () => {
      [deployer] = await ethers.getSigners();
      weth = await ethers.deployContract("WETH9"); // 1 * 10**18
      await weth.waitForDeployment();
      await weth.deposit({value: ethers.parseEther("1")});
      factory = await ethers.deployContract("PairFactory");
      await factory.waitForDeployment();
      lockFactory = await ethers.deployContract("LockFactory", [MAX_LOCK_DAYS]);
      await lockFactory.waitForDeployment();
      router = await ethers.deployContract("Router", [factory.target, lockFactory.target, weth.target]);
      await router.waitForDeployment();
      await lockFactory.initRouter(router.target);
      await factory.initRouter(router.target);
      usdToken = await ethers.deployContract("TERC20", ["USDT", "USDT", 1000]); // 1 * 10**18
      await usdToken.waitForDeployment();
      usdBToken = await ethers.deployContract("TERC20", ["USDC", "USDC", 1000]); // 1 * 10**18
      await usdToken.waitForDeployment();
      const pairAddr = await router.pairFor(usdBToken.target, usdToken.target, true);
      pair = await ethers.getContractAt('IERC20', pairAddr) as TERC20;
    });

    it("full flow", async () => {
      const amount = BigInt(ethers.parseEther("100"));
      console.log()
      await usdBToken.approve(router.target, amount);
      await usdToken.approve(router.target, amount);
      const lockerFeesP = 8000;
      await router.addLiquidity(
        usdBToken.target,
        usdToken.target,
        amount,
        amount,
        amount,
        amount,
        deployer.address,
        ethers.MaxUint256,
        true,
        lockerFeesP,
      );

      tokenLocker = await ethers.getContractAt('TokenLocker', await lockFactory.tokenLockers(pair)) as TokenLocker;
      feeDistributor = await ethers.getContractAt('FeeDistributor', await lockFactory.feeDistributors(pair)) as FeeDistributor;
      const lpBal = await pair.balanceOf(deployer.address);
      await pair.approve(tokenLocker.target, lpBal);
      await tokenLocker.lock(deployer.address, lpBal, 7);
      await usdBToken.approve(router.target, amount);
      await router.swapExactTokensForTokensSimple(
        amount / 4n,
        amount * 99n / 400n,
        usdBToken.target,
        usdToken.target,
        true,
        deployer.address,
        ethers.MaxUint256
      );
      await feeDistributor.depositFees();
      const lockData = await tokenLocker.getActiveUserLocks(deployer.address);
      expect(lockData.length).to.eq(1);
      expect(lockData[0][0]).to.eq(7);
      expect(lockData[0][1]).to.eq(lpBal);
      await time.setNextBlockTimestamp(Math.floor(Date.now() / 1000) + 2 * 86400);
      await mine();
      const claimable = await feeDistributor.claimable(deployer.address);
      const claimed = amount / 20000n
      expect(claimable[0] < claimed ? claimed - claimable[0] : claimable[0] - claimed).to.lt(1000000);
      const balBefore = await usdBToken.balanceOf(deployer.address);
      await feeDistributor.claim(deployer.address, [usdBToken.target, usdToken.target]);
      expect(await usdBToken.balanceOf(deployer.address)).to.eq(balBefore + claimable[0])
    });
  });
});
