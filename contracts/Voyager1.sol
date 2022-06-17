//SPDX-License-Identfier: UNLICESEND

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/interfaces/IERC721.sol";
import "@openzeppelin/contracts/interfaces/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./RaritySigner.sol";
contract Voyager1 is Ownable,RaritySigner{

    IERC721 PUFF;
    IERC20 xGRAV;
    IERC20 GRAV;

    struct tokenInfo{
        uint[] tokens;
        uint timestaked;
        uint amount;
        uint position;
    }

    struct resultInfo{
        uint[] tokens;
        uint amount;
        bool win;
    }

    uint public feeBalance;
    uint public FEE = 20; //20 % Fee

    uint public voyageSuccess = 10;
    uint public bonus = 5;
    uint public lockTime = 1 days;

    address designatedSigner = 0x08042c118719C9889A4aD70bc0D3644fBe288153;

    mapping(uint=>uint) public tokenRarity;
    mapping(address=>mapping(uint=>tokenInfo)) stakeInfo;
    mapping(address=>uint) public voyageId;
    mapping(address=>uint[]) public userStaked;
    mapping(address=>uint[]) public userEnded;
    mapping(address=>mapping(uint=>resultInfo)) public result;

    bool public Paused;


    event VoyageStarted(address indexed user,uint[] tokenIds,uint voyageId,uint price);
    event Result(address indexed user,uint indexed voyageId,bool win,uint amountGrav);

    constructor(address _puff,address _xgrav,address _grav){
        PUFF = IERC721(_puff);
        xGRAV = IERC20(_xgrav);
        GRAV = IERC20(_grav);
    }

    function initializePuff(Rarity[] memory rarities) external {
        for(uint i=0;i<rarities.length;i++){
            require(getSigner(rarities[i])==designatedSigner,"Invalid signer");
            tokenRarity[rarities[i].tokenId] = rarities[i].rarity;
        }
    }

    function startVoyage(uint[][] memory tokenIds,uint[] memory price) external {
        require(!Paused,"Execution paused");
        require(tokenIds.length == price.length,"Length mismatch");
        require(msg.sender == tx.origin,"sender not origin");
        uint length  = tokenIds.length;
        uint amount = 0;
        for(uint i=0;i<length;i++){
            require(price[i] == 1 || price[i] == 2,"Invalid price");
            require(tokenIds[i].length > 0,"Can't send no puffs");
            voyageId[msg.sender]++;
            amount += tokenIds[i].length * price[i] * 1 ether;
            uint inLength = tokenIds[i].length;
            for(uint j=0;j<inLength;j++){
                require(PUFF.ownerOf(tokenIds[i][j])==msg.sender,"Not owner");
                require(tokenRarity[tokenIds[i][j]]!= 0,"Rarity not set");
                PUFF.transferFrom(msg.sender,address(this),tokenIds[i][j]);
            }
            uint[] memory tokenArray = new uint[](inLength);
            tokenArray = tokenIds[i];
            stakeInfo[msg.sender][voyageId[msg.sender]] = tokenInfo(tokenArray,block.timestamp,price[i],userStaked[msg.sender].length);
            userStaked[msg.sender].push(voyageId[msg.sender]);
            emit VoyageStarted(msg.sender, tokenIds[i], voyageId[msg.sender], price[i]);
        }
        feeBalance += amount * FEE/100;
        amount += amount * FEE/100;
        require(xGRAV.transferFrom(msg.sender,address(this),amount),"xGrav transfer failed");
    }

    function endVoyage(uint[] memory voyageIds) external {
        uint length = voyageIds.length;
        require(length < 60,"Can't end more than 60 batches");
        uint Grav;
        uint xGrav;
        uint random = uint(vrf());
        for(uint i=0;i<length;i++){
            tokenInfo storage currToken = stakeInfo[msg.sender][voyageIds[i]];
            require(block.timestamp - currToken.timestaked >= currToken.amount * lockTime,"Not ended");
            require(currToken.amount != 0,"Invalid id");
            uint inLength = currToken.tokens.length;
            uint rarityBonus;
            for(uint j=0;j<inLength;j++){
                rarityBonus += tokenRarity[currToken.tokens[j]];
                PUFF.transferFrom(address(this),msg.sender,currToken.tokens[j]);
            }
            rarityBonus /= inLength;
            uint _bonus = bonus*(rarityBonus-558412)/1670760;
            if (random % 100 < voyageSuccess + _bonus) {
                Grav += currToken.amount * inLength * 1 ether;
                result[msg.sender][voyageIds[i]] = resultInfo(currToken.tokens,currToken.amount,true);
                emit Result(msg.sender, voyageIds[i], true, currToken.amount);
            }
            else{
                xGrav += currToken.amount * inLength * 1 ether;
                result[msg.sender][voyageIds[i]] = resultInfo(currToken.tokens,currToken.amount,false);
                emit Result(msg.sender, voyageIds[i], false, currToken.amount);

            }
            popSlot(msg.sender, voyageIds[i]);
            userEnded[msg.sender].push(voyageIds[i]);
            delete stakeInfo[msg.sender][voyageIds[i]];
        }
        GRAV.transfer(msg.sender,Grav);
        xGRAV.transfer(msg.sender,xGrav);
    }

    function endEarly(uint[] memory voyageIds) external{
        uint length = voyageIds.length;
        for(uint i=0;i<length;i++){
            tokenInfo storage currToken = stakeInfo[msg.sender][voyageIds[i]];
            require(currToken.amount != 0,"Invalid id");
            require(block.timestamp - currToken.timestaked <= currToken.amount * lockTime,"Already completed");
            uint inLength = currToken.tokens.length;
            for(uint j=0;j<inLength;j++){
                PUFF.transferFrom(address(this),msg.sender,currToken.tokens[j]);
            }
            result[msg.sender][voyageIds[i]] = resultInfo(currToken.tokens,currToken.amount,false);
            popSlot(msg.sender, voyageIds[i]);
            userEnded[msg.sender].push(voyageIds[i]);
            emit Result(msg.sender, voyageIds[i], false, currToken.amount);
            delete stakeInfo[msg.sender][voyageIds[i]];
        }
    }

    function popSlot(address _user,uint _id) private {
        uint lastID = userStaked[_user][userStaked[_user].length - 1];
        uint currentPos = stakeInfo[_user][_id].position;
        userStaked[_user][currentPos] = lastID;
        stakeInfo[_user][lastID].position = currentPos;
        userStaked[_user].pop();
    }

    function vrf() private view returns (bytes32 result) {
        uint256[1] memory bn;
        bn[0] = block.number;
        assembly {
            let memPtr := mload(0x40)
            if iszero(staticcall(not(0), 0xff, bn, 0x20, memPtr, 0x20)) {
                invalid()
            }
            result := mload(memPtr)
        }
        return result;
    }

    function getUserStaked(address _user) external view returns(uint[] memory){
        return userStaked[_user];
    }

    function getUserEnded(address _user) external view returns(uint){
        return userEnded[_user].length;
    }

    function getStakeInfo(address _user,uint _voyageId) external view returns(tokenInfo memory){
        return stakeInfo[_user][_voyageId];
    }

    function getResult(address _user,uint _voyageId) external view returns(resultInfo memory){
        return result[_user][_voyageId];
    }

    function setPuff(address _puff) external onlyOwner{
        PUFF = IERC721(_puff);
    }

    function setxGrav(address _xgrav) external onlyOwner{
        xGRAV = IERC20(_xgrav);
    }

    function setGrav(address _grav) external onlyOwner{
        GRAV = IERC20(_grav);
    }

    function setSuccess(uint _success) external onlyOwner{
        voyageSuccess = _success;
    }

    function setBonus(uint _bonus) external onlyOwner{
        bonus = _bonus;
    }

    function setFee(uint _fee) external onlyOwner{
        FEE = _fee;
    }

    function setLockTime(uint _time) external onlyOwner{
        lockTime = _time;
    }

    function pauseContract(bool _pause) external onlyOwner{
        Paused = _pause;
    }

    function withdrawGrav(address _to) external onlyOwner{
        GRAV.transfer(_to,GRAV.balanceOf(address(this)));
    }

    function withdrawxGrav(address _to) external onlyOwner{
        uint amount = feeBalance;
        feeBalance = 0;
        xGRAV.transfer(_to,amount);
    }
}