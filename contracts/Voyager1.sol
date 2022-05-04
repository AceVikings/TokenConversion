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
    uint public FEE;

    uint voyageSuccess = 10;

    address designatedSigner = 0x08042c118719C9889A4aD70bc0D3644fBe288153;

    mapping(uint=>uint) public tokenRarity;
    mapping(address=>mapping(uint=>tokenInfo)) public stakeInfo;
    mapping(address=>uint) public voyageId;
    mapping(address=>uint[]) public userStaked;
    mapping(address=>mapping(uint=>resultInfo)) public result;

    bool public Paused;

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
        require(tokenIds.length == price.length,"Length mismatch");
        require(msg.sender == tx.origin,"sender not origin");
        uint length  = tokenIds.length;
        uint amount = 0;
        for(uint i=0;i<length;i++){
            require(price[i] == 1 || price[i] == 2,"Invalid price");
            voyageId[msg.sender]++;
            amount += tokenIds[i].length * price[i] * 1 ether;
            uint inLength = tokenIds[i].length;
            for(uint j=0;i<inLength;i++){
                require(PUFF.ownerOf(tokenIds[i][j])==msg.sender,"Not owner");
            }
            stakeInfo[msg.sender][voyageId[msg.sender]] = tokenInfo(tokenIds[i],block.timestamp,price[i],userStaked[msg.sender].length);
            userStaked[msg.sender].push(voyageId[msg.sender]);
        }
        feeBalance += amount * FEE/100;
        amount += amount * FEE/100;
        require(xGRAV.transferFrom(msg.sender,address(this),amount));
    }

    function endVoyage(uint[] memory voyageIds) external {
        uint length = voyageIds.length;
        require(length < 60,"Can't end more than 60 batches");
        uint Grav;
        uint xGrav;
        uint random = uint(vrf());
        for(uint i=0;i<length;i++){
            tokenInfo storage currToken = stakeInfo[msg.sender][voyageIds[i]];
            require(block.timestamp - currToken.timestaked >= currToken.amount * 1 days);
            uint inLength = currToken.tokens.length;
            uint rarityBonus;
            for(uint j=0;i<inLength;i++){
                rarityBonus += tokenRarity[currToken.tokens[j]];
                PUFF.transferFrom(address(this),msg.sender,currToken.tokens[j]);
            }
            rarityBonus /= inLength;
            uint bonus = 5*(rarityBonus-558412)/1670760;
            if (random % 100 < voyageSuccess + bonus) {
                Grav += currToken.amount * inLength * 1 ether;
                result[msg.sender][voyageIds[i]] = resultInfo(currToken.tokens,currToken.amount,true);
            }
            else{
                xGrav += currToken.amount * inLength * 1 ether;
                result[msg.sender][voyageIds[i]] = resultInfo(currToken.tokens,currToken.amount,false);
            }
            popSlot(msg.sender, voyageIds[i]);
        }
        GRAV.transfer(msg.sender,Grav);
        xGRAV.transfer(msg.sender,xGrav);
    }

    function endEarly(uint[] memory voyageIds) external{
        uint length = voyageIds.length;
        for(uint i=0;i<length;i++){
            tokenInfo storage currToken = stakeInfo[msg.sender][voyageIds[i]];
            require(block.timestamp - currToken.timestaked >= currToken.amount * 1 days);
            uint inLength = currToken.tokens.length;
            for(uint j=0;i<inLength;i++){
                PUFF.transferFrom(address(this),msg.sender,currToken.tokens[j]);
            }
            popSlot(msg.sender, voyageIds[i]);
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