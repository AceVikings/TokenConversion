const { inputToConfig } = require("@ethereum-waffle/compiler");
const { expect } = require("chai");
const { BigNumber } = require("ethers");
const { parseEther, formatEther } = require("ethers/lib/utils");
const { ethers } = require("hardhat");

describe("Quest Contract",function(){

    let NFTFactory;
    let GravFactory;
    let xGravFactory;
    let VoyagerFactory;

    let NFT;
    let Grav;
    let xGrav;
    let Voyager;

    before(async function() {

        [owner,ace,acadia] = await ethers.getSigners();

        NFTFactory = await ethers.getContractFactory("testNFT");
        GravFactory = await ethers.getContractFactory("testToken1");
        xGravFactory = await ethers.getContractFactory("testToken2");
        VoyagerFactory = await ethers.getContractFactory("Voyager1");

        NFT = await NFTFactory.deploy();
        Grav = await GravFactory.deploy();
        xGrav = await xGravFactory.deploy();
        Voyager = await VoyagerFactory.deploy(NFT.address,xGrav.address,Grav.address);

        await NFT.connect(owner).mint(20);
        await NFT.connect(owner).setApprovalForAll(Voyager.address,true);
        await xGrav.connect(owner).mint(1000);
        await xGrav.connect(owner).increaseAllowance(Voyager.address,parseEther("1000"))
        await Grav.connect(owner).mint(1000);
        await Grav.transfer(Voyager.address,parseEther("1000"));
    });

    describe("Deployment", function(){
        it("Should set the owner", async function(){
            expect(await Voyager.owner()).to.equal(owner.address);
        })
    })

    describe("Intialization",function(){
        // let rarity = [[1,1670760,"0x91369e121087da8ce3a93a8fb3130ad45da79788fda60bb017eef42ff61fc49d"],[2,1670760,"0x91369e121087da8ce3a93a8fb3130ad45da79788fda60bb017eef42ff61fc49d"]];
        let rarity = [];
        for(var i=1;i<10;i++){
            rarity.push([i,1670760,"0x91369e121087da8ce3a93a8fb3130ad45da79788fda60bb017eef42ff61fc49d"])
        }
        it("Should set token rarity", async function(){
            await Voyager.initializePuff(rarity);
            expect (await Voyager.tokenRarity(1)).to.equal(1670760);
            expect (await Voyager.tokenRarity(2)).to.equal(1670760);
            
        })
    })

    describe("Start Voyage",function(){
        let tokens = [[1,2],[3,4,5],[6],[7,8,9]];
        let price = [1,1,2,1];
        it("Should transfer tokens to contract",async function(){
            await Voyager.connect(owner).startVoyage(tokens,price);
            for(var i=1;i<10;i++){
                expect (await NFT.ownerOf(i)).to.equal(Voyager.address);
            }
        });
        it("Should update Voyage ID",async function(){
            expect ((await Voyager.voyageId(owner.address))).to.equal(4);
            // console.log((await DenariQuest.stakeInfo(1))["duration"]/3600);
        })  
        it("Should update Info mapping",async function(){
            for(var i=0;i<4;i++){
                expect((await Voyager.getStakeInfo(owner.address,i+1))["tokens"].map((value)=>{
                    return parseInt(value)
                })).to.deep.equal(tokens[i])
            }
        })
        it("Should update User Staked",async function(){
            for(var i=0;i<4;i++){
                expect((await Voyager.getUserStaked(owner.address)).map((value)=>{
                    return parseInt(value)
                })).to.include(i+1);
            }
        })
        it("Should update contract xGrav balanace",async function(){
            let balance = 0;
            for(var i=0;i<4;i++){
                balance = balance + tokens[i].length * price[i];
            }
            balance += balance * 0.2;
            expect(await xGrav.balanceOf(Voyager.address)).to.equal(parseEther(balance.toString()));
        })
        it("Should update Fee Balance",async function(){
            let balance = 0;
            for(var i=0;i<4;i++){
                balance = balance + tokens[i].length * price[i];
            }
            balance = 0.2*balance;
            expect (await Voyager.feeBalance()).to.equal(parseEther(balance.toString()));
        })
        
    })

    describe("Recover fees",function(){
        
        it("Should recover fees",async function(){
            let fees = await Voyager.feeBalance();
            let userPreBalance = await xGrav.balanceOf(owner.address);
            await Voyager.withdrawxGrav(owner.address);
            let userPostBalance = await xGrav.balanceOf(owner.address);
            expect (parseInt(userPreBalance) + parseInt(fees)).to.equal(parseInt(userPostBalance));
        })

        it("Fees should revert to 0",async function(){
            expect (await Voyager.feeBalance()).to.equal(0)
        })
    })

    describe("End Early",function(){
        it("Should return token to owner",async function(){
            await Voyager.endEarly([1]);
            for(var i=1;i<=2;i++){
                expect (await NFT.ownerOf(i)).to.equal(owner.address);
            }
        })
        it("Should remove from Staked Ids",async function(){
            expect((await Voyager.getUserStaked(owner.address)).map((value)=>{
                return parseInt(value)
            })).to.not.include(1);
        })
        it("Should delete mapping",async function(){
            expect ((await Voyager.getStakeInfo(owner.address,1))["tokens"]).to.deep.equal([])
        })
        it("Should update result",async function(){
            expect ((await Voyager.getResult(owner.address,1))["win"]).to.equal(false);
            expect (((await Voyager.getResult(owner.address,1))["tokens"]).map((value)=>{
                return parseInt(value)
            })).to.deep.equal([1,2]);
        })
        
    })

    describe("End on time",function(){
        it("Should fail if it's not time",async function(){
            await expect (Voyager.endVoyage([2])).to.be.reverted;
        })
        it("Should return token to owner",async function(){
            await network.provider.send("evm_increaseTime", [24*60*60 + 1])
            await Voyager.endVoyage([2]);
            for(var i = 3;i<6;i++){
                expect (await NFT.ownerOf(i)).to.equal(owner.address);
            }
        })
        it("Should remove from Staked Ids",async function(){
            expect((await Voyager.getUserStaked(owner.address)).map((value)=>{
                return parseInt(value)
            })).to.not.include(2);
        })
        it("Should delete mappings",async function(){
            expect ((await Voyager.getStakeInfo(owner.address,2))["tokens"]).to.deep.equal([])
        })
        it("Should update result",async function(){
            expect ((await Voyager.getResult(owner.address,2))["win"]).to.equal(true);
            expect (((await Voyager.getResult(owner.address,2))["tokens"]).map((value)=>{
                return parseInt(value)
            })).to.deep.equal([3,4,5]);
        })
        it("Should send rewards",async function(){
            expect (await Grav.balanceOf(owner.address)).to.equal(parseEther("3"))
        })
        it("Should wait as many days as amount",async function(){
            await expect (Voyager.endVoyage([3])).to.be.reverted;
            await network.provider.send("evm_increaseTime", [24*60*60 + 1])
            await expect (Voyager.endVoyage([3])).to.not.be.reverted;
        })
        

    })


})